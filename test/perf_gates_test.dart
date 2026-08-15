@TestOn('vm')
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';

/// 性能门禁（perf gates）固化：静态扫描 lib/screens/（递归）与
/// lib/widgets/（顶层），不运行任何 widget、不触碰产品代码。
///
/// P1 懒构建门禁（严格，违规即失败）：
///   数据驱动列表禁止用 `SingleChildScrollView + Column(children: [
///   for/map...])` 模式全量构建大列表。豁免仅限三类——固定内容、
///   对话框、表格包装——登记在 [_lazyExemptions]，并带 stale 检测：
///   已登记但不再命中的豁免会失败，强制清单诚实。
///
/// P2 build 方法规模（警告级，报告不失败，未来收紧）：
///   block-bodied `Widget build(` 方法体（花括号之间，不含注释影响）
///   超过 [_buildBodyWarningLines]（当前 100）行即列入报告。
///   阈值收紧时仅改常量即可。
///
/// P3 const 启发式（宽松，报告不失败）：
///   静态启发式抽样：单行、全部参数为字面量的可 const 构造未写
///   const（EdgeInsets/SizedBox/Text/Icon/Divider 等 6 类）。仅报告，
///   未来可在代码库推进 const 化后收紧为硬门禁。
///
/// 报告：docs/ui/pages-per-page/perf-gates.md（扫描结果随测试输出，
/// 文档记录当前基线）。
void main() {
  group('P1 懒构建门禁（严格）', () {
    test('数据驱动列表不得用 SingleChildScrollView + Column + for/map 全量构建', () {
      final violations = <String>[];
      final matchedExemptions = <String>{};
      for (final path in _scannedFiles()) {
        final source = File(path).readAsStringSync();
        for (final hit in _lazyPatternHits(path, source)) {
          // 命中禁用模式：查豁免清单（键 = 文件|所在方法）。
          if (_lazyExemptions.containsKey(hit.key)) {
            matchedExemptions.add(hit.key);
            continue;
          }
          violations.add(
            '$path:${hit.line} （方法 ${hit.method}）: '
            'SingleChildScrollView + Column + children: [for/map]',
          );
        }
      }
      expect(
        violations,
        isEmpty,
        reason:
            '数据驱动列表必须懒构建（ListView.builder）；固定内容/对话框/'
            '表格包装请登记到 _lazyExemptions 并更新质量门禁报告：\n'
            '${violations.join('\n')}',
      );
      final stale =
          _lazyExemptions.keys
              .where((key) => !matchedExemptions.contains(key))
              .toList()
            ..sort();
      expect(
        stale,
        isEmpty,
        reason:
            '以下懒构建豁免条目已失配（模式已消除或文件改动），请从 '
            '_lazyExemptions 移除：\n${stale.join('\n')}',
      );
    });
  });

  group('P2 build 方法规模（警告级，报告不失败）', () {
    test('build 方法体超过 100 行：输出关注清单（不失败）', () {
      final findings = <({String path, int line, int body})>[];
      var totalBuilds = 0;
      var maxBody = 0;
      for (final path in _scannedFiles()) {
        final source = File(path).readAsStringSync();
        for (final method in _buildMethods(source)) {
          totalBuilds++;
          maxBody = math.max(maxBody, method.body);
          if (method.body > _buildBodyWarningLines) {
            findings.add((path: path, line: method.line, body: method.body));
          }
        }
      }
      // 报告（stdout 展示，供人工关注与未来收紧；本用例不失败）。
      findings.sort((a, b) => b.body.compareTo(a.body));
      _printReport(
        '[P2] build 方法体 > $_buildBodyWarningLines 行（警告级，报告不失败）',
        '共扫描 $totalBuilds 个 block-bodied build 方法，最大方法体 $maxBody 行；'
            '关注 ${findings.length} 处',
      );
      for (final f in findings) {
        // ignore: avoid_print
        debugPrint('  ${f.path}:${f.line}  body=${f.body} 行');
      }
      // 反例段：列出 81-100 行的临界区，便于观察未来收紧的影响面。
      final near = <({String path, int line, int body})>[];
      for (final path in _scannedFiles()) {
        final source = File(path).readAsStringSync();
        for (final method in _buildMethods(source)) {
          if (method.body > 80 && method.body <= _buildBodyWarningLines) {
            near.add((path: path, line: method.line, body: method.body));
          }
        }
      }
      near.sort((a, b) => b.body.compareTo(a.body));
      _printReport(
        '[P2] 临界区（81-$_buildBodyWarningLines 行，收紧预警）',
        '${near.length} 处',
      );
      for (final f in near.take(10)) {
        // ignore: avoid_print
        debugPrint('  ${f.path}:${f.line}  body=${f.body} 行');
      }
      // 扫描健康性：文件集非空（防扫描静默失效）。
      expect(_scannedFiles(), isNotEmpty, reason: '扫描文件集不能为空');
      expect(totalBuilds, greaterThan(0), reason: '必须扫描到 build 方法');
    });
  });

  group('P3 const 启发式（宽松，报告不失败）', () {
    test('可 const 的单行字面量构造未写 const：抽样告警（不失败）', () {
      final findings =
          <({String path, int line, String kind, String literal})>[];
      for (final path in _scannedFiles()) {
        final source = File(path).readAsStringSync();
        for (final entry in _constCandidates.entries) {
          for (final match in entry.value.allMatches(source)) {
            if (_isConstPreceded(source, match.start)) continue;
            if (_inConstContext(source, match.start)) continue;
            final literal = match.group(0)!;
            if (!_looksConstAble(entry.key, literal)) continue;
            findings.add((
              path: path,
              line: _lineOf(source, match.start),
              kind: entry.key,
              literal: literal,
            ));
          }
        }
      }
      _printReport(
        '[P3] const 启发式抽样告警（宽松，报告不失败）',
        '共 ${findings.length} 处可 const 构造（6 类启发式，仅单行全字面量参数，'
            '非穷尽；const 集合内已传导 const 的上下文可能误报）',
      );
      final byKind = <String, int>{};
      for (final f in findings) {
        byKind[f.kind] = (byKind[f.kind] ?? 0) + 1;
        // ignore: avoid_print
        debugPrint('  ${f.path}:${f.line}  ${f.kind}  ${f.literal}');
      }
      // ignore: avoid_print
      debugPrint(
        '  [按类别] ${byKind.entries.map((e) => '${e.key}: ${e.value}').join('；')}',
      );
      expect(_scannedFiles(), isNotEmpty, reason: '扫描文件集不能为空');
    });
  });

  group('扫描器自检（防启发式静默失效）', () {
    test('P1 禁用模式可被检出、固定内容不误报', () {
      // 数据驱动 for 列表：必须命中。
      const bad = '''
class _X extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          for (final item in items) ListTile(title: Text(item)),
        ],
      ),
    );
  }
}
''';
      final badHits = _lazyPatternHits('synthetic.dart', bad);
      expect(badHits, hasLength(1), reason: 'for 列表必须命中禁用模式');
      expect(badHits.single.key, 'synthetic.dart|build');

      // 固定内容（无 for/map）：必须不命中。
      const fixed = '''
class _Y extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Text('title'),
          Text('body'),
        ],
      ),
    );
  }
}
''';
      expect(
        _lazyPatternHits('synthetic.dart', fixed),
        isEmpty,
        reason: '固定内容不得命中禁用模式',
      );
    });

    test('P2 build 方法体行数统计正确（含表达式体排除）', () {
      // 手工构造：block 体 7 行、表达式体 1 行。
      const src = '''
class _Z extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text('a'),
        Text('b'),
      ],
    );
  }

  Widget buildSmall(BuildContext context) => const SizedBox.shrink();
}
''';
      final methods = _buildMethods(src);
      expect(methods, hasLength(1), reason: '表达式体 build 不计入');
      expect(methods.single.line, 3);
      expect(methods.single.body, 7, reason: '方法体行数 = 闭括号行 - 开括号行 - 1');
    });

    test('P3 const 启发式可检出真违规、排除 const 上下文', () {
      // 真违规：非 const 单行字面量。
      expect(_isConstPreceded("Text('x')", 0), isFalse);
      expect(_looksConstAble('Text(单字符串字面量)', "Text('x')"), isTrue);
      // 直接 const。
      expect(_isConstPreceded("const Text('x')", 6), isTrue);
      // 嵌入更长标识符（LocalizedText(...) 中的 Text）。
      expect(_isConstPreceded("LocalizedText('x')", 8), isTrue);
      // const 祖先传导：两层、展开列表、直接构造。
      expect(
        _inConstContext(
          'const Center(child: Padding(padding: EdgeInsets.all(32)))',
          'const Center(child: Padding(padding: '.length,
        ),
        isTrue,
        reason: '两层 const 祖先应被识别',
      );
      expect(
        _inConstContext('items: const [Text(\'a\')]', 'items: const ['.length),
        isTrue,
        reason: 'const 列表应被识别',
      );
      expect(
        _inConstContext('...const [Text(\'a\')]', '...const ['.length),
        isTrue,
        reason: '展开 const 列表应被识别',
      );
      // 非 const 上下文：不得误判。
      expect(
        _inConstContext(
          'Padding(padding: EdgeInsets.all(16))',
          'Padding(padding: '.length,
        ),
        isFalse,
        reason: '无 const 祖先不得误判',
      );
      // 数字参数校验。
      expect(_onlyNumericArgs('top: 16, right: 8'), isTrue);
      expect(_onlyNumericArgs('left: someVar'), isFalse);
      expect(_looksConstAble('Text(单字符串字面量)', r"Text('\$5')"), isFalse);
    });
  });
}

// ---------------------------------------------------------------------
// P1 懒构建门禁：模式与豁免清单（与 docs/ui/pages-per-page/perf-gates.md
// 同步；新豁免必须先审查并登记，条目失配触发 stale 失败）
// ---------------------------------------------------------------------

final _singleScrollView = RegExp(r'SingleChildScrollView');
final _columnConstructor = RegExp(r'Column\(');
final _childrenOpen = RegExp(r'children:\s*\[');
final _dataDrivenChildren = RegExp(r'for\s*\(|\.map\s*\(');

/// 禁用模式窗口：SingleChildScrollView 后 [lazyWindowLines] 行内出现
/// Column(，其 children:[ 后 [lazyWindowChars] 字符内出现 for(/map(。
/// 参数经实测对 lib/ 全量在 800-4000 区间结果稳定，仅命中豁免项。
const _lazyWindowLines = 40;
const _lazyWindowChars = 2000;

/// 懒构建豁免：键为 `文件|方法名`，值为豁免理由。当前仅表格包装类。
const _lazyExemptions = <String, String>{
  'lib/widgets/admin_data_table.dart|_cards':
      '表格包装豁免：窄视口卡片模式回退——父级固定高容器内自滚，'
      '卡片数受分页 itemCount 约束（有界）',
  'lib/widgets/admin_data_table.dart|_table':
      '表格包装豁免：表格本体——固定高容器内纵向自滚 + 宽表横向滚动，'
      '数据行受分页 itemCount 约束（有界）',
};

/// 方法定义启发式（2 空格缩进类成员），用于给命中点取所在方法名。
final _methodDef = RegExp(
  r'^\s{2}[A-Za-z_][\w<>,? ]*\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(',
);

String _methodAt(List<String> lines, int lineIndex) {
  for (var i = lineIndex; i >= 0; i--) {
    final match = _methodDef.firstMatch(lines[i]);
    if (match != null) return match.group(1)!;
  }
  return '<top-level>';
}

/// 命中禁用模式（SingleChildScrollView + Column + children: [for/map]）的
/// 全部位置；键 = `文件|方法`。窗口参数经实测在 800-4000 字符区间稳定。
List<({int line, String method, String key})> _lazyPatternHits(
  String path,
  String source,
) {
  final hits = <({int line, String method, String key})>[];
  final lines = source.split('\n');
  for (final match in _singleScrollView.allMatches(source)) {
    final lineNo = _lineOf(source, match.start);
    final windowLines = <String>[
      for (
        var i = lineNo - 1;
        i < math.min(lineNo - 1 + _lazyWindowLines, lines.length);
        i++
      )
        lines[i],
    ].join('\n');
    final columnMatch = _columnConstructor.firstMatch(windowLines);
    if (columnMatch == null) continue;
    final columnWindow = windowLines.substring(
      columnMatch.start,
      math.min(columnMatch.start + _lazyWindowChars, windowLines.length),
    );
    final childrenMatch = _childrenOpen.firstMatch(columnWindow);
    if (childrenMatch == null) continue;
    final childrenRegion = columnWindow.substring(
      childrenMatch.start,
      math.min(childrenMatch.start + _lazyWindowChars, columnWindow.length),
    );
    if (!_dataDrivenChildren.hasMatch(childrenRegion)) continue;
    final method = _methodAt(lines, lineNo - 1);
    hits.add((line: lineNo, method: method, key: '$path|$method'));
  }
  return hits;
}

// ---------------------------------------------------------------------
// P2 build 方法规模：解析与计数
// ---------------------------------------------------------------------

/// 阈值：build 方法体超过该行数即列入关注报告（当前警告级，未来收紧）。
const _buildBodyWarningLines = 100;

/// 找出全部 block-bodied `Widget build(` 方法（含 @override），
/// 返回 {方法声明行, 结束行, 方法体行数}。表达式体（=>）不计入。
List<({int line, int endLine, int body})> _buildMethods(String source) {
  final methods = <({int start, int endLine, int body, int declLine})>[];
  final pattern = RegExp(
    r'^\s*@override\s*\n\s*Widget\s+build\s*\(|^\s*Widget\s+build\s*\(',
    multiLine: true,
  );
  for (final match in pattern.allMatches(source)) {
    // 表达式体（=> 先于 { 出现）跳过。
    final rest = source.substring(match.end);
    final arrow = rest.indexOf('=>');
    final open = rest.indexOf('{');
    if (arrow != -1 && (open == -1 || arrow < open)) continue;
    final brace = open == -1 ? -1 : match.end + open;
    if (brace == -1) continue;
    final close = _matchingBrace(source, brace);
    if (close == -1) continue;
    final declLine = _lineOf(source, match.end - 1);
    methods.add((
      start: match.start,
      endLine: _lineOf(source, close),
      body: _lineOf(source, close) - _lineOf(source, brace) - 1,
      declLine: declLine,
    ));
  }
  // 去重（@override 匹配与普通匹配重叠时保留先出现者）并排序。
  methods.sort((a, b) => a.start.compareTo(b.start));
  final deduped = <({int line, int endLine, int body})>[];
  var lastEnd = -1;
  for (final m in methods) {
    if (m.start <= lastEnd) continue;
    deduped.add((line: m.declLine, endLine: m.endLine, body: m.body));
    lastEnd = m.endLine;
  }
  return deduped;
}

/// 从开放花括号位置开始括号匹配（跳过字符串与注释），返回闭合位置。
int _matchingBrace(String source, int openIndex) {
  var depth = 0;
  var i = openIndex;
  String? inString;
  while (i < source.length) {
    final c = source[i];
    if (inString != null) {
      if (c == r'\') {
        i += 2;
        continue;
      }
      if (c == inString) inString = null;
    } else {
      if (c == '"' || c == "'" || c == '`') {
        inString = c;
      } else if (c == '/' && i + 1 < source.length) {
        if (source[i + 1] == '/') {
          final nl = source.indexOf('\n', i);
          i = nl == -1 ? source.length : nl + 1;
          continue;
        } else if (source[i + 1] == '*') {
          final end = source.indexOf('*/', i + 2);
          i = end == -1 ? source.length : end + 2;
          continue;
        }
      } else if (c == '{') {
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0) return i;
      }
    }
    i++;
  }
  return -1;
}

// ---------------------------------------------------------------------
// P3 const 启发式：可 const 的单行字面量构造模式
// ---------------------------------------------------------------------

/// 类别 → 正则（单行、全字面量参数；不含 lookbehind，配合
/// [_isConstPreceded] 手工排除已 const 的调用）。
final _constCandidates = <String, RegExp>{
  'EdgeInsets.all/only/symmetric/fromLTRB': RegExp(
    r'EdgeInsets\.(?:all|only|symmetric|fromLTRB)\(([^)]*)\)',
  ),
  'SizedBox(width/height 数字)': RegExp(
    r'SizedBox\(\s*((?:width|height):\s*\d+(?:\.\d+)?'
    r'(?:\s*,\s*(?:width|height):\s*\d+(?:\.\d+)?)?)\s*\)',
  ),
  'Text(单字符串字面量)': RegExp(r'''Text\(\s*["'](?:[^"']|\\["'])*["']\s*\)'''),
  'Icon(Icons.x 无参)': RegExp(
    r'Icon\(\s*Icons\.[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)?\s*\)',
  ),
  'Divider() 空参': RegExp(r'Divider\(\s*\)'),
  'SizedBox.shrink/expand()': RegExp(r'SizedBox\.(?:shrink|expand)\(\s*\)'),
};

/// 该调用是否已被 `const` 前缀（跳过空白与 `([,{;`），或是否嵌在更长
/// 标识符内（如 LocalizedText(...) 中的 Text(...)，启发式排除）。
bool _isConstPreceded(String source, int position) {
  var i = position;
  while (i > 0 &&
      (source[i - 1].trim().isEmpty || '([,{;'.contains(source[i - 1]))) {
    i--;
  }
  // 紧邻前一字符仍是标识符成分 → 非独立构造调用（如 LocalizedText）。
  if (i > 0 && RegExp(r'[A-Za-z0-9_.]').hasMatch(source[i - 1])) {
    return true; // 视为已“const 前置”：不报告（非独立调用）
  }
  final before = source.substring(math.max(0, i - 5), i);
  return before == 'const';
}

/// 调用是否位于 `const 构造(...)` / `const [...]` 等已传导 const 的
/// 祖先上下文内（const 传播到整个子树）。如 `const Center(child:
/// Padding(padding: EdgeInsets.all(32)))` 中 EdgeInsets 已是 const，
/// 但 const 在两层之外。向后扫描至最近的 const 祖先；跳过注释与字符串。
bool _inConstContext(String source, int position) {
  var depth = 0;
  var i = position - 1;
  while (i >= 0) {
    final c = source[i];
    if (c == '"' || c == "'" || c == '`') {
      i = _skipStringBackward(source, i);
      continue;
    }
    if (c == '/' && i > 0) {
      if (source[i - 1] == '/') {
        final nl = source.lastIndexOf('\n', i - 2);
        i = nl == -1 ? -1 : nl - 1;
        continue;
      }
      if (source[i - 1] == '*') {
        final start = source.lastIndexOf('/*', i - 2);
        i = start == -1 ? -1 : start - 1;
        continue;
      }
    }
    if (c == ')' || c == ']' || c == '}') {
      depth++;
    } else if (c == '(' || c == '[' || c == '{') {
      if (depth == 0 && _tokenBeforeIsConst(source, i)) return true;
      if (depth > 0) depth--;
    }
    i--;
  }
  return false;
}

/// 从字符串结尾引号向后跳到开头引号（处理 \' \" 转义）。
int _skipStringBackward(String source, int closeIndex) {
  final quote = source[closeIndex];
  var j = closeIndex - 1;
  while (j >= 0) {
    if (source[j] == quote && (j == 0 || source[j - 1] != r'\')) {
      return j - 1;
    }
    if (source[j] == r'\') {
      j -= 2;
      continue;
    }
    j--;
  }
  return -1;
}

/// 开放括号/方括号前至多两个令牌内是否有 `const`：`const [` 或
/// `const Padding(`（构造名 + const）。
bool _tokenBeforeIsConst(String source, int openerIndex) {
  var i = openerIndex - 1;
  // token1：紧邻开括号的令牌。
  while (i >= 0 && source[i].trim().isEmpty) {
    i--;
  }
  if (i < 0) return false;
  var end = i + 1;
  while (i >= 0 && RegExp(r'[A-Za-z0-9_.]').hasMatch(source[i])) {
    i--;
  }
  // 兼容展开前缀：`...const [` 的令牌是 `...const`。
  final token1 = source.substring(i + 1, end).replaceFirst(RegExp(r'^\.+'), '');
  if (token1 == 'const') return true;
  // token2：构造名/键名之后的令牌。
  while (i >= 0 && source[i].trim().isEmpty) {
    i--;
  }
  if (i < 0) return false;
  end = i + 1;
  while (i >= 0 && RegExp(r'[A-Za-z0-9_.]').hasMatch(source[i])) {
    i--;
  }
  final token2 = source.substring(i + 1, end).replaceFirst(RegExp(r'^\.+'), '');
  return token2 == 'const';
}

/// 字面量是否确实可 const：EdgeInsets/SizedBox 仅数字参数；
/// 含字符串插值（$）的 Text 不可 const。
bool _looksConstAble(String kind, String literal) {
  if (literal.contains(r'$')) return false;
  if (!kind.startsWith('EdgeInsets') && !kind.startsWith('SizedBox(w')) {
    return true;
  }
  final open = literal.indexOf('(');
  final args = literal.substring(open + 1, literal.length - 1);
  return _onlyNumericArgs(args);
}

bool _onlyNumericArgs(String args) {
  var rest = args.replaceAll(RegExp(r'\s'), '');
  if (rest.isEmpty) return false;
  rest = rest.replaceAll(RegExp(r'-?\d+(?:\.\d+)?'), '');
  rest = rest.replaceAll(RegExp(r'[A-Za-z_][A-Za-z0-9_]*:'), '');
  rest = rest.replaceAll(',', '').replaceAll(':', '');
  return rest.isEmpty;
}

// ---------------------------------------------------------------------
// 公共工具
// ---------------------------------------------------------------------

/// 扫描集：lib/widgets/ 顶层 + lib/screens/ 递归（与间距门禁口径一致）。
List<String> _scannedFiles() => <String>[
  ...Directory('lib/widgets')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.path),
  ...Directory('lib/screens')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.path),
];

int _lineOf(String source, int offset) =>
    source.substring(0, offset).split('\n').length;

void _printReport(String title, String summary) {
  // ignore: avoid_print
  debugPrint('\n$title\n  $summary');
}

@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 间距 token 门禁（质量门禁固化）：
/// lib/widgets/ 公共组件与 lib/screens/ 页面文件中的间距字面量
/// （SizedBox width/height、EdgeInsets.*、leadingWidth）必须落在
/// 4-64 设计 token 集合 {4, 8, 12, 16, 20, 24, 32, 40, 48, 64} 内。
///
/// 豁免规则：
/// - 0 值（无间距语义）；
/// - 组件固有宽度/几何耦合值（注册在 [_spacingExemptions]，如
///   NavigationRail 宽度 80、图标几何 26、timeline 竖线 14、角标 4/1）。
///   新豁免必须先审查并登记（同时更新质量门禁报告），条目失配会触发
///   「stale exemption」失败，迫使清理。
void main() {
  test('widgets and screens use only spacing tokens from the 4-64 set', () {
    final violations = <String>[];
    final matchedExemptions = <String>{};
    for (final path in _scannedFiles()) {
      final source = File(path).readAsStringSync();
      for (final match in _edgeInsets.allMatches(source)) {
        _checkNumbers(path, source, match.start, match.group(0)!, violations,
            matchedExemptions);
      }
      for (final pattern in _sizedBoxes) {
        for (final match in pattern.allMatches(source)) {
          _checkNumbers(path, source, match.start, match.group(0)!, violations,
              matchedExemptions);
        }
      }
      for (final match in _leadingWidth.allMatches(source)) {
        _checkNumbers(path, source, match.start, match.group(0)!, violations,
            matchedExemptions);
      }
    }
    expect(
      violations,
      isEmpty,
      reason: '非 token 间距（4-64 集之外；若是几何/固有宽度，请登记到 '
          '_spacingExemptions 并更新质量门禁报告）：\n'
          '${violations.join('\n')}',
    );

    final stale = _spacingExemptions.keys
        .where((key) => !matchedExemptions.contains(key))
        .toList()
      ..sort();
    expect(
      stale,
      isEmpty,
      reason: '以下豁免条目已失配（值已被 token 化或文件改动），请从 '
          '_spacingExemptions 移除：\n${stale.join('\n')}',
    );
  });
}

// ---------------------------------------------------------------------
// token 集与豁免清单（与 docs/ui/pages-per-page/quality-gates.md 同步）
// ---------------------------------------------------------------------

final _tokens = <double>{4, 8, 12, 16, 20, 24, 32, 40, 48, 64};

/// 几何/组件固有宽度豁免：键为 `文件路径|规范化字面量`（去掉所有空白，
/// 便于跨行匹配），值为豁免理由。必须逐条审查后登记。
const _spacingExemptions = <String, String>{
  'lib/widgets/theme_selector.dart|leadingWidth:26':
      '下拉图标几何：彩色图标 18 + 间距 8（源码注释同款说明）',
  'lib/widgets/timeline_list.dart|EdgeInsets.only(left:14)':
      'timeline 竖线居中于 30px 圆点中心（x=15），几何耦合',
  'lib/screens/admin/dashboard_screen.dart|leadingWidth:80':
      'NavigationRail 标准宽度（logo 与 rail 图标中心对齐线）',
  'lib/screens/portal/portal_screen_shell.dart|leadingWidth:80':
      'NavigationRail 标准宽度（logo 与 rail 图标中心对齐线）',
  'lib/screens/portal/notification_bell.dart|EdgeInsets.symmetric(horizontal:4,vertical:1)':
      '通知角标几何：贴合 16px 高度文本的紧凑角标',
};

final _edgeInsets = RegExp(r'EdgeInsets\.(?:symmetric|all|only|fromLTRB)\([^)]*\)');

/// lib/widgets/ 公共组件（顶层）+ lib/screens/ 页面文件（递归）。
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
final _sizedBoxes = <RegExp>[
  RegExp(r'SizedBox\(width:\s*\d+(?:\.\d+)?\)'),
  RegExp(r'SizedBox\(height:\s*\d+(?:\.\d+)?\)'),
];
final _leadingWidth = RegExp(r'leadingWidth:\s*\d+(?:\.\d+)?');

final _number = RegExp(r'\d+(?:\.\d+)');

void _checkNumbers(
  String path,
  String source,
  int offset,
  String literal,
  List<String> violations,
  Set<String> matchedExemptions,
) {
  final line = source.substring(0, offset).split('\n').length;
  final key = '$path|${_normalizeSpacing(literal)}';
  final exempt = _spacingExemptions.containsKey(key);
  for (final match in _number.allMatches(literal)) {
    final value = double.parse(match.group(0)!);
    if (value != 0 && !_tokens.contains(value) && !exempt) {
      violations.add('$path:$line: $literal');
    }
  }
  if (exempt) matchedExemptions.add(key);
}

String _normalizeSpacing(String literal) {
  var normalized = literal.replaceAll(RegExp(r'\s'), '');
  return normalized.replaceAll(RegExp(r',+\)'), ')');
}

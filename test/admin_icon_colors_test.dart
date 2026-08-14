@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/admin/admin_module_groups.dart';
import 'package:sso_admin/screens/admin/admin_navigation.dart';
import 'package:sso_admin/widgets/section_selector.dart';

/// 管理导航图标彩色：一级 rail 组图标与子菜单模块图标都使用品牌强调色，
/// 模块色继承所属组色。
///
/// 另含质量门禁的静态扫描（覆盖 6 个产品入口：
/// admin / portal / developer / login / device / setup）：
/// - 导航分节（SectionDef）图标必须显式上色；
/// - rail 图标经由 responsive_navigation_scaffold 的 IconTheme 主题化（豁免）；
/// - 页面级 Icon 缺省颜色时必须命中主题继承白名单（按钮/输入/组件容器 +
///   固定名称集；动态图标仅限 ListTile/Row/Stack 等状态/示意上下文）；
/// - admin 图标不得用品牌主色，其余入口不得引用 admin 组色。
/// 白名单机制对应 docs/ui/pages-per-page/quality-gates.md 的门禁说明。
void main() {
  test('group colors cover every group and are distinct per group', () {
    for (final group in adminModuleGroups) {
      expect(
        adminGroupIconColor(group.id),
        isNot(const Color(0xFF64748B)),
        reason: '${group.id} must have its own accent (not the fallback)',
      );
    }
    final distinct = adminModuleGroups
        .map((g) => g.iconColor)
        .toSet();
    expect(distinct.length, adminModuleGroups.length,
        reason: 'every group gets a distinct color');
  });

  test('module colors inherit their group color', () {
    for (final group in adminModuleGroups) {
      for (final module in group.modules) {
        expect(adminModuleIconColor(module), group.iconColor,
            reason: '$module must inherit ${group.id} color');
      }
    }
    expect(
      adminModuleIconColor('unknown-module'),
      const Color(0xFF64748B),
      reason: 'unknown module falls back to slate',
    );
  });

  testWidgets('dashboard rail and section selector icons are colored', (
    tester,
  ) async {
    // 直接渲染 SectionSelector：所有 chip 图标带组色。
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SectionSelector(
            sections: [
              SectionDef(
                'clients',
                'Clients',
                Icons.apps,
                color: adminModuleIconColor(AdminModuleId.clients),
              ),
              SectionDef(
                'users',
                'Users',
                Icons.people,
                color: adminModuleIconColor(AdminModuleId.users),
              ),
            ],
            current: 'clients',
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final icon in [Icons.apps, Icons.people]) {
      final icons = tester.widgetList<Icon>(find.byIcon(icon));
      expect(icons, isNotEmpty, reason: '$icon must render');
      for (final iconWidget in icons) {
        expect(iconWidget.color, isNotNull,
            reason: '$icon must be colored in section selector');
      }
    }
    // 同组模块共享同色（identity 组 violet）。
    final appsColor = tester
        .widget<Icon>(find.byIcon(Icons.apps).first)
        .color;
    final peopleColor = tester
        .widget<Icon>(find.byIcon(Icons.people).first)
        .color;
    expect(appsColor, peopleColor,
        reason: 'same-group module icons share the group color');
  });

  // ---------------------------------------------------------------------
  // 质量门禁：图标上色静态扫描（6 入口）
  // ---------------------------------------------------------------------

  group('icon color gate (static scans, 6 entries)', () {
    test('navigation section chips carry an explicit color', () {
      final violations = <String>[];
      for (final path in _screenFiles()) {
        final source = File(path).readAsStringSync();
        for (final call in _findCalls(source)) {
          if (call.name != 'SectionDef') continue;
          final args = source.substring(call.start + 'SectionDef'.length, call.end - 1);
          if (!args.contains('color:')) {
            violations.add(
                '$path:${_lineOf(source, call.start)}: SectionDef without color');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'navigation section icons must carry an explicit accent color:\n'
            '${violations.join('\n')}',
      );
    });

    test('rail icons are themed by the scaffold icon themes', () {
      // rail 图标的缺省颜色豁免依赖 responsive_navigation_scaffold 的
      // IconTheme：选中 primary、未选 onSurfaceVariant。此测试固定该机制，
      // 防止主题被移除后 rail 图标悄悄失去品牌色。
      final scaffold = File(
        'lib/widgets/responsive_navigation_scaffold.dart',
      ).readAsStringSync();
      expect(scaffold, contains('selectedIconTheme: IconThemeData('),
          reason: 'rail selected icons must be themed');
      expect(
        scaffold,
        contains('color: Theme.of(context).colorScheme.primary'),
        reason: 'selected rail icons must use the theme primary (brand) color',
      );
      expect(scaffold, contains('unselectedIconTheme: IconThemeData('),
          reason: 'rail unselected icons must be themed');
      expect(
        scaffold,
        contains('color: Theme.of(context).colorScheme.onSurfaceVariant'),
        reason: 'unselected rail icons must use the theme surface color',
      );
    });

    test('page-level icons carry a color or a whitelisted theme-inherit icon', () {
      final violations = <String>[];
      for (final path in _screenFiles()) {
        final source = File(path).readAsStringSync();
        final calls = _findCalls(source);
        for (final call in calls) {
          if (call.name != 'Icon') continue;
          final args = source.substring(call.start + 'Icon'.length, call.end - 1);
          if (args.contains('color:')) continue; // 显式上色 → 合规
          final line = _lineOf(source, call.start);
          final container = _enclosingContainer(calls, call);
          if (_themeInheritContainers.contains(container)) continue;
          final firstArg = args.trim().replaceFirst(RegExp(r'^\(?'), '').trim();
          final iconName = RegExp(r'^Icons\.([A-Za-z0-9_]+)').firstMatch(firstArg);
          if (iconName == null) {
            // 动态图标（变量/条件）：仅允许状态/示意上下文继承主题色。
            if (_themeInheritDynamicContainers.contains(container)) continue;
            violations.add('$path:$line: 未上色动态图标 [$container] $firstArg');
            continue;
          }
          if (_themeInheritIconNames.contains(iconName.group(1))) continue;
          violations.add('$path:$line: 未上色图标 [$container] Icons.${iconName.group(1)}');
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'page-level icons outside the theme-inherit whitelist must be '
            'explicitly colored (add a color: or extend the whitelist in this '
            'test + docs/ui/pages-per-page/quality-gates.md):\n'
            '${violations.join('\n')}',
      );
    });

    test('admin icons do not use brand primary; other entries do not use admin group colors', () {
      final violations = <String>[];
      for (final path in _screenFiles()) {
        final source = File(path).readAsStringSync();
        final isAdmin = path.startsWith('lib/screens/admin') ||
            path == 'lib/screens/settings_screen.dart';
        for (final call in _findCalls(source)) {
          if (call.name != 'Icon') continue;
          final args = source.substring(call.start + 'Icon'.length, call.end - 1);
          if (!args.contains('color:')) continue;
          final line = _lineOf(source, call.start);
          if (isAdmin &&
              args.contains('colorScheme.primary') &&
              !args.contains('adminModuleIconColor') &&
              !args.contains('adminGroupIconColor') &&
              !args.contains('_accent') &&
              !args.contains('accent')) {
            final firstArg = args.trim().replaceFirst(RegExp(r'^\(?'), '').trim();
            final iconName = RegExp(r'^Icons\.([A-Za-z0-9_]+)')
                .firstMatch(firstArg)
                ?.group(1);
            final exemptKey = iconName == null ? null : '$path|$iconName';
            if (!_adminBrandIconExemptions.containsKey(exemptKey)) {
              violations.add('$path:$line: admin 图标使用品牌主色而非组色');
            }
          }
          if (!isAdmin &&
              (args.contains('adminModuleIconColor') ||
                  args.contains('adminGroupIconColor'))) {
            violations.add('$path:$line: 非 admin 入口引用 admin 组色');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason: '色彩身份混淆（admin 应组色、其余入口应品牌色）：\n'
            '${violations.join('\n')}',
      );
    });
  });
}

// ---------------------------------------------------------------------
// 静态扫描辅助（与 docs/ui/pages-per-page/quality-gates.md 的白名单同步）
// ---------------------------------------------------------------------

/// 主题继承豁免的组件容器：这些容器内的 Icon 一律经由 IconTheme/
/// ButtonStyle 着色，允许缺省。
const _themeInheritContainers = <String>{
  'IconButton',
  'FilledButton.icon',
  'FilledButton.tonalIcon',
  'OutlinedButton.icon',
  'TextButton.icon',
  'InputDecoration',
  'CircleAvatar',
  'NavigationRailDestination',
  'Chip',
  'Image.network',
};

/// 动态图标（非 `Icons.*` 字面量）缺色时允许继承主题色的上下文：
/// 状态/示意类容器（ListTile leading、Row/Stack 中的说明图标、顶层）。
const _themeInheritDynamicContainers = <String>{'ListTile', 'Row', 'Stack', ''};

/// 固定名称集的缺省色白名单：这些图标在非豁免容器中出现时仍继承主题色
/// （动作/状态/示意图标，非导航/批量/空态的强调图标）。新增缺省色图标必须
/// 先经过审查并在此登记（同时更新质量门禁报告）。
const _themeInheritIconNames = <String>{
  'all_inclusive',
  'business',
  'chevron_right',
  'delete_outline',
  'error_outline',
  'history',
  'info_outline',
  'notifications_outlined',
  'restart_alt',
  'save_outlined',
  'speed_outlined',
};

/// admin 页面中允许使用品牌主色的图标（逐条登记）：设置页导航项的选中
/// 角标——设置页整体沿用登录头品牌色系（admin_module_groups.dart 注释），
/// 选中态用 primary 与 portal rail 的 selectedIconTheme 同语义。
const _adminBrandIconExemptions = <String, String>{
  'lib/screens/settings_screen.dart|check_circle':
      '设置页导航项选中角标（品牌色选中态）',
};

class _Call {
  final String name;
  final int start;
  final int end;

  const _Call(this.name, this.start, this.end);
}

class _OpenCall {
  final String name;
  final int start;

  const _OpenCall(this.name, this.start);
}

/// 全量提取 `name(...)` 调用区间（嵌套、字符串/注释感知）。
List<_Call> _findCalls(String source) {
  final calls = <_Call>[];
  final stack = <_OpenCall>[];
  var i = 0;
  while (i < source.length) {
    final c = source[i];
    if (c == "'" || c == '"' || c == '`') {
      final quote = c;
      i++;
      while (i < source.length) {
        if (source[i] == r'\') {
          i += 2;
        } else if (source[i] == quote) {
          i++;
          break;
        } else {
          i++;
        }
      }
      continue;
    }
    if (c == '/' && i + 1 < source.length && source[i + 1] == '/') {
      final end = source.indexOf('\n', i);
      i = end < 0 ? source.length : end + 1;
      continue;
    }
    if (c == '/' && i + 1 < source.length && source[i + 1] == '*') {
      final end = source.indexOf('*/', i);
      i = end < 0 ? source.length : end + 2;
      continue;
    }
    if (c == '(') {
      var nameStart = i - 1;
      while (nameStart >= 0 &&
          RegExp('[A-Za-z0-9_.]').hasMatch(source[nameStart])) {
        nameStart--;
      }
      stack.add(_OpenCall(source.substring(nameStart + 1, i), nameStart + 1));
    } else if (c == ')' && stack.isNotEmpty) {
      final open = stack.removeLast();
      calls.add(_Call(open.name, open.start, i + 1));
    }
    i++;
  }
  return calls;
}

/// 最近一层包裹 [call] 的调用名（不含 Icon 自身）；无包裹时返回空串。
String _enclosingContainer(List<_Call> calls, _Call call) {
  _Call? best;
  for (final other in calls) {
    if (other.name == 'Icon') continue;
    if (other.start <= call.start && other.end >= call.end) {
      if (best == null || other.end - other.start < best.end - best.start) {
        best = other;
      }
    }
  }
  return best?.name ?? '';
}

int _lineOf(String source, int offset) =>
    source.substring(0, offset).split('\n').length;

/// 6 个产品入口的页面文件 + admin 设置页。
List<String> _screenFiles() {
  const roots = <String>[
    'lib/screens/admin',
    'lib/screens/portal',
    'lib/screens/developer',
    'lib/screens/device',
    'lib/screens/setup',
    'lib/screens/oidc_login',
  ];
  return <String>[
    for (final root in roots)
      ...Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.path),
    if (File('lib/screens/settings_screen.dart').existsSync())
      'lib/screens/settings_screen.dart',
  ];
}

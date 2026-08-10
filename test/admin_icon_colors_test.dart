import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/admin/admin_module_groups.dart';
import 'package:sso_admin/screens/admin/admin_navigation.dart';
import 'package:sso_admin/widgets/section_selector.dart';

/// 管理导航图标彩色：一级 rail 组图标与子菜单模块图标都使用品牌强调色，
/// 模块色继承所属组色。
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
}

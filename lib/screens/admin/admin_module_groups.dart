import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'admin_navigation.dart';

/// 导航分组：一级 NavigationRail 只显示组（≤8），组内模块用页面内
/// SectionSelector 切换（参考 Supabase/Stripe 的两级信息架构）。
///
/// group 是**纯导航层派生**——不进入路由状态；module id 与 URL 全部保留
/// （`/admin/clients` 深链不变），group 只决定 rail 与 tabs 的渲染。
class AdminModuleGroup {
  final String id;
  final IconData icon;
  final IconData selectedIcon;
  final String labelKey;
  final List<String> modules;

  const AdminModuleGroup({
    required this.id,
    required this.icon,
    required this.selectedIcon,
    required this.labelKey,
    required this.modules,
  });
}

const adminModuleGroups = <AdminModuleGroup>[
  AdminModuleGroup(
    id: 'overview',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    labelKey: 'Overview',
    modules: [AdminModuleId.overview, AdminModuleId.health],
  ),
  AdminModuleGroup(
    id: 'identity',
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    labelKey: 'Identity',
    modules: [
      AdminModuleId.clients,
      AdminModuleId.users,
      AdminModuleId.localUsers,
      AdminModuleId.scimDirectory,
      AdminModuleId.permissions,
      AdminModuleId.authzChecks,
    ],
  ),
  AdminModuleGroup(
    id: 'security',
    icon: Icons.shield_outlined,
    selectedIcon: Icons.shield,
    labelKey: 'Security',
    modules: [
      AdminModuleId.connections,
      AdminModuleId.domains,
      AdminModuleId.deviceSecurity,
      AdminModuleId.tokenSecurity,
      AdminModuleId.tokenPolicies,
      AdminModuleId.tokenExchange,
      AdminModuleId.networkPolicies,
      AdminModuleId.accessPolicies,
      AdminModuleId.threatPolicies,
      AdminModuleId.drMode,
      AdminModuleId.cryptoKeys,
      AdminModuleId.credentials,
      AdminModuleId.emergencyAccess,
      AdminModuleId.changeApprovals,
    ],
  ),
  AdminModuleGroup(
    id: 'tenants',
    icon: Icons.business_outlined,
    selectedIcon: Icons.business,
    labelKey: 'Tenants',
    modules: [
      AdminModuleId.tenants,
      AdminModuleId.organizations,
      AdminModuleId.commerce,
      AdminModuleId.usageAnalytics,
      AdminModuleId.privacyCompliance,
    ],
  ),
  AdminModuleGroup(
    id: 'developers',
    icon: Icons.code_outlined,
    selectedIcon: Icons.code,
    labelKey: 'Developers',
    modules: [
      AdminModuleId.webhooks,
      AdminModuleId.liveActivity,
      AdminModuleId.operations,
      AdminModuleId.recoveryReleases,
    ],
  ),
  AdminModuleGroup(
    id: 'system',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    labelKey: 'System',
    modules: [
      AdminModuleId.governance,
      AdminModuleId.auditLog,
      AdminModuleId.userSupport,
    ],
  ),
];

/// module → group 映射（按组定义顺序构建）。
final Map<String, String> _moduleToGroup = {
  for (final group in adminModuleGroups)
    for (final module in group.modules) module: group.id,
};

/// 返回 module 所属组 id；未知 module 归入 overview 组。
String adminGroupForModule(String module) =>
    _moduleToGroup[module] ?? adminModuleGroups.first.id;

/// 组的可见模块（能力过滤后），保持组内定义顺序。
List<String> adminGroupVisibleModules(
  AdminModuleGroup group,
  List<String> visibleModules,
) => [
  for (final module in group.modules)
    if (visibleModules.contains(module)) module,
];

/// 组内第一个可见模块（点击一级导航时跳转目标）。
String? adminGroupDefaultModule(
  AdminModuleGroup group,
  List<String> visibleModules,
) {
  final visible = adminGroupVisibleModules(group, visibleModules);
  return visible.isEmpty ? null : visible.first;
}

/// 组标签（i18n）。
LocalizedText adminGroupLabel(AdminModuleGroup group) =>
    LocalizedText(group.labelKey);

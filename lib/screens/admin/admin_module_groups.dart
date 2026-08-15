import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/theme/app_colors.dart';
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

  /// 导航图标彩色（品牌强调色，选中/未选中共用）。
  final Color iconColor;

  const AdminModuleGroup({
    required this.id,
    required this.icon,
    required this.selectedIcon,
    required this.labelKey,
    required this.modules,
    required this.iconColor,
  });
}

/// 导航组图标色板（与登录头/设置页品牌色同一色系）。
const adminGroupIconColors = <String, Color>{
  'overview': Color(0xFF0EA5E9), // sky
  'identity': Color(0xFF7C6FF0), // indigo-violet
  'security': Color(0xFFF43F5E), // rose
  'tenants': Color(0xFFF59E0B), // amber
  'developers': Color(0xFF10B981), // emerald
  'system': Color(0xFF4F46E5), // indigo
};

/// 组图标色（未知组回退 slate）。
Color adminGroupIconColor(String groupId) =>
    adminGroupIconColors[groupId] ?? AppColors.muted;

/// 模块图标色：继承所属组的颜色，保证子菜单与一级导航同组同色。
/// 未知模块回退中性 slate（不冒充任何组）。
Color adminModuleIconColor(String module) {
  final known = adminModuleGroups.any((group) => group.modules.contains(module));
  if (!known) return AppColors.muted;
  return adminGroupIconColor(adminGroupForModule(module));
}

const adminModuleGroups = <AdminModuleGroup>[
  AdminModuleGroup(
    id: 'overview',
    iconColor: Color(0xFF0EA5E9),
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    labelKey: 'Overview',
    modules: [AdminModuleId.overview, AdminModuleId.health],
  ),
  AdminModuleGroup(
    id: 'identity',
    iconColor: Color(0xFF7C6FF0),
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
    iconColor: Color(0xFFF43F5E),
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
    iconColor: Color(0xFFF59E0B),
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
    iconColor: Color(0xFF10B981),
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
    iconColor: Color(0xFF4F46E5),
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

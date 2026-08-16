import 'package:flutter/material.dart';
import 'package:sso_admin/screens/admin/admin_module_groups.dart';

/// 命令面板条目：标题 / 路由 / 图标 / 描述，以及从路由派生的模块与动作段。
///
/// 静态目录 [commandPaletteItems] 与模块过滤函数
/// [commandPaletteItemsForModules] 供 [CommandPalette] 渲染搜索结果；
/// 条目自身不持有行为，激活由调用方按 [path] 路由。
class CommandPaletteItem {
  final String title;
  final String path;
  final IconData icon;
  final String description;

  /// 组标题行（浏览态按导航分组显示）。
  final bool isGroupHeader;

  const CommandPaletteItem(
    this.title,
    this.path,
    this.icon,
    this.description, {
    this.isGroupHeader = false,
  });

  String get routeModule {
    final parts = path.replaceFirst('/admin/', '').split('/');
    return parts[0];
  }

  String get routeId {
    final parts = path.replaceFirst('/admin/', '').split('/');
    if (parts.length >= 2 && !['new', 'report', 'rotate'].contains(parts[1])) {
      return parts[1];
    }
    return '';
  }

  String get routeAction {
    final parts = path.replaceFirst('/admin/', '').split('/');
    if (parts.last == 'new') return 'new';
    return '';
  }

  String get routeSubresource {
    final parts = path.replaceFirst('/admin/', '').split('/');
    if (parts.length >= 2 &&
        !['new', 'rotate'].contains(parts[1]) &&
        parts[1] != routeId) {
      return parts[1];
    }
    if (parts.last == 'report' || parts.last == 'rotate') return parts.last;
    return '';
  }
}

const commandPaletteItems = <CommandPaletteItem>[
  CommandPaletteItem(
    'Go to Overview',
    '/admin/',
    Icons.dashboard_outlined,
    'Administration overview',
  ),
  CommandPaletteItem(
    'Go to Clients',
    '/admin/clients',
    Icons.apps,
    'Navigate to client management',
  ),
  CommandPaletteItem(
    'Go to Users',
    '/admin/users',
    Icons.person,
    'Navigate to user management',
  ),
  CommandPaletteItem(
    'Go to Local Users',
    '/admin/local-users',
    Icons.password,
    'Manage password-authenticated users',
  ),
  CommandPaletteItem(
    'Go to Tenants',
    '/admin/tenants',
    Icons.business,
    'Navigate to tenant management',
  ),
  CommandPaletteItem(
    'Go to Subscriptions & Billing',
    '/admin/commerce',
    Icons.payments_outlined,
    'Manage plans, subscriptions, quotas, wallets, and top-ups',
  ),
  CommandPaletteItem(
    'Go to Organizations',
    '/admin/organizations',
    Icons.groups,
    'Manage tenant members and invitations',
  ),
  CommandPaletteItem(
    'Go to SCIM Directory',
    '/admin/scim-directory',
    Icons.account_tree,
    'Provision SCIM users and groups',
  ),
  CommandPaletteItem(
    'Go to Permissions',
    '/admin/permissions',
    Icons.shield,
    'Navigate to permission management',
  ),
  CommandPaletteItem(
    'Go to Connections',
    '/admin/connections',
    Icons.link,
    'Navigate to connection management',
  ),
  CommandPaletteItem(
    'Go to User Support',
    '/admin/user-support',
    Icons.support_agent,
    'Investigate and recover user access',
  ),
  CommandPaletteItem(
    'Go to Device Security',
    '/admin/device-security',
    Icons.devices_other,
    'Investigate physical devices and risky activity',
  ),
  CommandPaletteItem(
    'Go to Live Activity',
    '/admin/live-activity',
    Icons.sensors,
    'Watch live administrative events',
  ),
  CommandPaletteItem(
    'Go to Token Security',
    '/admin/token-security',
    Icons.security,
    'Token and session security',
  ),
  CommandPaletteItem(
    'Go to Usage Insights',
    '/admin/usage-analytics',
    Icons.insights,
    'Tenant and token usage analytics',
  ),
  CommandPaletteItem(
    'Go to Operations',
    '/admin/operations',
    Icons.terminal,
    'Use the complete API operation catalog',
  ),
  CommandPaletteItem(
    'Go to Token Policies',
    '/admin/token-policies',
    Icons.policy,
    'Inspect token policies',
  ),
  CommandPaletteItem(
    'Go to Token Exchange',
    '/admin/token-exchange',
    Icons.swap_horiz,
    'Trace token exchange chains',
  ),
  CommandPaletteItem(
    'Go to Authorization Checks',
    '/admin/authz-checks',
    Icons.fact_check,
    'Evaluate ReBAC and WASM authorization',
  ),
  CommandPaletteItem(
    'Go to Governance',
    '/admin/governance',
    Icons.verified_user,
    'Governance and compliance',
  ),
  CommandPaletteItem(
    'Go to Change Approvals',
    '/admin/change-approvals',
    Icons.approval,
    'Review two-person change requests',
  ),
  CommandPaletteItem(
    'Go to Recovery & Releases',
    '/admin/recovery-releases',
    Icons.settings_backup_restore,
    'Snapshots, backups, and paired releases',
  ),
  CommandPaletteItem(
    'Go to Privacy & Retention',
    '/admin/privacy-compliance',
    Icons.privacy_tip,
    'Data-subject requests and retention sweeps',
  ),
  CommandPaletteItem(
    'Go to Webhooks',
    '/admin/webhooks',
    Icons.webhook,
    'Webhook management',
  ),
  CommandPaletteItem(
    'Go to Emergency Access',
    '/admin/emergency-access',
    Icons.warning_amber,
    'Break-glass access',
  ),
  CommandPaletteItem(
    'Go to Crypto Keys',
    '/admin/crypto-keys',
    Icons.vpn_key,
    'Crypto key management',
  ),
  CommandPaletteItem(
    'Go to Credentials',
    '/admin/credentials',
    Icons.badge,
    'Credential management',
  ),
  CommandPaletteItem(
    'Go to Domains',
    '/admin/domains',
    Icons.language,
    'Domain management',
  ),
  CommandPaletteItem(
    'Go to Network Policies',
    '/admin/network-policies',
    Icons.lan,
    'Network boundary and endpoint routing',
  ),
  CommandPaletteItem(
    'Go to Access Policies',
    '/admin/access-policies',
    Icons.verified_user,
    'Inspect effective access policies',
  ),
  CommandPaletteItem(
    'Go to Threat Policies',
    '/admin/threat-policies',
    Icons.warning_amber,
    'Manage token threat policies',
  ),
  CommandPaletteItem(
    'Go to DR Mode',
    '/admin/dr-mode',
    Icons.monitor_heart,
    'Control degradation mode',
  ),
  CommandPaletteItem(
    'Go to Console Activity',
    '/admin/audit-log',
    Icons.receipt_long,
    'Local console operation history',
  ),
  CommandPaletteItem(
    'Go to Health',
    '/admin/health',
    Icons.health_and_safety,
    'Platform health status',
  ),
  CommandPaletteItem(
    'Go to Settings',
    '/settings',
    Icons.settings,
    'Application settings',
  ),
  CommandPaletteItem(
    'Create New Client',
    '/admin/clients/new',
    Icons.add,
    'Register a new OIDC client',
  ),
  CommandPaletteItem(
    'Create New User',
    '/admin/users/new',
    Icons.add,
    'Create a new user account',
  ),
  CommandPaletteItem(
    'Create New Tenant',
    '/admin/tenants/new',
    Icons.add,
    'Create a new tenant workspace',
  ),
  CommandPaletteItem(
    'Add Domain',
    '/admin/domains/new',
    Icons.add,
    'Register a new email domain',
  ),
  CommandPaletteItem(
    'Add Threat Policy',
    '/admin/threat-policies/new',
    Icons.add,
    'Create a new token threat policy',
  ),
  CommandPaletteItem(
    'Create New Webhook',
    '/admin/webhooks/new',
    Icons.add,
    'Create a new webhook subscription',
  ),
  CommandPaletteItem(
    'Report Credential Compromise',
    '/admin/credentials/report',
    Icons.warning,
    'Report compromised credentials',
  ),
  CommandPaletteItem(
    'Rotate Signing Key',
    '/admin/crypto-keys/rotate',
    Icons.refresh,
    'Rotate the active signing key',
  ),
  CommandPaletteItem(
    'Refresh current view',
    '/refresh',
    Icons.refresh,
    'Reload current page data',
  ),
];

/// 按当前可用模块过滤命令目录，并按导航分组插入组标题行。
///
/// 非 admin 命令（如 /settings）固定归 Overview 组；admin 命令按
/// [adminModuleGroups] 顺序分组，模块不可用时整组隐藏。
List<CommandPaletteItem> commandPaletteItemsForModules(
  Iterable<String> modules,
) {
  final availableModules = modules.toSet();
  final filtered = commandPaletteItems
      .where((command) {
        if (!command.path.startsWith('/admin/')) return true;
        final module = command.routeModule;
        return module.isEmpty || availableModules.contains(module);
      })
      .toList(growable: false);
  // 浏览态插入组标题（按 adminModuleGroups 顺序）。
  final result = <CommandPaletteItem>[];
  for (final group in adminModuleGroups) {
    final groupItems = filtered.where((c) {
      if (!c.path.startsWith('/admin/')) {
        // 非 admin 命令（如 /settings）只归 Overview 组。
        return group.id == 'overview';
      }
      return adminGroupForModule(c.routeModule) == group.id;
    });
    if (groupItems.isNotEmpty) {
      result.add(
        CommandPaletteItem(
          group.labelKey.toUpperCase(),
          '',
          Icons.label_outline,
          '',
          isGroupHeader: true,
        ),
      );
      result.addAll(groupItems);
    }
  }
  return result;
}

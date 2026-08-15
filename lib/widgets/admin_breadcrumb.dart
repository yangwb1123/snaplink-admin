import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import '../screens/admin/admin_module_groups.dart';
import '../screens/admin/admin_route.dart';

/// Breadcrumb navigation for admin detail pages.
///
/// Renders a trail like:  Users → user-abc → Sessions
/// based on the current URL path components.
///
/// 路径层级（分组 → 模块 → 资源 → 子资源）由当前 URL 自动推导，页面只需
/// 传入超出路由语义的额外片段；模块链接点击回到对应列表页。
class AdminBreadcrumb extends StatelessWidget {
  /// 追加在自动路径之后的额外面包屑片段（本地化键）。
  final List<String> trailing;

  /// 覆盖首段模块标签（默认按 URL 模块名映射）；null = 自动推导。
  final String? overrideModule;

  const AdminBreadcrumb({
    super.key,
    this.trailing = const [],
    this.overrideModule,
  });

  static String _moduleLabel(String module) => switch (module) {
    'users' => 'Users',
    'local-users' => 'Local Users',
    'scim-directory' => 'SCIM Directory',
    'clients' => 'Clients',
    'tenants' => 'Tenants',
    'commerce' => 'Subscriptions & Billing',
    'connections' => 'Connections',
    'permissions' => 'Permissions',
    'webhooks' => 'Webhooks',
    'emergency-access' => 'Emergency Access',
    'token-security' => 'Token Security',
    'usage-analytics' => 'Usage Insights',
    'threat-policies' => 'Threat Policies',
    'domains' => 'Domains',
    'network-policies' => 'Network Policies',
    'credentials' => 'Credentials',
    'crypto-keys' => 'Crypto Keys',
    'access-policies' => 'Access Policies',
    'governance' => 'Governance',
    'change-approvals' => 'Change Approvals',
    'recovery-releases' => 'Recovery & Releases',
    'privacy-compliance' => 'Privacy & Retention',
    'dr-mode' => 'DR Mode',
    'user-support' => 'User Support',
    'device-security' => 'Device Security',
    'live-activity' => 'Live Activity',
    'operations' => 'Operations',
    'authz-checks' => 'AuthZ Checks',
    'token-policies' => 'Token Policies',
    'token-exchange' => 'Token Exchange',
    'organizations' => 'Organizations',
    _ => module[0].toUpperCase() + module.substring(1),
  };

  static String _groupLabel(AdminModuleGroup group) => switch (group.id) {
    'overview' => 'Overview',
    'identity' => 'Identity',
    'security' => 'Security',
    'tenants' => 'Tenants',
    'developers' => 'Developers',
    'system' => 'System',
    _ => group.labelKey,
  };

  @override
  Widget build(BuildContext context) {
    final route = AdminRoute.fromUri(Uri.base);
    final theme = Theme.of(context);
    final crumbs = <Widget>[];

    // Group prefix（Identity › ...）——非 overview 模块显示分组层级。
    final groupId = route.module.isEmpty ? '' : adminGroupForModule(route.module);
    final group = groupId.isEmpty
        ? null
        : adminModuleGroups.where((g) => g.id == groupId).firstOrNull;
    if (group != null && group.modules.length > 1) {
      crumbs.add(
        Text(
          _groupLabel(group),
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
      crumbs.add(_separator(context));
    }

    // Module link
    if (route.module.isNotEmpty) {
      crumbs.add(
        TextButton(
          onPressed: () => AdminRoute.go(route.module),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: theme.colorScheme.primary,
          ),
          child: LocalizedText(
            _moduleLabel(route.module),
            style: const TextStyle(fontSize: 13),
          ),
        ),
      );
    }

    // Resource ID or action
    if (route.resourceId.isNotEmpty) {
      crumbs.add(_separator(context));
      if (route.action == 'edit') {
        crumbs.add(
          _crumb(context, 
            route.resourceId,
            () => AdminRoute.go(route.module, resourceId: route.resourceId),
          ),
        );
        crumbs.add(_separator(context));
        crumbs.add(_crumb(context, 'Edit', null, localized: true));
      } else if (route.action == 'new') {
        crumbs.add(_crumb(context, 'New', null, localized: true));
      } else if (route.subresource.isEmpty) {
        crumbs.add(_crumb(context, route.resourceId, null));
      } else {
        crumbs.add(
          _crumb(context, 
            route.resourceId,
            () => AdminRoute.go(route.module, resourceId: route.resourceId),
          ),
        );
      }
    }

    // Sub-resource
    if (route.subresource.isNotEmpty) {
      crumbs.add(_separator(context));
      crumbs.add(_crumb(context, _subLabel(route.subresource), null, localized: true));
    }

    // Extra trailing crumbs
    for (final t in trailing) {
      crumbs.add(_separator(context));
      crumbs.add(_crumb(context, t, null, localized: true));
    }

    // Override module label
    if (overrideModule != null && crumbs.isNotEmpty) {
      crumbs[0] = TextButton(
        onPressed: () => AdminRoute.go(route.module),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: theme.colorScheme.primary,
        ),
        child: LocalizedText(
          overrideModule!,
          style: const TextStyle(fontSize: 13),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.chevron_right,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          ...crumbs,
        ],
      ),
    );
  }

  Widget _separator(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Icon(
      Icons.chevron_right,
      size: 14,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );

  Widget _crumb(BuildContext context, String text, VoidCallback? onTap, {bool localized = false}) {
    final style = TextStyle(
      fontSize: 13,
      fontWeight: onTap == null ? FontWeight.w700 : FontWeight.w500,
      color: onTap == null
          ? Theme.of(context).colorScheme.onSurface
          : Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final label = localized
        ? LocalizedText(text, style: style)
        : Text(text, style: style);
    if (onTap == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: label,
      );
    }
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      child: localized
          ? LocalizedText(text, style: const TextStyle(fontSize: 13))
          : Text(text, style: const TextStyle(fontSize: 13)),
    );
  }

  static String _subLabel(String sub) => switch (sub) {
    'sessions' => 'Sessions',
    'consents' => 'Consents',
    'mfa' => 'MFA',
    'lifecycle' => 'Lifecycle',
    'members' => 'Members',
    'invitations' => 'Invitations',
    'usage' => 'Usage',
    'roles' => 'Roles',
    'assignments' => 'Assignments',
    'deadletters' => 'Dead Letters',
    'rotate-secret' => 'Rotate Secret',
    'approve' => 'Approve',
    'reject' => 'Reject',
    _ => sub[0].toUpperCase() + sub.substring(1),
  };
}

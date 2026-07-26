import 'package:flutter/material.dart';
import '../screens/admin/admin_route.dart';

/// Breadcrumb navigation for admin detail pages.
///
/// Renders a trail like:  Users → user-abc → Sessions
/// based on the current URL path components.
class AdminBreadcrumb extends StatelessWidget {
  final List<String> trailing;
  final String? overrideModule;

  const AdminBreadcrumb({super.key, this.trailing = const [], this.overrideModule});

  static String _moduleLabel(String module) => switch (module) {
    'users' => 'Users',
    'clients' => 'Clients',
    'tenants' => 'Tenants',
    'connections' => 'Connections',
    'permissions' => 'Permissions',
    'webhooks' => 'Webhooks',
    'emergency-access' => 'Emergency Access',
    'token-security' => 'Token Security',
    'threat-policies' => 'Threat Policies',
    'domains' => 'Domains',
    'credentials' => 'Credentials',
    'crypto-keys' => 'Crypto Keys',
    'access-policies' => 'Access Policies',
    'governance' => 'Governance',
    'dr-mode' => 'DR Mode',
    'user-support' => 'User Support',
    'live-activity' => 'Live Activity',
    'admin-operations' => 'Operations',
    'authz-checks' => 'AuthZ Checks',
    'token-policies' => 'Token Policies',
    'token-exchange' => 'Token Exchange',
    'organizations' => 'Organizations',
    _ => module[0].toUpperCase() + module.substring(1),
  };

  @override
  Widget build(BuildContext context) {
    final route = AdminRoute.fromUri(Uri.base);
    final theme = Theme.of(context);
    final crumbs = <Widget>[];

    // Module link
    if (route.module.isNotEmpty) {
      crumbs.add(TextButton(
        onPressed: () => AdminRoute.go(route.module),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: theme.colorScheme.primary,
        ),
        child: Text(_moduleLabel(route.module), style: const TextStyle(fontSize: 13)),
      ));
    }

    // Resource ID or action
    if (route.resourceId.isNotEmpty) {
      crumbs.add(_separator());
      if (route.action == 'edit') {
        crumbs.add(_crumb(route.resourceId, () => AdminRoute.go(route.module, resourceId: route.resourceId)));
        crumbs.add(_separator());
        crumbs.add(_crumb('Edit', null));
      } else if (route.action == 'new') {
        crumbs.add(_crumb('New', null));
      } else if (route.subresource.isEmpty) {
        crumbs.add(_crumb(route.resourceId, null));
      } else {
        crumbs.add(_crumb(route.resourceId, () => AdminRoute.go(route.module, resourceId: route.resourceId)));
      }
    }

    // Sub-resource
    if (route.subresource.isNotEmpty) {
      crumbs.add(_separator());
      crumbs.add(_crumb(_subLabel(route.subresource), null));
    }

    // Extra trailing crumbs
    for (final t in trailing) {
      crumbs.add(_separator());
      crumbs.add(_crumb(t, null));
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
        child: Text(overrideModule!, style: const TextStyle(fontSize: 13)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          const SizedBox(width: 4),
          ...crumbs,
        ],
      ),
    );
  }

  Widget _separator() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 4),
    child: Icon(Icons.chevron_right, size: 14, color: Colors.grey),
  );

  Widget _crumb(String text, VoidCallback? onTap) {
    if (onTap == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade50,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      );
    }
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: Colors.blueGrey.shade700,
      ),
      child: Text(text, style: const TextStyle(fontSize: 13)),
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

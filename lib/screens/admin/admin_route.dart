import 'package:sso_admin/services/browser_navigation.dart';

/// Three-level admin route: `/admin/<module>/<resource>/{id}/<action>/<subaction>`
///
/// Maps directly to snaplink's API resource hierarchy:
///
/// Level 1 - Module (功能模块):
///   /admin/clients, /admin/users, /admin/tokens, /admin/tenants ...
///
/// Level 2 - Resource + Action:
///   /admin/clients              → list
///   /admin/clients/new          → create form
///   /admin/clients/client-abc   → detail view
///   /admin/clients/client-abc/edit → edit form
///
/// Level 3 - Sub-resource + Action:
///   /admin/users/user-xyz/sessions        → user's sessions
///   /admin/users/user-xyz/consents        → user's consents
///   /admin/users/user-xyz/mfa             → user's MFA factors
///   /admin/tenants/t-1/members            → tenant members
///   /admin/tenants/t-1/invitations        → tenant invitations
///   /admin/clients/c-1/rotate-secret      → rotate client secret
///
class AdminRoute {
  /// Module name (e.g. 'clients', 'users', 'tenants')
  final String module;

  /// Resource identifier (e.g. client id, user id, tenant id)
  final String resourceId;

  /// Action (e.g. '', 'new', 'edit', 'view')
  final String action;

  /// Sub-resource (e.g. 'sessions', 'consents', 'mfa', 'members')
  final String subresource;

  /// Sub-action within sub-resource
  final String subaction;

  const AdminRoute({
    this.module = '',
    this.resourceId = '',
    this.action = '',
    this.subresource = '',
    this.subaction = '',
  });

  bool get isList =>
      resourceId.isEmpty && action.isEmpty && subresource.isEmpty;
  bool get isNew => action == 'new' && resourceId.isEmpty;
  bool get isDetail =>
      resourceId.isNotEmpty &&
      (action.isEmpty || action == 'view') &&
      subresource.isEmpty;
  bool get isEdit => action == 'edit' && resourceId.isNotEmpty;
  bool get hasSubresource => subresource.isNotEmpty;

  /// Stable widget identity for a resource detail subtree.
  ///
  /// A direct A -> B history transition can keep the same widget type. The
  /// resource identity forces Flutter to discard A's state before rendering B.
  String get detailIdentity => '$module/$resourceId';

  /// Known subresource names for each module.
  /// These are second-level segments that represent module sub-features
  /// rather than resource IDs (e.g. /admin/credentials/report).
  static const _knownSubresourceNames = <String, Set<String>>{
    'credentials': {'report'},
    'crypto-keys': {'rotate'},
    'governance': {
      'audit',
      'compliance',
      'configuration',
      'lifecycle',
      'write',
    },
    'token-security': {
      'portfolio',
      'suspicious',
      'sessions',
      'subjects',
      'expiring',
      'temp',
      'revoke',
      'bulk-revoke',
    },
  };

  /// Parse current browser URL into AdminRoute.
  factory AdminRoute.fromUri(Uri uri) {
    final pathSegments = uri.pathSegments;
    if (pathSegments.isEmpty || pathSegments.first != 'admin') {
      return const AdminRoute();
    }
    // Uri.pathSegments preserves an encoded slash as part of one decoded
    // resource ID. Splitting Uri.path would turn IDs such as `team/a` into
    // extra route levels after a safe `%2F` deep link.
    final segments = pathSegments
        .skip(1)
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);

    if (segments.isEmpty) return const AdminRoute();

    // /admin/<module>
    if (segments.length == 1) return AdminRoute(module: segments[0]);

    // /admin/<module>/new
    if (segments.length == 2 && segments[1] == 'new') {
      return AdminRoute(module: segments[0], action: 'new');
    }

    // /admin/<module>/<id> OR /admin/<module>/<subresource>
    // Check if second segment is a known subresource name for this module
    if (segments.length == 2) {
      final known = _knownSubresourceNames[segments[0]];
      if (known != null && known.contains(segments[1])) {
        return AdminRoute(module: segments[0], subresource: segments[1]);
      }
      return AdminRoute(
        module: segments[0],
        resourceId: segments[1],
        action: 'view',
      );
    }

    // /admin/<module>/<id>/edit
    if (segments.length == 3 && segments[2] == 'edit') {
      return AdminRoute(
        module: segments[0],
        resourceId: segments[1],
        action: 'edit',
      );
    }

    // /admin/<module>/<id>/<subresource>
    if (segments.length == 3) {
      return AdminRoute(
        module: segments[0],
        resourceId: segments[1],
        subresource: segments[2],
      );
    }

    // /admin/<module>/<id>/<subresource>/<action>
    if (segments.length == 4) {
      return AdminRoute(
        module: segments[0],
        resourceId: segments[1],
        subresource: segments[2],
        subaction: segments[3],
      );
    }

    // /admin/<module>/<id>/<subresource>/<action>/<extra>
    return AdminRoute(
      module: segments[0],
      resourceId: segments[1],
      subresource: segments[2],
      subaction: segments[3],
    );
  }

  /// Build a URL string for a given route (no navigation).
  static String url(
    String module, {
    String resourceId = '',
    String action = '',
    String subresource = '',
    String subaction = '',
  }) {
    final parts = <String>[module];
    if (resourceId.isNotEmpty) parts.add(resourceId);
    if (action.isNotEmpty && action != 'view') parts.add(action);
    if (subresource.isNotEmpty) parts.add(subresource);
    if (subaction.isNotEmpty) parts.add(subaction);
    return '/admin/${parts.map(Uri.encodeComponent).join('/')}';
  }

  /// Navigate to a URL using history.pushState.
  static void go(
    String module, {
    String resourceId = '',
    String action = '',
    String subresource = '',
    String subaction = '',
  }) {
    final path = url(
      module,
      resourceId: resourceId,
      action: action,
      subresource: subresource,
      subaction: subaction,
    );
    BrowserNavigation.pushState(path);
  }

  @override
  String toString() =>
      'AdminRoute($module, $resourceId, $action, $subresource, $subaction)';

  @override
  bool operator ==(Object other) =>
      other is AdminRoute &&
      module == other.module &&
      resourceId == other.resourceId &&
      action == other.action &&
      subresource == other.subresource &&
      subaction == other.subaction;

  @override
  int get hashCode =>
      Object.hash(module, resourceId, action, subresource, subaction);
}

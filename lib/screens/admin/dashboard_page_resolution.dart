import 'package:flutter/material.dart';

import '../../api/snaplink_admin_api.dart';
import '../../api/sso_client.dart';
import '../../i18n/localized_text.dart';
import '../../services/operator_persona.dart';
import '../../widgets/error_boundary.dart';
import 'admin_navigation.dart';
import 'admin_route.dart';
import 'break_glass_detail_screen.dart';
import 'client_detail_screen.dart';
import 'connection_detail_screen.dart';
import 'permission_detail_screen.dart';
import 'tenant_detail_screen.dart';
import 'user_detail_screen.dart';
import 'webhook_detail_screen.dart';

/// module → visible label map for the dashboard section selector.
Map<String, String> dashboardModuleLabels(
  List<AdminNavigationEntry<NavigationRailDestination, Widget>> entries,
) => {
  for (final entry in entries)
    entry.module: dashboardWidgetLabel(entry.destination.label),
};

/// Extracts the text of a navigation label widget ([Text]/[LocalizedText]).
String dashboardWidgetLabel(Widget label) {
  if (label is Text) return label.data ?? '';
  if (label is LocalizedText) return label.data;
  return '';
}

/// Icon of the module's rail destination (fallback: outline circle).
IconData dashboardModuleIcon(
  String module,
  List<AdminNavigationEntry<NavigationRailDestination, Widget>> entries,
) {
  for (final entry in entries) {
    if (entry.module != module) continue;
    final icon = entry.destination.icon;
    if (icon is Icon) return icon.icon ?? Icons.circle_outlined;
  }
  return Icons.circle_outlined;
}

/// Resolves the page rendered for the current admin route.
///
/// Deep links with a resource id resolve to the matching detail screen;
/// anything else renders the selected module's entry page. The result is
/// wrapped in [ErrorBoundary] keyed by the route identity so detail-to-
/// detail transitions discard stale subtree state.
Widget resolveDashboardPage({
  required AdminRoute route,
  required List<AdminNavigationEntry<NavigationRailDestination, Widget>>
  entries,
  required String selectedModule,
  required SnaplinkAdminApi api,
  required SSOAdminClient client,
  required SnaplinkAdminCapabilities capabilities,
  required OperatorPersona persona,
}) {
  Widget page;
  final rid = route.resourceId;
  if (rid.isNotEmpty) {
    final detail = <String, Widget Function()>{
      AdminModuleId.users: () => UserDetailScreen(
        api: api,
        client: client,
        userId: rid,
        capabilities: capabilities,
      ),
      AdminModuleId.clients: () => ClientDetailScreen(
        api: api,
        client: client,
        clientId: rid,
        persona: persona,
      ),
      AdminModuleId.tenants: () => TenantDetailScreen(
        api: api,
        client: client,
        tenantId: rid,
        capabilities: capabilities,
        persona: persona,
      ),
      AdminModuleId.connections: () =>
          ConnectionDetailScreen(api: api, client: client, connectionId: rid),
      AdminModuleId.emergencyAccess: () =>
          BreakGlassDetailScreen(api: api, sessionId: rid),
      AdminModuleId.permissions: () =>
          PermissionDetailScreen(api: api, client: client, clientId: rid),
      AdminModuleId.webhooks: () =>
          WebhookDetailScreen(api: api, client: client, subId: rid),
    };
    final builder = detail[route.module];
    if (builder != null) {
      page = ErrorBoundary(
        key: ValueKey(route.detailIdentity),
        child: builder(),
      );
    } else {
      page = ErrorBoundary(
        child: entries[adminNavigationIndexForModule(entries, selectedModule)]
            .page,
      );
    }
  } else {
    page = ErrorBoundary(
      child:
          entries[adminNavigationIndexForModule(entries, selectedModule)].page,
    );
  }
  return page;
}

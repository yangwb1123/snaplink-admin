import 'package:flutter/material.dart';

import '../../api/admin_paths.dart';
import '../../api/snaplink_admin_types.dart';
import '../../widgets/section_header.dart';
import 'admin_capability_boundary.dart';
import 'admin_navigation.dart';

// Only families mirrored by Snaplink's runtime inventory belong here. The
// catalog still supplies compatibility navigation for gateway-only routes.
// Audit Governance and Billing have independent deployment/probe contracts;
// their absence from the identity inventory is not evidence of unavailability.
const _runtimeMirroredModules = <String, String>{
  AdminModuleId.connections: '/api/v1/admin/connections',
  AdminModuleId.networkPolicies: '/api/v1/netpolicy',
  AdminModuleId.accessPolicies: AdminPaths.accessPolicies,
  AdminModuleId.webhooks: AdminPaths.webhookSubscriptions,
};

/// Apply the same runtime boundary to menu pages and resource deep links.
/// Keeping this at page resolution prevents detail routes from bypassing a
/// gate, and avoids mounting/fetching the child while availability is unknown.
Widget dashboardCapabilityGate({
  required String module,
  required Widget child,
  SnaplinkAdminCapabilitySnapshot? snapshot,
  VoidCallback? onRetry,
  String? title,
}) {
  final prefix = _runtimeMirroredModules[module];
  if (prefix == null ||
      snapshot == null ||
      snapshot.canUseAnyPathPrefix(prefix)) {
    return child;
  }
  final boundary = AdminCapabilityBoundary(
    snapshot: snapshot,
    pathPrefix: prefix,
    onRetry: onRetry,
    builder: (_) => child,
  );
  if (title == null) return boundary;
  // Preserve route identity even when normal mode hides this module's group.
  // The status replaces the fetching child, not the page's navigation label.
  return Column(
    children: [
      Padding(padding: const EdgeInsets.all(16), child: SectionHeader(title)),
      Expanded(child: boundary),
    ],
  );
}

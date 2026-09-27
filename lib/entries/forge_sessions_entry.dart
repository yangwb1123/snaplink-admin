import 'package:flutter/material.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/widgets/error_boundary.dart';

/// Builds the Forge surface for both the collection route and a session deep
/// link. The ID is only a client-side selection hint; the gate still obtains
/// the authenticated owner token and the screen uses the owner-scoped detail
/// endpoint before showing a session outside the first page.
Widget buildForgeSessionsScreen(Uri routeUri) => ErrorBoundary(
  child: ForgeSessionsGate(
    initialConversationID: _conversationIDFromRoute(routeUri),
    initialClientInstanceID: _clientInstanceIDFromRoute(routeUri),
  ),
);

String? _conversationIDFromRoute(Uri routeUri) {
  final segments = routeUri.pathSegments;
  if (segments.length != 3 ||
      segments[0] != 'forge' ||
      segments[1] != 'conversations' ||
      segments[2].isEmpty) {
    return null;
  }
  return segments[2];
}

String? _clientInstanceIDFromRoute(Uri routeUri) {
  final value = routeUri.queryParameters['instance_id'];
  if (value == null || value.trim().isEmpty) return null;
  return value.trim();
}

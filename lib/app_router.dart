import 'package:flutter/material.dart';
import 'screens/admin/admin_gate.dart';
import 'screens/oidc_login/oidc_login_screen.dart';
import 'screens/setup/setup_screen.dart';
import 'screens/portal/portal_screen.dart';
import 'screens/developer/developer_screen.dart';
import 'screens/device/device_verify_screen.dart';

/// One Flutter web build serves all five areas of the SSO product (extracted
/// from the sso-server Go binary, which is now a pure API backend) — a
/// reverse proxy (OpenResty) routes /login/, /setup/, /portal/, /developer/,
/// /admin/ all to this SAME static bundle, and THIS function picks which
/// screen to show based on the path the browser actually loaded, exactly
/// like any client-routed SPA behind a proxy.
///
/// /admin/ is gated by AdminGateScreen — no session (or a session without
/// admin API access) means a real redirect to /login/?redirect=/admin/,
/// never an inline login form on the /admin/ path itself. /login/ is the
/// ONE login screen every account kind (admin or regular) authenticates
/// through; what happens afterward is decided by admin API access, not by
/// which URL was used to sign in.
Widget resolveInitialScreen() {
  final path = Uri.base.path;
  if (path.startsWith('/setup')) return const SetupScreen();
  if (path.startsWith('/portal')) return const PortalScreen();
  if (path.startsWith('/developer')) return const DeveloperScreen();
  if (path.startsWith('/device/verify')) return const DeviceVerifyScreen();
  if (path.startsWith('/admin')) return const AdminGateScreen();
  return const OidcLoginScreen(defaultClientId: 'sso-admin-console');
}

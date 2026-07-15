import 'package:flutter/material.dart';
import 'screens/admin/admin_login_screen.dart';
import 'screens/oidc_login/oidc_login_screen.dart';
import 'screens/setup/setup_screen.dart';
import 'screens/portal/portal_screen.dart';
import 'screens/developer/developer_screen.dart';

/// One Flutter web build serves all five areas of the SSO product (extracted
/// from the sso-server Go binary, which is now a pure API backend) — a
/// reverse proxy (OpenResty) routes /login/, /setup/, /portal/, /developer/,
/// /admin/ all to this SAME static bundle, and THIS function picks which
/// screen to show based on the path the browser actually loaded, exactly
/// like any client-routed SPA behind a proxy.
Widget resolveInitialScreen() {
  final path = Uri.base.path;
  if (path.startsWith('/login')) return const OidcLoginScreen();
  if (path.startsWith('/setup')) return const SetupScreen();
  if (path.startsWith('/portal')) return const PortalScreen();
  if (path.startsWith('/developer')) return const DeveloperScreen();
  return const AdminLoginScreen();
}

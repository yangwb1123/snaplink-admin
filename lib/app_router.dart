import 'package:flutter/material.dart';
import 'api/oidc_login_api.dart';
import 'api/sso_client.dart';
import 'screens/admin/admin_gate.dart';
import 'screens/oidc_login/oidc_login_screen.dart';
import 'screens/setup/setup_screen.dart';
import 'screens/portal/portal_screen.dart';
import 'screens/developer/developer_screen.dart';
import 'screens/device/device_verify_screen.dart';
import 'services/product_entry_route.dart';

/// One Flutter web build serves all six areas of the SSO product (extracted
/// from the sso-server Go binary, which is now a pure API backend) — a
/// reverse proxy (OpenResty) routes /login/, /setup/, /portal/, /developer/,
/// /device/verify, and /admin/ all to this SAME static bundle, and THIS
/// function picks which screen to show based on the path the browser actually
/// loaded, exactly like any client-routed SPA behind a proxy.
///
/// /admin/ is gated by AdminGateScreen — no session (or a session without
/// admin API access) means a real redirect to /login/?redirect=/admin/,
/// never an inline login form on the /admin/ path itself. /login/ is the
/// ONE login screen every account kind (admin or regular) authenticates
/// through; what happens afterward is decided by admin API access, not by
/// which URL was used to sign in.
Widget resolveInitialScreen({OidcLoginApi? oidcLoginApi}) =>
    resolveProductScreen(Uri.base, oidcLoginApi: oidcLoginApi);

Widget resolveProductScreen(Uri location, {OidcLoginApi? oidcLoginApi}) {
  return switch (productEntryForPath(location.path)) {
    ProductEntry.setup => const SetupScreen(),
    ProductEntry.portal => PortalScreen(routeUri: location),
    ProductEntry.developer => const DeveloperScreen(),
    ProductEntry.deviceVerification => DeviceVerifyScreen(routeUri: location),
    ProductEntry.admin => const AdminGateScreen(),
    ProductEntry.login => OidcLoginScreen(
      defaultClientId: SSOAdminClient.firstPartyClientId,
      api: oidcLoginApi,
      routeUri: location,
    ),
  };
}

/// Used by native shells when BrowserNavigation replaces an application
/// location without a browser history or page reload.
Route<dynamic> buildProductRoute(RouteSettings settings) {
  final location = Uri.tryParse(settings.name ?? '/') ?? Uri(path: '/');
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => resolveProductScreen(location),
  );
}

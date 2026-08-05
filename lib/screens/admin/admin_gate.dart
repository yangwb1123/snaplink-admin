import 'package:flutter/material.dart';
import 'package:sso_admin/services/admin_oauth_resources.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import '../../i18n/app_strings.dart';
import 'dashboard_screen.dart';
import '../../session.dart';
import '../../sso_client.dart';
import '../setup/setup_api.dart';

/// Builds the hosted-login return location for an unauthenticated Admin deep
/// link. Only an in-product `/admin` path is retained; fragments and
/// credential-like query values never cross the authentication boundary.
String adminLoginLocation(Uri current, {List<String>? resources}) {
  final requestedResources = resources ?? AdminOAuthResources.values;
  final isAdminPath =
      current.path == '/admin' || current.path.startsWith('/admin/');
  final privateParameters = const {
    'access_token',
    'assertion',
    'code',
    'code_verifier',
    'consent_challenge_id',
    'consent_decision',
    'credential',
    'device_token',
    'email',
    'error',
    'error_description',
    'id_token',
    'login_transaction_id',
    'mfa_challenge_id',
    'mfa_method',
    'password',
    'refresh_token',
    'state',
    'token',
    'verification_code',
  };
  final query = isAdminPath
      ? <String, dynamic>{
          for (final entry in current.queryParametersAll.entries)
            if (!privateParameters.contains(entry.key))
              entry.key: entry.value.length == 1
                  ? entry.value.single
                  : entry.value,
        }
      : null;
  final target = Uri(
    path: isAdminPath ? _adminReturnPath(current) : '/admin/',
    queryParameters: query == null || query.isEmpty ? null : query,
  ).toString();
  return Uri(
    path: '/login/',
    queryParameters: {
      'redirect': target,
      if (requestedResources.isNotEmpty) 'resource': requestedResources,
    },
  ).toString();
}

String _adminReturnPath(Uri current) {
  final encoded = '/${current.pathSegments.map(Uri.encodeComponent).join('/')}';
  if (current.path.endsWith('/') && !encoded.endsWith('/')) {
    return '$encoded/';
  }
  return encoded;
}

/// /admin/'s auth+authz gate: no separate admin login screen — a visit here
/// with no session (or a session that turns out to lack admin API access)
/// does a REAL browser redirect to /login/?redirect=/admin/, matching how
/// any protected route should behave (unauthenticated -> /login with a
/// return path -> sign in -> land back here). Only a valid, admin-capable
/// session renders the dashboard.
class AdminGateScreen extends StatefulWidget {
  const AdminGateScreen({super.key});

  @override
  State<AdminGateScreen> createState() => _AdminGateScreenState();
}

class _AdminGateScreenState extends State<AdminGateScreen> {
  SSOAdminClient? _client;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    setState(() => _error = null);
    final token = Session.read();
    if (token == null) {
      if (await _redirectFreshInstallToSetup()) return;
      _redirectToLogin();
      return;
    }
    final client = SSOAdminClient.withToken(
      token,
      onUnauthorized: _redirectToLogin,
    );
    try {
      // Probe the read-only runtime inventory rather than coupling entry to a
      // managed resource such as OAuth clients. Snaplink applies the same
      // admin:read middleware while returning no tenant/client records.
      await client.probeAdminAccess();
      if (!mounted) return;
      setState(() => _client = client);
    } on SSOError catch (e) {
      // A 401 is handled centrally by SSOAdminClient: it clears both the
      // in-memory and stored session, then invokes our login redirect. A 403
      // instead
      // proves the session is still valid but lacks the admin capability, so
      // keep it intact and render an actionable denial rather than leaving a
      // perpetual loading indicator.
      if (e.status == 401) return;
      if (!mounted) return;
      setState(() => _error = e);
    } catch (e) {
      // A transient network blip or 5xx during this one probe shouldn't
      // discard a perfectly valid session — offer a retry instead of
      // force-clearing and bouncing to /login/.
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  /// Snaplink exposes this public probe precisely so a fresh deployment can
  /// reach its one-time bootstrap wizard before any administrator exists.
  /// A disabled wizard (404) and a transient probe failure leave the regular
  /// login route unchanged.
  Future<bool> _redirectFreshInstallToSetup() async {
    try {
      final status = await SetupApi().checkStatus();
      if (status.available && status.setupRequired) {
        BrowserNavigation.replaceLocation('/setup/');
        return true;
      }
    } on SetupNetworkError {
      // Login remains the safe default when the public status probe is down.
    }
    return false;
  }

  void _redirectToLogin() {
    BrowserNavigation.replaceLocation(
      adminLoginLocation(BrowserNavigation.currentUri),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final client = _client;
    if (client != null) {
      return DashboardScreen(client: client);
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(strings.failedToLoadAdminConsole(_error!)),
              const SizedBox(height: 12),
              FilledButton(onPressed: _checkAccess, child: Text(strings.retry)),
            ],
          ),
        ),
      );
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

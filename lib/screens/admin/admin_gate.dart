import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dashboard_screen.dart';
import '../../session.dart';
import '../../sso_client.dart';
import '../setup/setup_api.dart';

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
    final client = SSOAdminClient.withToken(token);
    try {
      // Reuses the exact request the dashboard itself makes, rather than
      // parsing JWT claims or coupling to the permissions schema, to decide
      // whether this session actually has admin API access.
      await client.listClients();
      if (!mounted) return;
      setState(() => _client = client);
    } on SSOError catch (e) {
      // A 401 is handled centrally by SSOAdminClient: it clears the stale
      // browser session and returns the operator to login. A 403 instead
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
        web.window.location.replace('/setup/');
        return true;
      }
    } on SetupNetworkError {
      // Login remains the safe default when the public status probe is down.
    }
    return false;
  }

  void _redirectToLogin() {
    web.window.location.replace(
      '/login/?redirect=${Uri.encodeComponent('/admin/')}',
    );
  }

  @override
  Widget build(BuildContext context) {
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
              Text('Failed to load admin console: $_error'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _checkAccess, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

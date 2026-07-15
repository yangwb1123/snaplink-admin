import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dashboard_screen.dart';
import '../../session.dart';
import '../../sso_client.dart';

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

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final token = Session.read();
    if (token == null) {
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
    } catch (_) {
      // Expired/invalid token, or a real session with no admin access —
      // either way this route isn't usable; clear and send back to login.
      Session.clear();
      _redirectToLogin();
    }
  }

  void _redirectToLogin() {
    web.window.location.replace('/login/?redirect=${Uri.encodeComponent('/admin/')}');
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;
    if (client == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return DashboardScreen(client: client);
  }
}

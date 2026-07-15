import 'package:flutter/material.dart';
import 'portal_api.dart';
import 'overview_tab.dart';
import 'security_tab.dart';
import 'sessions_tab.dart';
import 'consents_tab.dart';
import 'organizations_tab.dart';
import 'privacy_tab.dart';

/// Self-service account portal ("/portal") — entry widget referenced by
/// app_router.dart's resolveInitialScreen().
///
/// Auth model, ported exactly from interfaces/web/portal/app.js: this portal
/// has NO login form of its own on the server. The end user is expected to
/// already hold a bearer access token (e.g. from a completed OIDC login
/// elsewhere) and pastes it in; the token is accepted once it passes a
/// GET /me probe, and every subsequent call in this screen rides that same
/// token. There is no username/password step here, unlike the admin
/// console's `/auth/login` password-grant flow — that would be the wrong
/// model for an end user managing their own already-authenticated account.
///
/// One deliberate gap vs. app.js: app.js also persists the token in
/// `sessionStorage` and silently resumes a stored session on page load. This
/// build keeps the token in memory only (no `dart:html`/`package:web`
/// dependency is wired into this project), so a full browser reload always
/// returns to the token-entry screen — see the task report for why.
class PortalScreen extends StatefulWidget {
  const PortalScreen({super.key});

  @override
  State<PortalScreen> createState() => _PortalScreenState();
}

class _PortalScreenState extends State<PortalScreen> {
  final PortalApi _api = PortalApi();
  final TextEditingController _tokenCtrl = TextEditingController();

  Map<String, dynamic>? _me;
  bool _loggingIn = false;
  String? _loginError;
  String? _postSignOutNotice;
  int _navIndex = 0;

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final t = _tokenCtrl.text.trim();
    if (t.isEmpty) {
      setState(() => _loginError = 'Enter a token.');
      return;
    }
    setState(() {
      _loggingIn = true;
      _loginError = null;
    });
    try {
      final me = await _api.login(t);
      if (!mounted) return;
      setState(() {
        _me = me;
        _postSignOutNotice = null;
        _navIndex = 0;
      });
    } catch (_) {
      setState(() => _loginError = 'That token was not accepted.');
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  void _signOut() {
    _api.signOut();
    setState(() {
      _me = null;
      _tokenCtrl.clear();
      _navIndex = 0;
    });
  }

  void _onAccountDeleted() {
    _tokenCtrl.clear();
    setState(() {
      _me = null;
      _navIndex = 0;
      _postSignOutNotice = 'Your account has been deleted.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return _me == null ? _buildLoginGate(context) : _buildApp(context);
  }

  Widget _buildLoginGate(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.account_circle, color: Color(0xFF6366F1)),
                        const SizedBox(width: 10),
                        Text('Your account', style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Paste your access token to manage your account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _tokenCtrl,
                      obscureText: true,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Access token'),
                      onSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _loggingIn ? null : _login,
                      child: _loggingIn
                          ? const SizedBox(
                              height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Continue'),
                    ),
                    if (_loginError != null) ...[
                      const SizedBox(height: 14),
                      Text(_loginError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
                    ],
                    if (_postSignOutNotice != null) ...[
                      const SizedBox(height: 14),
                      Text(_postSignOutNotice!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.greenAccent)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _destinations = [
    NavigationRailDestination(icon: Icon(Icons.person_outline), label: Text('Overview')),
    NavigationRailDestination(icon: Icon(Icons.lock_outline), label: Text('Security')),
    NavigationRailDestination(icon: Icon(Icons.devices_outlined), label: Text('Sessions')),
    NavigationRailDestination(icon: Icon(Icons.apps_outlined), label: Text('Connected apps')),
    NavigationRailDestination(icon: Icon(Icons.business_outlined), label: Text('Organizations')),
    NavigationRailDestination(icon: Icon(Icons.privacy_tip_outlined), label: Text('Privacy')),
  ];

  Widget _buildApp(BuildContext context) {
    final mySub = _me?['sub']?.toString() ?? '';
    final page = switch (_navIndex) {
      0 => OverviewTab(api: _api),
      1 => SecurityTab(api: _api),
      2 => SessionsTab(api: _api),
      3 => ConsentsTab(api: _api),
      4 => OrganizationsTab(api: _api),
      _ => PrivacyTab(api: _api, mySub: mySub, onAccountDeleted: _onAccountDeleted),
    };
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Your account'),
            if (mySub.isNotEmpty)
              Text(mySub, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _navIndex,
            onDestinationSelected: (i) => setState(() => _navIndex = i),
            labelType: NavigationRailLabelType.all,
            destinations: _destinations,
          ),
          const VerticalDivider(width: 1),
          Expanded(child: page),
        ],
      ),
    );
  }
}

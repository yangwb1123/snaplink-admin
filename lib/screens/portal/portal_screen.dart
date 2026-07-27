import 'package:flutter/material.dart';
import 'portal_api.dart';
import 'overview_tab.dart';
import 'identities_tab.dart';
import 'security_tab.dart';
import 'sessions_tab.dart';
import 'consents_tab.dart';
import 'devices_tab.dart';
import 'organizations_tab.dart';
import 'privacy_tab.dart';
import 'security_activity_tab.dart';
import '../../session.dart';
import '../../widgets/responsive_navigation_scaffold.dart';

/// Self-service account portal ("/portal") — entry widget referenced by
/// app_router.dart's resolveInitialScreen().
///
/// Auth model, ported from interfaces/web/portal/app.js: this portal has NO
/// login form of its own on the server. The end user is expected to already
/// hold a bearer access token (e.g. from a completed OIDC login elsewhere);
/// the token is accepted once it passes a GET /me probe, and every
/// subsequent call in this screen rides that same token.
///
/// On init this now checks the shared [Session] first (matching
/// admin_gate.dart's pattern): a user who already signed in via /login or
/// /admin lands straight in the authenticated view with no re-paste. Only
/// when there's no stored session (native builds, where [Session] is a
/// no-op; or a visitor who reached /portal directly) does this fall back to
/// the manual token-paste gate below — which also still works standalone
/// for anyone bringing a token minted a different way.
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
  bool _resumingSession = true;
  String? _loginError;
  String? _postSignOutNotice;
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _tryResumeSession();
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  /// Mirrors admin_gate.dart's `_checkAccess`: a stored session token is
  /// tried against the same GET /me probe the manual-paste path uses, so
  /// this can never diverge from what "a valid token" means here. An
  /// expired/invalid stored token is cleared rather than left to dead-end
  /// silently, then falls through to the manual-paste gate same as having
  /// no session at all.
  Future<void> _tryResumeSession() async {
    final token = Session.read();
    if (token == null) {
      setState(() => _resumingSession = false);
      return;
    }
    try {
      final me = await _api.login(
        token,
        sessionId: Session.readSessionId(),
        clientId: Session.readClientId(),
      );
      if (!mounted) return;
      _api.onSessionExpired = _handleSessionExpired;
      setState(() {
        _me = me;
        _resumingSession = false;
      });
    } catch (_) {
      Session.clear();
      if (!mounted) return;
      setState(() => _resumingSession = false);
    }
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
      _api.onSessionExpired = _handleSessionExpired;
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

  Future<void> _signOut() async {
    // A logout 401 only means the bearer was already revoked; it should not
    // race the explicit local cleanup below.
    _api.onSessionExpired = null;
    try {
      await _api.logout();
    } catch (_) {
      // Local revocation remains deliberate even if the network request could
      // not be delivered. The next authenticated request will be impossible
      // from this browser tab.
    }
    _api.signOut();
    // A no-op off web / when the active token was never Session's (manual
    // paste with no prior /login) — only clears anything when it was.
    Session.clear();
    setState(() {
      _me = null;
      _tokenCtrl.clear();
      _navIndex = 0;
    });
  }

  void _onAccountDeleted() {
    _api.onSessionExpired = null;
    _tokenCtrl.clear();
    Session.clear();
    setState(() {
      _me = null;
      _navIndex = 0;
      _postSignOutNotice = 'Your account has been deleted.';
    });
  }

  void _onCurrentSessionRevoked() {
    _api.onSessionExpired = null;
    _tokenCtrl.clear();
    Session.clear();
    setState(() {
      _me = null;
      _navIndex = 0;
      _postSignOutNotice = 'This session was revoked. Please sign in again.';
    });
  }

  /// The [PortalApi.onSessionExpired] equivalent of admin_gate.dart's
  /// redirect-to-login on a mid-session 401/403 — the portal has no
  /// separate /login/ route to bounce to (see class doc), so "re-auth" here
  /// means dropping back to this screen's own token-paste gate instead.
  void _handleSessionExpired() {
    _api.onSessionExpired = null;
    _tokenCtrl.clear();
    Session.clear();
    if (!mounted) return;
    setState(() {
      _me = null;
      _navIndex = 0;
      _postSignOutNotice = 'Your session has expired. Please sign in again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_resumingSession) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
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
                        const Icon(
                          Icons.account_circle,
                          color: Color(0xFF6366F1),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Your account',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
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
                      decoration: const InputDecoration(
                        labelText: 'Access token',
                      ),
                      onSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _loggingIn ? null : _login,
                      child: _loggingIn
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Continue'),
                    ),
                    if (_loginError != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _loginError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    if (_postSignOutNotice != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _postSignOutNotice!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.greenAccent),
                      ),
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
    NavigationRailDestination(
      icon: Icon(Icons.person_outline),
      label: Text('Overview'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.lock_outline),
      label: Text('Security'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.devices_other_outlined),
      label: Text('Devices'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.devices_outlined),
      label: Text('Sessions'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.security_outlined),
      label: Text('Activity'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.link_outlined),
      label: Text('Linked identities'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.apps_outlined),
      label: Text('Connected apps'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.business_outlined),
      label: Text('Organizations'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.privacy_tip_outlined),
      label: Text('Privacy'),
    ),
  ];

  Widget _buildApp(BuildContext context) {
    final mySub = _me?['sub']?.toString() ?? '';
    final useCompactActions = MediaQuery.sizeOf(context).width < 520;
    final page = switch (_navIndex) {
      0 => OverviewTab(api: _api),
      1 => SecurityTab(api: _api),
      2 => DevicesTab(api: _api),
      3 => SessionsTab(
        api: _api,
        onCurrentSessionRevoked: _onCurrentSessionRevoked,
      ),
      4 => SecurityActivityTab(api: _api),
      5 => IdentitiesTab(api: _api),
      6 => ConsentsTab(api: _api),
      7 => OrganizationsTab(api: _api),
      _ => PrivacyTab(
        api: _api,
        mySub: mySub,
        onAccountDeleted: _onAccountDeleted,
      ),
    };
    return ResponsiveNavigationScaffold(
      selectedIndex: _navIndex,
      onDestinationSelected: (index) {
        if (index != _navIndex) setState(() => _navIndex = index);
      },
      destinations: _destinations,
      drawerHeader: 'Your account',
      body: page,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Your account'),
            if (mySub.isNotEmpty)
              Text(
                mySub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          if (useCompactActions)
            IconButton(
              onPressed: _signOut,
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
            )
          else
            TextButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

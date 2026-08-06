import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/section_selector.dart';
import 'package:sso_admin/widgets/page_transition.dart';
import '../../i18n/app_strings.dart';
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
import 'notifications_tab.dart';
import 'notification_bell.dart';
import 'portal_entry.dart';
import '../../session.dart';
import '../../services/browser_navigation.dart';
import '../../widgets/responsive_navigation_scaffold.dart';

part 'portal_screen_notifications.dart';
part 'portal_screen_shell.dart';

/// Self-service account portal ("/portal") — entry widget referenced by
/// app_router.dart's resolveInitialScreen().
///
/// Auth model, ported from interfaces/web/portal/app.js: this portal has NO
/// login form of its own on the server. The end user is expected to already
/// hold a bearer access token (e.g. from a completed OIDC login elsewhere);
/// the token is accepted once it passes a GET /me probe, and every
/// subsequent call in this screen rides that same token.
///
/// On init this checks the shared [Session] first (matching admin_gate.dart's
/// pattern): a user who already signed in via /login or /admin lands straight
/// in the authenticated view with no re-paste. An unauthenticated visit is
/// sent through the unified hosted login with a validated return target. Web
/// uses browser navigation while native shells use the application navigator.
class PortalScreen extends StatefulWidget {
  /// Overrides the unified-login policy for embedded surfaces and tests.
  ///
  /// All product shells default to hosted login. Set this to false only when
  /// the caller deliberately supplies a bearer token minted elsewhere.
  final bool? redirectMissingSessionToLogin;
  final void Function(String location)? onLoginRedirect;
  final PortalApi? api;
  final Uri? routeUri;

  const PortalScreen({
    super.key,
    this.redirectMissingSessionToLogin,
    this.onLoginRedirect,
    this.api,
    this.routeUri,
  });

  @override
  State<PortalScreen> createState() => _PortalScreenState();
}

class _PortalScreenState extends State<PortalScreen> {
  late final PortalApi _api;
  late final Uri _routeUri;
  late PortalActionRoute _pendingAction;
  final TextEditingController _tokenCtrl = TextEditingController();

  Map<String, dynamic>? _me;
  bool _loggingIn = false;
  bool _resumingSession = true;
  String? _loginError;
  String? _postSignOutNotice;
  String? _actionNotice;
  bool _actionSucceeded = false;
  bool _actionHandled = false;
  bool _redirectingToLogin = false;
  int _navIndex = 0;
  int _notificationUnread = 0;
  List<Map<String, dynamic>> _recentNotifications = const [];
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;

  bool get _usesHostedLogin => widget.redirectMissingSessionToLogin ?? true;

  void _update(VoidCallback callback) => setState(callback);

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? PortalApi();
    _routeUri = widget.routeUri ?? Uri.base;
    _pendingAction = PortalActionRoute.fromUri(_routeUri);
    _tryResumeSession();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _tokenCtrl.dispose();
    super.dispose();
  }

  /// Mirrors admin_gate.dart's `_checkAccess`: a stored session token is
  /// tried against the same GET /me probe the manual-paste path uses, so
  /// this can never diverge from what "a valid token" means here. An
  /// explicit 401 clears the stale bearer and returns through hosted login;
  /// a 403 or transport failure preserves it so the user can retry.
  Future<void> _tryResumeSession() async {
    final token = Session.read();
    if (token == null) {
      if (_usesHostedLogin) {
        _startHostedLogin();
        return;
      }
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
        _navIndex = _pendingAction.isAvailable
            ? _pendingAction.navigationIndex
            : 0;
      });
      await _completePendingAction();
      unawaited(_initializeNotifications());
    } on PortalApiError catch (error) {
      if (!mounted) return;
      if (error.status == 401) {
        // Only an explicit authentication failure invalidates the browser
        // session. A valid bearer can still receive 403 for a portal feature
        // or tenant policy and must not be silently logged out.
        Session.clear();
        if (_usesHostedLogin) {
          _startHostedLogin();
        } else {
          setState(() {
            _resumingSession = false;
            _loginError = AppStrings.of(context).sessionExpired;
          });
        }
        return;
      }
      setState(() {
        _resumingSession = false;
        _loginError = error.status == 403
            ? context.tr(
                'This session is not authorized to use the account portal.',
              )
            : AppStrings.of(context).networkErrorRetry;
      });
    } catch (_) {
      // Network and transport failures are not proof that a bearer is stale.
      // Keep the tab-scoped token and offer an explicit retry instead of
      // turning an outage into an unsolicited logout.
      if (!mounted) return;
      setState(() {
        _resumingSession = false;
        _loginError = AppStrings.of(context).networkErrorRetry;
      });
    }
  }

  void _retryStoredSession() {
    if (!mounted || Session.read() == null) return;
    setState(() {
      _resumingSession = true;
      _loginError = null;
    });
    unawaited(_tryResumeSession());
  }

  void _startHostedLogin() {
    if (!mounted) return;
    unawaited(_stopNotifications());
    setState(() {
      _me = null;
      _resumingSession = false;
      _redirectingToLogin = true;
      _navIndex = 0;
    });
    final location = portalLoginLocation(_routeUri);
    final redirect = widget.onLoginRedirect;
    if (redirect == null) {
      BrowserNavigation.replaceLocation(location);
    } else {
      redirect(location);
    }
  }

  Future<void> _login() async {
    final strings = AppStrings.of(context);
    final t = _tokenCtrl.text.trim();
    if (t.isEmpty) {
      setState(() => _loginError = strings.enterToken);
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
        _navIndex = _pendingAction.isAvailable
            ? _pendingAction.navigationIndex
            : 0;
      });
      await _completePendingAction();
      unawaited(_initializeNotifications());
    } catch (_) {
      setState(() => _loginError = strings.tokenNotAccepted);
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  Future<void> _signOut() async {
    await _stopNotifications();
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
    if (_usesHostedLogin) {
      _startHostedLogin();
      return;
    }
    setState(() {
      _me = null;
      _tokenCtrl.clear();
      _navIndex = 0;
    });
  }

  void _onAccountDeleted() {
    final strings = AppStrings.of(context);
    _api.onSessionExpired = null;
    _tokenCtrl.clear();
    Session.clear();
    unawaited(_stopNotifications());
    if (_usesHostedLogin) {
      _startHostedLogin();
      return;
    }
    setState(() {
      _me = null;
      _navIndex = 0;
      _postSignOutNotice = strings.accountDeleted;
    });
  }

  void _onCurrentSessionRevoked() {
    final strings = AppStrings.of(context);
    _api.onSessionExpired = null;
    _tokenCtrl.clear();
    Session.clear();
    unawaited(_stopNotifications());
    if (_usesHostedLogin) {
      _startHostedLogin();
      return;
    }
    setState(() {
      _me = null;
      _navIndex = 0;
      _postSignOutNotice = strings.sessionRevoked;
    });
  }

  /// The [PortalApi.onSessionExpired] equivalent of admin_gate.dart's
  /// redirect-to-login on a mid-session authentication failure. Every product
  /// shell returns through hosted login unless explicit token mode was chosen.
  void _handleSessionExpired() {
    final strings = AppStrings.of(context);
    _api.onSessionExpired = null;
    _tokenCtrl.clear();
    Session.clear();
    unawaited(_stopNotifications());
    if (!mounted) return;
    if (_usesHostedLogin) {
      _startHostedLogin();
      return;
    }
    setState(() {
      _me = null;
      _navIndex = 0;
      _postSignOutNotice = strings.sessionExpired;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_resumingSession || _redirectingToLogin) {
      return PortalEntryProgress(redirecting: _redirectingToLogin);
    }
    return _me == null
        ? PortalTokenGate(
            tokenController: _tokenCtrl,
            loggingIn: _loggingIn,
            error: _loginError,
            notice: _postSignOutNotice,
            onLogin: _login,
            onRetry: Session.read() == null ? null : _retryStoredSession,
          )
        : _buildApp(context);
  }
}

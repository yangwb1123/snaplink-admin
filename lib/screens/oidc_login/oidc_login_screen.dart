import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'federated_login.dart';
import 'oauth_params.dart';
import 'oidc_login_api.dart';
import 'trusted_device_token.dart';
import 'webauthn_assertion.dart';
import 'package:web/web.dart' as web;
import '../../session.dart';
import '../../i18n/app_strings.dart';
import '../../app_settings.dart';

enum _View { login, mfa, consent, success }

/// Connection IDs offered as "Sign in with ..." buttons. Shown unconditionally
/// — a connection that isn't actually configured on the server just fails
/// with the normal unsupported_provider error when clicked (anti-enumeration:
/// this screen has no way to know server-side connection config, and
/// shouldn't leak it by hiding/showing buttons based on a probe).
const _federatedConnections = [
  (id: 'google', label: 'Google', icon: Icons.g_mobiledata),
  (id: 'github', label: 'GitHub', icon: Icons.code),
];

/// The hosted /login/ page: replaces interfaces/web/login/{index.html,app.js}.
/// Serves TWO purposes on the same screen:
///  - External relying parties (the IM/Source demos, and any future RP)
///    redirect here with authorization-request query params — the JS's core
///    contract: authorization_code / implicit redirect handling, MFA,
///    consent, forgot password, signup.
///  - First-party access (no RP query params — this app's own /login/ and
///    /admin/ areas): a successful login stores the token (see
///    [Session]) and does a REAL browser redirect to the `?redirect=`
///    query param (validated same-origin-relative, default `/admin/`) — the
///    "no session, then /login?redirect=[path], then sign in, then land on
///    [path]" pattern every protected route uses (see admin_gate.dart).
/// Supports password, code-based providers, federated redirects, and browser
/// WebAuthn ceremonies, B2B home-realm routing, and host-scoped branding.
class OidcLoginScreen extends StatefulWidget {
  /// Used as client_id when the URL carries no RP client_id — the first-party
  /// case (direct /login/ or /admin/ access). Both admin and regular
  /// accounts authenticate as this SAME client; /admin's RBAC gate (not a
  /// separate login) is what differentiates what they can see afterward.
  final String? defaultClientId;

  const OidcLoginScreen({super.key, this.defaultClientId});

  @override
  State<OidcLoginScreen> createState() => _OidcLoginScreenState();
}

/// Query param a protected route redirects here with, naming where to land
/// after a successful first-party login. Validated in [_safeRedirectTarget]
/// — must be a same-origin relative path, never an absolute/external URL
/// (an unvalidated redirect target here would be an open-redirect hole: a
/// crafted /login/?redirect=https://evil.example link would send a freshly
/// authenticated session's browser off-site).
const _redirectParam = 'redirect';
const _defaultRedirectTarget = '/admin/';
const _codeProviders = {'phone', 'email', 'magiclink'};
const _localCredentialProviders = {
  'password',
  'phone',
  'email',
  'magiclink',
  'totp',
  'webauthn',
};

Color? _parseBrandColor(String? raw) {
  final value = raw?.trim() ?? '';
  final match = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').firstMatch(value);
  if (match == null) return null;
  final hex = match.group(1)!;
  return Color(int.parse(hex.length == 6 ? 'ff$hex' : hex, radix: 16));
}

String? _magicLinkEmail() {
  final fragment = Uri.base.fragment;
  if (fragment.isEmpty) return null;
  return Uri(query: fragment).queryParameters['email'];
}

String _safeRedirectTarget() {
  final raw = Uri.base.queryParameters[_redirectParam];
  if (raw == null || raw.isEmpty || raw.contains('\\')) {
    return _defaultRedirectTarget;
  }
  // Resolve with the same (WHATWG-equivalent) parser the browser will apply
  // and compare origins, rather than a hand-rolled prefix denylist — a
  // string-prefix check can't see tricks like backslash-as-slash
  // normalization that change how the resolved URL's authority is parsed.
  try {
    final resolved = Uri.base.resolve(raw);
    if (!resolved.hasAuthority || resolved.origin != Uri.base.origin) {
      return _defaultRedirectTarget;
    }
  } catch (_) {
    return _defaultRedirectTarget;
  }
  return raw;
}

class _OidcLoginScreenState extends State<OidcLoginScreen> {
  late final OAuthParams _params = OAuthParams.fromUri(Uri.base);
  final OidcLoginApi _api = OidcLoginApi();

  _View _view = _View.login;
  String _provider = 'password';
  List<String> _providers = const ['password'];

  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _codeTargetCtrl = TextEditingController();
  final _providerCodeCtrl = TextEditingController();
  bool _codeSent = false;
  String? _codeMessage;
  bool _loading = false;
  String? _error;
  String? _brandName;
  String? _brandLogoUrl;
  Color? _brandColor;

  // MFA state
  String _mfaChallengeId = '';
  List<String> _mfaMethods = const [];
  Map<String, Map<String, String>> _mfaMethodData = const {};
  String? _selectedMfaMethod;
  final _mfaCodeCtrl = TextEditingController();
  bool _trustThisDevice = false;

  // Consent state
  Map<String, dynamic>? _pendingLoginPayload;
  String _consentChallengeId = '';
  String _consentClientName = '';

  // Forgot-password / signup panel state
  bool _showForgot = false;
  bool _showSignup = false;
  final _forgotIdCtrl = TextEditingController();
  String? _forgotMsg;
  bool _showReset = false;
  bool _showTokenChoice = false;
  bool _showEmailVerification = false;
  final _resetPassCtrl = TextEditingController();
  final _resetConfirmCtrl = TextEditingController();
  String? _resetMsg;
  final _signupUserCtrl = TextEditingController();
  final _signupPassCtrl = TextEditingController();
  final _signupEmailCtrl = TextEditingController();
  String? _signupConfirmed;

  /// client_id to actually use: the URL's own (an RP-initiated flow) when
  /// present, else [OidcLoginScreen.defaultClientId] (first-party access).
  String get _effectiveClientId => _params.clientId.isNotEmpty
      ? _params.clientId
      : (widget.defaultClientId ?? '');

  bool _checkingFederatedReturn = true;

  bool get _usesCodeProvider => _codeProviders.contains(_provider);

  bool get _usesTotpProvider => _provider == 'totp';

  /// Tenant-owned connection ids must start as a top-level navigation so the
  /// browser can follow the upstream IdP's cross-origin redirect.
  bool get _usesFederatedProvider =>
      !_localCredentialProviders.contains(_provider);

  String? get _magicLinkToken => Uri.base.queryParameters['token'];

  @override
  void initState() {
    super.initState();
    _provider = _params.provider.isNotEmpty ? _params.provider : 'password';
    _userCtrl.text = _params.loginHint;
    final magicEmail = _magicLinkEmail();
    final followsMagicLink = _magicLinkToken != null && magicEmail != null;
    final tokenFlow = Uri.base.queryParameters['flow'];
    if (followsMagicLink) {
      _provider = 'magiclink';
      _codeTargetCtrl.text = magicEmail;
      WidgetsBinding.instance.addPostFrameCallback((_) => _submitLogin());
    } else if (_magicLinkToken != null) {
      _showEmailVerification = tokenFlow == 'verify-email';
      _showReset = tokenFlow == 'reset-password';
      _showTokenChoice = !_showEmailVerification && !_showReset;
    }
    if (Uri.base.queryParameters['verified'] == 'email') {
      _signupConfirmed = 'Email verified — you can now sign in.';
    }
    _loadBranding();
    _checkFederatedReturn();
    if (_effectiveClientId.isNotEmpty &&
        !followsMagicLink &&
        !_params.hasPromptNone) {
      _probeProviders();
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _codeTargetCtrl.dispose();
    _providerCodeCtrl.dispose();
    _mfaCodeCtrl.dispose();
    _forgotIdCtrl.dispose();
    _resetPassCtrl.dispose();
    _resetConfirmCtrl.dispose();
    _signupUserCtrl.dispose();
    _signupPassCtrl.dispose();
    _signupEmailCtrl.dispose();
    super.dispose();
  }

  /// Runs once on load: if this page was just redirected back to from a
  /// federated provider (see federated_login.dart), finish the exchange and
  /// complete the first-party login instead of showing the plain form.
  Future<void> _checkFederatedReturn() async {
    try {
      final result = await FederatedLogin.consumeReturnIfPresent();
      if (!mounted) return;
      if (result != null) {
        _completeFirstPartyLogin(
          result.accessToken,
          redirectTarget: result.redirectTarget,
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Sign-in failed: $e');
    }
    if (_isRpFlow && _params.hasPromptNone) {
      await _submitSilentRenewal();
      if (mounted) setState(() => _checkingFederatedReturn = false);
      return;
    }
    if (mounted) setState(() => _checkingFederatedReturn = false);
  }

  /// Stores the session and does a REAL browser redirect to the target path
  /// — a fresh page load, so the target route (e.g. admin_gate.dart) sees the
  /// session via [Session.read] exactly like any other visit, no in-memory
  /// hand-off needed.
  void _completeFirstPartyLogin(
    String accessToken, {
    String? redirectTarget,
    String? sessionId,
  }) {
    Session.store(
      accessToken,
      sessionId: sessionId,
      clientId: _effectiveClientId,
    );
    _redirect(redirectTarget ?? _safeRedirectTarget());
  }

  /// True when this page was reached via an external RP's authorization
  /// request rather than direct first-party console access — see
  /// [_effectiveClientId].
  bool get _isRpFlow =>
      _params.clientId.isNotEmpty && _params.redirectUri.isNotEmpty;

  /// The normal login path validates an RP redirect URI on Snaplink before it
  /// returns a code or token. Its prompt=none branch currently returns JSON
  /// without performing that validation, so the console must never relay a
  /// silent-response credential to a cross-origin URI supplied in the page
  /// query. Same-origin console clients remain safe to complete here; external
  /// RPs need Snaplink to render the validated authorization response itself.
  bool get _hasSameOriginRpRedirect {
    final redirect = Uri.tryParse(_params.redirectUri);
    return redirect != null &&
        redirect.hasAuthority &&
        redirect.origin == Uri.base.origin;
  }

  bool get _usesJarm =>
      _params.responseMode == 'jwt' || _params.responseMode.endsWith('.jwt');

  void _signInWithFederated(String connectionId) {
    final clientId = _effectiveClientId;
    if (clientId.isEmpty) {
      setState(() => _error = 'No client configured for sign-in.');
      return;
    }
    if (_isRpFlow) {
      // Carry the RP's own redirect_uri/state/nonce/PKCE through to the
      // connection dispatch instead of starting a brand-new console-only
      // PKCE flow — this is a real top-level navigation, so the SSO server
      // completes the connection round trip and returns control straight to
      // the RP's registered redirect_uri, exactly like the password path.
      final query = _params.toLoginPayload(connectionId);
      query['response_type'] = _params.responseType.isNotEmpty
          ? _params.responseType
          : 'code';
      _redirect(
        Uri.base
            .resolve('../auth/login')
            .replace(queryParameters: query)
            .toString(),
      );
      return;
    }
    final url = FederatedLogin.beginLoginUrl(
      connectionId: connectionId,
      clientId: clientId,
      redirectTarget: _safeRedirectTarget(),
    );
    _redirect(url);
  }

  Future<void> _probeProviders() async {
    try {
      final out = await _api.probeProviders(
        _effectiveClientId,
        loginHint: _params.loginHint,
      );
      if (!mounted) return;
      final connectionId = out.data['connection_id']?.toString() ?? '';
      if (out.data['connection_required'] == true && connectionId.isNotEmpty) {
        _signInWithFederated(connectionId);
        return;
      }
      final providers = out.data['providers'];
      if (providers is List && providers.isNotEmpty) {
        setState(() {
          _providers = providers.map((e) => e.toString()).toList();
          if (!_providers.contains(_provider)) _provider = _providers.first;
        });
      }
    } catch (_) {
      // best-effort — the default "password" provider stays selectable.
    }
  }

  Future<void> _loadBranding() async {
    try {
      final branding = await _api.loadBranding();
      if (!mounted || branding.isEmpty) return;
      final logo = branding['logo_url']?.trim();
      final logoUri = logo == null || logo.isEmpty ? null : Uri.tryParse(logo);
      final safeLogo =
          logoUri != null &&
              (logoUri.scheme == 'https' ||
                  ((logoUri.scheme == 'http' || logoUri.scheme.isEmpty) &&
                      (logoUri.host.isEmpty ||
                          logoUri.origin == Uri.base.origin)))
          ? logo
          : null;
      setState(() {
        _brandName = branding['brand_name']?.trim();
        _brandLogoUrl = safeLogo;
        _brandColor = _parseBrandColor(branding['primary_color']);
      });
    } catch (_) {
      // Branding is cosmetic; the default login page remains usable.
    }
  }

  Future<void> _discoverHomeRealm() async {
    final identifier = _userCtrl.text.trim();
    if (identifier.isEmpty) {
      setState(() => _error = 'Enter your work email first.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final outcome = await _api.discoverHomeRealm(identifier);
      if (!mounted) return;
      final connectionId = outcome.data['connection_id']?.toString() ?? '';
      if (outcome.ok &&
          outcome.data['found'] == true &&
          connectionId.isNotEmpty) {
        _signInWithFederated(connectionId);
        return;
      }
      setState(
        () => _error = outcome.status == 404
            ? 'Organization sign-in is not enabled.'
            : 'No organization sign-in was found for that address.',
      );
    } catch (_) {
      if (mounted) setState(() => _error = AppStrings.of(context).networkError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _redirect(String url) {
    web.window.location.replace(url);
  }

  void _handleSuccess(LoginOutcome outcome) {
    if (_trustThisDevice) {
      TrustedDeviceToken.store(
        _effectiveClientId,
        outcome.data['device_token']?.toString() ?? '',
      );
    }
    if (outcome.isFormPost && _isRpFlow) {
      _submitServerFormPost(outcome.html!);
      return;
    }
    final data = outcome.data;
    if (_usesJarm && _isRpFlow && outcome.redirectUrl != null) {
      final loginUrl = Uri.base.resolve('../auth/login');
      if (outcome.redirectUrl != loginUrl) {
        _redirect(outcome.redirectUrl.toString());
        return;
      }
    }
    final redirectUri = _params.redirectUri;
    if (data['code'] != null && redirectUri.isNotEmpty) {
      _redirectAuthorizationResponse({
        'code': data['code'].toString(),
        if ((data['state'] ?? _params.state).toString().isNotEmpty)
          'state': (data['state'] ?? _params.state).toString(),
        if (data['iss'] != null) 'iss': data['iss'].toString(),
      }, tokenResponse: false);
      return;
    }
    if (redirectUri.isNotEmpty &&
        (data['access_token'] != null || data['id_token'] != null)) {
      final fragment = <String, String>{
        if (data['access_token'] != null)
          'access_token': data['access_token'].toString(),
        if (data['access_token'] != null)
          'token_type': (data['token_type'] ?? 'Bearer').toString(),
        if (data['expires_in'] != null)
          'expires_in': data['expires_in'].toString(),
        if (data['id_token'] != null) 'id_token': data['id_token'].toString(),
        if (data['scope'] != null) 'scope': data['scope'].toString(),
        if ((data['state'] ?? _params.state).toString().isNotEmpty)
          'state': (data['state'] ?? _params.state).toString(),
        if (data['session_state'] != null)
          'session_state': data['session_state'].toString(),
        if (data['iss'] != null) 'iss': data['iss'].toString(),
      };
      _redirectAuthorizationResponse(fragment, tokenResponse: true);
      return;
    }
    if (data['access_token'] != null) {
      _completeFirstPartyLogin(
        data['access_token'].toString(),
        sessionId: data['session_id']?.toString(),
      );
      return;
    }
    setState(() => _view = _View.success);
  }

  /// Delivers a non-JARM authorization response with the mode requested by
  /// the relying party. Successful form-post responses still come from the
  /// server; this covers client-side consent and prompt=none error paths.
  void _redirectAuthorizationResponse(
    Map<String, String> response, {
    required bool tokenResponse,
  }) {
    final redirectUri = _params.redirectUri;
    if (redirectUri.isEmpty) return;
    final mode = _params.responseMode;
    if (mode == 'form_post') {
      _submitAuthorizationFormPost(redirectUri, response);
      return;
    }
    final target = Uri.parse(redirectUri);
    final useFragment = mode == 'fragment' || (mode.isEmpty && tokenResponse);
    if (useFragment) {
      _redirect(
        target
            .replace(fragment: Uri(queryParameters: response).query)
            .toString(),
      );
      return;
    }
    _redirect(
      target
          .replace(queryParameters: {...target.queryParameters, ...response})
          .toString(),
    );
  }

  /// JARM responses must be signed by Snaplink. The console intentionally
  /// never fabricates one; a server JSON error cannot safely satisfy a JARM
  /// request, so leave an explicit error on the hosted page instead.
  void _redirectAuthorizationError(LoginOutcome outcome) {
    final error = outcome.error ?? 'login_required';
    if (!_isRpFlow || _usesJarm) {
      setState(
        () => _error = _usesJarm
            ? 'The authorization server must return this JARM error directly.'
            : error,
      );
      return;
    }
    _redirectAuthorizationResponse({
      'error': error,
      if (outcome.data['error_description'] != null)
        'error_description': outcome.data['error_description'].toString(),
      if (_params.state.isNotEmpty) 'state': _params.state,
      if (outcome.data['iss'] != null) 'iss': outcome.data['iss'].toString(),
    }, tokenResponse: false);
  }

  void _submitAuthorizationFormPost(
    String redirectUri,
    Map<String, String> response,
  ) {
    final form = web.HTMLFormElement()
      ..method = 'post'
      ..action = redirectUri;
    for (final entry in response.entries) {
      form.append(
        web.HTMLInputElement()
          ..type = 'hidden'
          ..name = entry.key
          ..value = entry.value,
      );
    }
    web.window.document.body?.append(form);
    form.submit();
  }

  Future<void> _submitSilentRenewal() async {
    if (!_hasSameOriginRpRedirect) {
      setState(
        () => _error =
            'Silent sign-in for an external relying party must be completed by the authorization server.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = _params.toLoginPayload('');
      payload['client_id'] = _effectiveClientId;
      final outcome = await _api.login(payload);
      if (!mounted) return;
      if (outcome.ok) {
        _handleSuccess(outcome);
      } else {
        _redirectAuthorizationError(outcome);
      }
    } catch (_) {
      if (mounted) {
        _redirectAuthorizationError(
          LoginOutcome(0, const {'error': 'temporarily_unavailable'}),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Snaplink owns the generated form and its escaped code/JARM response.
  /// Writing it into this same-origin document preserves the exact browser
  /// form submission contract instead of trying to reinterpret an RP redirect
  /// as JSON in the SPA.
  void _submitServerFormPost(String html) {
    final document = web.window.document;
    document.callMethod<JSAny?>('open'.toJS);
    document.callMethod<JSAny?>('write'.toJS, html.toJS);
    document.callMethod<JSAny?>('close'.toJS);
  }

  void _handleLoginError(LoginOutcome out) {
    if (out.isMfaRequired) {
      setState(() {
        _mfaChallengeId = out.data['mfa_challenge_id']?.toString() ?? '';
        _mfaMethods = (out.data['mfa_methods'] as List? ?? [])
            .map((e) => e.toString())
            .toList();
        _mfaMethodData = _methodData(out.data['mfa_method_data']);
        _selectedMfaMethod = _mfaMethods.length == 1 ? _mfaMethods.first : null;
        _view = _View.mfa;
        _error = null;
      });
      return;
    }
    if (out.isConsentRequired) {
      setState(() {
        _consentChallengeId =
            out.data['consent_challenge_id']?.toString() ?? '';
        _consentClientName = out.data['client_name']?.toString() ?? '';
        _view = _View.consent;
        _error = null;
      });
      return;
    }
    if (out.error == 'password_expired') {
      // This response is only returned after the user has proved possession
      // of their current password. Route them into the reset flow instead of
      // leaving a dead-end server code on the sign-in form.
      setState(() {
        _view = _View.login;
        _forgotIdCtrl.text = _userCtrl.text.trim();
        _showForgot = true;
        _forgotMsg =
            'Your password has expired. Request a reset link to continue.';
        _error = null;
      });
      return;
    }
    setState(
      () => _error = out.error ?? 'Authentication failed. Please try again.',
    );
  }

  Map<String, Map<String, String>> _methodData(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.value is Map)
          entry.key.toString(): {
            for (final value in (entry.value as Map).entries)
              value.key.toString(): value.value.toString(),
          },
    };
  }

  Future<void> _submitLogin() async {
    if (_usesFederatedProvider) {
      _signInWithFederated(_provider);
      return;
    }
    if (_provider == 'webauthn') {
      await _submitPasskeyLogin();
      return;
    }
    final code = _magicLinkToken ?? _providerCodeCtrl.text.trim();
    if (_usesCodeProvider &&
        (_codeTargetCtrl.text.trim().isEmpty || code.isEmpty)) {
      setState(() => _error = 'Request a code and enter it before signing in.');
      return;
    }
    if (_usesTotpProvider && (_userCtrl.text.trim().isEmpty || code.isEmpty)) {
      setState(() => _error = 'Enter your username and verification code.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final payload = _params.toLoginPayload(_provider);
    payload['client_id'] = _effectiveClientId;
    final trustedDeviceToken = TrustedDeviceToken.read(_effectiveClientId);
    if (trustedDeviceToken != null && trustedDeviceToken.isNotEmpty) {
      payload['device_token'] = trustedDeviceToken;
    }
    payload['credential'] = _usesCodeProvider
        ? {
            _provider == 'phone' ? 'phone' : 'email': _codeTargetCtrl.text
                .trim(),
            'code': code,
          }
        : _usesTotpProvider
        ? {'username': _userCtrl.text.trim(), 'code': code}
        : {'username': _userCtrl.text.trim(), 'password': _passCtrl.text};
    _pendingLoginPayload = payload;
    try {
      final out = await _api.login(payload);
      if (out.ok) {
        _handleSuccess(out);
      } else {
        _handleLoginError(out);
      }
    } catch (_) {
      setState(() => _error = AppStrings.of(context).networkError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendProviderCode() async {
    final target = _codeTargetCtrl.text.trim();
    if (target.isEmpty) {
      setState(
        () => _codeMessage =
            'Enter your ${_provider == 'phone' ? 'phone number' : 'email address'} first.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _codeMessage = null;
    });
    try {
      final out = await _api.sendCode(_provider, target);
      if (!mounted) return;
      setState(() {
        _codeSent = out.ok;
        _codeMessage = out.ok
            ? _provider == 'magiclink'
                  ? 'If this address can receive mail, a sign-in link has been sent.'
                  : 'If this address can receive messages, a verification code has been sent.'
            : out.error ?? 'Could not send a verification code.';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _codeMessage = AppStrings.of(context).networkError);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitPasskeyLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final begin = await _api.beginPasswordlessWebAuthn();
      final sessionId = begin.data['session_id']?.toString() ?? '';
      final options = begin.data['options'];
      if (!begin.ok || sessionId.isEmpty || options == null) {
        setState(
          () => _error = begin.error ?? 'Passkey sign-in is not enabled.',
        );
        return;
      }
      final assertion = await WebAuthnAssertion.request(options);
      final payload = _params.toLoginPayload('webauthn');
      payload['client_id'] = _effectiveClientId;
      final trustedDeviceToken = TrustedDeviceToken.read(_effectiveClientId);
      if (trustedDeviceToken != null && trustedDeviceToken.isNotEmpty) {
        payload['device_token'] = trustedDeviceToken;
      }
      payload['credential'] = {'session_id': sessionId, 'assertion': assertion};
      _pendingLoginPayload = payload;
      final out = await _api.login(payload);
      if (out.ok) {
        _handleSuccess(out);
      } else {
        _handleLoginError(out);
      }
    } on FormatException catch (_) {
      setState(() => _error = 'This passkey request is invalid. Try again.');
    } on StateError catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = AppStrings.of(context).networkError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitMfa() async {
    if (_selectedMfaMethod == null) {
      setState(() => _error = 'Select a verification method.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final method = _selectedMfaMethod!;
      String? code;
      Map<String, String>? params;
      if (method == 'webauthn') {
        final data = _mfaMethodData[method];
        final options = data?['options'];
        final session = data?['session'];
        if (options == null || session == null) {
          throw StateError('This passkey challenge is no longer available.');
        }
        final assertion = await WebAuthnAssertion.request(options);
        params = {'session': session, 'assertion': assertion};
      } else if (method == 'push') {
        final approvalId = _mfaMethodData[method]?['approval_id'];
        if (approvalId == null || approvalId.isEmpty) {
          throw StateError('This push approval is no longer available.');
        }
        // The server holds this request until the external notification is
        // approved, denied, or expires. The browser never calls its trusted
        // push callback directly.
        params = {'approval_id': approvalId};
      } else {
        code = _mfaCodeCtrl.text.trim();
      }
      final out = await _api.mfaComplete(
        mfaChallengeId: _mfaChallengeId,
        method: method,
        code: code,
        params: params,
        trustDevice: _trustThisDevice,
      );
      if (out.ok) {
        _handleSuccess(out);
      } else {
        setState(() => _error = out.error ?? 'Verification failed.');
      }
    } on FormatException catch (_) {
      setState(
        () => _error = 'This passkey challenge is invalid. Try another method.',
      );
    } on StateError catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Passkey verification failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitConsent(bool allow) async {
    if (!allow) {
      if (_isRpFlow && !_usesJarm) {
        _redirectAuthorizationResponse({
          'error': 'access_denied',
          if (_params.state.isNotEmpty) 'state': _params.state,
        }, tokenResponse: false);
      } else {
        setState(() => _view = _View.login);
      }
      return;
    }
    if (_pendingLoginPayload == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = {
        ..._pendingLoginPayload!,
        'consent_challenge_id': _consentChallengeId,
      };
      final out = await _api.login(payload);
      if (out.ok) {
        _handleSuccess(out);
      } else {
        _handleLoginError(out);
      }
    } catch (_) {
      setState(() => _error = AppStrings.of(context).networkError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitForgot() async {
    final id = _forgotIdCtrl.text.trim();
    if (id.isEmpty) {
      setState(() => _forgotMsg = 'Enter your username or email.');
      return;
    }
    setState(() => _loading = true);
    try {
      final status = await _api.forgotPassword(id);
      if (status == 404) {
        setState(() => _forgotMsg = 'Password reset is not enabled.');
      } else if (status >= 200 && status < 300) {
        setState(
          () => _forgotMsg =
              'If that account exists, a reset link has been sent.',
        );
      } else {
        setState(
          () => _forgotMsg = 'Could not request a reset. Please try again.',
        );
      }
    } catch (_) {
      setState(() => _forgotMsg = AppStrings.of(context).networkError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitReset() async {
    final token = _magicLinkToken;
    if (token == null || token.isEmpty) {
      setState(() => _resetMsg = 'This password-reset link is invalid.');
      return;
    }
    if (_resetPassCtrl.text.isEmpty ||
        _resetPassCtrl.text != _resetConfirmCtrl.text) {
      setState(() => _resetMsg = 'Enter matching new passwords.');
      return;
    }
    setState(() {
      _loading = true;
      _resetMsg = null;
    });
    try {
      final out = await _api.resetPassword(token, _resetPassCtrl.text);
      if (!mounted) return;
      if (out.status >= 200 && out.status < 300) {
        final clean = Uri.base.replace(
          queryParameters: {
            for (final entry in Uri.base.queryParameters.entries)
              if (entry.key != 'token') entry.key: entry.value,
          },
          fragment: '',
        );
        _redirect(clean.toString());
        return;
      }
      setState(
        () => _resetMsg = out.error == 'password_policy_violation'
            ? 'That password does not meet this account’s policy.'
            : 'This password-reset link is invalid or has expired.',
      );
    } catch (_) {
      if (mounted) {
        setState(() => _resetMsg = AppStrings.of(context).networkError);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitEmailVerification() async {
    final token = _magicLinkToken;
    if (token == null || token.isEmpty) {
      setState(() => _resetMsg = 'This email-verification link is invalid.');
      return;
    }
    setState(() {
      _loading = true;
      _resetMsg = null;
    });
    try {
      final outcome = await _api.verifyEmail(token);
      if (!mounted) return;
      if (outcome.status >= 200 && outcome.status < 300) {
        final clean = Uri.base.replace(
          queryParameters: {
            for (final entry in Uri.base.queryParameters.entries)
              if (entry.key != 'token' && entry.key != 'flow')
                entry.key: entry.value,
            'verified': 'email',
          },
          fragment: '',
        );
        _redirect(clean.toString());
        return;
      }
      setState(
        () => _resetMsg =
            'This email-verification link is invalid or has expired.',
      );
    } catch (_) {
      if (mounted) {
        setState(() => _resetMsg = AppStrings.of(context).networkError);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitSignup() async {
    final username = _signupUserCtrl.text.trim();
    final password = _signupPassCtrl.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter a username and password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final out = await _api.register(
        username: username,
        password: password,
        email: _signupEmailCtrl.text.trim(),
      );
      if (out.status == 404) {
        setState(() => _error = 'Self-service signup is not enabled.');
      } else if (out.status == 409) {
        setState(() => _error = 'That account already exists.');
      } else if (out.status >= 200 && out.status < 300) {
        setState(() {
          _userCtrl.text = username;
          _showSignup = false;
          _signupConfirmed = out.data['status'] == 'pending'
              ? 'Check your email to verify your account before signing in.'
              : 'Account created — you can now sign in.';
        });
      } else {
        setState(
          () => _error = 'Could not create the account. Please try again.',
        );
      }
    } catch (_) {
      setState(() => _error = AppStrings.of(context).networkError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // LayoutBuilder + SingleChildScrollView + a minHeight constraint: the
      // login card's content (language toggle + form + federated buttons)
      // can be taller than a short viewport (mobile portrait, a small
      // browser window, browser zoom) — scroll instead of overflowing,
      // while still centering vertically when it DOES fit (a bare
      // SingleChildScrollView(child: Center(...)) gives Center unbounded
      // height and breaks centering entirely).
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _languageToggle(),
                          const SizedBox(height: 8),
                          if (_brandName != null || _brandLogoUrl != null) ...[
                            _brandingHeader(),
                            const SizedBox(height: 16),
                          ],
                          _buildView(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Small EN / 中文 toggle shown above every view of this screen (login,
  /// MFA, consent, forgot/signup, even the federated-return spinner) — a
  /// user may need to switch language before they've authenticated, so it
  /// can't live only on a post-login settings screen. Labels are
  /// deliberately plain literals, not translated: they name the language
  /// itself, not UI text in the current language.
  Widget _languageToggle() {
    final current = AppSettings.instance.locale.languageCode;
    Widget langButton(String code, String label) {
      final selected = current == code;
      return TextButton(
        onPressed: () => AppSettings.instance.locale = Locale(code),
        style: TextButton.styleFrom(
          foregroundColor: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [langButton('en', 'EN'), langButton('zh', '中文')],
    );
  }

  Widget _brandingHeader() => Row(
    children: [
      if (_brandLogoUrl != null) ...[
        Image.network(
          _brandLogoUrl!,
          width: 40,
          height: 40,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        const SizedBox(width: 12),
      ],
      Expanded(
        child: Text(
          _brandName ?? '',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: _brandColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );

  Widget _buildView() {
    if (_checkingFederatedReturn) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    switch (_view) {
      case _View.mfa:
        return _mfaView();
      case _View.consent:
        return _consentView();
      case _View.success:
        return Text(AppStrings.of(context).signedIn);
      case _View.login:
        return _loginView();
    }
  }

  Widget _loginView() {
    if (_showTokenChoice) return _tokenChoiceView();
    if (_showEmailVerification) return _emailVerificationView();
    if (_showReset) return _resetView();
    if (_showForgot) return _forgotView();
    if (_showSignup) return _signupView();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.of(context).signIn,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 20),
        if (_providers.length > 1) ...[
          DropdownButtonFormField<String>(
            initialValue: _provider,
            items: _providers
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: (v) => setState(() {
              _provider = v ?? _provider;
              _codeSent = false;
              _codeMessage = null;
              _error = null;
            }),
            decoration: InputDecoration(
              labelText: AppStrings.of(context).provider,
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (_signupConfirmed != null) ...[
          Text(
            _signupConfirmed!,
            style: const TextStyle(color: Colors.greenAccent),
          ),
          const SizedBox(height: 10),
        ],
        if (_usesFederatedProvider)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text('Continue to $_provider to sign in.'),
          )
        else if (_provider == 'webauthn')
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text('Choose a passkey to sign in without a password.'),
          )
        else if (_usesCodeProvider) ...[
          TextField(
            controller: _codeTargetCtrl,
            keyboardType: _provider == 'phone'
                ? TextInputType.phone
                : TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: _provider == 'phone'
                  ? 'Phone number'
                  : 'Email address',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _loading || _magicLinkToken != null
                ? null
                : _sendProviderCode,
            child: Text(
              _provider == 'magiclink'
                  ? (_codeSent ? 'Resend sign-in link' : 'Send sign-in link')
                  : (_codeSent ? 'Resend code' : 'Send code'),
            ),
          ),
          if (_codeMessage != null) ...[
            const SizedBox(height: 10),
            Text(_codeMessage!),
          ],
          if (_provider != 'magiclink' || _magicLinkToken == null) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _providerCodeCtrl,
              decoration: InputDecoration(
                labelText: _provider == 'magiclink'
                    ? 'Sign-in link token'
                    : AppStrings.of(context).verificationCode,
              ),
              onSubmitted: (_) => _submitLogin(),
            ),
          ],
        ] else if (_usesTotpProvider) ...[
          TextField(
            controller: _userCtrl,
            decoration: InputDecoration(
              labelText: AppStrings.of(context).username,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _providerCodeCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: AppStrings.of(context).verificationCode,
            ),
            onSubmitted: (_) => _submitLogin(),
          ),
        ] else ...[
          TextField(
            controller: _userCtrl,
            decoration: InputDecoration(
              labelText: AppStrings.of(context).username,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passCtrl,
            decoration: InputDecoration(
              labelText: AppStrings.of(context).password,
            ),
            obscureText: true,
            onSubmitted: (_) => _submitLogin(),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _loading ? null : _submitLogin,
          child: _loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _usesFederatedProvider
                      ? 'Continue with $_provider'
                      : _provider == 'webauthn'
                      ? 'Sign in with passkey'
                      : AppStrings.of(context).signIn,
                ),
        ),
        if (_provider == 'password') ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: TextButton(
                  onPressed: () => setState(() {
                    _forgotIdCtrl.text = _userCtrl.text;
                    _forgotMsg = null;
                    _showForgot = true;
                  }),
                  child: Text(
                    AppStrings.of(context).forgotPassword,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Flexible(
                child: TextButton(
                  onPressed: () => setState(() {
                    _error = null;
                    _showSignup = true;
                  }),
                  child: Text(
                    AppStrings.of(context).signUp,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          if (_provider == 'password')
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _loading ? null : _discoverHomeRealm,
                icon: const Icon(Icons.business_outlined),
                label: const Text('Use organization sign-in'),
              ),
            ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                AppStrings.of(context).orDivider,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 14),
        ..._federatedConnections.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton.icon(
              onPressed: () => _signInWithFederated(c.id),
              icon: Icon(c.icon),
              label: Text('${AppStrings.of(context).signInWith} ${c.label}'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _mfaView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.of(context).verifyIdentity,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: _mfaMethods.map((m) {
            final selected = _selectedMfaMethod == m;
            return ChoiceChip(
              label: Text(_mfaMethodLabel(context, m)),
              selected: selected,
              onSelected: (_) => setState(() => _selectedMfaMethod = m),
            );
          }).toList(),
        ),
        if (_selectedMfaMethod != null &&
            _selectedMfaMethod != 'webauthn' &&
            _selectedMfaMethod != 'push') ...[
          const SizedBox(height: 14),
          TextField(
            controller: _mfaCodeCtrl,
            decoration: InputDecoration(
              labelText: _selectedMfaMethod == 'recovery'
                  ? 'Recovery code'
                  : AppStrings.of(context).verificationCode,
            ),
          ),
        ],
        if (_selectedMfaMethod == 'webauthn') ...[
          const SizedBox(height: 14),
          const Text('Use a registered passkey to verify this sign-in.'),
        ],
        if (_selectedMfaMethod == 'push') ...[
          const SizedBox(height: 14),
          const Text(
            'Approve the sign-in notification on your registered device, then continue here.',
          ),
        ],
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Trust this device'),
          subtitle: const Text('Skip future MFA when this policy allows it.'),
          value: _trustThisDevice,
          onChanged: _loading
              ? null
              : (value) => setState(() => _trustThisDevice = value ?? false),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _loading ? null : _submitMfa,
          child: _loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _selectedMfaMethod == 'webauthn'
                      ? 'Use passkey'
                      : AppStrings.of(context).verify,
                ),
        ),
        TextButton(
          onPressed: () => setState(() {
            _view = _View.login;
            _error = null;
          }),
          child: Text(AppStrings.of(context).back),
        ),
      ],
    );
  }

  String _mfaMethodLabel(BuildContext context, String m) {
    final s = AppStrings.of(context);
    final labels = {
      'totp': s.mfaMethodTotp,
      'otp': s.mfaMethodOtp,
      'webauthn': s.mfaMethodWebauthn,
      'push': s.mfaMethodPush,
      'sms': s.mfaMethodSms,
    };
    return labels[m] ?? m;
  }

  Widget _consentView() {
    final scopes = _params.scope.where((s) => s != 'openid').toList();
    if (scopes.isEmpty) scopes.add('openid');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_consentClientName.isNotEmpty ? _consentClientName : _params.clientId} wants to:',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        ...scopes.map(
          (s) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('• ${_scopeLabel(s)}'),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _loading ? null : () => _submitConsent(false),
                child: const Text('Deny'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _loading ? null : () => _submitConsent(true),
                child: const Text('Allow'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _scopeLabel(String s) {
    const labels = {
      'openid': 'Verify your identity',
      'profile': 'View your profile information',
      'email': 'View your email address',
      'offline_access': 'Stay signed in (refresh token)',
    };
    return labels[s] ?? s;
  }

  Widget _forgotView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.of(context).resetPassword,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _forgotIdCtrl,
          decoration: InputDecoration(
            labelText: AppStrings.of(context).usernameOrEmail,
          ),
        ),
        if (_forgotMsg != null) ...[
          const SizedBox(height: 14),
          Text(_forgotMsg!),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _loading ? null : _submitForgot,
          child: _loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppStrings.of(context).sendResetLink),
        ),
        TextButton(
          onPressed: () => setState(() => _showForgot = false),
          child: Text(AppStrings.of(context).back),
        ),
      ],
    );
  }

  Widget _tokenChoiceView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Continue with your email link',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        const Text(
          'Choose the action that sent this link. This prevents a signup verification token from being treated as a password-reset token.',
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => setState(() {
            _showTokenChoice = false;
            _showEmailVerification = true;
            _resetMsg = null;
          }),
          child: const Text('Verify my email'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => setState(() {
            _showTokenChoice = false;
            _showReset = true;
            _resetMsg = null;
          }),
          child: const Text('Reset my password'),
        ),
      ],
    );
  }

  Widget _emailVerificationView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Verify your email',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        const Text('Confirm to finish creating your account.'),
        if (_resetMsg != null) ...[
          const SizedBox(height: 14),
          Text(_resetMsg!, style: const TextStyle(color: Colors.redAccent)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _loading ? null : _submitEmailVerification,
          child: _loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Verify email'),
        ),
        TextButton(
          onPressed: () => setState(() {
            _showEmailVerification = false;
            _showTokenChoice = true;
            _resetMsg = null;
          }),
          child: Text(AppStrings.of(context).back),
        ),
      ],
    );
  }

  Widget _resetView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.of(context).resetPassword,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _resetPassCtrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New password'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _resetConfirmCtrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Confirm new password'),
          onSubmitted: (_) => _submitReset(),
        ),
        if (_resetMsg != null) ...[
          const SizedBox(height: 14),
          Text(_resetMsg!, style: const TextStyle(color: Colors.redAccent)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _loading ? null : _submitReset,
          child: _loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Reset password'),
        ),
      ],
    );
  }

  Widget _signupView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.of(context).createAccount,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _signupUserCtrl,
          decoration: InputDecoration(
            labelText: AppStrings.of(context).username,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _signupPassCtrl,
          decoration: InputDecoration(
            labelText: AppStrings.of(context).password,
          ),
          obscureText: true,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _signupEmailCtrl,
          decoration: InputDecoration(
            labelText: AppStrings.of(context).emailOptional,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _loading ? null : _submitSignup,
          child: _loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppStrings.of(context).signUp),
        ),
        TextButton(
          onPressed: () => setState(() {
            _showSignup = false;
            _error = null;
          }),
          child: Text(AppStrings.of(context).back),
        ),
      ],
    );
  }
}

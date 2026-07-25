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
import 'login_view_widget.dart';
import 'language_toggle.dart';
import 'branding_header.dart';
import 'mfa_view.dart';
import 'consent_view.dart';
enum _View { login, mfa, consent, success }
/// Connection IDs offered as "Sign in with ..." buttons. Shown unconditionally
/// — a connection that isn't actually configured on the server just fails
/// with the normal unsupported_provider error when clicked (anti-enumeration:
/// this screen has no way to know server-side connection config, and
/// shouldn't leak it by hiding/showing buttons based on a probe).
/// OIDC login screen: RFC-compliant auth with password, code-based,
/// federated, WebAuthn, and B2B home-realm routing support.
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
/// Redirect target validation for first-party login.
String? _magicLinkEmail() { final f = Uri.base.fragment; return f.isEmpty ? null : Uri(query: f).queryParameters['email']; }
  String _safeRedirectTarget() {
    final raw = Uri.base.queryParameters['redirect'];
    if (raw == null || raw.isEmpty || raw.contains('\\')) return '/admin/';
    try { final r = Uri.base.resolve(raw); if (!r.hasAuthority || r.origin != Uri.base.origin) return '/admin/'; } catch (_) { return '/admin/'; }
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
  final _forgotIdCtrl = TextEditingController();
  final _resetPassCtrl = TextEditingController();
  final _resetConfirmCtrl = TextEditingController();
  final _signupUserCtrl = TextEditingController();
  final _signupPassCtrl = TextEditingController();
  final _signupEmailCtrl = TextEditingController();
  String? _signupConfirmed;
  /// client_id to actually use: the URL's own (an RP-initiated flow) when
  /// present, else [OidcLoginScreen.defaultClientId] (first-party access).
  String get _effectiveClientId => _params.clientId.isNotEmpty ? _params.clientId : (widget.defaultClientId ?? '');
  bool _checkingFederatedReturn = true;
  bool get _usesCodeProvider => {'phone', 'email', 'magiclink'}.contains(_provider);
  bool get _usesTotpProvider => _provider == 'totp';
  /// Tenant-owned connection ids must start as a top-level navigation so the
  /// browser can follow the upstream IdP's cross-origin redirect.
  bool get _usesFederatedProvider => !{'password', 'phone', 'email', 'magiclink', 'totp', 'webauthn'}.contains(_provider);
  String? get _magicLinkToken => Uri.base.queryParameters['token'];
  @override
  void initState() {
    super.initState();
    _provider = _params.provider.isNotEmpty ? _params.provider : 'password';
    _userCtrl.text = _params.loginHint;
    final magicEmail = _magicLinkEmail();
    final followsMagicLink = _magicLinkToken != null && magicEmail != null;
    if (followsMagicLink) { _provider = 'magiclink'; _codeTargetCtrl.text = magicEmail; WidgetsBinding.instance.addPostFrameCallback((_) => _submitLogin()); }
    if (Uri.base.queryParameters['verified'] == 'email') _signupConfirmed = 'Email verified.';
    _loadBranding(); _checkFederatedReturn();
    if (_effectiveClientId.isNotEmpty && !followsMagicLink && !_params.hasPromptNone) _probeProviders();
  }
  @override
  void dispose() {
    _userCtrl.dispose(); _passCtrl.dispose(); _codeTargetCtrl.dispose(); _providerCodeCtrl.dispose(); _mfaCodeCtrl.dispose();
    _forgotIdCtrl.dispose(); _resetPassCtrl.dispose(); _resetConfirmCtrl.dispose(); _signupUserCtrl.dispose(); _signupPassCtrl.dispose(); _signupEmailCtrl.dispose();
    super.dispose();
  }
  /// Runs once on load: if this page was just redirected back to from a
  /// federated provider (see federated_login.dart), finish the exchange and
  /// complete the first-party login instead of showing the plain form.
  Future<void> _checkFederatedReturn() async {
    try { final r = await FederatedLogin.consumeReturnIfPresent(); if (!mounted) return; if (r != null) { _completeFirstPartyLogin(r.accessToken, redirectTarget: r.redirectTarget); return; } }
    catch (e) { if (!mounted) return; setState(() => _error = 'Sign-in failed: $e'); }
    if (_isRpFlow && _params.hasPromptNone) { await _submitSilentRenewal(); if (mounted) setState(() => _checkingFederatedReturn = false); return; }
    if (mounted) setState(() => _checkingFederatedReturn = false);
  }
  /// Stores the session and does a REAL browser redirect to the target path
  /// — a fresh page load, so the target route (e.g. admin_gate.dart) sees the
  /// session via [Session.read] exactly like any other visit, no in-memory
  /// hand-off needed.
  void _completeFirstPartyLogin(String t, {String? redirectTarget, String? sessionId}) {
    Session.store(t, sessionId: sessionId, clientId: _effectiveClientId);
    _redirect(redirectTarget ?? _safeRedirectTarget());
  }
  /// True when this page was reached via an external RP's authorization
  /// request rather than direct first-party console access — see
  bool get _isRpFlow => _params.clientId.isNotEmpty && _params.redirectUri.isNotEmpty;
  bool get _hasSameOriginRpRedirect {
    final r = Uri.tryParse(_params.redirectUri);
    return r != null && r.hasAuthority && r.origin == Uri.base.origin;
  }
  bool get _usesJarm => _params.responseMode == 'jwt' || _params.responseMode.endsWith('.jwt');
  void _signInWithFederated(String connectionId) {
    if (_effectiveClientId.isEmpty) { setState(() => _error = 'No client.'); return; }
    if (_isRpFlow) { final q = _params.toLoginPayload(connectionId); q['response_type'] = _params.responseType.isNotEmpty ? _params.responseType : 'code'; _redirect(Uri.base.resolve('../auth/login').replace(queryParameters: q).toString()); return; }
    _redirect(FederatedLogin.beginLoginUrl(connectionId: connectionId, clientId: _effectiveClientId, redirectTarget: _safeRedirectTarget()));
  }
  Future<void> _probeProviders() async {
    try {
      final out = await _api.probeProviders(_effectiveClientId, loginHint: _params.loginHint);
      if (!mounted) return;
      final cid = out.data['connection_id']?.toString() ?? '';
      if (out.data['connection_required'] == true && cid.isNotEmpty) { _signInWithFederated(cid); return; }
      final ps = out.data['providers'];
      if (ps is List && ps.isNotEmpty) setState(() { _providers = ps.map((e) => (e as Map)['id']?.toString() ?? e.toString()).toList(); if (!_providers.contains(_provider)) _provider = _providers.first; });
    } catch (_) {}
  }
  Future<void> _loadBranding() async {
    try {
      final b = await _api.loadBranding(); if (!mounted || b.isEmpty) return;
      final logo = b['logo_url']?.trim();
      final uri = logo == null ? null : Uri.tryParse(logo);
      final safe = uri != null && (uri.scheme == 'https' || uri.scheme == 'http' || uri.scheme.isEmpty) && (uri.host.isEmpty || uri.origin == Uri.base.origin) ? logo : null;
      setState(() { _brandName = b['brand_name']?.trim(); _brandLogoUrl = safe; _brandColor = () { final v = b['primary_color']?.trim() ?? ''; final m = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').firstMatch(v); return m == null ? null : Color(int.parse(m.group(1)!.length == 6 ? 'ff${m.group(1)}' : m.group(1)!, radix: 16)); }(); });
    } catch (_) {}
  }
  Future<void> _discoverHomeRealm() async {
    final id = _userCtrl.text.trim(); if (id.isEmpty) { setState(() => _error = 'Enter work email.'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final o = await _api.discoverHomeRealm(id); if (!mounted) return;
      final connId = o.data['connection_id']?.toString() ?? '';
      if (o.ok && o.data['found'] == true && connId.isNotEmpty) { _signInWithFederated(connId); return; }
      setState(() => _error = o.status == 404 ? 'Not enabled.' : 'Not found.');
    } catch (_) { if (mounted) setState(() => _error = AppStrings.of(context).networkError); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  void _redirect(String url) {
    web.window.location.replace(url);
  }
  void _handleSuccess(LoginOutcome o) {
    if (_trustThisDevice) TrustedDeviceToken.store(_effectiveClientId, o.data['device_token']?.toString() ?? '');
    if (o.isFormPost && _isRpFlow) { _submitServerFormPost(o.html!); return; }
    final d = o.data;
    if (_usesJarm && _isRpFlow && o.redirectUrl != null) { final lu = Uri.base.resolve('../auth/login'); if (o.redirectUrl != lu) { _redirect(o.redirectUrl.toString()); return; } }
    final ru = _params.redirectUri;
    if (d['code'] != null && ru.isNotEmpty) { _redirectAuthorizationResponse({'code': d['code'].toString(), if ((d['state'] ?? _params.state).toString().isNotEmpty) 'state': (d['state'] ?? _params.state).toString(), if (d['iss'] != null) 'iss': d['iss'].toString()}, tokenResponse: false); return; }
    if (ru.isNotEmpty && (d['access_token'] != null || d['id_token'] != null)) { _redirectAuthorizationResponse({if (d['access_token'] != null) 'access_token': d['access_token'].toString(), if (d['access_token'] != null) 'token_type': (d['token_type'] ?? 'Bearer').toString(), if (d['expires_in'] != null) 'expires_in': d['expires_in'].toString(), if (d['id_token'] != null) 'id_token': d['id_token'].toString(), if (d['scope'] != null) 'scope': d['scope'].toString(), if ((d['state'] ?? _params.state).toString().isNotEmpty) 'state': (d['state'] ?? _params.state).toString(), if (d['session_state'] != null) 'session_state': d['session_state'].toString(), if (d['iss'] != null) 'iss': d['iss'].toString()}, tokenResponse: true); return; }
    if (d['access_token'] != null) { _completeFirstPartyLogin(d['access_token'].toString(), sessionId: d['session_id']?.toString()); return; }
    setState(() => _view = _View.success);
  }
  /// Delivers a non-JARM authorization response with the mode requested by
  /// the relying party. Successful form-post responses still come from the
  /// server; this covers client-side consent and prompt=none error paths.
  void _redirectAuthorizationResponse(Map<String, String> r, {required bool tokenResponse}) {
    final ru = _params.redirectUri; if (ru.isEmpty) return;
    if (_params.responseMode == 'form_post') { _submitAuthorizationFormPost(ru, r); return; }
    final t = Uri.parse(ru);
    if (_params.responseMode == 'fragment' || (_params.responseMode.isEmpty && tokenResponse)) { _redirect(t.replace(fragment: Uri(queryParameters: r).query).toString()); return; }
    _redirect(t.replace(queryParameters: {...t.queryParameters, ...r}).toString());
  }
  /// JARM responses must be signed by Snaplink. The console intentionally
  /// never fabricates one; a server JSON error cannot safely satisfy a JARM
  /// request, so leave an explicit error on the hosted page instead.
  void _redirectAuthorizationError(LoginOutcome o) {
    final e = o.error ?? 'login_required';
    if (!_isRpFlow || _usesJarm) { setState(() => _error = _usesJarm ? 'JARM error from server.' : e); return; }
    _redirectAuthorizationResponse({'error': e, if (o.data['error_description'] != null) 'error_description': o.data['error_description'].toString(), if (_params.state.isNotEmpty) 'state': _params.state, if (o.data['iss'] != null) 'iss': o.data['iss'].toString()}, tokenResponse: false);
  }
  void _submitAuthorizationFormPost(String uri, Map<String, String> r) {
    final form = web.HTMLFormElement()..method = 'post'..action = uri;
    for (final e in r.entries) form.append(web.HTMLInputElement()..type = 'hidden'..name = e.key..value = e.value);
    web.window.document.body?.append(form); form.submit();
  }
  Future<void> _submitSilentRenewal() async {
    if (!_hasSameOriginRpRedirect) { setState(() => _error = 'External RP must use server.'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final p = _params.toLoginPayload(''); p['client_id'] = _effectiveClientId;
      final o = await _api.login(p); if (!mounted) return;
      if (o.ok) _handleSuccess(o); else _redirectAuthorizationError(o);
    } catch (_) { if (mounted) _redirectAuthorizationError(LoginOutcome(0, const {'error': 'temporarily_unavailable'})); }
    finally { if (mounted) setState(() => _loading = false); }
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
    if (out.isMfaRequired) { setState(() { _mfaChallengeId = out.data['mfa_challenge_id']?.toString() ?? ''; _mfaMethods = (out.data['mfa_methods'] as List? ?? []).map((e) => e.toString()).toList(); _mfaMethodData = _methodData(out.data['mfa_method_data']); _selectedMfaMethod = _mfaMethods.length == 1 ? _mfaMethods.first : null; _view = _View.mfa; _error = null; }); return; }
    if (out.isConsentRequired) { setState(() { _consentChallengeId = out.data['consent_challenge_id']?.toString() ?? ''; _consentClientName = out.data['client_name']?.toString() ?? ''; _view = _View.consent; _error = null; }); return; }
    if (out.error == 'password_expired') { setState(() { _view = _View.login; _forgotIdCtrl.text = _userCtrl.text.trim(); _error = null; }); return; }
    setState(() => _error = out.error ?? 'Authentication failed.');
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
    if (_usesFederatedProvider) { _signInWithFederated(_provider); return; }
    if (_provider == 'webauthn') { await _submitPasskeyLogin(); return; }
    final code = _magicLinkToken ?? _providerCodeCtrl.text.trim();
    if (_usesCodeProvider && (_codeTargetCtrl.text.trim().isEmpty || code.isEmpty)) { setState(() => _error = 'Request code.'); return; }
    if (_usesTotpProvider && (_userCtrl.text.trim().isEmpty || code.isEmpty)) { setState(() => _error = 'Enter username and code.'); return; }
    setState(() { _loading = true; _error = null; });
    final payload = _params.toLoginPayload(_provider); payload['client_id'] = _effectiveClientId;
    final tdt = TrustedDeviceToken.read(_effectiveClientId); if (tdt != null && tdt.isNotEmpty) payload['device_token'] = tdt;
    payload['credential'] = _usesCodeProvider ? {_provider == 'phone' ? 'phone' : 'email': _codeTargetCtrl.text.trim(), 'code': code} : _usesTotpProvider ? {'username': _userCtrl.text.trim(), 'code': code} : {'username': _userCtrl.text.trim(), 'password': _passCtrl.text};
    _pendingLoginPayload = payload;
    try { final out = await _api.login(payload); if (out.ok) _handleSuccess(out); else _handleLoginError(out); }
    catch (_) { setState(() => _error = AppStrings.of(context).networkError); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  Future<void> _sendProviderCode() async {
    final target = _codeTargetCtrl.text.trim();
    if (target.isEmpty) { setState(() => _codeMessage = 'Enter email/phone.'); return; }
    setState(() { _loading = true; _error = null; _codeMessage = null; });
    try {
      final out = await _api.sendCode(_provider, target); if (!mounted) return;
      setState(() { _codeSent = out.ok; _codeMessage = out.ok ? 'Sent.' : (out.error ?? 'Failed.'); });
    } catch (_) { if (mounted) setState(() => _codeMessage = AppStrings.of(context).networkError); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  Future<void> _submitPasskeyLogin() async {
    setState(() { _loading = true; _error = null; });
    try {
      final b = await _api.beginPasswordlessWebAuthn();
      final sid = b.data['session_id']?.toString() ?? ''; final opts = b.data['options'];
      if (!b.ok || sid.isEmpty || opts == null) { setState(() => _error = b.error ?? 'Unavailable.'); return; }
      final a = await WebAuthnAssertion.request(opts);
      final p = _params.toLoginPayload('webauthn'); p['client_id'] = _effectiveClientId;
      final tdt = TrustedDeviceToken.read(_effectiveClientId); if (tdt != null && tdt.isNotEmpty) p['device_token'] = tdt;
      p['credential'] = {'session_id': sid, 'assertion': a};
      _pendingLoginPayload = p;
      final out = await _api.login(p);
      if (out.ok) _handleSuccess(out); else _handleLoginError(out);
    } on FormatException catch (_) { setState(() => _error = 'Invalid.'); } on StateError catch (e) { setState(() => _error = e.message); }
    catch (_) { setState(() => _error = AppStrings.of(context).networkError); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  Future<void> _submitMfa() async {
    if (_selectedMfaMethod == null) { setState(() => _error = 'Select a method.'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final method = _selectedMfaMethod!;
      String? code; Map<String, String>? params;
      if (method == 'webauthn') { final d = _mfaMethodData[method]; if (d?['options'] == null || d?['session'] == null) throw StateError('Unavailable.'); final a = await WebAuthnAssertion.request(d!['options']!); params = {'session': d['session']!, 'assertion': a}; }
      else if (method == 'push') { final id = _mfaMethodData[method]?['approval_id']; if (id == null || id.isEmpty) throw StateError('Unavailable.'); params = {'approval_id': id}; }
      else { code = _mfaCodeCtrl.text.trim(); }
      final out = await _api.mfaComplete(mfaChallengeId: _mfaChallengeId, method: method, code: code, params: params, trustDevice: _trustThisDevice);
      if (out.ok) _handleSuccess(out); else setState(() => _error = out.error ?? 'Failed.');
    } on StateError catch (e) { setState(() => _error = e.message); }
    catch (_) { setState(() => _error = 'Verification failed.'); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  Future<void> _submitConsent(bool allow) async {
    if (!allow) { if (_isRpFlow && !_usesJarm) _redirectAuthorizationResponse({'error': 'access_denied', if (_params.state.isNotEmpty) 'state': _params.state}, tokenResponse: false); else setState(() => _view = _View.login); return; }
    if (_pendingLoginPayload == null) return;
    setState(() { _loading = true; _error = null; });
    try { final out = await _api.login({..._pendingLoginPayload!, 'consent_challenge_id': _consentChallengeId}); if (out.ok) _handleSuccess(out); else _handleLoginError(out); }
    catch (_) { setState(() => _error = AppStrings.of(context).networkError); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  
  
  
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (c, cs) => SingleChildScrollView(
        child: ConstrainedBox(constraints: BoxConstraints(minHeight: cs.maxHeight),
          child: Center(
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(padding: const EdgeInsets.all(24),
                child: Card(child: Padding(padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _languageToggle(),
                    const SizedBox(height: 8),
                    if (_brandName != null || _brandLogoUrl != null) ...[_brandingHeader(), const SizedBox(height: 16)],
                    _buildView(),
                  ]),
                )),
              ),
            ),
          ),
        ),
      )),
    );
  }
    Widget _languageToggle() => const LanguageToggle();
    Widget _brandingHeader() => BrandingHeader(brandLogoUrl: _brandLogoUrl, brandName: _brandName, brandColor: _brandColor);
  Widget _buildView() {
    if (_checkingFederatedReturn) return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
    switch (_view) {
      case _View.mfa: return _mfaView();
      case _View.consent: return _consentView();
      case _View.success: return Text(AppStrings.of(context).signedIn);
      case _View.login: return _loginView();
    }
  }
  Widget _loginView() => LoginViewWidget(provider: _provider, providers: _providers, signupConfirmed: _signupConfirmed, userCtrl: _userCtrl, passCtrl: _passCtrl, codeTargetCtrl: _codeTargetCtrl, providerCodeCtrl: _providerCodeCtrl, codeSent: _codeSent, codeMessage: _codeMessage, loading: _loading, error: _error, usesFederatedProvider: _usesFederatedProvider, usesCodeProvider: _usesCodeProvider, usesTotpProvider: _usesTotpProvider, magicLinkToken: _magicLinkToken, federatedConnections: const [(id: 'google', label: 'Google', icon: Icons.g_mobiledata), (id: 'github', label: 'GitHub', icon: Icons.code)], onSubmit: _submitLogin, onSendCode: _sendProviderCode, onHomeRealm: _discoverHomeRealm, onPasskeyLogin: _submitPasskeyLogin, onForgotPassword: () => setState(() { _forgotIdCtrl.text = _userCtrl.text; _error = null; }), onSignUp: () => setState(() { _error = null; }), onProviderChanged: (p) => setState(() { _provider = p; _codeSent = false; _codeMessage = null; _error = null; }), onFederatedSignIn: (id) => _signInWithFederated(id));
  Widget _mfaView() => MfaView(mfaMethods: _mfaMethods, selectedMfaMethod: _selectedMfaMethod, mfaMethodData: _mfaMethodData, mfaCodeCtrl: _mfaCodeCtrl, trustThisDevice: _trustThisDevice, loading: _loading, error: _error, onMethodChanged: (m) => setState(() { _selectedMfaMethod = m; }), onTrustChanged: (v) => setState(() { _trustThisDevice = v ?? false; }), onSubmit: _submitMfa, onBack: () => setState(() { _view = _View.login; _error = null; }));
  Widget _consentView() => ConsentView(clientName: _consentClientName, clientId: _params.clientId, scopes: _params.scope, error: _error, loading: _loading, onAllow: () => _submitConsent(true), onDeny: () => _submitConsent(false));
}
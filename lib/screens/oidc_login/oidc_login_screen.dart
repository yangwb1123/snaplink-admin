import 'package:flutter/material.dart';
import 'federated_login.dart';
import 'oauth_params.dart';
import 'oidc_login_api.dart';
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
/// Deliberately NOT ported (documented gaps, not silent omissions): WebAuthn
/// conditional-mediation passkey autofill (needs JS interop for
/// navigator.credentials) and dynamic white-label branding.
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

String _safeRedirectTarget() {
  final raw = Uri.base.queryParameters[_redirectParam];
  if (raw == null || raw.isEmpty) return _defaultRedirectTarget;
  if (!raw.startsWith('/') || raw.startsWith('//') || raw.contains('://')) {
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
  bool _loading = false;
  String? _error;

  // MFA state
  String _mfaChallengeId = '';
  List<String> _mfaMethods = const [];
  String? _selectedMfaMethod;
  final _mfaCodeCtrl = TextEditingController();

  // Consent state
  Map<String, dynamic>? _pendingLoginPayload;
  String _consentChallengeId = '';
  String _consentClientName = '';

  // Forgot-password / signup panel state
  bool _showForgot = false;
  bool _showSignup = false;
  final _forgotIdCtrl = TextEditingController();
  String? _forgotMsg;
  final _signupUserCtrl = TextEditingController();
  final _signupPassCtrl = TextEditingController();
  final _signupEmailCtrl = TextEditingController();
  String? _signupConfirmed;

  /// client_id to actually use: the URL's own (an RP-initiated flow) when
  /// present, else [OidcLoginScreen.defaultClientId] (first-party access).
  String get _effectiveClientId =>
      _params.clientId.isNotEmpty ? _params.clientId : (widget.defaultClientId ?? '');

  bool _checkingFederatedReturn = true;

  @override
  void initState() {
    super.initState();
    _provider = _params.provider.isNotEmpty ? _params.provider : 'password';
    _checkFederatedReturn();
    if (_effectiveClientId.isNotEmpty) _probeProviders();
  }

  /// Runs once on load: if this page was just redirected back to from a
  /// federated provider (see federated_login.dart), finish the exchange and
  /// complete the first-party login instead of showing the plain form.
  Future<void> _checkFederatedReturn() async {
    try {
      final result = await FederatedLogin.consumeReturnIfPresent();
      if (!mounted) return;
      if (result != null) {
        _completeFirstPartyLogin(result.accessToken, redirectTarget: result.redirectTarget);
        return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Sign-in failed: $e');
    }
    if (mounted) setState(() => _checkingFederatedReturn = false);
  }

  /// Stores the session and does a REAL browser redirect to the target path
  /// — a fresh page load, so the target route (e.g. admin_gate.dart) sees the
  /// session via [Session.read] exactly like any other visit, no in-memory
  /// hand-off needed.
  void _completeFirstPartyLogin(String accessToken, {String? redirectTarget}) {
    Session.store(accessToken);
    _redirect(redirectTarget ?? _safeRedirectTarget());
  }

  void _signInWithFederated(String connectionId) {
    final clientId = _effectiveClientId;
    if (clientId.isEmpty) {
      setState(() => _error = 'No client configured for sign-in.');
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
      final out = await _api.probeProviders(_effectiveClientId);
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

  void _redirect(String url) {
    web.window.location.replace(url);
  }

  void _handleSuccess(Map<String, dynamic> data) {
    final redirectUri = _params.redirectUri;
    if (data['code'] != null && redirectUri.isNotEmpty) {
      final u = Uri.parse(redirectUri).replace(queryParameters: {
        ...Uri.parse(redirectUri).queryParameters,
        'code': data['code'].toString(),
        if ((data['state'] ?? _params.state).toString().isNotEmpty)
          'state': (data['state'] ?? _params.state).toString(),
        if (data['iss'] != null) 'iss': data['iss'].toString(),
      });
      _redirect(u.toString());
      return;
    }
    if (data['access_token'] != null && redirectUri.isNotEmpty) {
      final frag = StringBuffer('access_token=${Uri.encodeComponent(data['access_token'].toString())}');
      frag.write('&token_type=${Uri.encodeComponent((data['token_type'] ?? 'Bearer').toString())}');
      if (data['expires_in'] != null) frag.write('&expires_in=${data['expires_in']}');
      if (_params.state.isNotEmpty) frag.write('&state=${Uri.encodeComponent(_params.state)}');
      if (data['iss'] != null) frag.write('&iss=${Uri.encodeComponent(data['iss'].toString())}');
      _redirect('$redirectUri#$frag');
      return;
    }
    if (data['access_token'] != null) {
      _completeFirstPartyLogin(data['access_token'].toString());
      return;
    }
    setState(() => _view = _View.success);
  }

  void _handleLoginError(LoginOutcome out) {
    if (out.isMfaRequired) {
      setState(() {
        _mfaChallengeId = out.data['mfa_challenge_id']?.toString() ?? '';
        _mfaMethods = (out.data['mfa_methods'] as List? ?? []).map((e) => e.toString()).toList();
        _selectedMfaMethod = _mfaMethods.length == 1 ? _mfaMethods.first : null;
        _view = _View.mfa;
        _error = null;
      });
      return;
    }
    if (out.isConsentRequired) {
      setState(() {
        _consentChallengeId = out.data['consent_challenge_id']?.toString() ?? '';
        _consentClientName = out.data['client_name']?.toString() ?? '';
        _view = _View.consent;
        _error = null;
      });
      return;
    }
    setState(() => _error = out.error ?? 'Authentication failed. Please try again.');
  }

  Future<void> _submitLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final payload = _params.toLoginPayload(_provider);
    payload['client_id'] = _effectiveClientId;
    payload['credential'] = {'username': _userCtrl.text.trim(), 'password': _passCtrl.text};
    _pendingLoginPayload = payload;
    try {
      final out = await _api.login(payload);
      if (out.ok) {
        _handleSuccess(out.data);
      } else {
        _handleLoginError(out);
      }
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
      final out = await _api.mfaComplete(
        mfaChallengeId: _mfaChallengeId,
        method: _selectedMfaMethod!,
        credential: {'code': _mfaCodeCtrl.text.trim()},
      );
      if (out.ok) {
        _handleSuccess(out.data);
      } else {
        setState(() => _error = out.error ?? 'Verification failed.');
      }
    } catch (_) {
      setState(() => _error = AppStrings.of(context).networkError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitConsent(bool allow) async {
    if (!allow) {
      if (_params.redirectUri.isNotEmpty) {
        final u = Uri.parse(_params.redirectUri).replace(queryParameters: {
          ...Uri.parse(_params.redirectUri).queryParameters,
          'error': 'access_denied',
          if (_params.state.isNotEmpty) 'state': _params.state,
        });
        _redirect(u.toString());
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
      final payload = {..._pendingLoginPayload!, 'consent_challenge_id': _consentChallengeId};
      final out = await _api.login(payload);
      if (out.ok) {
        _handleSuccess(out.data);
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
        setState(() => _forgotMsg = 'If that account exists, a reset link has been sent.');
      } else {
        setState(() => _forgotMsg = 'Could not request a reset. Please try again.');
      }
    } catch (_) {
      setState(() => _forgotMsg = AppStrings.of(context).networkError);
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
      final out = await _api.register(username: username, password: password, email: _signupEmailCtrl.text.trim());
      if (out.status == 404) {
        setState(() => _error = 'Self-service signup is not enabled.');
      } else if (out.status == 409) {
        setState(() => _error = 'That account already exists.');
      } else if (out.status >= 200 && out.status < 300) {
        setState(() {
          _userCtrl.text = username;
          _showSignup = false;
          _signupConfirmed = 'Account created — you can now sign in.';
        });
      } else {
        setState(() => _error = 'Could not create the account. Please try again.');
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
          foregroundColor: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        child: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [langButton('en', 'EN'), langButton('zh', '中文')],
    );
  }

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
    if (_showForgot) return _forgotView();
    if (_showSignup) return _signupView();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(AppStrings.of(context).signIn, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 20),
        if (_providers.length > 1) ...[
          DropdownButtonFormField<String>(
            initialValue: _provider,
            items: _providers.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (v) => setState(() => _provider = v ?? _provider),
            decoration: InputDecoration(labelText: AppStrings.of(context).provider),
          ),
          const SizedBox(height: 14),
        ],
        if (_signupConfirmed != null) ...[
          Text(_signupConfirmed!, style: const TextStyle(color: Colors.greenAccent)),
          const SizedBox(height: 10),
        ],
        TextField(controller: _userCtrl, decoration: InputDecoration(labelText: AppStrings.of(context).username)),
        const SizedBox(height: 14),
        TextField(
          controller: _passCtrl,
          decoration: InputDecoration(labelText: AppStrings.of(context).password),
          obscureText: true,
          onSubmitted: (_) => _submitLogin(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _loading ? null : _submitLogin,
          child: _loading
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(AppStrings.of(context).signIn),
        ),
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
                child: Text(AppStrings.of(context).forgotPassword, overflow: TextOverflow.ellipsis),
              ),
            ),
            Flexible(
              child: TextButton(
                onPressed: () => setState(() {
                  _error = null;
                  _showSignup = true;
                }),
                child: Text(AppStrings.of(context).signUp, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(AppStrings.of(context).orDivider, style: Theme.of(context).textTheme.bodySmall),
          ),
          const Expanded(child: Divider()),
        ]),
        const SizedBox(height: 14),
        ..._federatedConnections.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton.icon(
                onPressed: () => _signInWithFederated(c.id),
                icon: Icon(c.icon),
                label: Text('${AppStrings.of(context).signInWith} ${c.label}'),
              ),
            )),
      ],
    );
  }

  Widget _mfaView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(AppStrings.of(context).verifyIdentity, style: Theme.of(context).textTheme.titleLarge),
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
        if (_selectedMfaMethod == 'totp' || _selectedMfaMethod == 'otp') ...[
          const SizedBox(height: 14),
          TextField(controller: _mfaCodeCtrl, decoration: InputDecoration(labelText: AppStrings.of(context).verificationCode)),
        ],
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _loading ? null : _submitMfa,
          child: _loading
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(AppStrings.of(context).verify),
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
        ...scopes.map((s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('• ${_scopeLabel(s)}'),
            )),
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
        Text(AppStrings.of(context).resetPassword, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(controller: _forgotIdCtrl, decoration: InputDecoration(labelText: AppStrings.of(context).usernameOrEmail)),
        if (_forgotMsg != null) ...[
          const SizedBox(height: 14),
          Text(_forgotMsg!),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _loading ? null : _submitForgot,
          child: _loading
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(AppStrings.of(context).sendResetLink),
        ),
        TextButton(onPressed: () => setState(() => _showForgot = false), child: Text(AppStrings.of(context).back)),
      ],
    );
  }

  Widget _signupView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(AppStrings.of(context).createAccount, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(controller: _signupUserCtrl, decoration: InputDecoration(labelText: AppStrings.of(context).username)),
        const SizedBox(height: 14),
        TextField(
          controller: _signupPassCtrl,
          decoration: InputDecoration(labelText: AppStrings.of(context).password),
          obscureText: true,
        ),
        const SizedBox(height: 14),
        TextField(controller: _signupEmailCtrl, decoration: InputDecoration(labelText: AppStrings.of(context).emailOptional)),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _loading ? null : _submitSignup,
          child: _loading
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
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

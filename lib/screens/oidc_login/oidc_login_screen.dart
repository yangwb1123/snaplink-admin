import 'package:flutter/material.dart';
import 'oauth_params.dart';
import 'oidc_login_api.dart';
import 'package:web/web.dart' as web;

enum _View { login, mfa, consent, success }

/// The hosted /login/ page: replaces interfaces/web/login/{index.html,app.js}.
/// Real external relying parties (the IM/Source demos, and any future RP)
/// redirect here — this must stay faithful to the JS's core contract:
/// authorization_code / implicit redirect handling, MFA, consent, forgot
/// password, and signup. Deliberately NOT ported (documented gaps, not
/// silent omissions): WebAuthn conditional-mediation passkey autofill (needs
/// JS interop for navigator.credentials) and home-realm-discovery / dynamic
/// white-label branding (multi-tenant niceties, not core auth).
class OidcLoginScreen extends StatefulWidget {
  const OidcLoginScreen({super.key});

  @override
  State<OidcLoginScreen> createState() => _OidcLoginScreenState();
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

  @override
  void initState() {
    super.initState();
    _provider = _params.provider.isNotEmpty ? _params.provider : 'password';
    if (_params.clientId.isNotEmpty) _probeProviders();
  }

  Future<void> _probeProviders() async {
    try {
      final out = await _api.probeProviders(_params.clientId);
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
      setState(() => _error = 'Network error. Please check your connection.');
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
      setState(() => _error = 'Network error. Please try again.');
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
      setState(() => _error = 'Network error. Please try again.');
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
      setState(() => _forgotMsg = 'Network error. Please try again.');
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
      setState(() => _error = 'Network error. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(padding: const EdgeInsets.all(28), child: _buildView()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildView() {
    switch (_view) {
      case _View.mfa:
        return _mfaView();
      case _View.consent:
        return _consentView();
      case _View.success:
        return const Text('Signed in.');
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
        Text('Sign in', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 20),
        if (_providers.length > 1) ...[
          DropdownButtonFormField<String>(
            initialValue: _provider,
            items: _providers.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (v) => setState(() => _provider = v ?? _provider),
            decoration: const InputDecoration(labelText: 'Provider'),
          ),
          const SizedBox(height: 14),
        ],
        if (_signupConfirmed != null) ...[
          Text(_signupConfirmed!, style: const TextStyle(color: Colors.greenAccent)),
          const SizedBox(height: 10),
        ],
        TextField(controller: _userCtrl, decoration: const InputDecoration(labelText: 'Username')),
        const SizedBox(height: 14),
        TextField(
          controller: _passCtrl,
          decoration: const InputDecoration(labelText: 'Password'),
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
              : const Text('Sign in'),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => setState(() {
                _forgotIdCtrl.text = _userCtrl.text;
                _forgotMsg = null;
                _showForgot = true;
              }),
              child: const Text('Forgot password?'),
            ),
            TextButton(
              onPressed: () => setState(() {
                _error = null;
                _showSignup = true;
              }),
              child: const Text('Sign up'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _mfaView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Verify your identity', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: _mfaMethods.map((m) {
            final selected = _selectedMfaMethod == m;
            return ChoiceChip(
              label: Text(_mfaMethodLabel(m)),
              selected: selected,
              onSelected: (_) => setState(() => _selectedMfaMethod = m),
            );
          }).toList(),
        ),
        if (_selectedMfaMethod == 'totp' || _selectedMfaMethod == 'otp') ...[
          const SizedBox(height: 14),
          TextField(controller: _mfaCodeCtrl, decoration: const InputDecoration(labelText: 'Verification code')),
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
              : const Text('Verify'),
        ),
        TextButton(
          onPressed: () => setState(() {
            _view = _View.login;
            _error = null;
          }),
          child: const Text('Back'),
        ),
      ],
    );
  }

  String _mfaMethodLabel(String m) {
    const labels = {
      'totp': 'Authenticator app (TOTP)',
      'otp': 'One-time code',
      'webauthn': 'Security key / passkey',
      'push': 'Push notification',
      'sms': 'SMS code',
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
        Text('Reset your password', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(controller: _forgotIdCtrl, decoration: const InputDecoration(labelText: 'Username or email')),
        if (_forgotMsg != null) ...[
          const SizedBox(height: 14),
          Text(_forgotMsg!),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _loading ? null : _submitForgot,
          child: _loading
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Send reset link'),
        ),
        TextButton(onPressed: () => setState(() => _showForgot = false), child: const Text('Back')),
      ],
    );
  }

  Widget _signupView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Create an account', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(controller: _signupUserCtrl, decoration: const InputDecoration(labelText: 'Username')),
        const SizedBox(height: 14),
        TextField(
          controller: _signupPassCtrl,
          decoration: const InputDecoration(labelText: 'Password'),
          obscureText: true,
        ),
        const SizedBox(height: 14),
        TextField(controller: _signupEmailCtrl, decoration: const InputDecoration(labelText: 'Email (optional)')),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _loading ? null : _submitSignup,
          child: _loading
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Sign up'),
        ),
        TextButton(
          onPressed: () => setState(() {
            _showSignup = false;
            _error = null;
          }),
          child: const Text('Back'),
        ),
      ],
    );
  }
}

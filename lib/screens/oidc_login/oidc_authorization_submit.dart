part of 'oidc_login_screen.dart';

/// 授权流提交侧：凭据提交/验证码发送/静默续期/表单回填。
/// 从 oidc_authorization_flow.dart 提取的 submit 方法组（2026-08 门禁
/// 收尾拆分），与 `_OidcAuthorizationFlow` 同库、行为完全不变。
extension _OidcAuthorizationSubmit on _OidcLoginScreenState {
  /// The POST remains same-origin even when the RP redirect is external; the
  /// successful/error result is then delivered by a top-level navigation.
  /// Signed JARM redirect handling remains server-owned.
  Future<void> _submitSilentRenewal() async {
    _update(() {
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
      if (mounted) _update(() => _loading = false);
    }
  }

  /// Writes Snaplink's escaped form-post document into this same-origin page.
  void _submitServerFormPost(String html) {
    if (!BrowserAuthResponse.replaceDocument(html)) {
      _update(
        () => _error = 'The server form response requires the web console.',
      );
    }
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

    final magicLinkToken = _magicLinkToken;
    final code = magicLinkToken ?? _providerCodeCtrl.text.trim();
    if (_usesCodeProvider &&
        (_codeTargetCtrl.text.trim().isEmpty || code.isEmpty)) {
      _update(() => _error = 'Request or enter a verification code.');
      return;
    }
    if (_usesTotpProvider && (_userCtrl.text.trim().isEmpty || code.isEmpty)) {
      _update(() => _error = 'Enter your username and verification code.');
      return;
    }
    if (!_usesCodeProvider &&
        !_usesTotpProvider &&
        _passCtrl.text.isEmpty) {
      // 浏览器密码管理器在 Flutter Web 上经常不会把自动填充的密码同步进
      // TextEditingController：这里在提交前拦截空密码并聚焦输入框，
      // 避免向服务器发送注定 401 的空凭据请求。
      _update(() => _error = 'Enter your password.');
      _passwordFocusNode.requestFocus();
      return;
    }
    if (magicLinkToken != null) _scrubOneTimeLoginData();
    _update(() {
      if (magicLinkToken != null) _magicLinkToken = null;
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
    try {
      final outcome = await _api.login(payload);
      if (!mounted) return;
      if (outcome.ok) {
        _handleSuccess(outcome);
      } else {
        _handleLoginError(outcome);
      }
    } catch (_) {
      if (mounted) {
        _update(() => _error = AppStrings.of(context).networkError);
      }
    } finally {
      if (mounted) _update(() => _loading = false);
    }
  }

  Future<void> _sendProviderCode() async {
    final target = _codeTargetCtrl.text.trim();
    if (target.isEmpty) {
      _update(() => _codeMessage = 'Enter an email address or phone number.');
      return;
    }
    _update(() {
      _loading = true;
      _error = null;
      _codeMessage = null;
    });
    try {
      final outcome = await _api.sendCode(_provider, target);
      if (!mounted) return;
      _update(() {
        _codeSent = outcome.ok;
        _codeMessage = outcome.ok
            ? 'Instructions sent.'
            : (outcome.error ?? 'Unable to send instructions.');
      });
    } catch (_) {
      if (mounted) {
        _update(() => _codeMessage = AppStrings.of(context).networkError);
      }
    } finally {
      if (mounted) _update(() => _loading = false);
    }
  }

  Future<void> _submitPasskeyLogin() async {
    _update(() {
      _loading = true;
      _error = null;
    });
    try {
      final begin = await _api.beginPasswordlessWebAuthn();
      final sessionId = begin.data['session_id']?.toString() ?? '';
      final options = begin.data['options'];
      if (!begin.ok || sessionId.isEmpty || options == null) {
        _update(() => _error = begin.error ?? 'Passkey sign-in unavailable.');
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
      final outcome = await _api.login(payload);
      if (!mounted) return;
      if (outcome.ok) {
        _handleSuccess(outcome);
      } else {
        _handleLoginError(outcome);
      }
    } on FormatException {
      _update(() => _error = 'The passkey response was invalid.');
    } on StateError catch (error) {
      _update(() => _error = error.message);
    } catch (_) {
      _update(() => _error = AppStrings.of(context).networkError);
    } finally {
      if (mounted) _update(() => _loading = false);
    }
  }
}

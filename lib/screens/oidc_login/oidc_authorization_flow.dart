part of 'oidc_login_screen.dart';

extension _OidcAuthorizationFlow on _OidcLoginScreenState {
  void _redirect(String url) {
    web.window.location.replace(url);
  }

  void _handleSuccess(LoginOutcome outcome) {
    final data = outcome.data;
    if (_usesJarm) {
      final completion = resolveJarmCompletion(
        responseMode: _params.responseMode,
        redirectUri: _params.redirectUri,
        responseData: data,
        serverContinuation: outcome.redirectUrl,
        serverFormPost: outcome.html,
        authorizationEndpoint: Uri.base.resolve('../auth/login'),
      );
      if (!completion.accepted) {
        _update(() => _error = completion.error);
        return;
      }
      _storeTrustedDeviceToken(outcome);
      if (completion.formPostHtml != null) {
        _submitServerFormPost(completion.formPostHtml!);
      } else {
        _redirect(completion.redirectTarget.toString());
      }
      return;
    }

    _storeTrustedDeviceToken(outcome);
    if (outcome.isFormPost && _isRpFlow) {
      _submitServerFormPost(outcome.html!);
      return;
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
      _redirectAuthorizationResponse({
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
      }, tokenResponse: true);
      return;
    }
    if (data['access_token'] != null) {
      _completeFirstPartyLogin(
        data['access_token'].toString(),
        sessionId: data['session_id']?.toString(),
      );
      return;
    }
    _update(() => _view = _View.success);
  }

  void _storeTrustedDeviceToken(LoginOutcome outcome) {
    if (!_trustThisDevice) return;
    TrustedDeviceToken.store(
      _effectiveClientId,
      outcome.data['device_token']?.toString() ?? '',
    );
  }

  /// Delivers non-JARM authorization responses in the RP-requested mode.
  void _redirectAuthorizationResponse(
    Map<String, String> response, {
    required bool tokenResponse,
  }) {
    final redirectUri = _params.redirectUri;
    if (redirectUri.isEmpty) return;
    if (_params.responseMode == 'form_post') {
      _submitAuthorizationFormPost(redirectUri, response);
      return;
    }
    final target = Uri.parse(redirectUri);
    if (_params.responseMode == 'fragment' ||
        (_params.responseMode.isEmpty && tokenResponse)) {
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

  /// JARM responses must be signed by Snaplink; the SPA never fabricates one.
  void _redirectAuthorizationError(LoginOutcome outcome) {
    final error = outcome.error ?? 'login_required';
    // An error body does not prove that redirect_uri passed the client's
    // allowlist check. Redirect only when the server explicitly attests that
    // validation; otherwise an attacker-controlled login URL becomes an open
    // redirect. Current Snaplink does not yet emit this attestation.
    final redirectValidated = outcome.data['redirect_uri_validated'] == true;
    if (!_isRpFlow || _usesJarm || !redirectValidated) {
      _update(
        () => _error = switch ((_usesJarm, redirectValidated)) {
          (true, _) => 'Snaplink could not deliver the signed JARM response.',
          (false, false) =>
            'Snaplink did not confirm the redirect URI for this error. '
                'No authorization error was redirected.',
          _ => error,
        },
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

  void _submitAuthorizationFormPost(String uri, Map<String, String> response) {
    final form = web.HTMLFormElement()
      ..method = 'post'
      ..action = uri;
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
    final document = web.window.document;
    document.callMethod<JSAny?>('open'.toJS);
    document.callMethod<JSAny?>('write'.toJS, html.toJS);
    document.callMethod<JSAny?>('close'.toJS);
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
      _update(() => _error = 'Request or enter a verification code.');
      return;
    }
    if (_usesTotpProvider && (_userCtrl.text.trim().isEmpty || code.isEmpty)) {
      _update(() => _error = 'Enter your username and verification code.');
      return;
    }
    _update(() {
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
      _pendingLoginPayload = payload;
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

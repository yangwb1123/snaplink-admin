part of 'oidc_login_screen.dart';

extension _OidcAuthorizationFlow on _OidcLoginScreenState {
  void _redirect(String url) {
    BrowserNavigation.replaceLocation(url);
  }

  void _handleSuccess(LoginOutcome outcome) {
    // 登录成功：通知浏览器保存凭据（用户下次访问时自动填充）。
    // Flutter Web 上 finishAutofillContext 是让浏览器记住密码的唯一路径。
    TextInput.finishAutofillContext(shouldSave: true);
    // Authentication credentials are no longer needed once the server has
    // reached a terminal success. Clear them even when redirect/JARM delivery
    // is later blocked and this widget remains mounted.
    _passCtrl.clear();
    _providerCodeCtrl.clear();
    _mfaCodeCtrl.clear();
    final data = outcome.data;
    final jarmEnvelope = (data['response']?.toString().trim() ?? '').isNotEmpty;
    final code = data['code']?.toString().trim() ?? '';
    final accessToken = data['access_token']?.toString().trim() ?? '';
    final idToken = data['id_token']?.toString().trim() ?? '';
    if (_usesJarm || jarmEnvelope) {
      final delivery = resolveAuthorizationDelivery(
        request: _params,
        response: data,
        errorResponse: false,
        tokenResponse: false,
      );
      if (delivery == null || !delivery.usesJarm) {
        _update(() => _error = JarmCompletion.blockedMessage);
        return;
      }
      final completion = resolveJarmCompletion(
        responseMode: delivery.responseMode,
        redirectUri: delivery.redirectUri.toString(),
        responseData: data,
        serverContinuation: outcome.redirectUrl,
        serverFormPost: outcome.html,
        authorizationEndpoint: ProductApiOrigin.baseUri.resolve('/auth/login'),
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
    if (outcome.isFormPost && !_isRpFlow) {
      _update(
        () => _error =
            'Snaplink returned an authorization form without a relying-party '
            'request. Sign in again.',
      );
      return;
    }
    if (outcome.isFormPost && _isRpFlow) {
      final redirectUri = Uri.tryParse(_params.redirectUri);
      if (_params.responseMode != 'form_post' ||
          redirectUri == null ||
          !isTrustedAuthorizationFormPost(outcome.html!, redirectUri)) {
        _authorizationDeliveryBlocked();
        return;
      }
      _submitServerFormPost(outcome.html!);
      return;
    }
    if (code.isNotEmpty && _isRpFlow) {
      final delivery = resolveAuthorizationDelivery(
        request: _params,
        response: data,
        errorResponse: false,
        tokenResponse: false,
      );
      if (delivery == null || delivery.usesJarm) {
        _authorizationDeliveryBlocked();
        return;
      }
      _redirectAuthorizationResponse({
        'code': code,
        if (data['state']?.toString().isNotEmpty == true)
          'state': data['state'].toString(),
        if (data['iss'] != null) 'iss': data['iss'].toString(),
        if (data['session_state'] != null)
          'session_state': data['session_state'].toString(),
      }, delivery: delivery);
      return;
    }
    if (_isRpFlow && (accessToken.isNotEmpty || idToken.isNotEmpty)) {
      final delivery = resolveAuthorizationDelivery(
        request: _params,
        response: data,
        errorResponse: false,
        tokenResponse: true,
      );
      if (delivery == null || delivery.usesJarm) {
        _authorizationDeliveryBlocked();
        return;
      }
      _redirectAuthorizationResponse({
        if (accessToken.isNotEmpty) 'access_token': accessToken,
        if (accessToken.isNotEmpty)
          'token_type': (data['token_type'] ?? 'Bearer').toString(),
        if (data['expires_in'] != null)
          'expires_in': data['expires_in'].toString(),
        if (idToken.isNotEmpty) 'id_token': idToken,
        if (data['scope'] != null) 'scope': data['scope'].toString(),
        if (data['state']?.toString().isNotEmpty == true)
          'state': data['state'].toString(),
        if (data['session_state'] != null)
          'session_state': data['session_state'].toString(),
        if (data['iss'] != null) 'iss': data['iss'].toString(),
      }, delivery: delivery);
      return;
    }
    if (accessToken.isNotEmpty) {
      _completeFirstPartyLogin(
        accessToken,
        sessionId: data['session_id']?.toString(),
      );
      return;
    }
    if (_isRpFlow) {
      // A relying-party authorization request is not complete merely because
      // the primary login endpoint returned 2xx. Without a code, token,
      // server form-post, or signed JARM envelope there is no safe response
      // to deliver and the page must not claim a successful sign-in.
      _authorizationDeliveryBlocked();
      return;
    }
    _update(
      () => _error =
          'Snaplink did not return an access token. Sign in again to retry.',
    );
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
    required AuthorizationDelivery delivery,
  }) {
    if (delivery.responseMode == 'form_post') {
      _submitAuthorizationFormPost(delivery.redirectUri.toString(), response);
      return;
    }
    final target = delivery.redirectUri;
    if (delivery.responseMode == 'fragment') {
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
    final delivery = _isRpFlow
        ? resolveAuthorizationDelivery(
            request: _params,
            response: outcome.data,
            errorResponse: true,
            tokenResponse: _requestsTokenResponse,
          )
        : null;
    final requiresJarm = _usesJarm || delivery?.usesJarm == true;
    if (!_isRpFlow || requiresJarm || delivery == null) {
      _update(
        () => _error = switch ((requiresJarm, delivery != null)) {
          (true, _) => 'Snaplink could not deliver the signed JARM response.',
          (false, false) =>
            'Snaplink did not provide a server-validated authorization '
                'continuation. No code, token, or error was redirected.',
          _ => error,
        },
      );
      return;
    }
    _redirectAuthorizationResponse({
      'error': error,
      if (outcome.data['error_description'] != null)
        'error_description': outcome.data['error_description'].toString(),
      if (outcome.data['state']?.toString().isNotEmpty == true)
        'state': outcome.data['state'].toString(),
      if (outcome.data['iss'] != null) 'iss': outcome.data['iss'].toString(),
    }, delivery: delivery);
  }

  void _authorizationDeliveryBlocked() {
    _update(
      () => _error =
          'Snaplink did not provide a server-validated authorization '
          'continuation. No code, token, or error was redirected.',
    );
  }

  void _submitAuthorizationFormPost(String uri, Map<String, String> response) {
    if (!BrowserAuthResponse.submitForm(uri, response)) {
      _update(
        () => _error = 'The form_post response mode requires the web console.',
      );
    }
  }
}

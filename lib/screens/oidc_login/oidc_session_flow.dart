part of 'oidc_login_screen.dart';

extension _OidcSessionFlow on _OidcLoginScreenState {
  bool get _canResumeBrowserSession {
    final prompts = _params.prompt.split(RegExp(r'\s+'));
    // Do not consume opaque one-use PAR/JAR requests in an automatic probe.
    // Their existing primary/federated authorization flow remains unchanged.
    return _isRpFlow &&
        _route.flow == HostedLoginFlow.login &&
        _params.responseType == 'code' &&
        _params.requestUri.isEmpty &&
        _params.request.isEmpty &&
        _params.idTokenHint.isEmpty &&
        !prompts.contains('login') &&
        !prompts.contains('select_account') &&
        _params.maxAge != '0';
  }

  /// The OP cookie stays HttpOnly. No application token, password, session ID
  /// or id_token_hint is copied from another client's browser storage.
  Future<bool> _tryBrowserSession(Map<String, dynamic> discovery) async {
    if (!_canResumeBrowserSession ||
        discovery['op_session_supported'] != true) {
      return false;
    }
    if (discovery['op_session_error'] != null) {
      _update(() {
        _sessionAttemptHandled = true;
        _error = AppStrings.of(context).networkError;
      });
      return true;
    }
    if (discovery['op_session_available'] != true) return false;
    _update(() {
      _loading = true;
      _sessionAttemptHandled = true;
      _error = null;
    });
    try {
      final payload = _params.toLoginPayload('');
      payload['client_id'] = _effectiveClientId;
      payload['resume_session'] = true;
      final outcome = await _api.login(payload);
      if (!_ownsLoginRequest) return true;
      if (outcome.ok) {
        await _handleSuccess(outcome);
      } else if (outcome.isMfaRequired || outcome.isConsentRequired) {
        _handleLoginError(outcome);
      } else if (const {
        'login_required',
        'account_selection_required',
        'unmet_authentication_requirements',
        'passwordless_required',
        'authenticator_not_allowed',
        'authenticator_not_allowed_for_client',
        'unsupported_provider',
      }.contains(outcome.error)) {
        // An expired/revoked/insufficient identity session requires the normal
        // login form, not a failed prompt=none redirect to the relying party.
        _sessionAttemptHandled = false;
        return false;
      } else if (outcome.error == 'password_expired') {
        _handleLoginError(outcome);
      } else {
        _redirectAuthorizationError(outcome);
      }
    } catch (_) {
      if (mounted) {
        _update(() => _error = AppStrings.of(context).networkError);
      }
      // No automatic replay: the server may already have issued a code or a
      // one-use continuation. A new sign-in navigation is a new transaction.
    } finally {
      if (mounted) _update(() => _loading = false);
    }
    return true;
  }

  Future<bool> _silentUsesBrowserSession() async {
    if (!_canResumeBrowserSession) return false;
    final discovery = await _api.probeProviders(
      _effectiveClientId,
      loginHint: _params.loginHint,
    );
    if (!discovery.ok) {
      throw StateError('Identity session discovery is unavailable.');
    }
    if (discovery.data['op_session_error'] != null) {
      throw StateError('Identity session verification is unavailable.');
    }
    return discovery.data['op_session_supported'] == true;
  }
}

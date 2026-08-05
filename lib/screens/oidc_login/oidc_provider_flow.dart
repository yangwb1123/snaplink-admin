part of 'oidc_login_screen.dart';

extension _OidcProviderFlow on _OidcLoginScreenState {
  /// Finishes a federated first-party return before showing the plain form.
  Future<void> _checkFederatedReturn() async {
    final continuationId = _federatedContinuationId;
    if (continuationId != null) {
      await _resumeFederatedAuthorization(continuationId);
      return;
    }
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
    } on TimeoutException {
      if (!mounted) return;
      _update(
        () => _error =
            'The federated sign-in return timed out after its one-time PKCE '
            'state was consumed. Start sign-in again.',
      );
    } catch (error) {
      if (!mounted) return;
      _update(() => _error = 'Sign-in failed: $error');
    }

    if (_isRpFlow &&
        _params.hasPromptNone &&
        _route.flow == HostedLoginFlow.login) {
      await _submitSilentRenewal();
      if (mounted) {
        _update(() => _checkingFederatedReturn = false);
      }
      return;
    }
    if (mounted) {
      _update(() => _checkingFederatedReturn = false);
    }
  }

  Future<void> _resumeFederatedAuthorization(String transactionId) async {
    // The server transaction and browser fragment are both one-shot. Scrub
    // the fragment before the request so a refresh, timeout, crash, copied
    // URL, or embedded resource cannot replay or disclose it.
    BrowserNavigation.replaceState(_routeUri.replace(fragment: '').toString());
    try {
      final outcome = await _api.login({
        'client_id': _effectiveClientId,
        'login_transaction_id': transactionId,
      });
      if (!mounted) return;
      _update(() => _checkingFederatedReturn = false);
      if (outcome.ok) {
        _handleSuccess(outcome);
      } else if (outcome.isMfaRequired ||
          outcome.isConsentRequired ||
          outcome.error == 'password_expired') {
        _handleLoginError(outcome);
      } else {
        _redirectAuthorizationError(outcome);
      }
    } catch (_) {
      if (!mounted) return;
      _update(() {
        _checkingFederatedReturn = false;
        _error =
            'The federated authorization result is unknown. Restart sign-in; '
            'the one-time continuation was not replayed.';
      });
    }
  }

  void _completeFirstPartyLogin(
    String token, {
    String? redirectTarget,
    String? sessionId,
  }) {
    if (!Session.store(
      token,
      sessionId: sessionId,
      clientId: _effectiveClientId,
    )) {
      _update(
        () => _error =
            'Sign-in succeeded, but this browser cannot securely store the '
            'session. Enable site storage and try again.',
      );
      return;
    }
    _redirect(
      redirectTarget ??
          _route.portalActionTarget ??
          _safeRedirectTarget(_routeUri),
    );
  }

  void _signInWithFederated(String connectionId) {
    if (!kIsWeb) {
      _update(() => _error = 'Federated sign-in requires the web console.');
      return;
    }
    if (_effectiveClientId.isEmpty) {
      _update(() => _error = 'No client is configured for this sign-in.');
      return;
    }
    if (_isRpFlow && !_serverOwnedAuthorizationRequestSupported) {
      _update(
        () => _error =
            'Federated RP sign-in requires a Snaplink deployment that '
            'preserves the server-owned authorization request and securely '
            'resumes it after the identity-provider callback.',
      );
      return;
    }
    if (_isRpFlow) {
      final query = _params.toFederatedLoginQuery(connectionId);
      query['response_type'] = _params.responseType.isNotEmpty
          ? _params.responseType
          : 'code';
      _redirect(
        ProductApiOrigin.baseUri
            .resolve('/auth/login')
            .replace(queryParameters: query)
            .toString(),
      );
      return;
    }
    try {
      _redirect(
        FederatedLogin.beginLoginUrl(
          connectionId: connectionId,
          clientId: _effectiveClientId,
          redirectTarget:
              _route.portalActionTarget ?? _safeRedirectTarget(_routeUri),
        ),
      );
    } catch (_) {
      _update(
        () => _error =
            'Federated sign-in could not start because secure tab storage is '
            'unavailable.',
      );
    }
  }

  Future<void> _probeProviders() async {
    try {
      final outcome = await _api.probeProviders(
        _effectiveClientId,
        loginHint: _params.loginHint,
      );
      if (!mounted) return;

      _serverOwnedAuthorizationRequestSupported =
          outcome.data['authorization_request_passthrough_supported'] == true;

      _applyBranding(outcome.data['branding'], clientSpecific: true);

      final loginPage = buildLoginPageRedirect(
        outcome.data['login_page_uri']?.toString(),
        _routeUri,
      );
      if (loginPage != null &&
          _route.allowsCustomLoginPage &&
          !hostedLoginRedirectContainsSensitiveData(_routeUri)) {
        _redirect(loginPage.toString());
        return;
      }

      final connectionId =
          outcome.data['connection_id']?.toString().trim() ?? '';
      if (outcome.data['connection_required'] == true &&
          connectionId.isNotEmpty) {
        _signInWithFederated(connectionId);
        return;
      }

      final rawProviders = outcome.data['providers'];
      if (rawProviders is! List) return;
      final seen = <String>{};
      final descriptors = rawProviders
          .map(LoginProviderDescriptor.fromWire)
          .where(
            (descriptor) => descriptor.id.isNotEmpty && seen.add(descriptor.id),
          )
          .toList(growable: false);
      _update(() {
        _providerDiscoveryComplete = true;
        _providers = descriptors;
        if (!_providers.any((item) => item.id == _provider) &&
            _providers.isNotEmpty) {
          _provider = _providers
              .firstWhere(
                (item) => item.builtin,
                orElse: () => _providers.first,
              )
              .id;
        }
      });
    } catch (_) {
      // Discovery is best-effort; direct login still owns the final decision.
    }
  }

  Future<void> _loadBranding() async {
    try {
      final branding = await _api.loadBranding();
      if (!mounted || branding.isEmpty || _clientBrandingApplied) return;
      _applyBranding(branding);
    } catch (_) {
      // The default theme is a valid fallback.
    }
  }

  void _applyBranding(Object? raw, {bool clientSpecific = false}) {
    if (!mounted || raw is! Map) return;
    final name = _nonEmptyString(raw['brand_name']);
    final rawLogo =
        _nonEmptyString(raw['logo_url']) ?? _nonEmptyString(raw['logo']);
    final logo = resolveSafeHostedUrl(
      rawLogo,
      ProductApiOrigin.baseUri,
    )?.toString();
    final color = _parseColor(
      _nonEmptyString(raw['primary_color']) ??
          _nonEmptyString(raw['color']) ??
          '',
    );
    if (name == null && logo == null && color == null) return;

    _update(() {
      if (name != null) _brandName = name;
      if (logo != null) _brandLogoUrl = logo;
      if (color != null) _brandColor = color;
      if (clientSpecific) _clientBrandingApplied = true;
    });
  }

  String? _nonEmptyString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  Color? _parseColor(String raw) {
    final match = RegExp(
      r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
    ).firstMatch(raw.trim());
    if (match == null) return null;
    final value = match.group(1)!;
    final flutterHex = value.length == 6
        ? 'ff$value'
        : '${value.substring(6)}${value.substring(0, 6)}';
    return Color(int.parse(flutterHex, radix: 16));
  }

  Future<void> _discoverHomeRealm() async {
    final identifier = _userCtrl.text.trim();
    if (identifier.isEmpty) {
      _update(() => _error = 'Enter your work email.');
      return;
    }
    _update(() {
      _loading = true;
      _error = null;
    });
    try {
      final outcome = await _api.discoverHomeRealm(identifier);
      if (!mounted) return;
      _serverOwnedAuthorizationRequestSupported =
          outcome.data['authorization_request_passthrough_supported'] == true;
      final connectionId =
          outcome.data['connection_id']?.toString().trim() ?? '';
      if (outcome.ok &&
          outcome.data['found'] == true &&
          connectionId.isNotEmpty) {
        _signInWithFederated(connectionId);
        return;
      }
      _update(
        () => _error = outcome.status == 404
            ? 'Organization sign-in is not enabled.'
            : 'No organization sign-in route was found.',
      );
    } catch (_) {
      if (mounted) {
        _update(() => _error = AppStrings.of(context).networkError);
      }
    } finally {
      if (mounted) _update(() => _loading = false);
    }
  }
}

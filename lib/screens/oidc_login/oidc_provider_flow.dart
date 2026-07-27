part of 'oidc_login_screen.dart';

extension _OidcProviderFlow on _OidcLoginScreenState {
  /// Finishes a federated first-party return before showing the plain form.
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

  void _completeFirstPartyLogin(
    String token, {
    String? redirectTarget,
    String? sessionId,
  }) {
    Session.store(token, sessionId: sessionId, clientId: _effectiveClientId);
    _redirect(redirectTarget ?? _safeRedirectTarget());
  }

  void _signInWithFederated(String connectionId) {
    if (_effectiveClientId.isEmpty) {
      _update(() => _error = 'No client is configured for this sign-in.');
      return;
    }
    if (_isRpFlow) {
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
    _redirect(
      FederatedLogin.beginLoginUrl(
        connectionId: connectionId,
        clientId: _effectiveClientId,
        redirectTarget: _safeRedirectTarget(),
      ),
    );
  }

  Future<void> _probeProviders() async {
    try {
      final outcome = await _api.probeProviders(
        _effectiveClientId,
        loginHint: _params.loginHint,
      );
      if (!mounted) return;

      _applyBranding(outcome.data['branding'], clientSpecific: true);

      final loginPage = buildLoginPageRedirect(
        outcome.data['login_page_uri']?.toString(),
        Uri.base,
      );
      if (loginPage != null) {
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
    final logo = resolveSafeHostedUrl(rawLogo, Uri.base)?.toString();
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

import 'dart:convert';

/// A provider descriptor returned by Snaplink's provider-discovery response.
///
/// Older deployments returned provider IDs as strings, so [fromWire] keeps
/// that shape compatible while preferring the richer server-owned metadata.
class LoginProviderDescriptor {
  static const builtinProviderIds = {
    'password',
    'phone',
    'email',
    'magiclink',
    'totp',
    'webauthn',
  };

  final String id;
  final String type;
  final String displayName;
  final String iconUrl;
  final String buttonLabel;
  final String buttonColor;
  final bool builtin;

  const LoginProviderDescriptor({
    required this.id,
    required this.type,
    required this.displayName,
    this.iconUrl = '',
    this.buttonLabel = '',
    this.buttonColor = '',
    required this.builtin,
  });

  const LoginProviderDescriptor.password()
    : id = 'password',
      type = 'builtin',
      displayName = 'Password',
      iconUrl = '',
      buttonLabel = '',
      buttonColor = '',
      builtin = true;

  factory LoginProviderDescriptor.fromWire(Object? raw) {
    if (raw is String) {
      final id = raw.trim();
      return LoginProviderDescriptor(
        id: id,
        type: builtinProviderIds.contains(id) ? 'builtin' : '',
        displayName: _fallbackProviderName(id),
        builtin: builtinProviderIds.contains(id),
      );
    }
    if (raw is Map) {
      final id = raw['id']?.toString().trim() ?? '';
      final type = raw['type']?.toString().trim() ?? '';
      return LoginProviderDescriptor(
        id: id,
        type: type,
        displayName: _nonEmpty(
          raw['display_name'],
          fallback: _fallbackProviderName(id),
        ),
        iconUrl: raw['icon_url']?.toString().trim() ?? '',
        buttonLabel: raw['button_label']?.toString().trim() ?? '',
        buttonColor: raw['button_color']?.toString().trim() ?? '',
        builtin:
            raw['builtin'] == true ||
            type == 'builtin' ||
            builtinProviderIds.contains(id),
      );
    }
    return const LoginProviderDescriptor(
      id: '',
      type: '',
      displayName: '',
      builtin: false,
    );
  }

  bool get isFederated => !builtin;

  String get effectiveButtonLabel =>
      buttonLabel.isNotEmpty ? buttonLabel : 'Sign in with $displayName';

  String? safeIconUrl(Uri pageUri) =>
      resolveSafeHostedUrl(iconUrl, pageUri)?.toString();

  static String _nonEmpty(Object? value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String _fallbackProviderName(String id) {
    if (id.isEmpty) return '';
    final words = id
        .split(RegExp(r'[-_\s]+'))
        .where((word) => word.isNotEmpty)
        .map(
          (word) => '${word.substring(0, 1).toUpperCase()}${word.substring(1)}',
        );
    return words.join(' ');
  }
}

/// Resolves a branding, provider-icon, or custom-login URL.
///
/// Cross-origin resources must be explicit HTTPS URLs. Relative URLs and HTTP
/// are accepted only when they resolve to the current page origin.
Uri? resolveSafeHostedUrl(String? raw, Uri pageUri) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty ||
      value.contains('\\') ||
      RegExp(r'[\u0000-\u001f\u007f]').hasMatch(value)) {
    return null;
  }

  final parsed = Uri.tryParse(value);
  if (parsed == null ||
      parsed.userInfo.isNotEmpty ||
      (parsed.hasAuthority && !parsed.hasScheme)) {
    return null;
  }

  final resolved = pageUri.resolveUri(parsed);
  if (!resolved.hasAuthority ||
      resolved.userInfo.isNotEmpty ||
      (resolved.scheme != 'https' && resolved.scheme != 'http')) {
    return null;
  }
  if (resolved.scheme == 'https') return resolved;
  return pageUri.scheme == 'http' &&
          pageUri.hasAuthority &&
          resolved.origin == pageUri.origin
      ? resolved
      : null;
}

/// Builds a safe navigation target for a server-provided `login_page_uri`.
///
/// OAuth request parameters are forwarded to the custom page, while query
/// parameters configured on the target take precedence. Returning null avoids
/// unsafe targets and redirects back to the current page.
Uri? buildLoginPageRedirect(String? raw, Uri currentUri) {
  final target = resolveSafeHostedUrl(raw, currentUri);
  if (target == null) return null;

  final query = <String, dynamic>{
    for (final entry in currentUri.queryParametersAll.entries)
      entry.key: entry.value.length == 1 ? entry.value.first : entry.value,
    for (final entry in target.queryParametersAll.entries)
      entry.key: entry.value.length == 1 ? entry.value.first : entry.value,
  };
  final redirect = target.replace(queryParameters: query, fragment: '');
  final current = currentUri.replace(fragment: '');
  return redirect == current ? null : redirect;
}

class ConsentScopeDescriptor {
  final String scope;
  final String description;

  const ConsentScopeDescriptor({required this.scope, this.description = ''});
}

/// A fail-closed rendering model for a `consent_required` response.
class ConsentRequestSummary {
  final List<ConsentScopeDescriptor> scopes;
  final List<Map<String, dynamic>> authorizationDetails;
  final String? parseError;

  const ConsentRequestSummary({
    required this.scopes,
    required this.authorizationDetails,
    this.parseError,
  });

  const ConsentRequestSummary.invalid([this.parseError = consentSummaryError])
    : scopes = const [],
      authorizationDetails = const [];

  static const consentSummaryError =
      'The authorization request could not be summarized safely.';

  factory ConsentRequestSummary.fromResponse(Map<String, dynamic> response) {
    final parsedScopes = <ConsentScopeDescriptor>[];
    final rawScopes = response['scopes'];
    if (rawScopes is! List) {
      return const ConsentRequestSummary.invalid();
    }
    for (final rawScope in rawScopes) {
      if (rawScope is String) {
        final scope = rawScope.trim();
        if (scope.isEmpty) {
          return const ConsentRequestSummary.invalid();
        }
        parsedScopes.add(ConsentScopeDescriptor(scope: scope));
        continue;
      }
      if (rawScope is! Map) {
        return const ConsentRequestSummary.invalid();
      }
      final scope = rawScope['scope']?.toString().trim() ?? '';
      if (scope.isEmpty) {
        return const ConsentRequestSummary.invalid();
      }
      parsedScopes.add(
        ConsentScopeDescriptor(
          scope: scope,
          description: rawScope['description']?.toString().trim() ?? '',
        ),
      );
    }

    final parsedDetails = <Map<String, dynamic>>[];
    if (response.containsKey('authorization_details')) {
      Object? rawDetails = response['authorization_details'];
      if (rawDetails is String) {
        try {
          rawDetails = jsonDecode(rawDetails);
        } on FormatException {
          return const ConsentRequestSummary.invalid();
        }
      }
      if (rawDetails is! List || rawDetails.isEmpty) {
        return const ConsentRequestSummary.invalid();
      }
      for (final rawDetail in rawDetails) {
        if (rawDetail is! Map || rawDetail.isEmpty) {
          return const ConsentRequestSummary.invalid();
        }
        parsedDetails.add({
          for (final entry in rawDetail.entries)
            entry.key.toString(): entry.value,
        });
      }
    }

    final summary = ConsentRequestSummary(
      scopes: List.unmodifiable(parsedScopes),
      authorizationDetails: List.unmodifiable(parsedDetails),
    );
    if (!summary.hasTerms) {
      return const ConsentRequestSummary.invalid(
        'The authorization request contains no permissions to review.',
      );
    }
    return summary;
  }

  bool get hasTerms => scopes.isNotEmpty || authorizationDetails.isNotEmpty;

  bool get canAuthorize => parseError == null && hasTerms;
}

enum HostedLoginFlow {
  login,
  forgotPassword,
  resetPassword,
  signup,
  verifyEmail,
  magicLink,
}

/// Routes opaque email tokens only when the URL explicitly identifies their
/// purpose. The fragment-email magic-link shape remains supported for legacy
/// links without a `flow` parameter.
class HostedLoginRoute {
  final HostedLoginFlow flow;
  final bool hasExplicitFlow;
  final String? token;
  final String? magicLinkEmail;

  const HostedLoginRoute({
    required this.flow,
    required this.hasExplicitFlow,
    required this.token,
    required this.magicLinkEmail,
  });

  factory HostedLoginRoute.fromUri(Uri uri) {
    final rawFlow = uri.queryParameters['flow']?.trim() ?? '';
    final fragmentEmail = uri.fragment.isEmpty
        ? null
        : Uri(query: uri.fragment).queryParameters['email']?.trim();
    final flow = _parseFlow(rawFlow);
    final explicitMagicEmail = flow == HostedLoginFlow.magicLink
        ? uri.queryParameters['email']?.trim()
        : null;
    return HostedLoginRoute(
      flow: flow,
      hasExplicitFlow: rawFlow.isNotEmpty,
      token: _nonEmptyOrNull(uri.queryParameters['token']),
      magicLinkEmail:
          _nonEmptyOrNull(explicitMagicEmail) ?? _nonEmptyOrNull(fragmentEmail),
    );
  }

  String? get resetToken =>
      flow == HostedLoginFlow.resetPassword ? token : null;

  String? get verificationToken =>
      flow == HostedLoginFlow.verifyEmail ? token : null;

  String? get magicLinkToken {
    if (flow == HostedLoginFlow.magicLink) return token;
    if (!hasExplicitFlow && magicLinkEmail != null) return token;
    return null;
  }

  bool get shouldAutoSubmitMagicLink =>
      magicLinkToken != null && magicLinkEmail != null;

  static HostedLoginFlow _parseFlow(String raw) {
    switch (raw.toLowerCase()) {
      case 'forgot':
      case 'forgot_password':
        return HostedLoginFlow.forgotPassword;
      case 'reset':
      case 'reset_password':
        return HostedLoginFlow.resetPassword;
      case 'signup':
      case 'register':
        return HostedLoginFlow.signup;
      case 'verify':
      case 'verify_email':
        return HostedLoginFlow.verifyEmail;
      case 'magiclink':
      case 'magic_link':
        return HostedLoginFlow.magicLink;
      default:
        return HostedLoginFlow.login;
    }
  }

  static String? _nonEmptyOrNull(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

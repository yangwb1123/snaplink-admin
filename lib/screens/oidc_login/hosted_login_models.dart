export 'consent_models.dart';

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
bool isSafeHostedReturnTarget(String raw, Uri currentUri) {
  if (raw.isEmpty || raw.contains('\\')) return false;
  final target = Uri.tryParse(raw);
  if (target == null || target.fragment.isNotEmpty) return false;
  if (!currentUri.hasAuthority) {
    return !target.hasScheme &&
        !target.hasAuthority &&
        target.path.startsWith('/');
  }
  final resolved = currentUri.resolve(raw);
  return resolved.hasAuthority &&
      resolved.userInfo.isEmpty &&
      (resolved.scheme == 'http' || resolved.scheme == 'https') &&
      resolved.origin == currentUri.origin;
}

Uri? buildLoginPageRedirect(String? raw, Uri currentUri) {
  final target = resolveSafeHostedUrl(raw, currentUri);
  if (target == null) return null;

  // These fields are action verifiers, identity hints used by one-time flows,
  // or bearer-equivalent MFA-skip credentials. They are not OAuth request
  // parameters and must not cross into a separately hosted login page, even
  // when a stale link or target configuration happens to contain them.
  const privateParameters = {
    // Account/action and MFA credentials.
    'device_token',
    'token',
    'email',
    'password',
    'credential',
    'code_verifier',
    'assertion',
    'verification_code',
    'mfa_challenge_id',
    'mfa_method',
    // Server-owned, one-use authorization continuations.
    'login_transaction_id',
    'consent_challenge_id',
    'consent_decision',
    // Authorization responses must never be copied into a login-page URL.
    'code',
    'access_token',
    'refresh_token',
    'id_token',
    'error',
    'error_description',
  };
  final query = <String, dynamic>{
    for (final entry in currentUri.queryParametersAll.entries)
      if (!privateParameters.contains(entry.key) &&
          (entry.key != 'redirect' ||
              (entry.value.length == 1 &&
                  isSafeHostedReturnTarget(entry.value.single, currentUri))))
        entry.key: entry.value.length == 1 ? entry.value.first : entry.value,
    for (final entry in target.queryParametersAll.entries)
      if (!privateParameters.contains(entry.key))
        entry.key: entry.value.length == 1 ? entry.value.first : entry.value,
  };
  final redirect = target.replace(queryParameters: query, fragment: '');
  final current = currentUri.replace(fragment: '');
  return redirect == current ? null : redirect;
}

/// Returns true when a first-party login URL carries sensitive material inside
/// its validated `redirect` target. Action tokens are kept nested so they can
/// return to the same-origin Portal after authentication, but they must not be
/// copied into a separately hosted login page's query string.
bool hostedLoginRedirectContainsSensitiveData(Uri currentUri) {
  final redirectValues =
      currentUri.queryParametersAll['redirect'] ?? const <String>[];
  // A repeated continuation is ambiguous. Do not let queryParameters pick a
  // winner and then send the request to a separately hosted login page.
  if (redirectValues.length != 1) return redirectValues.isNotEmpty;
  final raw = redirectValues.single;
  if (raw.trim().isEmpty) return false;
  final target = Uri.tryParse(raw);
  if (target == null) return false;
  const privateParameters = {
    'access_token',
    'assertion',
    'code',
    'code_verifier',
    'consent_challenge_id',
    'consent_decision',
    'credential',
    'device_token',
    'email',
    'error',
    'error_description',
    'id_token',
    'login_transaction_id',
    'mfa_challenge_id',
    'mfa_method',
    'password',
    'refresh_token',
    'state',
    'token',
    'verification_code',
  };
  return target.queryParametersAll.keys.any(privateParameters.contains);
}

enum HostedLoginFlow {
  login,
  forgotPassword,
  resetPassword,
  signup,
  verifyEmail,
  magicLink,
  changeEmail,
  invitation,
}

/// Routes opaque email tokens only when the URL explicitly identifies their
/// purpose. The fragment-email magic-link shape remains supported for legacy
/// links without a `flow` parameter.
class HostedLoginRoute {
  final HostedLoginFlow flow;
  final bool hasExplicitFlow;
  final String? token;
  final String? magicLinkEmail;
  final bool malformed;

  const HostedLoginRoute({
    required this.flow,
    required this.hasExplicitFlow,
    required this.token,
    required this.magicLinkEmail,
    this.malformed = false,
  });

  factory HostedLoginRoute.fromUri(Uri uri) {
    final flowValues = uri.queryParametersAll['flow'] ?? const <String>[];
    final tokenValues = uri.queryParametersAll['token'] ?? const <String>[];
    final emailValues = uri.queryParametersAll['email'] ?? const <String>[];
    final rawFlow = flowValues.length == 1 ? flowValues.single.trim() : '';
    final fragmentEmail = uri.fragment.isEmpty
        ? null
        : Uri(query: uri.fragment).queryParameters['email']?.trim();
    final flow = _parseFlow(rawFlow);
    final explicitMagicEmail =
        flow == HostedLoginFlow.magicLink && emailValues.length == 1
        ? emailValues.single.trim()
        : null;
    return HostedLoginRoute(
      flow: flow,
      hasExplicitFlow: rawFlow.isNotEmpty,
      token: tokenValues.length == 1
          ? _nonEmptyOrNull(tokenValues.single)
          : null,
      magicLinkEmail:
          _nonEmptyOrNull(explicitMagicEmail) ?? _nonEmptyOrNull(fragmentEmail),
      malformed:
          flowValues.length > 1 ||
          tokenValues.length > 1 ||
          emailValues.length > 1,
    );
  }

  String? get resetToken =>
      flow == HostedLoginFlow.resetPassword ? token : null;

  String? get verificationToken =>
      flow == HostedLoginFlow.verifyEmail ? token : null;

  String? get portalActionTarget {
    final action = switch (flow) {
      HostedLoginFlow.changeEmail => 'change_email',
      HostedLoginFlow.invitation => 'invitation',
      _ => null,
    };
    if (action == null || token == null) return null;
    return Uri(
      path: '/portal/',
      queryParameters: {'flow': action, 'token': token},
    ).toString();
  }

  bool get requiresAuthentication =>
      !malformed &&
      (flow == HostedLoginFlow.login ||
          flow == HostedLoginFlow.magicLink ||
          flow == HostedLoginFlow.changeEmail ||
          flow == HostedLoginFlow.invitation);

  /// A separately hosted login page may receive ordinary OAuth parameters,
  /// but it must not receive (or be expected to reconstruct) one-time account
  /// action material.  Keep magic-link, email-change, and invitation flows on
  /// this built-in page so the action token remains in the same-origin flow and
  /// can be handed to the authenticated Portal exactly once.
  bool get allowsCustomLoginPage => !malformed && flow == HostedLoginFlow.login;

  String? get magicLinkToken {
    if (malformed) return null;
    if (flow == HostedLoginFlow.magicLink) return token;
    if (!hasExplicitFlow && magicLinkEmail != null) return token;
    return null;
  }

  bool get shouldAutoSubmitMagicLink =>
      !malformed && magicLinkToken != null && magicLinkEmail != null;

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
      case 'change_email':
      case 'email_change':
        return HostedLoginFlow.changeEmail;
      case 'invitation':
      case 'invite':
        return HostedLoginFlow.invitation;
      default:
        return HostedLoginFlow.login;
    }
  }

  static String? _nonEmptyOrNull(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

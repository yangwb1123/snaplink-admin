import 'dart:convert';
import 'package:http/http.dart' as http;

/// Structured result of a POST to /auth/login or /auth/mfa: either a
/// terminal outcome (code/tokens to redirect with, or no redirect_uri at
/// all) or one of the two interactive continuations the hosted login page
/// must branch on (mfa_required / consent_required), mirroring
/// interfaces/web/login/app.js's handleLoginError exactly.
class LoginOutcome {
  final int status;
  final Map<String, dynamic> data;
  final String? html;
  final Uri? redirectUrl;

  LoginOutcome(this.status, this.data, {this.html, this.redirectUrl});

  bool get ok => status >= 200 && status < 300 && data['error'] == null;
  bool get isFormPost => html != null;
  String? get error => data['error'] as String?;
  bool get isMfaRequired => error == 'mfa_required';
  bool get isConsentRequired => error == 'consent_required';
}

class OidcLoginApi {
  final http.Client _http;
  final Uri _baseUri;
  final Duration _timeout;

  OidcLoginApi({
    http.Client? httpClient,
    Uri? baseUri,
    Duration timeout = const Duration(seconds: 30),
  }) : _http = httpClient ?? http.Client(),
       _baseUri = baseUri ?? Uri.base,
       _timeout = timeout;

  Uri _resolve(String path) => _baseUri.resolve(path);

  /// Cancels in-flight browser requests when the hosted login route unmounts.
  ///
  /// This releases the timeout future as well; mutation requests are never
  /// replayed by a replacement client.
  void close() => _http.close();

  Future<LoginOutcome> probeProviders(
    String clientId, {
    String? loginHint,
  }) async {
    return _postOutcome('../auth/login', {
      'client_id': clientId,
      if (loginHint != null && loginHint.isNotEmpty) 'login_hint': loginHint,
    });
  }

  Future<LoginOutcome> login(Map<String, dynamic> payload) =>
      _postOutcome('../auth/login', payload);

  /// Starts the discoverable-credential ceremony used by Snaplink's opt-in
  /// passwordless `provider=webauthn` authenticator.
  Future<LoginOutcome> beginPasswordlessWebAuthn() async {
    return _postOutcome('../webauthn/login/conditional/begin', const {});
  }

  /// Dispatches a phone, email OTP, or magic-link credential through the
  /// provider's configured CodeSender before `/auth/login` verifies it.
  Future<LoginOutcome> sendCode(String provider, String target) async {
    return _postOutcome('../auth/send-code', {
      'provider': provider,
      'target': target,
    });
  }

  /// Resolves a login identifier to a configured B2B connection. A successful
  /// `found: false` response is a routing miss, not an account lookup failure.
  Future<LoginOutcome> discoverHomeRealm(String identifier) {
    return _postOutcome('../auth/home-realm', {'login_hint': identifier});
  }

  /// Loads non-sensitive, host-scoped login branding. An absent feature or an
  /// unknown host is intentionally rendered as no custom branding.
  Future<Map<String, String>> loadBranding() async {
    final response = await _http.get(_resolve('../branding')).timeout(_timeout);
    if (response.statusCode != 200 || response.body.isEmpty) return const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['branding'] is Map) {
        return {
          for (final entry in (decoded['branding'] as Map).entries)
            entry.key.toString(): entry.value.toString(),
        };
      }
    } catch (_) {
      // A proxy error or an older deployment gets the default theme.
    }
    return const {};
  }

  Future<LoginOutcome> mfaComplete({
    required String mfaChallengeId,
    required String method,
    String? code,
    String? assertion,
    Map<String, String>? params,
    bool trustDevice = false,
  }) async {
    return _postOutcome('../auth/mfa', {
      'mfa_challenge_id': mfaChallengeId,
      // Snaplink binds the documented `mfa_method` plus flat factor
      // fields. A nested `credential` leaves Method empty and the server
      // correctly rejects it as mfa_invalid before factor verification.
      'mfa_method': method,
      if (code != null && code.isNotEmpty) 'code': code,
      if (assertion != null && assertion.isNotEmpty) 'assertion': assertion,
      if (params != null && params.isNotEmpty) 'params': params,
      if (trustDevice) 'trust_device': true,
    });
  }

  /// Always-200 anti-enumeration contract per the JS: caller just needs to
  /// know 404 (feature off) vs 2xx (generic "if that account exists" message).
  Future<int> forgotPassword(String identifier) async {
    final resp = await _http
        .post(
          _resolve('../auth/forgot-password'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'identifier': identifier}),
        )
        .timeout(_timeout);
    return resp.statusCode;
  }

  /// Consumes the one-time token sent by Snaplink's password-reset flow.
  Future<LoginOutcome> resetPassword(String token, String newPassword) {
    return _postOutcome('../auth/reset-password', {
      'token': token,
      'new_password': newPassword,
    });
  }

  /// Completes mandatory-signup email verification. It is distinct from a
  /// password reset even though both links carry opaque single-use tokens.
  Future<LoginOutcome> verifyEmail(String token) {
    return _postOutcome('../auth/verify-email', {'token': token});
  }

  Future<LoginOutcome> register({
    required String username,
    required String password,
    String? email,
  }) async {
    final resp = await _http
        .post(
          _resolve('../auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': username,
            'password': password,
            if (email != null && email.isNotEmpty) 'email': email,
          }),
        )
        .timeout(_timeout);
    return _parse(resp);
  }

  Future<LoginOutcome> _postOutcome(String path, Object body) async {
    final request = http.Request('POST', _resolve(path))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(body);
    final streamed = await _http.send(request).timeout(_timeout);
    final redirectUrl = streamed is http.BaseResponseWithUrl
        ? (streamed as http.BaseResponseWithUrl).url
        : null;
    final response = await http.Response.fromStream(streamed).timeout(_timeout);
    return _parse(response, redirectUrl);
  }

  LoginOutcome _parse(http.Response resp, [Uri? redirectUrl]) {
    final contentType = resp.headers['content-type']?.toLowerCase() ?? '';
    if (resp.statusCode == 200 && contentType.startsWith('text/html')) {
      // `response_mode=form_post` and form-post JARM deliberately return an
      // auto-submitting HTML document, not JSON. The UI renders this document
      // as a real browser navigation so the relying party receives a POST.
      return LoginOutcome(
        resp.statusCode,
        const {},
        html: resp.body,
        redirectUrl: redirectUrl,
      );
    }
    Map<String, dynamic> data = const {};
    if (resp.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {
        // non-JSON body (e.g. a plain-text 404) — status code alone still
        // lets callers branch correctly.
      }
    }
    return LoginOutcome(resp.statusCode, data, redirectUrl: redirectUrl);
  }
}

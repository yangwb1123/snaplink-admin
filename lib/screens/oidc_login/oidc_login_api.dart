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
  LoginOutcome(this.status, this.data);

  bool get ok => status == 200 && data['error'] == null;
  String? get error => data['error'] as String?;
  bool get isMfaRequired => error == 'mfa_required';
  bool get isConsentRequired => error == 'consent_required';
}

class OidcLoginApi {
  final http.Client _http = http.Client();

  Uri _resolve(String path) => Uri.base.resolve(path);

  Future<LoginOutcome> probeProviders(String clientId) async {
    final resp = await _http.post(
      _resolve('../auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'client_id': clientId}),
    );
    return _parse(resp);
  }

  Future<LoginOutcome> login(Map<String, dynamic> payload) async {
    final resp = await _http.post(
      _resolve('../auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    return _parse(resp);
  }

  Future<LoginOutcome> mfaComplete({
    required String mfaChallengeId,
    required String method,
    required Map<String, String> credential,
  }) async {
    final resp = await _http.post(
      _resolve('../auth/mfa'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'mfa_challenge_id': mfaChallengeId,
        'method': method,
        'credential': credential,
      }),
    );
    return _parse(resp);
  }

  /// Always-200 anti-enumeration contract per the JS: caller just needs to
  /// know 404 (feature off) vs 2xx (generic "if that account exists" message).
  Future<int> forgotPassword(String identifier) async {
    final resp = await _http.post(
      _resolve('../auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier}),
    );
    return resp.statusCode;
  }

  Future<LoginOutcome> register({
    required String username,
    required String password,
    String? email,
  }) async {
    final resp = await _http.post(
      _resolve('../auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        if (email != null && email.isNotEmpty) 'email': email,
      }),
    );
    return _parse(resp);
  }

  LoginOutcome _parse(http.Response resp) {
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
    return LoginOutcome(resp.statusCode, data);
  }
}

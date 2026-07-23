import 'dart:convert';
import 'package:http/http.dart' as http;

/// Result of `GET /api/v1/setup/status`. The JS wizard (interfaces/web/setup
/// /app.js) reads `d.setup_required` — NOT `initialized` — so this mirrors
/// that exact field name.
class SetupStatus {
  final bool setupRequired;
  final bool available;

  const SetupStatus(this.setupRequired, {this.available = true});
}

/// Step-1 payload, POSTed as `{"admin": {...}}`.
class SetupAdmin {
  final String username;
  final String password;
  const SetupAdmin({required this.username, required this.password});

  Map<String, dynamic> toJson() => {'username': username, 'password': password};
}

/// Step-2 (optional) payload, POSTed as `{"application": {...}}`. app.js only
/// includes `redirect_uris` (a one-element array) when the field was filled.
class SetupApplication {
  final String name;
  final String? redirectUri;
  const SetupApplication({required this.name, this.redirectUri});

  Map<String, dynamic> toJson() => {
    'name': name,
    if (redirectUri != null && redirectUri!.isNotEmpty)
      'redirect_uris': [redirectUri],
  };
}

/// Outcome of `POST /api/v1/setup`, covering the three branches app.js's
/// `finish()` distinguishes: success (200 + `ok:true`), the already-initialized
/// race (409), and any other failure (validation error or unexpected status).
class SetupResult {
  final bool alreadyInitialized;
  final String? error;
  final String? createdAdmin;
  final String? clientId;
  final String? clientSecret;

  const SetupResult._({
    this.alreadyInitialized = false,
    this.error,
    this.createdAdmin,
    this.clientId,
    this.clientSecret,
  });

  const SetupResult.success({
    required String? admin,
    String? clientId,
    String? clientSecret,
  }) : this._(
         createdAdmin: admin,
         clientId: clientId,
         clientSecret: clientSecret,
       );

  const SetupResult.alreadyDone() : this._(alreadyInitialized: true);

  const SetupResult.failed(String message) : this._(error: message);
}

/// Thrown only for a transport-level failure (fetch/http.post never got a
/// response) — mirrors app.js's `.catch(() => setError('Network error...'))`.
class SetupNetworkError implements Exception {}

/// Dedicated API helper for the setup wizard. Requests resolve against the
/// page's own origin via `Uri.base` — this screen is served behind the same
/// reverse proxy as the SSO API itself, so no cross-origin base URL field is
/// needed (every screen in this app resolves the SSO API the same way).
class SetupApi {
  final http.Client _http;
  SetupApi({http.Client? client}) : _http = client ?? http.Client();

  Uri _statusUri() => Uri.base.resolve('/api/v1/setup/status');
  Uri _setupUri() => Uri.base.resolve('/api/v1/setup');

  /// The setup route's 404 is meaningful: it says the one-time wizard is
  /// disabled. Other transport/status failures cannot safely be interpreted
  /// as permission to create a new administrator.
  Future<SetupStatus> checkStatus() async {
    try {
      final resp = await _http.get(
        _statusUri(),
        headers: const {'Accept': 'application/json'},
      );
      if (resp.statusCode == 404) {
        return const SetupStatus(false, available: false);
      }
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw SetupNetworkError();
      }
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic> &&
          decoded['setup_required'] == true) {
        return const SetupStatus(true);
      }
      return const SetupStatus(false);
    } catch (_) {
      throw SetupNetworkError();
    }
  }

  /// Mirrors app.js's `finish()`: POST once with the admin plus the optional
  /// application, then branch on status/body exactly as the JS does.
  Future<SetupResult> submit({
    required SetupAdmin admin,
    SetupApplication? application,
  }) async {
    final payload = <String, dynamic>{
      'admin': admin.toJson(),
      if (application != null) 'application': application.toJson(),
    };

    http.Response resp;
    try {
      resp = await _http.post(
        _setupUri(),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (_) {
      throw SetupNetworkError();
    }

    Map<String, dynamic> data = const {};
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {
      // Non-JSON body; fall through to the generic status-based branches below.
    }

    if (resp.statusCode == 200 && data['ok'] == true) {
      final created = data['created'] as Map<String, dynamic>? ?? const {};
      final app = created['application'] as Map<String, dynamic>?;
      return SetupResult.success(
        admin: created['admin']?.toString(),
        clientId: app?['client_id']?.toString(),
        clientSecret: app?['client_secret']?.toString(),
      );
    }
    if (resp.statusCode == 409) {
      return const SetupResult.alreadyDone();
    }
    final err = data['error']?.toString();
    return SetupResult.failed(
      err != null ? 'Setup failed: $err' : 'Setup failed.',
    );
  }
}

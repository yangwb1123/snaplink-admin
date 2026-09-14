import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../session.dart';
import 'forge_conversations_oauth.dart';
import 'forge_credential_store.dart';

/// Performs one per-client Snaplink refresh-token rotation after Forge rejects
/// an expired access token. Web keeps refresh tokens in tab-scoped storage;
/// Android and iOS persist the Forge client slot in platform secure storage.
class ForgeOAuthTokenRefresh {
  static const _maxResponseBytes = 64 * 1024;

  final String clientId;
  final Uri _tokenEndpoint;
  final Uri _revocationEndpoint;
  final http.Client _http;
  final ForgeCredentialStore _credentialStore;
  final Duration timeout;
  final Duration revocationTimeout;
  Future<String?>? _inFlight;
  Future<void>? _revocationInFlight;
  bool _revocationStarted = false;

  ForgeOAuthTokenRefresh({
    required String baseUrl,
    this.clientId = ForgeConversationsOAuth.clientId,
    ForgeCredentialStore? credentialStore,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 20),
    this.revocationTimeout = const Duration(seconds: 5),
  }) : _tokenEndpoint = _resolveEndpoint(baseUrl, '/token'),
       _revocationEndpoint = _resolveEndpoint(baseUrl, '/token/revoke'),
       _credentialStore =
           credentialStore ?? ForgeCredentialStore(clientId: clientId),
       _http = httpClient ?? http.Client();

  /// Reuses a newer access token if another request already completed the
  /// rotation. Concurrent 401 responses share one use of the rotating token.
  Future<String?> refreshAfterUnauthorized(String failedAccessToken) {
    if (_revocationStarted) return Future<String?>.value(null);

    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final currentAccessToken = Session.readForClient(clientId);
    if (currentAccessToken == null || currentAccessToken.isEmpty) {
      return Future<String?>.value(null);
    }
    if (currentAccessToken != failedAccessToken) {
      return Future<String?>.value(currentAccessToken);
    }

    final refreshToken = Session.readRefreshTokenForClient(clientId);
    if (refreshToken == null || refreshToken.isEmpty) {
      return Future<String?>.value(null);
    }

    final pending = _exchangeAndStore(refreshToken);
    _inFlight = pending;
    return pending.whenComplete(() {
      if (identical(_inFlight, pending)) _inFlight = null;
    });
  }

  /// Revokes the current Forge access token and latest refresh token using
  /// the public OAuth client contract. A refresh already in progress is
  /// allowed to finish first so both requests use the newest credentials.
  ///
  /// Revocation attempts are ordered and independent: failure to revoke the
  /// access token does not prevent the refresh-token attempt. This method
  /// never clears local credentials; its caller owns the sign-out flow.
  Future<void> revokeCurrentTokens() {
    final inFlightRevocation = _revocationInFlight;
    if (inFlightRevocation != null) return inFlightRevocation;

    _revocationStarted = true;
    final pending = _revokeCurrentTokens();
    _revocationInFlight = pending;
    return pending;
  }

  Future<void> _revokeCurrentTokens() async {
    final inFlight = _inFlight;
    if (inFlight != null) {
      try {
        await inFlight;
      } catch (_) {
        // A failed rotation clears its client slot. Still complete sign-out.
      }
    }

    final accessToken = Session.readForClient(clientId);
    final refreshToken = Session.readRefreshTokenForClient(clientId);
    if (accessToken != null && accessToken.isNotEmpty) {
      await _tryRevokeToken(accessToken, tokenTypeHint: 'access_token');
    }
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _tryRevokeToken(refreshToken, tokenTypeHint: 'refresh_token');
    }
  }

  Future<bool> _tryRevokeToken(
    String token, {
    required String tokenTypeHint,
  }) async {
    try {
      return await _sendRevocationRequest(
        token,
        tokenTypeHint: tokenTypeHint,
      ).timeout(revocationTimeout, onTimeout: () => false);
    } catch (_) {
      // Each token attempt is isolated so a failure cannot skip the next one.
      return false;
    }
  }

  Future<bool> _sendRevocationRequest(
    String token, {
    required String tokenTypeHint,
  }) async {
    try {
      final request = http.Request('POST', _revocationEndpoint)
        ..followRedirects = false
        ..headers.addAll(const {
          'Accept': 'application/json',
          'Cache-Control': 'no-store',
          'Content-Type': 'application/x-www-form-urlencoded',
        })
        ..bodyFields = {
          'token': token,
          'token_type_hint': tokenTypeHint,
          'client_id': clientId,
        };
      // The caller wraps this entire send-and-read operation in one total
      // revocation deadline, rather than giving each stage its own timeout.
      final streamed = await _http.send(request);
      final response = await _readBounded(streamed);
      return response.statusCode == 200;
    } on Exception {
      // A failed or timed-out request must not block the other token attempt.
      return false;
    }
  }

  Future<String?> _exchangeAndStore(String refreshToken) async {
    final request = http.Request('POST', _tokenEndpoint)
      ..followRedirects = false
      ..headers.addAll(const {
        'Accept': 'application/json',
        'Cache-Control': 'no-store',
        'Content-Type': 'application/x-www-form-urlencoded',
      })
      ..bodyFields = {
        'grant_type': 'refresh_token',
        'client_id': clientId,
        'refresh_token': refreshToken,
      };

    try {
      final streamed = await _http.send(request).timeout(timeout);
      final response = await _readBounded(streamed).timeout(timeout);
      if (response.statusCode != 200) {
        await _credentialStore.clear();
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        await _credentialStore.clear();
        return null;
      }
      final tokenReply = Map<String, dynamic>.from(decoded);
      final accessToken = tokenReply['access_token'];
      final rotatedRefreshToken = tokenReply['refresh_token'];
      final tokenType = tokenReply['token_type'];
      if (accessToken is! String ||
          accessToken.isEmpty ||
          accessToken != accessToken.trim() ||
          accessToken.contains(RegExp(r'[\r\n]')) ||
          rotatedRefreshToken is! String ||
          rotatedRefreshToken.isEmpty ||
          tokenType is! String ||
          tokenType.toLowerCase() != 'bearer') {
        await _credentialStore.clear();
        return null;
      }
      final stored = await _credentialStore.store(
        accessToken: accessToken,
        sessionId: Session.readSessionIdForClient(clientId),
        refreshToken: rotatedRefreshToken,
      );
      return stored ? accessToken : null;
    } on TimeoutException {
      // The rotating refresh token may already have been consumed. Fail
      // closed instead of replaying it and triggering family-reuse handling.
      await _credentialStore.clear();
      return null;
    } on FormatException {
      await _credentialStore.clear();
      return null;
    } on Exception {
      // Delivery may have succeeded even when the response was lost; never
      // retry the same single-use refresh credential.
      await _credentialStore.clear();
      return null;
    }
  }

  Future<http.Response> _readBounded(http.StreamedResponse streamed) async {
    final reader = StreamIterator<List<int>>(streamed.stream);
    if ((streamed.contentLength ?? 0) > _maxResponseBytes) {
      await reader.cancel();
      throw const FormatException('Refresh response exceeded its size limit.');
    }
    final bytes = <int>[];
    try {
      while (await reader.moveNext()) {
        final chunk = reader.current;
        if (bytes.length + chunk.length > _maxResponseBytes) {
          throw const FormatException(
            'Refresh response exceeded its size limit.',
          );
        }
        bytes.addAll(chunk);
      }
    } finally {
      await reader.cancel();
    }
    return http.Response(
      utf8.decode(bytes, allowMalformed: false),
      streamed.statusCode,
      headers: streamed.headers,
      request: streamed.request,
      reasonPhrase: streamed.reasonPhrase,
    );
  }

  static Uri _resolveEndpoint(String baseUrl, String path) {
    final origin = Uri.tryParse(baseUrl.trim());
    if (origin == null ||
        !origin.hasAuthority ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        origin.hasQuery ||
        origin.hasFragment ||
        !(origin.path.isEmpty || origin.path == '/') ||
        (origin.scheme != 'https' &&
            !(origin.scheme == 'http' &&
                (origin.host == 'localhost' ||
                    origin.host == '127.0.0.1' ||
                    origin.host == '::1')))) {
      throw ArgumentError.value(baseUrl, 'baseUrl', 'Expected a safe origin.');
    }
    return Uri(
      scheme: origin.scheme,
      host: origin.host,
      port: origin.hasPort ? origin.port : null,
      path: path,
    );
  }

  void close() => _http.close();
}

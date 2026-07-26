import 'dart:async';
import 'dart:convert';

/// Service for silent token refresh.
///
/// Monitors the access token's expiration time and automatically
/// refreshes it via the Snaplink API before it expires.
/// Users stay logged in without interruption during long sessions.
class TokenRefreshService {
  static final TokenRefreshService _instance = TokenRefreshService._();
  factory TokenRefreshService() => _instance;
  TokenRefreshService._();

  Timer? _refreshTimer;
  String? _currentToken;
  String? Function()? _getToken;
  Future<String?> Function()? _refreshToken;

  /// Initialize the refresh service.
  ///
  /// [getToken]: callback to get the current access token
  /// [refreshToken]: async callback that performs the refresh and returns new token
  void init({
    required String? Function() getToken,
    required Future<String?> Function() refreshToken,
  }) {
    _getToken = getToken;
    _refreshToken = refreshToken;
    _scheduleRefresh();
  }

  /// Called when a new token is obtained (after login).
  void onTokenUpdated(String token) {
    _currentToken = token;
    _scheduleRefresh();
  }

  /// Schedule a refresh 5 minutes before the token expires.
  void _scheduleRefresh() {
    _refreshTimer?.cancel();

    final token = _getToken?.call() ?? _currentToken;
    if (token == null || token.isEmpty) return;

    final exp = _parseExpiry(token);
    if (exp == null) return;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final ttl = exp - now;
    if (ttl <= 0) return; // Already expired

    // Refresh 5 minutes before expiry, or at 80% of TTL (whichever is sooner)
    final refreshIn = (ttl * 0.8).toInt().clamp(60, ttl - 60);
    final refreshDelay = Duration(seconds: refreshIn);

    _refreshTimer = Timer(refreshDelay, _performRefresh);
  }

  /// Perform the actual token refresh.
  Future<void> _performRefresh() async {
    try {
      final newToken = await _refreshToken?.call();
      if (newToken != null && newToken.isNotEmpty) {
        _currentToken = newToken;
        _scheduleRefresh(); // Schedule next refresh
      }
    } catch (_) {
      // Refresh failed - will retry on next API call via onUnauthorized
    }
  }

  /// Parse the expiry timestamp from a JWT token.
  int? _parseExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      // Add padding for base64 decoding
      var payload = parts[1];
      switch (payload.length % 4) {
        case 1: return null; // Invalid padding
        case 2: payload += '==';
        case 3: payload += '=';
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      final data = jsonDecode(decoded) as Map<String, dynamic>;
      return data['exp'] as int?;
    } catch (_) {
      return null;
    }
  }

  /// Clean up the refresh timer.
  void dispose() {
    _refreshTimer?.cancel();
  }
}

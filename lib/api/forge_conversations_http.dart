part of 'forge_conversations_api.dart';

extension _ForgeConversationsHttp on ForgeConversationsApi {
  /// The preview route is a deterministic P3a comparison over the exact
  /// caller declaration. Keep a server response from silently changing the
  /// eligibility or exclusion projection before it reaches a shared client.
  /// The route still has no inventory, reservation, or execution authority.
  bool _samePlacementPreview(
    ForgeDevicePlacementResult actual,
    ForgeDevicePlacementResult expected,
  ) => jsonEncode(actual.toJson()) == jsonEncode(expected.toJson());

  Future<ForgeJson> _requestJson(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    String? idempotencyKey,
    Set<int> expectedStatuses = const {200},
    bool retryUnauthorized = true,
  }) async {
    final uri = _origin.resolve('/api/v1$path').replace(queryParameters: query);
    final initialAccessToken = _currentAccessToken();
    if (!_isSafeBearerToken(initialAccessToken)) {
      throw const ForgeConversationsApiException(
        statusCode: 401,
        code: 'missing_access_token',
        message: 'The Forge session has expired. Sign in again.',
      );
    }
    var response = await _sendWithReadRetry(
      method,
      uri,
      body: body,
      idempotencyKey: idempotencyKey,
      bearerToken: initialAccessToken,
    );
    if (response.statusCode == 401 &&
        refreshAccessToken != null &&
        retryUnauthorized) {
      String? rotatedAccessToken;
      try {
        rotatedAccessToken = await refreshAccessToken!(initialAccessToken);
      } on Exception {
        _rejectedAccessTokens.add(initialAccessToken);
        throw const ForgeConversationsApiException(
          statusCode: 503,
          code: 'token_refresh_failed',
          message: 'Snaplink could not refresh the Forge session.',
        );
      }
      if (rotatedAccessToken != null &&
          _isSafeBearerToken(rotatedAccessToken) &&
          rotatedAccessToken != initialAccessToken) {
        response = await _sendWithReadRetry(
          method,
          uri,
          body: body,
          idempotencyKey: idempotencyKey,
          bearerToken: rotatedAccessToken,
        );
        if (response.statusCode == 401) {
          _rejectedAccessTokens
            ..add(initialAccessToken)
            ..add(rotatedAccessToken);
        }
      } else {
        _rejectedAccessTokens.add(initialAccessToken);
      }
    }
    if (response.statusCode >= 300 && response.statusCode < 400) {
      throw const ForgeConversationsApiException(
        statusCode: 502,
        code: 'redirect_rejected',
        message: 'Forge redirected the request; the response was rejected.',
      );
    }
    final root = _decodeRootResponse(response);
    if (response.statusCode >= 400) {
      throw _decodeError(response.statusCode, root);
    }
    if (!expectedStatuses.contains(response.statusCode)) {
      throw const ForgeConversationsApiException(
        statusCode: 502,
        code: 'unexpected_status',
        message: 'Forge returned an unexpected response.',
      );
    }
    return root;
  }

  String _currentAccessToken() {
    final current = accessTokenProvider?.call();
    final token = accessTokenProvider == null || current == null
        ? accessToken
        : current;
    return _rejectedAccessTokens.contains(token) ? '' : token;
  }

  ForgeJson _decodeRoot(String body) {
    _rejectDuplicateForgeJsonKeys(body);
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Invalid Forge API response.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  ForgeConversationsApiException _decodeError(int status, ForgeJson root) {
    final code = root['code'];
    final message = root['message'];
    return ForgeConversationsApiException(
      statusCode: status,
      code: code is String && code.isNotEmpty ? code : 'http_error',
      message: message is String && message.isNotEmpty
          ? message
          : 'Forge rejected the request (HTTP $status).',
    );
  }
}

Uri _parseForgeApiOrigin(String value) {
  final uri = Uri.tryParse(value.trim());
  final host = uri?.host.toLowerCase() ?? '';
  final parts = host.split('.');
  final loopback =
      host == 'localhost' ||
      host == '::1' ||
      (parts.length == 4 &&
          parts.first == '127' &&
          parts.every((part) {
            final octet = int.tryParse(part);
            return octet != null && octet >= 0 && octet <= 255;
          }));
  if (uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      (uri.scheme != 'https' && !(uri.scheme == 'http' && loopback)) ||
      !(uri.path.isEmpty || uri.path == '/') ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw ArgumentError.value(
      value,
      'baseUrl',
      'Expected a safe HTTPS origin.',
    );
  }
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
  );
}

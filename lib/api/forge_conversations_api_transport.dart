part of 'forge_conversations_api.dart';

const _forgeMaxResponseBytes = 1024 * 1024;
const _forgeMaxReadAttempts = 3;
const _forgeReadRetryBackoff = [50, 100];
const _forgeResponseBodyErrorHeader = 'x-forge-response-body-error';

extension ForgeConversationsApiTransport on ForgeConversationsApi {
  Future<T> _withRequestTimeout<T>(Future<T> Function() operation) {
    if (useWallClockTimeout) {
      return Zone.root.run(() => operation().timeout(timeout));
    }
    return operation().timeout(timeout);
  }

  /// Replays only idempotent GET reads after a transient response or
  /// transport failure. POST writes deliberately take the single request
  /// path so an uncertain result cannot create a second operation.
  Future<http.Response> _sendWithReadRetry(
    String method,
    Uri uri, {
    required String bearerToken,
    Map<String, dynamic>? body,
    String? idempotencyKey,
    String accept = 'application/json',
  }) async {
    final retryableRead = method == 'GET';
    for (var attempt = 0; ; attempt++) {
      try {
        final response = await _sendRequest(
          method,
          uri,
          body: body,
          idempotencyKey: idempotencyKey,
          bearerToken: bearerToken,
          accept: accept,
        );
        if (!retryableRead ||
            attempt + 1 >= _forgeMaxReadAttempts ||
            !_isTransientReadStatus(response.statusCode)) {
          return response;
        }
      } on ForgeConversationsApiException catch (error) {
        if (!retryableRead ||
            attempt + 1 >= _forgeMaxReadAttempts ||
            error.statusCode != 0) {
          rethrow;
        }
      }
      await Future<void>.delayed(
        Duration(milliseconds: _forgeReadRetryBackoff[attempt]),
      );
    }
  }

  static bool _isTransientReadStatus(int statusCode) =>
      statusCode == 408 ||
      statusCode == 425 ||
      statusCode == 429 ||
      (statusCode >= 500 && statusCode <= 599);

  Future<http.Response> _sendRequest(
    String method,
    Uri uri, {
    required String bearerToken,
    Map<String, dynamic>? body,
    String? idempotencyKey,
    String accept = 'application/json',
  }) async {
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..headers.addAll({
        'Accept': accept,
        'Authorization': 'Bearer $bearerToken',
        'Cache-Control': 'no-store',
        if (body != null) 'Content-Type': 'application/json',
        'Idempotency-Key': ?idempotencyKey,
      });
    if (body != null) request.body = jsonEncode(body);
    try {
      final streamed = await _withRequestTimeout(() => _http.send(request));
      return await _withRequestTimeout(() => _readBounded(streamed));
    } on TimeoutException {
      throw const ForgeConversationsApiException(
        statusCode: 0,
        code: 'request_timeout',
        message: 'Forge did not respond in time.',
      );
    } on ForgeConversationsApiException {
      rethrow;
    } on Exception {
      throw const ForgeConversationsApiException(
        statusCode: 0,
        code: 'network_error',
        message: 'Could not reach Forge.',
      );
    }
  }

  Future<http.Response> _readBounded(http.StreamedResponse streamed) async {
    final reader = StreamIterator<List<int>>(streamed.stream);
    if ((streamed.contentLength ?? 0) > _forgeMaxResponseBytes) {
      await _cancelIterator(reader);
      return _responseWithBodyError(streamed, 'response_too_large');
    }

    final bytes = <int>[];
    String? bodyError;
    try {
      while (await reader.moveNext()) {
        final chunk = reader.current;
        if (bytes.length + chunk.length > _forgeMaxResponseBytes) {
          bodyError = 'response_too_large';
          break;
        }
        bytes.addAll(chunk);
      }
    } catch (_) {
      bodyError = 'response_read_failed';
    } finally {
      await _cancelIterator(reader);
    }
    return _responseWithBodyError(streamed, bodyError, bytes: bytes);
  }

  Future<void> _cancelIterator(StreamIterator<List<int>> reader) async {
    try {
      await reader.cancel();
    } catch (_) {
      // Preserve the received response status when closing a broken stream.
    }
  }

  http.Response _responseWithBodyError(
    http.StreamedResponse streamed,
    String? bodyError, {
    List<int> bytes = const <int>[],
  }) {
    final headers = Map<String, String>.from(streamed.headers);
    if (bodyError != null) headers[_forgeResponseBodyErrorHeader] = bodyError;
    return http.Response.bytes(
      bytes,
      streamed.statusCode,
      headers: headers,
      request: streamed.request,
      reasonPhrase: streamed.reasonPhrase,
    );
  }

  ForgeJson _decodeRootResponse(http.Response response) {
    final bodyError = response.headers[_forgeResponseBodyErrorHeader];
    if (bodyError != null) {
      throw _responseBodyException(response, bodyError);
    }
    try {
      return _decodeRoot(response.body);
    } on FormatException {
      throw ForgeConversationsApiException(
        statusCode: response.statusCode,
        code: 'invalid_response',
        message: 'Forge returned an invalid response.',
      );
    }
  }

  ForgeConversationsApiException _responseBodyException(
    http.Response response,
    String code,
  ) {
    final message = switch (code) {
      'response_too_large' => 'Forge response exceeded the size limit.',
      'response_read_failed' => 'Forge returned an unreadable response.',
      _ => 'Forge returned an invalid response.',
    };
    return ForgeConversationsApiException(
      statusCode: response.statusCode,
      code: code,
      message: message,
    );
  }
}

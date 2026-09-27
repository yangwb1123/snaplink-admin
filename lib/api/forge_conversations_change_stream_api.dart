part of 'forge_conversations_api.dart';

const _forgeConversationChangesStreamPath = '/conversation-changes/stream';
const _forgeConversationChangesStreamDefaultWaitMS = 15000;
const _forgeConversationChangesStreamMaxWaitMS = 30000;

/// Reads one owner-scoped Conversation change page through the optional
/// authenticated SSE/long-poll transport.
///
/// The existing [conversationChanges] polling method remains the default for
/// the Sessions UI. This method is an explicit opt-in read: a `204` response
/// returns `null` after the bounded wait, while a `200` response must contain
/// exactly one `conversation_changes` SSE event. The event id is bound to the
/// page's `scanned_through_cursor` before the page is returned.
extension ForgeConversationsApiConversationChangesStream
    on ForgeConversationsApi {
  Future<ForgeConversationChangePage?> conversationChangesStream({
    required int afterCursor,
    int limit = 100,
    int waitMS = _forgeConversationChangesStreamDefaultWaitMS,
  }) async {
    if (afterCursor < 0 || afterCursor > 9007199254740991) {
      throw ArgumentError.value(afterCursor, 'afterCursor');
    }
    if (waitMS < 0 || waitMS > _forgeConversationChangesStreamMaxWaitMS) {
      throw ArgumentError.value(waitMS, 'waitMS');
    }
    final boundedLimit = ForgeConversationsApi._boundedLimit(limit);
    final uri = _origin
        .resolve('/api/v1$_forgeConversationChangesStreamPath')
        .replace(
          queryParameters: {
            'after_cursor': afterCursor.toString(),
            'limit': boundedLimit.toString(),
            'wait_ms': waitMS.toString(),
          },
        );
    final response = await _requestConversationChangesStreamResponse(uri);
    if (response.statusCode == 204) {
      if (response.bodyBytes.isNotEmpty) {
        throw const FormatException(
          'Forge returned a non-empty 204 conversation change stream.',
        );
      }
      return null;
    }
    if (response.statusCode != 200) {
      throw const ForgeConversationsApiException(
        statusCode: 502,
        code: 'unexpected_status',
        message: 'Forge returned an unexpected response.',
      );
    }
    final contentType = _responseContentType(response);
    if (contentType != 'text/event-stream') {
      throw const FormatException(
        'Forge returned a conversation change stream with the wrong content type.',
      );
    }
    final body = utf8.decode(response.bodyBytes, allowMalformed: false);
    return _parseConversationChangesStreamEvent(
      body,
      requestedAfterCursor: afterCursor,
      limit: boundedLimit,
    );
  }

  Future<http.Response> _requestConversationChangesStreamResponse(
    Uri uri,
  ) async {
    final initialAccessToken = _currentAccessToken();
    if (!_isSafeBearerToken(initialAccessToken)) {
      throw const ForgeConversationsApiException(
        statusCode: 401,
        code: 'missing_access_token',
        message: 'The Forge session has expired. Sign in again.',
      );
    }
    var response = await _sendWithReadRetry(
      'GET',
      uri,
      bearerToken: initialAccessToken,
      accept: 'text/event-stream',
    );
    if (response.statusCode == 401 && refreshAccessToken != null) {
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
          'GET',
          uri,
          bearerToken: rotatedAccessToken,
          accept: 'text/event-stream',
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
    if (response.statusCode >= 400) {
      final root = _decodeRootResponse(response);
      throw _decodeError(response.statusCode, root);
    }
    final bodyError = response.headers[_forgeResponseBodyErrorHeader];
    if (bodyError != null) {
      throw _responseBodyException(response, bodyError);
    }
    return response;
  }

  ForgeConversationChangePage _parseConversationChangesStreamEvent(
    String body, {
    required int requestedAfterCursor,
    required int limit,
  }) {
    // The Core stream currently emits one frame terminated by one empty line.
    // Keep the parser deliberately narrower than a generic EventSource parser:
    // comments, extra frames, unknown fields, and duplicate fields are all
    // rejected before any page is exposed to the caller.
    final normalized = body.replaceAll('\r\n', '\n');
    if (normalized.contains('\r') || !normalized.endsWith('\n\n')) {
      throw const FormatException('Malformed Forge conversation change SSE.');
    }
    final frame = normalized.substring(0, normalized.length - 2);
    final lines = frame.split('\n');
    if (lines.isEmpty || lines.any((line) => line.isEmpty)) {
      throw const FormatException('Malformed Forge conversation change SSE.');
    }

    String? event;
    String? id;
    String? data;
    final fields = <String>{};
    for (final line in lines) {
      final separator = line.indexOf(':');
      if (separator <= 0) {
        throw const FormatException('Malformed Forge conversation change SSE.');
      }
      final field = line.substring(0, separator);
      var value = line.substring(separator + 1);
      if (value.startsWith(' ')) value = value.substring(1);
      if (!const {'event', 'id', 'data'}.contains(field) ||
          !fields.add(field)) {
        throw const FormatException('Malformed Forge conversation change SSE.');
      }
      switch (field) {
        case 'event':
          event = value;
        case 'id':
          id = value;
        case 'data':
          data = value;
      }
    }
    if (event != 'conversation_changes' || id == null || data == null) {
      throw const FormatException(
        'Unknown or incomplete Forge conversation change SSE event.',
      );
    }
    if (!RegExp(r'^\d+$').hasMatch(id)) {
      throw const FormatException('Invalid Forge conversation change SSE id.');
    }
    final scannedCursor = int.tryParse(id);
    if (scannedCursor == null ||
        scannedCursor > 9007199254740991 ||
        scannedCursor.toString() != id) {
      throw const FormatException('Invalid Forge conversation change SSE id.');
    }
    final root = _decodeRoot(data);
    final page = ForgeConversationChangePage.fromJson(
      root,
      requestedAfterCursor: requestedAfterCursor,
      limit: limit,
    );
    if (page.scannedThroughCursor != scannedCursor) {
      throw const FormatException(
        'Forge conversation change SSE cursor does not match its page.',
      );
    }
    return page;
  }

  String? _responseContentType(http.Response response) {
    for (final entry in response.headers.entries) {
      if (entry.key.toLowerCase() == 'content-type') {
        return entry.value.split(';').first.trim().toLowerCase();
      }
    }
    return null;
  }
}

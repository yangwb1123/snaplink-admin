import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'forge_conversations_models.dart';

class ForgeConversationsApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  const ForgeConversationsApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => message;
}

/// Authenticated, bounded transport for Forge's owner-scoped conversation API.
/// It does not persist tokens. A configured OAuth refresh callback can retry
/// one request after a 401; write retries preserve the original idempotency
/// key so the authorization retry cannot create a second operation.
class ForgeConversationsApi {
  static const int _maxResponseBytes = 1024 * 1024;
  static const int maxPageSize = 128;
  static const int maxRunPageSize = 25;
  static const int maxRunTimelinePageSize = 128;

  final Uri _origin;
  final String accessToken;
  final String? Function()? accessTokenProvider;
  final Future<String?> Function(String failedAccessToken)? refreshAccessToken;
  final http.Client _http;
  final Duration timeout;
  final Set<String> _rejectedAccessTokens = <String>{};

  ForgeConversationsApi({
    required String baseUrl,
    required this.accessToken,
    this.accessTokenProvider,
    this.refreshAccessToken,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 20),
  }) : _origin = _parseOrigin(baseUrl),
       _http = httpClient ?? http.Client() {
    if (accessToken.trim().isEmpty || accessToken.contains(RegExp(r'[\r\n]'))) {
      throw ArgumentError.value(accessToken, 'accessToken');
    }
  }

  Future<ForgeConversationPage> listConversations({
    String? afterID,
    int limit = 50,
  }) async {
    final boundedLimit = _boundedLimit(limit);
    if (afterID != null &&
        afterID.isNotEmpty &&
        !_validConversationRequestID(afterID)) {
      throw ArgumentError.value(afterID, 'afterID');
    }
    final query = <String, String>{'limit': boundedLimit.toString()};
    if (afterID != null && afterID.isNotEmpty) query['after_id'] = afterID;
    final root = await _requestJson('GET', '/conversations', query: query);
    return ForgeConversationPage.fromJson(
      root,
      limit: boundedLimit,
      afterID: afterID == null || afterID.isEmpty ? null : afterID,
    );
  }

  Future<ForgeConversationChangePage> conversationChanges({
    required int afterCursor,
    int limit = 100,
  }) async {
    if (afterCursor < 0 || afterCursor > 9007199254740991) {
      throw ArgumentError.value(afterCursor, 'afterCursor');
    }
    final boundedLimit = _boundedLimit(limit);
    final root = await _requestJson(
      'GET',
      '/conversation-changes',
      query: {
        'after_cursor': afterCursor.toString(),
        'limit': boundedLimit.toString(),
      },
    );
    return ForgeConversationChangePage.fromJson(
      root,
      requestedAfterCursor: afterCursor,
      limit: boundedLimit,
    );
  }

  Future<ForgeConversation> createConversation({
    required ForgeConversationScope scope,
    required String title,
    required String idempotencyKey,
  }) async {
    final root = await _requestJson(
      'POST',
      '/conversations',
      body: {'scope': scope.toJson(), 'title': title},
      idempotencyKey: idempotencyKey,
      expectedStatuses: const {201},
    );
    return ForgeConversation.fromJson(root);
  }

  Future<ForgeConversationPromptPage> listPrompts({
    required String conversationID,
    ForgePromptCursor? before,
    int limit = 100,
  }) async {
    final boundedLimit = _boundedLimit(limit);
    final query = <String, String>{'limit': boundedLimit.toString()};
    if (before != null) {
      query['before_created_at_ms'] = before.createdAtMS.toString();
      query['before_prompt_id'] = before.promptID;
    }
    final path =
        '/conversations/${Uri.encodeComponent(conversationID)}/prompts';
    final root = await _requestJson('GET', path, query: query);
    final page = ForgeConversationPromptPage.fromJson(
      root,
      limit: boundedLimit,
    );
    if (page.conversationID != conversationID ||
        page.prompts.any((prompt) => prompt.conversationID != conversationID)) {
      throw const FormatException(
        'Forge returned prompts for another session.',
      );
    }
    return page;
  }

  Future<ForgeConversationRunPage> listRuns({
    required String conversationID,
    ForgeRunCursor? before,
    int limit = maxRunPageSize,
  }) async {
    final boundedLimit = limit.clamp(1, maxRunPageSize).toInt();
    if (!_validRunRequestID(conversationID) ||
        (before != null &&
            (before.createdAtMS < 0 ||
                before.createdAtMS > 9007199254740991 ||
                !_validRunRequestID(before.runID)))) {
      throw ArgumentError.value(before, 'before');
    }
    final query = <String, String>{'limit': boundedLimit.toString()};
    if (before != null) {
      query['before_created_at_ms'] = before.createdAtMS.toString();
      query['before_run_id'] = before.runID;
    }
    final path = '/conversations/${Uri.encodeComponent(conversationID)}/runs';
    final root = await _requestJson('GET', path, query: query);
    return ForgeConversationRunPage.fromJson(
      root,
      requestedConversationID: conversationID,
      before: before,
      limit: boundedLimit,
    );
  }

  Future<ForgeRunTimelinePage> listRunTimeline({
    required String conversationID,
    required String runID,
    int afterSequence = 0,
    int limit = maxRunTimelinePageSize,
  }) async {
    final boundedLimit = limit.clamp(1, maxRunTimelinePageSize).toInt();
    if (!_validRunRequestID(conversationID) || !_validRunRequestID(runID)) {
      throw ArgumentError.value('$conversationID/$runID', 'run IDs');
    }
    if (afterSequence < 0 || afterSequence > 9007199254740991) {
      throw ArgumentError.value(afterSequence, 'afterSequence');
    }
    final path =
        '/conversations/${Uri.encodeComponent(conversationID)}/runs/'
        '${Uri.encodeComponent(runID)}/timeline';
    final root = await _requestJson(
      'GET',
      path,
      query: {
        'after_sequence': afterSequence.toString(),
        'limit': boundedLimit.toString(),
      },
    );
    return ForgeRunTimelinePage.fromJson(
      root,
      requestedConversationID: conversationID,
      requestedRunID: runID,
      requestedAfterSequence: afterSequence,
      limit: boundedLimit,
    );
  }

  Future<ForgePromptAppendResult> appendPrompt({
    required String conversationID,
    required String content,
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    final path =
        '/conversations/${Uri.encodeComponent(conversationID)}/prompts';
    final root = await _requestJson(
      'POST',
      path,
      body: {'content': content, 'expected_version': expectedVersion},
      idempotencyKey: idempotencyKey,
      expectedStatuses: const {200, 201},
    );
    final result = ForgePromptAppendResult.fromJson(root);
    if (result.prompt.conversationID != conversationID ||
        result.prompt.content != content ||
        result.prompt.role != 'user') {
      throw const FormatException('Forge returned an invalid prompt result.');
    }
    return result;
  }

  Future<ForgeJson> _requestJson(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    String? idempotencyKey,
    Set<int> expectedStatuses = const {200},
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
    var response = await _sendRequest(
      method,
      uri,
      body: body,
      idempotencyKey: idempotencyKey,
      bearerToken: initialAccessToken,
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
        response = await _sendRequest(
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
    final root = _decodeRoot(response.body);
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

  Future<http.Response> _sendRequest(
    String method,
    Uri uri, {
    required String bearerToken,
    Map<String, dynamic>? body,
    String? idempotencyKey,
  }) async {
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $bearerToken',
        'Cache-Control': 'no-store',
        if (body != null) 'Content-Type': 'application/json',
        'Idempotency-Key': ?idempotencyKey,
      });
    if (body != null) request.body = jsonEncode(body);
    try {
      final streamed = await _http.send(request).timeout(timeout);
      return await _readBounded(streamed).timeout(timeout);
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

  String _currentAccessToken() {
    final current = accessTokenProvider?.call();
    final token = accessTokenProvider == null || current == null
        ? accessToken
        : current;
    return _rejectedAccessTokens.contains(token) ? '' : token;
  }

  Future<http.Response> _readBounded(http.StreamedResponse streamed) async {
    final reader = StreamIterator<List<int>>(streamed.stream);
    if ((streamed.contentLength ?? 0) > _maxResponseBytes) {
      await reader.cancel();
      throw const ForgeConversationsApiException(
        statusCode: 502,
        code: 'response_too_large',
        message: 'Forge response exceeded the size limit.',
      );
    }
    final bytes = <int>[];
    try {
      while (await reader.moveNext()) {
        final chunk = reader.current;
        if (bytes.length + chunk.length > _maxResponseBytes) {
          throw const ForgeConversationsApiException(
            statusCode: 502,
            code: 'response_too_large',
            message: 'Forge response exceeded the size limit.',
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

  ForgeJson _decodeRoot(String body) {
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

  static int _boundedLimit(int value) => value.clamp(1, maxPageSize);

  static Uri _parseOrigin(String value) {
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

  void close() => _http.close();
}

bool _validRunRequestID(String value) =>
    value.trim().isNotEmpty &&
    utf8.encode(value).length <= 128 &&
    !value.runes.any((rune) => rune < 0x20 || (rune >= 0x7f && rune <= 0x9f));

bool _validConversationRequestID(String value) =>
    _validRunRequestID(value) && !value.contains('/');

bool _isSafeBearerToken(String value) =>
    value.isNotEmpty &&
    value == value.trim() &&
    !value.contains(RegExp(r'[\r\n]'));

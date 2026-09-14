part of 'agent_hub_api.dart';

// Agent Hub envelopes, typed list pages, and bounded public error messages.
Map<String, dynamic> _decodeRoot(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    throw const FormatException('Invalid Agent Hub response envelope.');
  }
  return Map<String, dynamic>.from(decoded);
}

dynamic _readData(dynamic root) {
  if (root is! Map || !root.containsKey('data')) {
    throw const FormatException('Missing Agent Hub response data.');
  }
  return root['data'];
}

AgentJson _asObject(dynamic value) {
  if (value is! Map) {
    throw const FormatException('Invalid Agent Hub object response.');
  }
  return Map<String, dynamic>.from(value);
}

AgentListPage<T> _parsePage<T>(
  Map<String, dynamic> root,
  T Function(AgentJson json) parse,
) {
  final value = _readData(root);
  if (value is! List) {
    throw const FormatException('Invalid Agent Hub list response.');
  }
  if (value.any((item) => item is! Map)) {
    throw const FormatException('Invalid Agent Hub list response.');
  }
  final items = value
      .map((item) => parse(Map<String, dynamic>.from(item as Map)))
      .toList(growable: false);
  final rawCursor = root['next_cursor'];
  if (rawCursor != null && rawCursor is! String) {
    throw const FormatException('Invalid Agent Hub list cursor.');
  }
  final nextCursor = (rawCursor as String?)?.trim();
  return AgentListPage(
    items: items,
    nextCursor: nextCursor == null || nextCursor.isEmpty ? null : nextCursor,
  );
}

AgentHubApiException _decodeError(int status, String body) {
  try {
    final root = _decodeRoot(body);
    final error = root['error'];
    if (error is Map) {
      final object = Map<String, dynamic>.from(error);
      return AgentHubApiException(
        statusCode: status,
        code: object['code']?.toString() ?? 'http_$status',
        message: _boundedMessage(object['message']?.toString(), status),
      );
    }
  } on FormatException {
    // A proxy or gateway may return a non-JSON error. Keep it bounded and
    // avoid rendering raw response data that might contain credentials.
  }
  return AgentHubApiException(
    statusCode: status,
    code: 'http_$status',
    message: 'Agent Hub request failed ($status).',
  );
}

String _boundedMessage(String? message, int status) {
  final safe = message?.trim() ?? '';
  if (safe.isEmpty) return 'Agent Hub request failed ($status).';
  return safe.length <= 500 ? safe : '${safe.substring(0, 500)}…';
}

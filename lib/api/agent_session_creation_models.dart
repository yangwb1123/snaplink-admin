import 'dart:convert';

/// Hub identifiers use a Unicode-character bound and reject only C0/DEL
/// controls. C1 characters remain valid identifier data and are therefore
/// intentionally different from the stricter session-name validation below.
String validateAgentSessionId(String value) {
  if (value.isEmpty ||
      value != value.trim() ||
      value.runes.length > 256 ||
      utf8.decode(utf8.encode(value)) != value ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
    throw const FormatException('Invalid Agent session identifier.');
  }
  return value;
}

/// Names are the only user-controlled option; runtime and workspace stay fixed.
String validateAgentSessionName(String value) {
  final name = value.trim();
  if (name.isEmpty ||
      utf8.encode(name).length > 256 ||
      utf8.decode(utf8.encode(name)) != name ||
      RegExp(r'[\p{Cc}\p{Cf}]', unicode: true).hasMatch(value)) {
    throw const FormatException(
      'Enter a session name of at most 256 UTF-8 bytes without control characters.',
    );
  }
  return name;
}

class AgentSessionCreationRequest {
  final String requestId;
  final String instanceId;
  final String name;
  final String status;
  final String sessionId;
  final String errorCode;

  const AgentSessionCreationRequest({
    required this.requestId,
    required this.instanceId,
    required this.name,
    required this.status,
    required this.sessionId,
    required this.errorCode,
  });

  bool get isTerminal => status != 'queued';

  factory AgentSessionCreationRequest.fromJson(Map<String, dynamic> value) {
    const fields = {
      'request_id',
      'instance_id',
      'name',
      'status',
      'session_id',
      'error_code',
      'created_at',
      'updated_at',
    };
    if (value.length != fields.length || !fields.containsAll(value.keys)) {
      throw const FormatException('Invalid session creation response.');
    }
    final requestId = validateAgentSessionId(_text(value, 'request_id'));
    final instanceId = validateAgentSessionId(_text(value, 'instance_id'));
    final name = _text(value, 'name');
    final status = _text(value, 'status');
    final rawSessionId = _text(value, 'session_id', empty: true);
    final sessionId = rawSessionId.isEmpty
        ? ''
        : validateAgentSessionId(rawSessionId);
    final errorCode = _text(value, 'error_code', empty: true);
    if (!const {'queued', 'created', 'failed', 'lost'}.contains(status) ||
        (status == 'created') != sessionId.isNotEmpty ||
        (const {'queued', 'created'}.contains(status) &&
            errorCode.isNotEmpty) ||
        (const {'failed', 'lost'}.contains(status) && errorCode.isEmpty) ||
        name != validateAgentSessionName(name)) {
      throw const FormatException('Invalid session creation response.');
    }
    for (final key in ['created_at', 'updated_at']) {
      final timestamp = value[key];
      if (timestamp is! num || !timestamp.isFinite || timestamp < 0) {
        throw const FormatException('Invalid session creation timestamp.');
      }
    }
    return AgentSessionCreationRequest(
      requestId: requestId,
      instanceId: instanceId,
      name: name,
      status: status,
      sessionId: sessionId,
      errorCode: errorCode,
    );
  }

  static String _text(
    Map<String, dynamic> value,
    String key, {
    bool empty = false,
  }) {
    final text = value[key];
    if (text is! String ||
        (!empty && text.isEmpty) ||
        text.runes.length > 256 ||
        utf8.decode(utf8.encode(text)) != text ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(text)) {
      throw const FormatException('Invalid session creation response.');
    }
    return text;
  }
}

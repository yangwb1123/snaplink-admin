import 'agent_session_creation_models.dart';

String validateAgentCloseId(String value) {
  try {
    return validateAgentSessionId(value);
  } on FormatException {
    throw const FormatException('Invalid session close identifier.');
  }
}

class AgentSessionCloseRequest {
  final String requestId;
  final String instanceId;
  final String sessionId;
  final String status;
  final String errorCode;

  const AgentSessionCloseRequest({
    required this.requestId,
    required this.instanceId,
    required this.sessionId,
    required this.status,
    required this.errorCode,
  });

  bool get isTerminal => status != 'queued';

  factory AgentSessionCloseRequest.fromJson(Map<String, dynamic> value) {
    const fields = {
      'request_id',
      'instance_id',
      'session_id',
      'status',
      'error_code',
      'created_at',
      'updated_at',
    };
    if (value.length != fields.length || !fields.containsAll(value.keys)) {
      throw const FormatException('Invalid session close response.');
    }
    final ids = <String>[];
    for (final field in ['request_id', 'instance_id', 'session_id']) {
      final id = value[field];
      if (id is! String) {
        throw const FormatException('Invalid session close response.');
      }
      ids.add(validateAgentCloseId(id));
    }
    final status = value['status'];
    final error = value['error_code'];
    final valid = switch (status) {
      'queued' || 'closed' => error == '',
      'failed' => const {
        'session_close_failed',
        'session_unavailable',
      }.contains(error),
      'lost' => error == 'owner_replaced',
      _ => false,
    };
    if (!valid) throw const FormatException('Invalid session close outcome.');
    for (final field in ['created_at', 'updated_at']) {
      final timestamp = value[field];
      if (timestamp is! num || !timestamp.isFinite || timestamp < 0) {
        throw const FormatException('Invalid session close timestamp.');
      }
    }
    return AgentSessionCloseRequest(
      requestId: ids[0],
      instanceId: ids[1],
      sessionId: ids[2],
      status: status as String,
      errorCode: error as String,
    );
  }
}

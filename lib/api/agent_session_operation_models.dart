import 'agent_session_creation_models.dart';

String validateAgentOperationId(String value) {
  try {
    return validateAgentSessionId(value);
  } on FormatException {
    throw const FormatException('Invalid session operation identifier.');
  }
}

String validateAgentOperationCursor(String value) {
  if (value.length > 2048 ||
      (value.isNotEmpty && !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value))) {
    throw const FormatException('Invalid session operation cursor.');
  }
  return value;
}

/// A public request receipt. No retry keys or execution identity are retained.
class AgentSessionOperation {
  final String operation;
  final String requestId;
  final String instanceId;
  final String name;
  final String status;
  final String sessionId;
  final String errorCode;
  final num createdAt;
  final num updatedAt;

  const AgentSessionOperation({
    required this.operation,
    required this.requestId,
    required this.instanceId,
    required this.name,
    required this.status,
    required this.sessionId,
    required this.errorCode,
    required this.createdAt,
    required this.updatedAt,
  });

  String get identity => '$operation:$requestId';

  factory AgentSessionOperation.fromJson(Map<String, dynamic> value) {
    const fields = {
      'operation',
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
      throw const FormatException('Invalid session operation fields.');
    }
    final text = <String, String>{};
    for (final key in fields.difference({'created_at', 'updated_at'})) {
      final item = value[key];
      if (item is! String) {
        throw const FormatException('Invalid session operation text.');
      }
      text[key] = item;
    }
    for (final key in ['request_id', 'instance_id']) {
      validateAgentOperationId(text[key]!);
    }
    final operation = text['operation']!;
    final name = text['name']!;
    final sessionId = text['session_id']!;
    final status = text['status']!;
    final error = text['error_code']!;
    if (sessionId.isNotEmpty) validateAgentOperationId(sessionId);
    final validTarget = switch (operation) {
      'create' =>
        name == validateAgentSessionName(name) &&
            (status == 'created') == sessionId.isNotEmpty,
      'close' => name.isEmpty && sessionId.isNotEmpty,
      _ => false,
    };
    final validStatus = switch (status) {
      'queued' => error.isEmpty,
      'created' => operation == 'create' && error.isEmpty,
      'closed' => operation == 'close' && error.isEmpty,
      'failed' =>
        (operation == 'create'
                ? const {'session_creation_failed', 'session_capacity'}
                : const {'session_close_failed', 'session_unavailable'})
            .contains(error),
      'lost' => error == 'owner_replaced',
      _ => false,
    };
    if (!validTarget || !validStatus) {
      throw const FormatException('Invalid session operation outcome.');
    }
    for (final key in ['created_at', 'updated_at']) {
      final time = value[key];
      if (time is! num ||
          !time.isFinite ||
          !time.toDouble().isFinite ||
          time < 0) {
        throw const FormatException('Invalid session operation timestamp.');
      }
    }
    return AgentSessionOperation(
      operation: operation,
      requestId: text['request_id']!,
      instanceId: text['instance_id']!,
      name: name,
      status: status,
      sessionId: sessionId,
      errorCode: error,
      createdAt: value['created_at'] as num,
      updatedAt: value['updated_at'] as num,
    );
  }

  void checkRefresh(AgentSessionOperation updated) {
    if (updated.identity != identity ||
        updated.instanceId != instanceId ||
        updated.name != name ||
        updated.createdAt != createdAt ||
        (sessionId.isNotEmpty && updated.sessionId != sessionId)) {
      throw const FormatException('Session operation identity changed.');
    }
  }
}

class AgentSessionOperationPage {
  final List<AgentSessionOperation> items;
  final String nextCursor;
  const AgentSessionOperationPage(this.items, this.nextCursor);
}

typedef AgentJson = Map<String, dynamic>;

class AgentInstance {
  final String instanceId;
  final String name;
  final String projectId;
  final bool online;
  final int sessionCapacity;
  final bool sessionCloseSupported;

  const AgentInstance({
    required this.instanceId,
    required this.name,
    required this.projectId,
    required this.online,
    this.sessionCapacity = 0,
    this.sessionCloseSupported = false,
  });

  factory AgentInstance.fromJson(AgentJson json) => AgentInstance(
    instanceId: _requiredText(json, 'instance_id'),
    name: _optionalText(json, 'name'),
    projectId: _optionalText(json, 'project_id'),
    online: json['online'] == true,
    sessionCapacity: _capacity(json['session_capacity']),
    sessionCloseSupported: _closeSupported(json['session_close_supported']),
  );
}

bool _closeSupported(dynamic value) {
  if (value == null) return false;
  if (value is! bool) {
    throw const FormatException('Invalid Agent session close capability.');
  }
  return value;
}

int _capacity(dynamic value) {
  if (value == null) return 0;
  if (value is! int || value < 0 || value > 8) {
    throw const FormatException('Invalid Agent session capacity.');
  }
  return value;
}

class AgentSession {
  final String sessionId;
  final String instanceId;
  final String localSessionId;
  final String name;
  final String projectId;
  final String status;
  final bool controllable;
  final String activeTurnId;
  final bool frozen;

  const AgentSession({
    required this.sessionId,
    required this.instanceId,
    required this.localSessionId,
    required this.name,
    required this.projectId,
    required this.status,
    required this.controllable,
    this.activeTurnId = '',
    this.frozen = false,
  });

  factory AgentSession.fromJson(AgentJson json) => AgentSession(
    sessionId: _requiredText(json, 'session_id'),
    instanceId: _requiredText(json, 'instance_id'),
    localSessionId: _optionalText(json, 'local_session_id'),
    name: _optionalText(json, 'name'),
    projectId: _optionalText(json, 'project_id'),
    status: _optionalText(json, 'status', fallback: 'unknown'),
    controllable: json['controllable'] == true,
    activeTurnId: _optionalText(json, 'active_turn_id'),
    frozen: json['frozen'] == true,
  );
}

class AgentTurn {
  final String turnId;
  final String state;
  final String sessionId;

  const AgentTurn({
    required this.turnId,
    required this.state,
    required this.sessionId,
  });

  factory AgentTurn.fromJson(AgentJson json) => AgentTurn(
    turnId: _requiredText(json, 'turn_id'),
    state: _optionalText(
      json,
      'state',
      fallback: _optionalText(json, 'status', fallback: 'unknown'),
    ),
    sessionId: _optionalText(json, 'session_id'),
  );

  bool get isActive => const {
    'queued',
    'pending',
    'running',
    'cancelling',
    'cancel_requested',
  }.contains(state.toLowerCase());
}

class AgentSessionEvent {
  final int cursor;
  final String eventId;
  final String sessionId;
  final String turnId;
  final String kind;
  final AgentJson payload;
  final DateTime? createdAt;

  const AgentSessionEvent({
    required this.cursor,
    required this.eventId,
    required this.sessionId,
    required this.turnId,
    required this.kind,
    required this.payload,
    this.createdAt,
  });

  factory AgentSessionEvent.fromJson(AgentJson json) {
    final rawCursor = json['cursor'];
    final cursor = rawCursor is num
        ? rawCursor.toInt()
        : int.tryParse('$rawCursor');
    final rawPayload = json['payload'];
    if (cursor == null || cursor < 0 || rawPayload is! Map) {
      throw const FormatException('Invalid Agent Hub event.');
    }
    return AgentSessionEvent(
      cursor: cursor,
      eventId: _optionalText(json, 'event_id'),
      sessionId: _optionalText(json, 'session_id'),
      turnId: _optionalText(json, 'turn_id'),
      kind: _optionalText(json, 'kind', fallback: 'unknown'),
      payload: Map<String, dynamic>.from(rawPayload),
      createdAt: _eventDate(json['created_at']),
    );
  }

  String get text => payload['text']?.toString() ?? '';
}

DateTime? _eventDate(dynamic value) {
  if (value is num) {
    final integer = value.toInt();
    final milliseconds = integer.abs() < 100000000000
        ? integer * 1000
        : integer;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  }
  if (value is String && value.trim().isNotEmpty) {
    final numeric = num.tryParse(value);
    if (numeric != null) return _eventDate(numeric);
    return DateTime.tryParse(value)?.toUtc();
  }
  return null;
}

class AgentEventsPage {
  final List<AgentSessionEvent> events;
  final int? nextCursor;

  const AgentEventsPage({required this.events, this.nextCursor});
}

class AgentListPage<T> {
  final List<T> items;
  final String? nextCursor;

  const AgentListPage({required this.items, this.nextCursor});
}

String _requiredText(AgentJson json, String key) {
  final value = _optionalText(json, key);
  if (value.isEmpty) throw FormatException('Missing Agent Hub field: $key.');
  return value;
}

String _optionalText(AgentJson json, String key, {String fallback = ''}) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return fallback;
}

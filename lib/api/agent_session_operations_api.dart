part of 'agent_hub_api.dart';

extension AgentSessionOperationsApi on AgentHubApi {
  Future<AgentSessionOperationPage> sessionOperations({
    required String instanceId,
    String before = '',
    int limit = 20,
  }) async {
    validateAgentOperationId(instanceId);
    validateAgentOperationCursor(before);
    if (limit < 1 || limit > 50) {
      throw const FormatException('Invalid session operation page size.');
    }
    final response = await _request(
      'GET',
      '/session-operations',
      query: {
        'instance_id': instanceId,
        if (before.isNotEmpty) 'before': before,
        'limit': '$limit',
      },
      maxResponseBytes: 256 * 1024,
    );
    if (response.statusCode != 200) {
      throw const FormatException('Invalid session operation response.');
    }
    final root = _decodeRoot(response.body);
    final data = root['data'];
    final next = root['next_cursor'];
    if (root.length != 2 ||
        data is! List ||
        next is! String ||
        data.length > limit ||
        (data.isEmpty && next.isNotEmpty) ||
        (next.isNotEmpty && next == before)) {
      throw const FormatException('Invalid session operation page.');
    }
    validateAgentOperationCursor(next);
    final items = data
        .map((value) => AgentSessionOperation.fromJson(_asObject(value)))
        .toList(growable: false);
    if (items.any((item) => item.instanceId != instanceId) ||
        items.map((item) => item.identity).toSet().length != items.length) {
      throw const FormatException('Invalid session operation page identity.');
    }
    return AgentSessionOperationPage(List.unmodifiable(items), next);
  }

  Future<AgentSessionOperation> refreshSessionOperation(
    AgentSessionOperation current,
  ) async {
    validateAgentOperationId(current.requestId);
    final route = current.operation == 'create'
        ? 'session-requests'
        : 'session-close-requests';
    final response = await _request(
      'GET',
      '/$route/${Uri.encodeComponent(current.requestId)}',
      maxResponseBytes: 256 * 1024,
    );
    if (response.statusCode != 200) {
      throw const FormatException('Invalid session operation detail.');
    }
    final root = _decodeRoot(response.body);
    if (root.length != 1 || !root.containsKey('data')) {
      throw const FormatException('Invalid session operation detail envelope.');
    }
    final data = _asObject(root['data']);
    if (data.containsKey('operation') ||
        (current.operation == 'close' && data.containsKey('name'))) {
      throw const FormatException('Invalid session operation detail fields.');
    }
    final updated = AgentSessionOperation.fromJson({
      ...data,
      'operation': current.operation,
      if (current.operation == 'close') 'name': '',
    });
    current.checkRefresh(updated);
    return updated;
  }
}

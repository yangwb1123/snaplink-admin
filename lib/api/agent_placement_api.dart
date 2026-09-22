part of 'agent_hub_api.dart';

extension AgentPlacementApi on AgentHubApi {
  Future<AgentTaskPlacement> taskPlacement(
    String taskId, {
    String after = '',
    int limit = 20,
  }) async {
    validateAgentPlacementId(taskId);
    if (after.isNotEmpty) validateAgentPlacementId(after);
    if (limit < 1 || limit > 20) {
      throw const FormatException('Invalid placement page size.');
    }
    final response = await _request(
      'GET',
      '/tasks/${Uri.encodeComponent(taskId)}/placement',
      query: {if (after.isNotEmpty) 'after': after, 'limit': '$limit'},
      maxResponseBytes: 64 * 1024,
      notifyUnauthorized: false,
    );
    if (response.statusCode != 200) {
      throw const FormatException('Invalid placement response status.');
    }
    final root = _decodeRoot(response.body);
    _checkPlacementJsonKeys(response.body);
    if (root.length != 1 || !root.containsKey('data')) {
      throw const FormatException('Invalid placement response envelope.');
    }
    return AgentTaskPlacement.fromJson(
      root['data'],
      taskId: taskId,
      after: after,
      limit: limit,
    );
  }
}

// Run only after jsonDecode accepted the document. JSON object keys are the
// strings followed by a colon; retain one bounded key set per open object.
void _checkPlacementJsonKeys(String body) {
  final objects = <Set<String>>[];
  for (var index = 0; index < body.length; index++) {
    final char = body[index];
    if (char == '{') objects.add(<String>{});
    if (char == '}') objects.removeLast();
    if (char != '"') continue;
    final start = index++;
    while (index < body.length && body[index] != '"') {
      if (body[index] == r'\') index++;
      index++;
    }
    final end = index + 1;
    var next = end;
    while (next < body.length && body[next].trim().isEmpty) {
      next++;
    }
    if (next < body.length && body[next] == ':') {
      final key = jsonDecode(body.substring(start, end)) as String;
      if (!objects.last.add(key)) {
        throw const FormatException('Duplicate placement JSON key.');
      }
    }
  }
}

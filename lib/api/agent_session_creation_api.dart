part of 'agent_hub_api.dart';

extension AgentSessionCreationApi on AgentHubApi {
  Future<AgentSessionCreationRequest> createSession({
    required String instanceId,
    required String name,
    required String idempotencyKey,
  }) async {
    final checkedName = validateAgentSessionName(name);
    validateAgentSessionId(instanceId);
    if (idempotencyKey.isEmpty ||
        idempotencyKey.length > 128 ||
        RegExp(r'[\s\x00-\x1f\x7f]').hasMatch(idempotencyKey)) {
      throw const FormatException('Invalid session creation request.');
    }
    final response = await _request(
      'POST',
      '/instances/${Uri.encodeComponent(instanceId)}/sessions',
      body: {'name': checkedName},
      headers: {'Idempotency-Key': idempotencyKey},
      maxResponseBytes: 32768,
    );
    if (response.statusCode != 202) {
      throw const FormatException('Invalid session creation response.');
    }
    final request = AgentSessionCreationRequest.fromJson(
      _asObject(_readData(_decodeRoot(response.body))),
    );
    if (request.instanceId != instanceId || request.name != checkedName) {
      throw const FormatException(
        'Session creation response does not match the request.',
      );
    }
    return request;
  }

  Future<AgentSessionCreationRequest> sessionRequest(String requestId) async {
    validateAgentSessionId(requestId);
    final response = await _request(
      'GET',
      '/session-requests/${Uri.encodeComponent(requestId)}',
      maxResponseBytes: 32768,
    );
    if (response.statusCode != 200) {
      throw const FormatException('Invalid session creation response.');
    }
    final request = AgentSessionCreationRequest.fromJson(
      _asObject(_readData(_decodeRoot(response.body))),
    );
    if (request.requestId != requestId) {
      throw const FormatException(
        'Session creation response does not match the request.',
      );
    }
    return request;
  }
}

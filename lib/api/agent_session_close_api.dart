part of 'agent_hub_api.dart';

extension AgentSessionCloseApi on AgentHubApi {
  Future<AgentSessionCloseRequest> closeSession({
    required String sessionId,
    required String idempotencyKey,
  }) async {
    validateAgentCloseId(sessionId);
    if (idempotencyKey.isEmpty ||
        idempotencyKey.length > 256 ||
        idempotencyKey.codeUnits.any((code) => code < 33 || code > 126)) {
      throw const FormatException('Invalid session close key.');
    }
    final response = await _request(
      'POST',
      '/sessions/${Uri.encodeComponent(sessionId)}/close',
      body: const {},
      headers: {'Idempotency-Key': idempotencyKey},
      maxResponseBytes: 32768,
    );
    if (response.statusCode != 202) {
      throw const FormatException('Invalid session close response.');
    }
    final request = AgentSessionCloseRequest.fromJson(
      _asObject(_readData(_decodeRoot(response.body))),
    );
    if (request.sessionId != sessionId) {
      throw const FormatException('Session close response target changed.');
    }
    return request;
  }

  Future<AgentSessionCloseRequest> sessionCloseRequest(String requestId) async {
    validateAgentCloseId(requestId);
    final response = await _request(
      'GET',
      '/session-close-requests/${Uri.encodeComponent(requestId)}',
      maxResponseBytes: 32768,
    );
    if (response.statusCode != 200) {
      throw const FormatException('Invalid session close response.');
    }
    final request = AgentSessionCloseRequest.fromJson(
      _asObject(_readData(_decodeRoot(response.body))),
    );
    if (request.requestId != requestId) {
      throw const FormatException('Session close response identity changed.');
    }
    return request;
  }
}

part of 'agent_hub_api.dart';

extension AgentHubWorkspaceApi on AgentHubApi {
  Future<AgentListPage<AgentWorkspaceSnapshot>> listSnapshots({
    required String sessionId,
    String? after,
    int limit = 100,
  }) async {
    final root = await _requestJson(
      'GET',
      '/sessions/${Uri.encodeComponent(sessionId)}/snapshots',
      query: {
        'limit': '${limit.clamp(1, 200)}',
        if (after != null && after.isNotEmpty) 'after': after,
      },
    );
    final page = _parsePage(root, AgentWorkspaceSnapshot.fromJson);
    if (page.items.any((snapshot) => snapshot.sessionId != sessionId)) {
      throw const FormatException(
        'Workspace snapshot belongs to another session.',
      );
    }
    return page;
  }

  Future<AgentWorkspaceSnapshot> uploadSnapshot({
    required String sessionId,
    required AgentWorkspaceBundle bundle,
    required String idempotencyKey,
  }) async {
    if (idempotencyKey.isEmpty) {
      throw ArgumentError.value(idempotencyKey, 'idempotencyKey');
    }
    final body = {'bundle': bundle.toJson()};
    if (utf8.encode(jsonEncode(body)).length >
        AgentWorkspaceBundle.maxHttpBytes) {
      throw const FormatException(
        'Workspace upload exceeds the request limit.',
      );
    }
    final response = await _request(
      'POST',
      '/sessions/${Uri.encodeComponent(sessionId)}/snapshots',
      body: body,
      headers: {'Idempotency-Key': idempotencyKey},
    );
    _workspaceOk(response);
    final snapshot = AgentWorkspaceSnapshot.fromJson(
      _asObject(_readData(_decodeRoot(response.body))),
    );
    if (snapshot.sessionId != sessionId ||
        snapshot.sha256 != bundle.sha256 ||
        snapshot.size != bundle.size ||
        snapshot.fileCount != bundle.files.length) {
      throw const FormatException('Workspace checksum verification failed.');
    }
    return snapshot;
  }

  Future<AgentWorkspaceDownload> downloadWorkspace({
    required String taskId,
    required AgentWorkspaceResult expected,
  }) async {
    if (expected.state != 'ready') {
      throw const FormatException('Workspace output is not ready.');
    }
    final response = await _request(
      'GET',
      '/tasks/${Uri.encodeComponent(taskId)}/workspace',
      maxResponseBytes: AgentWorkspaceBundle.maxHttpBytes,
    );
    _workspaceOk(response);
    return AgentWorkspaceDownload.verified(
      _readData(_decodeRoot(response.body)),
      expected,
    );
  }
}

void _workspaceOk(http.Response response) {
  if (response.statusCode != 200) {
    throw const AgentHubApiException(
      statusCode: 502,
      code: 'unexpected_status',
      message: 'Agent Hub did not accept the workspace request.',
    );
  }
}

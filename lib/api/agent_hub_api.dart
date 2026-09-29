import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'agent_compute_models.dart';
import 'agent_placement_models.dart';
import 'agent_hub_models.dart';
import 'agent_session_creation_models.dart';
import 'agent_session_close_models.dart';
import 'agent_session_operation_models.dart';

part 'agent_hub_api_errors.dart';
part 'agent_hub_api_response.dart';
part 'agent_placement_api.dart';
part 'agent_hub_workspace_api.dart';
part 'agent_session_creation_api.dart';
part 'agent_session_close_api.dart';
part 'agent_session_operations_api.dart';

/// Authenticated transport for the Agent Hub API. It sends the Snaplink
/// bearer only in the Authorization header and never retries writes itself.
class AgentHubApi {
  static const int _maxResponseBytes = 8 * 1024 * 1024;
  final String baseUrl;
  final String accessToken;
  final http.Client _http;
  final Duration timeout;
  final AgentHubUnauthorizedHandler? onUnauthorized;

  AgentHubApi({
    required this.baseUrl,
    required this.accessToken,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 30),
    this.onUnauthorized,
  }) : _http = httpClient ?? http.Client();

  Future<AgentListPage<AgentInstance>> listInstances({
    String? after,
    int limit = 200,
  }) async {
    final boundedLimit = limit.clamp(1, 200);
    final root = await _requestJson(
      'GET',
      '/instances',
      query: {
        if (after != null && after.isNotEmpty) 'after': after,
        'limit': '$boundedLimit',
      },
    );
    return _parsePage(root, AgentInstance.fromJson);
  }

  Future<AgentListPage<AgentSession>> listSessions({
    String? instanceId,
    String? after,
    int limit = 200,
  }) async {
    final filter = instanceId?.trim();
    final boundedLimit = limit.clamp(1, 200);
    final query = <String, String>{
      if (filter != null && filter.isNotEmpty) 'instance_id': filter,
      if (after != null && after.isNotEmpty) 'after': after,
      'limit': '$boundedLimit',
    };
    final root = await _requestJson('GET', '/sessions', query: query);
    return _parsePage(root, AgentSession.fromJson);
  }

  Future<AgentListPage<AgentDevice>> listDevices({
    String? projectId,
    String? after,
    int limit = 100,
  }) async {
    final project = projectId?.trim();
    final boundedLimit = limit.clamp(1, 200);
    final root = await _requestJson(
      'GET',
      '/devices',
      query: {
        if (project != null && project.isNotEmpty) 'project_id': project,
        if (after != null && after.isNotEmpty) 'after': after,
        'limit': '$boundedLimit',
      },
    );
    return _parsePage(root, AgentDevice.fromJson);
  }

  Future<AgentListPage<AgentComputeTask>> listTasks({
    required String sessionId,
    String? after,
    int limit = 100,
  }) async {
    final session = sessionId.trim();
    if (session.isEmpty) throw ArgumentError.value(sessionId, 'sessionId');
    final boundedLimit = limit.clamp(1, 200);
    final root = await _requestJson(
      'GET',
      '/tasks',
      query: {
        'session_id': session,
        if (after != null && after.isNotEmpty) 'after': after,
        'limit': '$boundedLimit',
      },
    );
    return _parsePage(root, AgentComputeTask.fromJson);
  }

  Future<AgentComputeTask> getTask(String taskId) async {
    final data = await _getData('/tasks/${Uri.encodeComponent(taskId)}');
    return AgentComputeTask.fromJson(_asObject(data));
  }

  Future<AgentComputeTask> submitTask({
    required String sessionId,
    required AgentComputeRequest task,
    required String idempotencyKey,
  }) => _submitTaskRequest(
    '/sessions/${Uri.encodeComponent(sessionId)}/tasks',
    task.toJson(),
    idempotencyKey,
  );

  Future<AgentComputeTask> cancelTask(String taskId) => _submitTaskRequest(
    '/tasks/${Uri.encodeComponent(taskId)}/cancel',
    const <String, dynamic>{},
    '',
  );

  Future<AgentComputeTask> rescheduleTask(
    String taskId, {
    String targetDeviceId = '',
  }) => _submitTaskRequest(
    '/tasks/${Uri.encodeComponent(taskId)}/reschedule',
    <String, dynamic>{'target_device_id': targetDeviceId},
    '',
  );

  Future<AgentComputeTask> retryLostTask(
    String taskId, {
    String targetDeviceId = '',
    required bool confirmDuplicate,
  }) {
    if (!confirmDuplicate) {
      throw ArgumentError.value(
        confirmDuplicate,
        'confirmDuplicate',
        'must acknowledge duplicate side effects',
      );
    }
    return _submitTaskRequest(
      '/tasks/${Uri.encodeComponent(taskId)}/retry',
      <String, dynamic>{
        'target_device_id': targetDeviceId,
        'confirm_duplicate': true,
      },
      '',
    );
  }

  Future<AgentComputeTask> _submitTaskRequest(
    String path,
    Map<String, dynamic> body,
    String idempotencyKey,
  ) async {
    final response = await _request(
      'POST',
      path,
      body: body,
      headers: {
        if (idempotencyKey.isNotEmpty) 'Idempotency-Key': idempotencyKey,
      },
    );
    if (response.statusCode != 202) {
      throw const AgentHubApiException(
        statusCode: 502,
        code: 'unexpected_status',
        message: 'Agent Hub did not accept the compute task request.',
      );
    }
    return AgentComputeTask.fromJson(
      _asObject(_readData(_decodeRoot(response.body))),
    );
  }

  Future<AgentSession> getSession(String sessionId) async {
    final data = await _getData('/sessions/${Uri.encodeComponent(sessionId)}');
    return AgentSession.fromJson(_asObject(data));
  }

  Future<AgentTurn> getTurn(String turnId) async {
    final data = await _getData('/turns/${Uri.encodeComponent(turnId)}');
    return AgentTurn.fromJson(_asObject(data));
  }

  Future<AgentTurn> submitPrompt({
    required String sessionId,
    required String prompt,
    required String idempotencyKey,
  }) async {
    final response = await _request(
      'POST',
      '/sessions/${Uri.encodeComponent(sessionId)}/turns',
      body: {'prompt': prompt},
      headers: {'Idempotency-Key': idempotencyKey},
    );
    if (response.statusCode != 202) {
      throw const AgentHubApiException(
        statusCode: 502,
        code: 'unexpected_status',
        message: 'Agent Hub did not accept the prompt.',
      );
    }
    return AgentTurn.fromJson(_asObject(_readData(_decodeRoot(response.body))));
  }

  Future<AgentEventsPage> listEvents({
    required String sessionId,
    required int after,
    int limit = 100,
  }) async {
    if (after < 0) throw ArgumentError.value(after, 'after');
    final boundedLimit = limit.clamp(1, 100);
    final root = await _requestJson(
      'GET',
      '/sessions/${Uri.encodeComponent(sessionId)}/events',
      query: {'after': '$after', 'limit': '$boundedLimit'},
    );
    final data = _readData(root);
    if (data is! List) {
      throw const FormatException('Invalid Agent Hub events response.');
    }
    if (data.any((value) => value is! Map)) {
      throw const FormatException('Invalid Agent Hub events response.');
    }
    final events = data
        .map(
          (value) => AgentSessionEvent.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList(growable: false);
    final rawNextCursor = root['next_cursor'];
    final nextCursor = rawNextCursor is num
        ? rawNextCursor.toInt()
        : rawNextCursor == null
        ? null
        : int.tryParse('$rawNextCursor');
    if (rawNextCursor != null && (nextCursor == null || nextCursor < 0)) {
      throw const FormatException('Invalid Agent Hub event cursor.');
    }
    return AgentEventsPage(events: events, nextCursor: nextCursor);
  }

  Future<AgentTurn> cancelTurn(String turnId) async {
    final response = await _request(
      'POST',
      '/turns/${Uri.encodeComponent(turnId)}/cancel',
      body: const <String, dynamic>{},
    );
    if (response.statusCode != 202) {
      throw const AgentHubApiException(
        statusCode: 502,
        code: 'unexpected_status',
        message: 'Agent Hub did not accept the cancel request.',
      );
    }
    return AgentTurn.fromJson(_asObject(_readData(_decodeRoot(response.body))));
  }

  Future<dynamic> _getData(String path, {Map<String, String>? query}) async {
    final root = await _requestJson('GET', path, query: query);
    return _readData(root);
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await _request(method, path, query: query);
    return _decodeRoot(response.body);
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, String> headers = const {},
    Map<String, dynamic>? body,
    int maxResponseBytes = _maxResponseBytes,
    bool notifyUnauthorized = true,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/agent$path',
    ).replace(queryParameters: query?.isEmpty ?? true ? null : query);
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
        ...headers,
        if (body != null) 'Content-Type': 'application/json',
      });
    if (body != null) request.body = jsonEncode(body);
    late final http.Response response;
    try {
      final streamed = await _http.send(request).timeout(timeout);
      response = await _boundedResponse(
        streamed,
        maxResponseBytes,
      ).timeout(timeout);
    } on TimeoutException {
      throw const AgentHubApiException(
        statusCode: 0,
        code: 'request_timeout',
        message: 'Agent Hub request timed out.',
      );
    } on AgentHubApiException {
      rethrow;
    } on Exception {
      throw const AgentHubApiException(
        statusCode: 0,
        code: 'network_error',
        message: 'Could not reach Agent Hub.',
      );
    }
    if (response.statusCode >= 300 && response.statusCode < 400) {
      throw const AgentHubApiException(
        statusCode: 502,
        code: 'redirect_rejected',
        message: 'Agent Hub redirected the request; the response was rejected.',
      );
    }
    if (response.statusCode >= 400) {
      final error = _decodeError(response.statusCode, response.body);
      if (error.isUnauthorized && notifyUnauthorized) {
        onUnauthorized?.call(error);
      }
      throw error;
    }
    return response;
  }

  Future<http.Response> _boundedResponse(
    http.StreamedResponse streamed,
    int maxBytes,
  ) async {
    final reader = StreamIterator<List<int>>(streamed.stream);
    if ((streamed.contentLength ?? 0) > maxBytes) {
      await reader.cancel();
      throw const AgentHubApiException(
        statusCode: 502,
        code: 'response_too_large',
        message: 'Agent Hub response exceeded the size limit.',
      );
    }
    final bytes = BytesBuilder(copy: false);
    try {
      while (await reader.moveNext()) {
        final chunk = reader.current;
        if (bytes.length + chunk.length > maxBytes) {
          throw const AgentHubApiException(
            statusCode: 502,
            code: 'response_too_large',
            message: 'Agent Hub response exceeded the size limit.',
          );
        }
        bytes.add(chunk);
      }
    } finally {
      await reader.cancel();
    }
    return http.Response(
      utf8.decode(bytes.takeBytes(), allowMalformed: false),
      streamed.statusCode,
      headers: streamed.headers,
      request: streamed.request,
      isRedirect: streamed.isRedirect,
      persistentConnection: streamed.persistentConnection,
      reasonPhrase: streamed.reasonPhrase,
    );
  }

  void close() => _http.close();
}

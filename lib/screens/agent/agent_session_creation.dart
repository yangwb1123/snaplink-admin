import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sso_admin/api/agent_hub_api.dart';
import 'package:sso_admin/api/agent_idempotency_key.dart';
import 'package:sso_admin/api/agent_session_creation_models.dart';

/// One in-memory workflow. Unknown submissions retain their exact retry input.
class AgentSessionCreation extends ChangeNotifier {
  final AgentHubApi api;
  final Duration pollInterval;
  AgentSessionCreationRequest? request;
  String instanceId = '';
  String name = '';
  String? idempotencyKey;
  String? error;
  bool busy = false;
  bool _disposed = false;
  Timer? _timer;

  AgentSessionCreation(
    this.api, {
    this.pollInterval = const Duration(seconds: 2),
  });

  bool get hasInput => idempotencyKey != null;
  bool get canReset => !busy && (request?.isTerminal == true);
  bool get queued => request?.status == 'queued';

  Future<void> submit(String target, String sessionName) async {
    if (busy || request != null || _disposed) return;
    final checked = validateAgentSessionName(sessionName);
    if (hasInput && (target != instanceId || checked != name)) return;
    final recovering = hasInput;
    instanceId = target;
    name = checked;
    idempotencyKey ??= newAgentIdempotencyKey();
    busy = true;
    error = null;
    notifyListeners();
    try {
      request = await api.createSession(
        instanceId: instanceId,
        name: name,
        idempotencyKey: idempotencyKey!,
      );
    } catch (failure) {
      error = creationError(failure, submitting: true);
      if (!recovering && _definiteRejection(failure)) idempotencyKey = null;
    } finally {
      _finish();
    }
  }

  Future<void> refresh() async {
    final current = request;
    if (busy || current == null || current.isTerminal || _disposed) return;
    _timer?.cancel();
    busy = true;
    error = null;
    notifyListeners();
    try {
      final updated = await api.sessionRequest(current.requestId);
      if (updated.instanceId != instanceId || updated.name != name) {
        throw const FormatException('Invalid session creation response.');
      }
      request = updated;
    } catch (failure) {
      error = creationError(failure, submitting: false);
    } finally {
      _finish();
    }
  }

  void reset() {
    if (!canReset || _disposed) return;
    _timer?.cancel();
    request = null;
    idempotencyKey = null;
    instanceId = '';
    name = '';
    error = null;
    notifyListeners();
  }

  void _finish() {
    busy = false;
    if (_disposed) return;
    notifyListeners();
    // Pause on read failure. Explicit retry cannot accidentally repeat a POST.
    if (!_disposed && queued && error == null) {
      _timer = Timer(pollInterval, () => unawaited(refresh()));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

bool _definiteRejection(Object failure) =>
    failure is AgentHubApiException &&
    (const {400, 403, 404, 405, 422}.contains(failure.statusCode) ||
        const {
          'session_capacity',
          'instance_offline',
          'session_creation_unsupported',
        }.contains(failure.code));

String creationError(Object failure, {required bool submitting}) {
  if (failure is AgentHubApiException) {
    if (failure.statusCode == 401 || failure.statusCode == 403) {
      return 'You do not have permission to create or track this session.';
    }
    if (failure.code == 'session_capacity') {
      return 'This instance has reached its session capacity.';
    }
    if (failure.code == 'instance_offline') {
      return 'The selected instance is offline.';
    }
    if (failure.code == 'session_creation_unsupported') {
      return 'This instance does not support remote session creation.';
    }
    if (_definiteRejection(failure)) {
      return 'The session request was rejected. Check the target and name.';
    }
  }
  return submitting
      ? 'The creation result is unknown. Retry the same request to recover it.'
      : 'Could not read creation status. Retry to resume tracking.';
}

String creationStatus(
  AgentSessionCreationRequest request,
) => switch (request.status) {
  'created' => 'Session created.',
  'failed' when request.errorCode == 'session_capacity' =>
    'This instance has reached its session capacity.',
  'failed' => 'The instance could not create the session.',
  'lost' =>
    'The instance restarted before creation was confirmed. Check its sessions before starting again.',
  _ => 'Waiting for the instance to create the session.',
};

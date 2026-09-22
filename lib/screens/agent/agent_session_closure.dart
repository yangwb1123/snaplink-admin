import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sso_admin/api/agent_hub_api.dart';
import 'package:sso_admin/api/agent_idempotency_key.dart';
import 'package:sso_admin/api/agent_session_close_models.dart';

/// A single in-memory close workflow; ambiguous submissions retain their key.
class AgentSessionClosure extends ChangeNotifier {
  final AgentHubApi api;
  final Duration pollInterval;
  AgentSessionCloseRequest? request;
  String sessionId = '';
  String instanceId = '';
  String name = '';
  String? idempotencyKey;
  String? error;
  bool busy = false;
  bool _disposed = false;
  Timer? _timer;

  AgentSessionClosure(
    this.api, {
    this.pollInterval = const Duration(seconds: 2),
  });

  bool get hasInput => idempotencyKey != null;
  bool get canReset => !busy && request?.isTerminal == true;
  bool get queued => request?.status == 'queued';

  Future<void> submit(
    String target,
    String instance,
    String displayName,
  ) async {
    if (busy || request != null || _disposed) return;
    validateAgentCloseId(target);
    validateAgentCloseId(instance);
    if (hasInput && (target != sessionId || instance != instanceId)) return;
    final recovering = hasInput;
    sessionId = target;
    instanceId = instance;
    if (!recovering) name = displayName;
    idempotencyKey ??= newAgentIdempotencyKey();
    busy = true;
    error = null;
    notifyListeners();
    try {
      final result = await api.closeSession(
        sessionId: sessionId,
        idempotencyKey: idempotencyKey!,
      );
      _checkTarget(result);
      request = result;
    } catch (failure) {
      error = closureError(failure, submitting: true);
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
      final updated = await api.sessionCloseRequest(current.requestId);
      _checkTarget(updated);
      request = updated;
    } catch (failure) {
      error = closureError(failure, submitting: false);
    } finally {
      _finish();
    }
  }

  void _checkTarget(AgentSessionCloseRequest value) {
    if (value.sessionId != sessionId || value.instanceId != instanceId) {
      throw const FormatException('Session close response target changed.');
    }
  }

  void reset() {
    if (!canReset || _disposed) return;
    _timer?.cancel();
    request = null;
    idempotencyKey = null;
    sessionId = instanceId = name = '';
    error = null;
    notifyListeners();
  }

  void _finish() {
    busy = false;
    if (_disposed) return;
    notifyListeners();
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
          'session_busy',
          'session_close_unsupported',
          'instance_offline',
          'session_unavailable',
          'session_close_in_progress',
          'session_closed',
          'session_close_failed',
        }.contains(failure.code));

String closureError(Object failure, {required bool submitting}) {
  if (failure is AgentHubApiException) {
    if (failure.statusCode == 401 || failure.statusCode == 403) {
      return 'You do not have permission to close or track this session.';
    }
    if (failure.code == 'session_busy') {
      return 'This session has active work. Wait for it to finish before closing.';
    }
    if (failure.code == 'session_close_unsupported') {
      return 'This instance does not support remote session closing.';
    }
    if (failure.code == 'instance_offline') {
      return 'The selected instance is offline.';
    }
    if (failure.code == 'session_close_failed') {
      return 'Closing failed. The session remains unavailable until the instance restarts.';
    }
    if (_definiteRejection(failure)) {
      return 'The close request was rejected. Refresh the session before trying again.';
    }
  }
  return submitting
      ? 'The close result is unknown. Retry the same request to recover it.'
      : 'Could not read close status. Retry to resume tracking.';
}

String closureStatus(
  AgentSessionCloseRequest request,
) => switch (request.status) {
  'closed' => 'Session closed. Its history is still available.',
  'failed' =>
    'Closing failed. The session remains unavailable until the instance restarts.',
  'lost' =>
    'The instance restarted before closing was confirmed. The session history remains read-only.',
  _ =>
    'Waiting for the instance to close the session. Capacity is still reserved.',
};

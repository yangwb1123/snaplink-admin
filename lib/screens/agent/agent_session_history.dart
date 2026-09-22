import 'package:flutter/foundation.dart';
import 'package:sso_admin/api/agent_hub_api.dart';
import 'package:sso_admin/api/agent_hub_models.dart';
import 'package:sso_admin/api/agent_session_operation_models.dart';

/// One modal, one instance, one bounded page. Reads never adopt local retry keys.
class AgentSessionHistory extends ChangeNotifier {
  final AgentHubApi api;
  final String instanceId;
  final bool Function() isAuthorized;
  AgentSessionOperationPage? page;
  AgentSessionOperation? selected;
  String? error;
  bool busy = false;
  bool unsupported = false;
  String _before = '';
  int _generation = 0;
  bool _disposed = false;

  AgentSessionHistory(
    this.api,
    this.instanceId, {
    bool Function()? isAuthorized,
  }) : isAuthorized = isAuthorized ?? (() => true);

  bool _authorized() {
    if (_disposed) return false;
    if (isAuthorized()) return true;
    _generation++;
    page = null;
    selected = null;
    _before = '';
    busy = false;
    unsupported = false;
    error =
        'Your sign-in changed. Close this dialog and reopen requests after signing in.';
    notifyListeners();
    return false;
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  Future<void> load({String before = ''}) async {
    if (!_authorized() || busy) return;
    _before = before;
    selected = null;
    page = null;
    unsupported = false;
    final generation = _start();
    try {
      final result = await api.sessionOperations(
        instanceId: instanceId,
        before: before,
      );
      if (!_authorized()) return;
      if (_current(generation)) page = result;
    } catch (failure) {
      if (_authorized() && _current(generation)) {
        unsupported =
            failure is AgentHubApiException &&
            const {404, 405, 501}.contains(failure.statusCode);
        error = unsupported
            ? 'This Agent Hub does not support session request history yet.'
            : historyError(failure);
      }
    } finally {
      _finish(generation);
    }
  }

  Future<void> retryPage() => load(before: _before);

  void select(AgentSessionOperation value) {
    if (!_authorized() || page?.items.contains(value) != true) return;
    _generation++;
    selected = value;
    busy = false;
    error = null;
    notifyListeners();
  }

  Future<void> refreshSelected() async {
    final current = selected;
    if (!_authorized() || busy || current == null) return;
    final generation = _start();
    try {
      final updated = await api.refreshSessionOperation(current);
      if (!_authorized() || !_current(generation)) return;
      selected = updated;
      page = AgentSessionOperationPage(
        List.unmodifiable([
          for (final item in page!.items)
            if (item.identity == current.identity) updated else item,
        ]),
        page!.nextCursor,
      );
    } catch (failure) {
      if (_authorized() && _current(generation)) error = historyError(failure);
    } finally {
      _finish(generation);
    }
  }

  Future<AgentSession?> openSelected() async {
    final current = selected;
    if (!_authorized() ||
        busy ||
        current == null ||
        current.sessionId.isEmpty) {
      return null;
    }
    final generation = _start();
    try {
      final session = await api.getSession(current.sessionId);
      if (!_authorized() || !_current(generation)) return null;
      if (session.sessionId != current.sessionId ||
          session.instanceId != instanceId) {
        throw const FormatException('Session operation target changed.');
      }
      return session;
    } catch (failure) {
      if (_authorized() && _current(generation)) error = historyError(failure);
      return null;
    } finally {
      _finish(generation);
    }
  }

  int _start() {
    busy = true;
    error = null;
    final generation = ++_generation;
    notifyListeners();
    return generation;
  }

  void _finish(int generation) {
    if (!_current(generation)) return;
    busy = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

String historyError(Object failure) {
  if (failure is AgentHubApiException &&
      const {401, 403}.contains(failure.statusCode)) {
    return 'You do not have permission to view these session requests.';
  }
  if (failure is FormatException) {
    return 'Agent Hub returned an invalid response.';
  }
  return 'Could not read the session request. Retry to refresh it.';
}

String historyStatus(AgentSessionOperation request) => switch (request.status) {
  'queued' => 'Request queued',
  'created' => 'Session created.',
  'closed' => 'Session closed. Its history is still available.',
  'lost' => 'The instance restarted before this request was confirmed.',
  _ => switch (request.errorCode) {
    'session_capacity' => 'This instance has reached its session capacity.',
    'session_creation_failed' => 'The instance could not create the session.',
    _ =>
      'Closing failed. The session remains unavailable until the instance restarts.',
  },
};

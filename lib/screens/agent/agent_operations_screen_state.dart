part of 'agent_operations_screen.dart';

class _AgentOperationsScreenState extends State<AgentOperationsScreen>
    with _AgentOperationsComputeState {
  late final AgentHubApi _api;
  final TextEditingController _promptController = TextEditingController();
  final Map<String, _PendingAgentPrompt> _pendingPrompts = {};
  final Map<String, String> _promptErrors = {};
  Timer? _directoryTimer;
  Timer? _activityTimer;
  List<AgentInstance> _instances = const [];
  List<AgentSession> _sessions = const [];
  List<AgentSessionEvent> _events = const [];
  String _instanceFilter = '';
  AgentSession? _selectedSession;
  AgentTurn? _turn;
  Object? _directoryFailure;
  Object? _activityFailure;
  Object? _actionFailure;
  bool _directoryLoading = true;
  bool _activityLoading = false;
  bool _directoryBusy = false;
  bool _directoryPending = false;
  bool _instancesHaveMore = false;
  bool _sessionsHaveMore = false;
  bool _activityBusy = false;
  bool _sending = false;
  bool _cancelling = false;
  bool _unauthorized = false;
  bool _showSessionOnNarrowScreen = false;
  int _directoryGeneration = 0;
  int _selectionGeneration = 0;
  int _eventCursor = 0;
  String? _instanceCursor;
  String? _sessionCursor;

  @override
  void initState() {
    super.initState();
    _api = AgentHubApi(
      baseUrl: widget.apiOrigin,
      accessToken: widget.accessToken,
      httpClient: widget.httpClient,
      onUnauthorized: _onUnauthorized,
    );
    _refreshDirectory();
    _refreshComputeDevices();
    _directoryTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _refreshDirectory(silent: true);
      _refreshComputeDevices(silent: true);
    });
    _activityTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _refreshActivity(silent: true);
      _refreshComputeTasks(silent: true);
    });
  }

  @override
  void dispose() {
    _directoryTimer?.cancel();
    _activityTimer?.cancel();
    _api.close();
    _promptController.dispose();
    _disposeComputeControllers();
    super.dispose();
  }

  void _onUnauthorized(AgentHubApiException _) {
    Session.clear();
    if (!mounted) return;
    setState(() => _unauthorized = true);
  }

  Future<void> _refreshDirectory({
    bool silent = false,
    bool loadMore = false,
    bool reset = false,
  }) async {
    if (_unauthorized) return;
    if (_directoryBusy) {
      _directoryPending = true;
      return;
    }
    _directoryBusy = true;
    final generation = ++_directoryGeneration;
    if (!silent && mounted) {
      setState(() {
        _directoryLoading = true;
        _directoryFailure = null;
      });
    }
    try {
      final fetchInstances = !loadMore || _instancesHaveMore;
      final fetchSessions = !loadMore || _sessionsHaveMore;
      final instanceAfter = loadMore ? _instanceCursor : null;
      final sessionAfter = loadMore ? _sessionCursor : null;
      final values = await Future.wait<Object?>([
        fetchInstances
            ? _api.listInstances(
                after: loadMore ? _instanceCursor : null,
                limit: 200,
              )
            : Future<AgentListPage<AgentInstance>?>.value(null),
        fetchSessions
            ? _api.listSessions(
                instanceId: _instanceFilter.isEmpty ? null : _instanceFilter,
                after: loadMore ? _sessionCursor : null,
                limit: 200,
              )
            : Future<AgentListPage<AgentSession>?>.value(null),
      ]);
      if (!mounted || generation != _directoryGeneration) return;
      final instancePage = values[0] as AgentListPage<AgentInstance>?;
      final sessionPage = values[1] as AgentListPage<AgentSession>?;
      final loadedInstanceCount = _instances.length;
      final loadedSessionCount = _sessions.length;
      setState(() {
        if (instancePage != null) {
          _instances = _mergeById(
            instancePage.items,
            _instances,
            (item) => item.instanceId,
            appendExisting: loadMore,
            preserveTail: !loadMore && !reset,
          );
          if (loadMore || reset || loadedInstanceCount <= 200) {
            _instanceCursor = instancePage.nextCursor;
            _instancesHaveMore =
                instancePage.items.isNotEmpty &&
                instancePage.nextCursor != null &&
                instancePage.nextCursor != instanceAfter;
          }
        }
        if (sessionPage != null) {
          _sessions = _mergeById(
            sessionPage.items,
            _sessions,
            (item) => item.sessionId,
            appendExisting: loadMore,
            preserveTail: !loadMore && !reset,
          );
          if (loadMore || reset || loadedSessionCount <= 200) {
            _sessionCursor = sessionPage.nextCursor;
            _sessionsHaveMore =
                sessionPage.items.isNotEmpty &&
                sessionPage.nextCursor != null &&
                sessionPage.nextCursor != sessionAfter;
          }
        }
        _directoryFailure = null;
        _directoryLoading = false;
        final selectedId = _selectedSession?.sessionId;
        if (selectedId != null) {
          _selectedSession = _sessions.cast<AgentSession?>().firstWhere(
            (session) => session?.sessionId == selectedId,
            orElse: () => null,
          );
          if (_selectedSession == null) _clearSelection();
        }
      });
    } catch (error) {
      if (!mounted || generation != _directoryGeneration) return;
      setState(() {
        _directoryFailure = error;
        _directoryLoading = false;
      });
    } finally {
      _directoryBusy = false;
      if (_directoryPending && !_unauthorized) {
        _directoryPending = false;
        unawaited(_refreshDirectory(silent: true));
      }
    }
  }

  Future<void> _changeInstance(String? value) async {
    final next = value ?? '';
    if (next == _instanceFilter) return;
    setState(() {
      _instanceFilter = next;
      _directoryGeneration++;
      _sessions = const [];
      _sessionCursor = null;
      _sessionsHaveMore = false;
      _clearSelection();
      _directoryFailure = null;
      _directoryLoading = true;
    });
    await _refreshDirectory(reset: true);
    _refreshComputeDevices(reset: true);
  }

  Future<void> _loadMoreDirectory() =>
      _refreshDirectory(silent: true, loadMore: true);

  List<T> _mergeById<T>(
    List<T> incoming,
    List<T> existing,
    String Function(T) idOf, {
    required bool appendExisting,
    required bool preserveTail,
  }) {
    final items = <String, T>{};
    if (appendExisting) {
      for (final item in existing) {
        items[idOf(item)] = item;
      }
    }
    for (final item in incoming) {
      items[idOf(item)] = item;
    }
    if (preserveTail) {
      for (final item in existing) {
        items.putIfAbsent(idOf(item), () => item);
      }
    }
    return List.unmodifiable(items.values);
  }

  void _clearSelection() {
    _selectionGeneration++;
    _taskGeneration++;
    _selectedSession = null;
    _workspaceSelection = const AgentWorkspaceSelection();
    _events = const [];
    _turn = null;
    _activityFailure = null;
    _activityLoading = false;
    _eventCursor = 0;
    _computeTasks = const [];
    _taskDetails.clear();
    _taskCursor = null;
    _tasksHaveMore = false;
    _taskFailure = null;
    _taskActionFailure = null;
    _taskReadScopeMissing = false;
    _taskWriteScopeMissing = false;
    _taskCancelScopeMissing = false;
    _showSessionOnNarrowScreen = false;
  }

  void _selectSession(AgentSession session) {
    setState(() {
      _selectionGeneration++;
      _selectedSession = session;
      _workspaceSelection = const AgentWorkspaceSelection();
      _events = const [];
      _turn = null;
      _activityFailure = null;
      _activityLoading = true;
      _eventCursor = 0;
      _computeTasks = const [];
      _taskDetails.clear();
      _taskCursor = null;
      _tasksHaveMore = false;
      _taskFailure = null;
      _taskActionFailure = null;
      _taskReadScopeMissing = false;
      _taskWriteScopeMissing = false;
      _taskCancelScopeMissing = false;
      _showSessionOnNarrowScreen = true;
    });
    _refreshActivity();
    _refreshComputeDevices(reset: true);
    _refreshComputeTasks();
  }

  Future<void> _refreshActivity({bool silent = false}) async {
    final selected = _selectedSession;
    if (selected == null || _activityBusy || _unauthorized) return;
    _activityBusy = true;
    final generation = _selectionGeneration;
    if (!silent && mounted && _events.isEmpty) {
      setState(() {
        _activityLoading = true;
        _activityFailure = null;
      });
    }
    try {
      final detail = await _api.getSession(selected.sessionId);
      if (!_isCurrent(generation, selected.sessionId)) return;
      _selectedSession = detail;
      final additions = <AgentSessionEvent>[];
      var cursor = _eventCursor;
      var pageCount = 0;
      while (pageCount < 5) {
        final page = await _api.listEvents(
          sessionId: selected.sessionId,
          after: cursor,
          limit: 100,
        );
        if (!_isCurrent(generation, selected.sessionId)) return;
        if (page.events.isEmpty) break;
        for (final event in page.events) {
          if (event.cursor > cursor) additions.add(event);
        }
        final eventCursor = page.events.fold<int>(
          cursor,
          (current, event) => event.cursor > current ? event.cursor : current,
        );
        final nextCursor = page.nextCursor ?? eventCursor;
        if (nextCursor <= cursor) break;
        cursor = nextCursor;
        pageCount++;
        if (page.events.length < 100) break;
      }
      AgentTurn? turn = _turn;
      final activeTurnId = detail.activeTurnId;
      final knownTurnId = activeTurnId.isNotEmpty
          ? activeTurnId
          : (turn?.isActive == true ? turn!.turnId : null);
      if (knownTurnId != null) {
        turn = await _api.getTurn(knownTurnId);
        if (!_isCurrent(generation, selected.sessionId)) return;
      }
      setState(() {
        final byCursor = <int, AgentSessionEvent>{
          for (final event in _events) event.cursor: event,
          for (final event in additions) event.cursor: event,
        };
        final merged = byCursor.values.toList()
          ..sort((left, right) => left.cursor.compareTo(right.cursor));
        _events = List.unmodifiable(merged);
        _eventCursor = cursor;
        _turn = turn;
        _activityFailure = null;
        _activityLoading = false;
      });
    } catch (error) {
      if (!_isCurrent(generation, selected.sessionId)) return;
      setState(() {
        _activityFailure = error;
        _activityLoading = false;
      });
    } finally {
      _activityBusy = false;
    }
  }

  bool _isCurrent(int generation, String sessionId) =>
      mounted &&
      generation == _selectionGeneration &&
      _selectedSession?.sessionId == sessionId;

  void _update(VoidCallback action) => setState(action);

  @override
  Widget build(BuildContext context) => _buildOperationsView();
}

class _PendingAgentPrompt {
  final String sessionId;
  final String prompt;
  final String idempotencyKey;

  const _PendingAgentPrompt({
    required this.sessionId,
    required this.prompt,
    required this.idempotencyKey,
  });
}

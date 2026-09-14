part of 'agent_workspace_form.dart';

extension _AgentWorkspaceFormActions on _AgentWorkspaceFormState {
  bool _current(int generation) => mounted && generation == _generation;

  void _fail(Object error) {
    _scopeMissing =
        error is AgentHubApiException &&
        (error.isForbidden || error.isUnauthorized);
    _error = error is FormatException
        ? error.message
        : error is AgentHubApiException
        ? error.message
        : 'Could not read workspace JSON.';
  }

  bool _belongs(AgentWorkspaceSnapshot snapshot) =>
      snapshot.sessionId == widget.sessionId &&
      snapshot.instanceId == widget.instanceId &&
      snapshot.projectId == widget.projectId;

  Future<void> _load({bool more = false}) async {
    final generation = _generation;
    _update(() {
      _busy = true;
      _error = null;
      _scopeMissing = false;
    });
    try {
      final page = await widget.api.listSnapshots(
        sessionId: widget.sessionId,
        after: more ? _cursor : null,
      );
      if (!_current(generation)) return;
      if (page.items.any((snapshot) => !_belongs(snapshot))) {
        throw const FormatException(
          'Workspace snapshot belongs to another session.',
        );
      }
      _update(() {
        _snapshots = {
          if (more)
            for (final s in _snapshots) s.snapshotId: s,
          for (final s in page.items) s.snapshotId: s,
        }.values.toList();
        _cursor = page.nextCursor;
      });
    } on Exception catch (error) {
      if (_current(generation)) _update(() => _fail(error));
    } finally {
      if (_current(generation)) _update(() => _busy = false);
    }
  }

  Future<void> _pick() async {
    final generation = _generation;
    _update(() {
      _busy = true;
      _error = null;
    });
    try {
      final text = await pickAgentWorkspaceJson(
        maxBytes: AgentWorkspaceBundle.maxJsonBytes,
      );
      if (!_current(generation) || text == null) return;
      final bundle = AgentWorkspaceBundle.parse(text);
      _json.text = bundle.canonicalJson;
    } on Exception catch (error) {
      if (_current(generation)) _update(() => _fail(error));
    } finally {
      if (_current(generation)) _update(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    final generation = _generation;
    _change(clear: true);
    _update(() {
      _busy = true;
      _error = null;
      _scopeMissing = false;
    });
    try {
      final bundle = AgentWorkspaceBundle.parse(_json.text);
      final fingerprint = '${widget.sessionId}\n${bundle.sha256}';
      if (_keys.length >= 128 && !_keys.containsKey(fingerprint)) {
        throw const FormatException(
          'Too many unconfirmed workspace uploads. Retry an existing bundle.',
        );
      }
      final key = _keys.putIfAbsent(fingerprint, newAgentIdempotencyKey);
      final snapshot = await widget.api.uploadSnapshot(
        sessionId: widget.sessionId,
        bundle: bundle,
        idempotencyKey: key,
      );
      if (!_current(generation)) return;
      if (!_belongs(snapshot)) {
        throw const FormatException(
          'Workspace snapshot belongs to another session.',
        );
      }
      _keys.remove(fingerprint);
      _update(
        () => _snapshots = {
          for (final s in _snapshots) s.snapshotId: s,
          snapshot.snapshotId: snapshot,
        }.values.toList(),
      );
      _change(snapshot: snapshot);
    } on Exception catch (error) {
      if (_current(generation)) _update(() => _fail(error));
    } finally {
      if (_current(generation)) _update(() => _busy = false);
    }
  }
}

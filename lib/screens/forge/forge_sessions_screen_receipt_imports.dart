part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenReceiptImports on _ForgeSessionsScreenState {
  Future<void> _importRunnerAttemptBoundaryPreview() async {
    if (_loadingRunnerAttemptBoundaryPreview ||
        !widget.enableRunnerAttemptBoundaryProjection ||
        widget.runnerAttemptBoundaryScope == null) {
      return;
    }
    _update(() {
      _loadingRunnerAttemptBoundaryPreview = true;
      _runnerAttemptBoundaryPreviewError = null;
      _runnerAttemptBoundaryPreview = null;
    });
    try {
      final reader = widget.runnerAttemptBoundaryFileReader;
      final source =
          await (reader ??
              () => pickAgentWorkspaceJson(
                maxBytes: forgeRunnerAttemptBoundaryMaxInputBytes,
              ))();
      if (source == null) return;
      final observation = ForgeRunnerAttemptBoundaryObservation.fromJsonText(
        source,
      );
      final selectedConversationID = _selected?.conversation.id;
      final selectedRunID = _selectedRun?.runID;
      final scope = widget.runnerAttemptBoundaryScope!;
      if (!observation.isDisplayOnly ||
          !scope.matches(observation) ||
          !scope.matchesSelected(selectedConversationID, selectedRunID)) {
        throw const FormatException(
          'Runner Attempt boundary projection is outside the selected scope.',
        );
      }
      if (!mounted) return;
      _update(() => _runnerAttemptBoundaryPreview = observation);
    } catch (_) {
      if (!mounted) return;
      _update(() {
        _runnerAttemptBoundaryPreview = null;
        _runnerAttemptBoundaryPreviewError =
            'Invalid or stale Runner Attempt boundary projection.';
      });
    } finally {
      if (mounted) {
        _update(() => _loadingRunnerAttemptBoundaryPreview = false);
      }
    }
  }

  Future<void> _importRunnerLeaseFencingPreview() async {
    if (_loadingRunnerLeaseFencing) return;
    _update(() {
      _loadingRunnerLeaseFencing = true;
      _runnerLeaseFencingError = null;
    });
    try {
      final reader = widget.runnerLeaseFencingFileReader;
      final source =
          await (reader ??
              () => pickAgentWorkspaceJson(
                maxBytes: agentWorkspaceFileMaxBytes,
              ))();
      if (source == null) return;
      final fixture = ForgeRunnerLeaseFencingFixture.fromJsonText(source);
      if (_safeRunnerLeaseFencingPreview(fixture) == null) {
        throw const FormatException(
          'Runner lease fixture is not an offline 16-case contract.',
        );
      }
      if (!mounted) return;
      _update(() => _runnerLeaseFencingPreview = fixture);
    } catch (error) {
      if (!mounted) return;
      _update(() {
        _runnerLeaseFencingError =
            'Invalid or unavailable Runner lease/fencing preview.';
      });
    } finally {
      if (mounted) _update(() => _loadingRunnerLeaseFencing = false);
    }
  }

  Future<void> _importExecutionLeaseCheckpointPreview() async {
    if (_loadingExecutionLeaseCheckpoint) return;
    _update(() {
      _loadingExecutionLeaseCheckpoint = true;
      _executionLeaseCheckpointError = null;
    });
    try {
      final reader = widget.executionLeaseCheckpointFileReader;
      final source =
          await (reader ??
              () => pickAgentWorkspaceJson(
                maxBytes: agentWorkspaceFileMaxBytes,
              ))();
      if (source == null) return;
      final fixture = ForgeExecutionLeaseCheckpointFixture.fromJsonText(source);
      if (_safeExecutionLeaseCheckpointPreview(fixture) == null) {
        throw const FormatException(
          'Execution lease checkpoint is not an offline four-case contract.',
        );
      }
      if (!mounted) return;
      _update(() => _executionLeaseCheckpointPreview = fixture);
    } catch (error) {
      if (!mounted) return;
      _update(() {
        _executionLeaseCheckpointError =
            'Invalid or unavailable execution-lease checkpoint preview.';
      });
    } finally {
      if (mounted) _update(() => _loadingExecutionLeaseCheckpoint = false);
    }
  }

  Future<void> _importSessionRunnerReceiptVectorsPreview() async {
    if (_loadingSessionRunnerReceiptVectorsPreview) return;
    _update(() {
      _loadingSessionRunnerReceiptVectorsPreview = true;
      _sessionRunnerReceiptVectorsPreviewError = null;
    });
    try {
      final reader = widget.sessionRunnerReceiptVectorsFileReader;
      final source =
          await (reader ??
              () => pickAgentWorkspaceJson(
                maxBytes: agentWorkspaceFileMaxBytes,
              ))();
      if (source == null) return;
      final fixture = ForgeSessionRunnerReceiptVectors.fromJsonText(source);
      if (_safeSessionRunnerReceiptVectorsPreview(fixture) == null) {
        throw const FormatException(
          'Session Runner receipt vectors are not display-only.',
        );
      }
      if (!mounted) return;
      _update(() => _sessionRunnerReceiptVectorsPreview = fixture);
    } catch (_) {
      if (!mounted) return;
      _update(() {
        _sessionRunnerReceiptVectorsPreviewError =
            'Invalid or unavailable session Runner receipt vectors.';
      });
    } finally {
      if (mounted) {
        _update(() => _loadingSessionRunnerReceiptVectorsPreview = false);
      }
    }
  }

  Future<void> _importSessionRunnerReceiptHistoryPreview() async {
    if (_loadingSessionRunnerReceiptHistoryPreview) return;
    _update(() {
      _loadingSessionRunnerReceiptHistoryPreview = true;
      _sessionRunnerReceiptHistoryPreviewError = null;
    });
    try {
      final reader = widget.sessionRunnerReceiptHistoryFileReader;
      final source =
          await (reader ??
              () => pickAgentWorkspaceJson(
                maxBytes: agentWorkspaceFileMaxBytes,
              ))();
      if (source == null) return;
      final history = ForgeSessionRunnerReceiptHistory.fromJsonText(source);
      if (_safeSessionRunnerReceiptHistoryPreview(history) == null) {
        throw const FormatException(
          'Session Runner receipt history is not display-only.',
        );
      }
      if (!mounted) return;
      _update(() => _sessionRunnerReceiptHistoryPreview = history);
    } catch (_) {
      if (!mounted) return;
      _update(() {
        _sessionRunnerReceiptHistoryPreviewError =
            'Invalid or unavailable session Runner receipt history.';
      });
    } finally {
      if (mounted) {
        _update(() => _loadingSessionRunnerReceiptHistoryPreview = false);
      }
    }
  }

  Future<void> _importSessionRunnerReconciliationProjectionPreview() async {
    if (_loadingSessionRunnerReconciliationProjectionPreview) return;
    _update(() {
      _loadingSessionRunnerReconciliationProjectionPreview = true;
      _sessionRunnerReconciliationProjectionPreviewError = null;
    });
    try {
      final reader = widget.sessionRunnerReconciliationProjectionFileReader;
      final source =
          await (reader ??
              () => pickAgentWorkspaceJson(
                maxBytes: agentWorkspaceFileMaxBytes,
              ))();
      if (source == null) return;
      final projection =
          ForgeSessionRunnerReconciliationProjection.fromJsonText(source);
      if (_safeSessionRunnerReconciliationProjectionPreview(projection) ==
          null) {
        throw const FormatException(
          'Session Runner reconciliation projection is not display-only.',
        );
      }
      if (!mounted) return;
      _update(() => _sessionRunnerReconciliationProjectionPreview = projection);
    } catch (_) {
      if (!mounted) return;
      _update(() {
        _sessionRunnerReconciliationProjectionPreviewError =
            'Invalid or unavailable session Runner reconciliation projection.';
      });
    } finally {
      if (mounted) {
        _update(
          () => _loadingSessionRunnerReconciliationProjectionPreview = false,
        );
      }
    }
  }
}

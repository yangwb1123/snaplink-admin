part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenApplyImportChanges on _ForgeSessionsScreenState {
  void _applyImportChanges(
    ForgeSessionsScreen oldWidget,
    _ForgeSessionsWidgetChanges changes,
  ) {
    if (oldWidget.runnerLeaseFencingPreview !=
        widget.runnerLeaseFencingPreview) {
      _update(() {
        _runnerLeaseFencingPreview = _safeRunnerLeaseFencingPreview(
          widget.runnerLeaseFencingPreview,
        );
        _runnerLeaseFencingError = null;
      });
    }
    if (oldWidget.executionLeaseCheckpointPreview !=
        widget.executionLeaseCheckpointPreview) {
      _update(() {
        _executionLeaseCheckpointPreview = _safeExecutionLeaseCheckpointPreview(
          widget.executionLeaseCheckpointPreview,
        );
        _executionLeaseCheckpointError = null;
      });
    }
    if (oldWidget.sessionRunnerReceiptVectorsPreview !=
        widget.sessionRunnerReceiptVectorsPreview) {
      _update(() {
        _sessionRunnerReceiptVectorsPreview =
            _safeSessionRunnerReceiptVectorsPreview(
              widget.sessionRunnerReceiptVectorsPreview,
            );
        _sessionRunnerReceiptVectorsPreviewError = null;
      });
    }
    if (oldWidget.sessionRunnerReceiptHistoryPreview !=
        widget.sessionRunnerReceiptHistoryPreview) {
      _update(() {
        _sessionRunnerReceiptHistoryPreview =
            _safeSessionRunnerReceiptHistoryPreview(
              widget.sessionRunnerReceiptHistoryPreview,
            );
        _sessionRunnerReceiptHistoryPreviewError = null;
      });
    }
    if (oldWidget.sessionRunnerReconciliationProjectionPreview !=
        widget.sessionRunnerReconciliationProjectionPreview) {
      _update(() {
        _sessionRunnerReconciliationProjectionPreview =
            _safeSessionRunnerReconciliationProjectionPreview(
              widget.sessionRunnerReconciliationProjectionPreview,
            );
        _sessionRunnerReconciliationProjectionPreviewError = null;
      });
    }
    if (oldWidget.deviceInventoryV2Preview != widget.deviceInventoryV2Preview) {
      _update(() {
        _deviceInventoryV2Preview = _safeDeviceInventoryV2Preview(
          widget.deviceInventoryV2Preview,
        );
        _deviceInventoryV2PreviewError = null;
      });
    }
    if (oldWidget.deviceResourceSummaryPreview !=
        widget.deviceResourceSummaryPreview) {
      _update(() {
        _deviceResourceSummaryPreview = _safeDeviceResourceSummaryPreview(
          widget.deviceResourceSummaryPreview,
        );
        _deviceResourceSummaryPreviewError = null;
      });
    }
    if (oldWidget.clientInstanceResourceViewPreview !=
        widget.clientInstanceResourceViewPreview) {
      _update(() {
        _clientInstanceResourceViewPreview =
            _safeClientInstanceResourceViewPreview(
              widget.clientInstanceResourceViewPreview,
            );
        _clientInstanceResourceViewPreviewError = null;
      });
      _reconcileSelectedClientInstanceProjection();
    }
    if (oldWidget.clientInstanceSessionViewPreview !=
        widget.clientInstanceSessionViewPreview) {
      _update(() {
        _clientInstanceSessionViewPreview =
            _safeClientInstanceSessionViewPreview(
              widget.clientInstanceSessionViewPreview,
            );
        _clientInstanceSessionViewPreviewError = null;
      });
      _reconcileSelectedClientInstanceProjection();
    }
    if (oldWidget.deviceInventoryPlacementEvaluationV2Preview !=
        widget.deviceInventoryPlacementEvaluationV2Preview) {
      _update(() {
        _deviceInventoryPlacementEvaluationV2Preview =
            _safeDeviceInventoryPlacementEvaluationV2Preview(
              widget.deviceInventoryPlacementEvaluationV2Preview,
            );
        _deviceInventoryPlacementEvaluationV2PreviewError = null;
      });
    }
    if (oldWidget.deviceInventoryPlacementEvaluationPreview !=
        widget.deviceInventoryPlacementEvaluationPreview) {
      _update(() {
        _deviceInventoryPlacementEvaluationPreview =
            _safeDeviceInventoryPlacementEvaluationPreview(
              widget.deviceInventoryPlacementEvaluationPreview,
            );
        _deviceInventoryPlacementEvaluationPreviewError = null;
      });
    }
    if (oldWidget.deviceInventoryPlacementBatchEvaluationPreview !=
        widget.deviceInventoryPlacementBatchEvaluationPreview) {
      _update(() {
        _deviceInventoryPlacementBatchEvaluationPreview =
            _safeDeviceInventoryPlacementBatchEvaluationPreview(
              widget.deviceInventoryPlacementBatchEvaluationPreview,
            );
        _deviceInventoryPlacementBatchEvaluationPreviewError = null;
      });
    }
  }
}

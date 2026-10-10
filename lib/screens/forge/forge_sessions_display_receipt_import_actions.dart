part of 'forge_sessions_screen.dart';

extension _ForgeSessionsDisplayReceiptImportActions
    on _ForgeSessionsScreenState {
  Widget _runnerAttemptBoundaryImportAction(BuildContext context) => Card(
    key: const ValueKey('forge-runner-attempt-boundary-import-card'),
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Tooltip(
      message: context.tr('Import Runner Attempt boundary JSON'),
      child: Semantics(
        button: true,
        label: context.tr('Local Runner Attempt boundary projection'),
        child: IconButton(
          key: const ValueKey('forge-import-runner-attempt-boundary'),
          tooltip: context.tr('Import Runner Attempt boundary JSON'),
          onPressed: _loadingRunnerAttemptBoundaryPreview
              ? null
              : _importRunnerAttemptBoundaryPreview,
          icon: _loadingRunnerAttemptBoundaryPreview
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.account_tree_outlined),
        ),
      ),
    ),
  );

  Widget _runnerLeaseFencingImportAction(BuildContext context) => Card(
    key: const ValueKey('forge-runner-lease-fencing-import-card'),
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Tooltip(
      message: context.tr('Import Runner lease/fencing JSON'),
      child: Semantics(
        button: true,
        label: context.tr('Local Runner lease/fencing preview'),
        child: IconButton(
          key: const ValueKey('forge-import-runner-lease-fencing'),
          tooltip: context.tr('Import Runner lease/fencing JSON'),
          onPressed: _loadingRunnerLeaseFencing
              ? null
              : _importRunnerLeaseFencingPreview,
          icon: _loadingRunnerLeaseFencing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_open_outlined),
        ),
      ),
    ),
  );

  Widget _compactImportMenu(BuildContext context) => PopupMenuButton<String>(
    key: const ValueKey('forge-compact-import-menu'),
    tooltip: context.tr('Import Forge preview JSON'),
    icon: const Icon(Icons.file_open_outlined),
    onSelected: (value) {
      switch (value) {
        case 'runner-lease-fencing':
          _importRunnerLeaseFencingPreview();
        case 'execution-lease-checkpoint':
          _importExecutionLeaseCheckpointPreview();
        case 'session-runner-receipt-vectors':
          _importSessionRunnerReceiptVectorsPreview();
        case 'session-runner-receipt-history':
          _importSessionRunnerReceiptHistoryPreview();
        case 'session-runner-reconciliation-projection':
          _importSessionRunnerReconciliationProjectionPreview();
        case 'runner-attempt-boundary':
          _importRunnerAttemptBoundaryPreview();
        case 'device-inventory-v2':
          _importDeviceInventoryV2Preview();
        case 'device-placement-evaluation-v2':
          _importDeviceInventoryPlacementEvaluationV2Preview();
        case 'device-placement-batch':
          _importDeviceInventoryPlacementBatchEvaluationPreview();
      }
    },
    itemBuilder: (context) => [
      PopupMenuItem<String>(
        value: 'runner-lease-fencing',
        enabled: !_loadingRunnerLeaseFencing,
        child: Text(context.tr('Import Runner lease/fencing JSON')),
      ),
      PopupMenuItem<String>(
        value: 'execution-lease-checkpoint',
        enabled: !_loadingExecutionLeaseCheckpoint,
        child: Text(context.tr('Import execution-lease checkpoint JSON')),
      ),
      PopupMenuItem<String>(
        value: 'session-runner-receipt-vectors',
        enabled: !_loadingSessionRunnerReceiptVectorsPreview,
        child: Text(context.tr('Import session Runner receipt vectors JSON')),
      ),
      PopupMenuItem<String>(
        value: 'session-runner-receipt-history',
        enabled: !_loadingSessionRunnerReceiptHistoryPreview,
        child: Text(context.tr('Import session Runner receipt history JSON')),
      ),
      PopupMenuItem<String>(
        value: 'session-runner-reconciliation-projection',
        enabled: !_loadingSessionRunnerReconciliationProjectionPreview,
        child: Text(
          context.tr('Import session Runner reconciliation projection JSON'),
        ),
      ),
      if (widget.enableRunnerAttemptBoundaryProjection &&
          widget.runnerAttemptBoundaryScope != null)
        PopupMenuItem<String>(
          value: 'runner-attempt-boundary',
          enabled: !_loadingRunnerAttemptBoundaryPreview,
          child: Text(context.tr('Import Runner Attempt boundary JSON')),
        ),
      PopupMenuItem<String>(
        value: 'device-inventory-v2',
        enabled: !_loadingDeviceInventoryV2Preview,
        child: Text(context.tr('Import Forge v2 device inventory JSON')),
      ),
      PopupMenuItem<String>(
        value: 'device-placement-evaluation-v2',
        enabled: !_loadingDeviceInventoryPlacementEvaluationV2Preview,
        child: Text(context.tr('Import Forge v2 placement evaluation JSON')),
      ),
      PopupMenuItem<String>(
        value: 'device-placement-batch',
        enabled: !_loadingDeviceInventoryPlacementBatchEvaluationPreview,
        child: Text(context.tr('Import Forge placement batch JSON')),
      ),
    ],
  );

  Widget _executionLeaseCheckpointImportAction(BuildContext context) => Card(
    key: const ValueKey('forge-execution-lease-checkpoint-import-card'),
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Tooltip(
      message: context.tr('Import execution-lease checkpoint JSON'),
      child: Semantics(
        button: true,
        label: context.tr('Local execution-lease checkpoint preview'),
        child: IconButton(
          key: const ValueKey('forge-import-execution-lease-checkpoint'),
          tooltip: context.tr('Import execution-lease checkpoint JSON'),
          onPressed: _loadingExecutionLeaseCheckpoint
              ? null
              : _importExecutionLeaseCheckpointPreview,
          icon: _loadingExecutionLeaseCheckpoint
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_open_outlined),
        ),
      ),
    ),
  );

  Widget _sessionRunnerReceiptVectorsImportAction(BuildContext context) => Card(
    key: const ValueKey('forge-session-runner-receipt-vectors-import-card'),
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Tooltip(
      message: context.tr('Import session Runner receipt vectors JSON'),
      child: Semantics(
        button: true,
        label: context.tr('Local session Runner receipt vectors preview'),
        child: IconButton(
          key: const ValueKey('forge-import-session-runner-receipt-vectors'),
          tooltip: context.tr('Import session Runner receipt vectors JSON'),
          onPressed: _loadingSessionRunnerReceiptVectorsPreview
              ? null
              : _importSessionRunnerReceiptVectorsPreview,
          icon: _loadingSessionRunnerReceiptVectorsPreview
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.fact_check_outlined),
        ),
      ),
    ),
  );

  Widget _sessionRunnerReceiptHistoryImportAction(BuildContext context) => Card(
    key: const ValueKey('forge-session-runner-receipt-history-import-card'),
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Tooltip(
      message: context.tr('Import session Runner receipt history JSON'),
      child: Semantics(
        button: true,
        label: context.tr('Local session Runner receipt history preview'),
        child: IconButton(
          key: const ValueKey('forge-import-session-runner-receipt-history'),
          tooltip: context.tr('Import session Runner receipt history JSON'),
          onPressed: _loadingSessionRunnerReceiptHistoryPreview
              ? null
              : _importSessionRunnerReceiptHistoryPreview,
          icon: _loadingSessionRunnerReceiptHistoryPreview
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.history_outlined),
        ),
      ),
    ),
  );

  Widget _sessionRunnerReconciliationProjectionImportAction(
    BuildContext context,
  ) => Card(
    key: const ValueKey(
      'forge-session-runner-reconciliation-projection-import-card',
    ),
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Tooltip(
      message: context.tr(
        'Import session Runner reconciliation projection JSON',
      ),
      child: Semantics(
        button: true,
        label: context.tr(
          'Local session Runner reconciliation projection preview',
        ),
        child: IconButton(
          key: const ValueKey(
            'forge-import-session-runner-reconciliation-projection',
          ),
          tooltip: context.tr(
            'Import session Runner reconciliation projection JSON',
          ),
          onPressed: _loadingSessionRunnerReconciliationProjectionPreview
              ? null
              : _importSessionRunnerReconciliationProjectionPreview,
          icon: _loadingSessionRunnerReconciliationProjectionPreview
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.rule_folder_outlined),
        ),
      ),
    ),
  );
}

part of 'forge_sessions_screen.dart';

class _ForgeSessionsView extends StatelessWidget {
  final _ForgeSessionsScreenState state;

  const _ForgeSessionsView({required this.state});

  @override
  Widget build(BuildContext context) => state.render(context);
}

const _allClientInstanceFilter = '\u0000all-client-instances';

extension _ForgeSessionsDisplayShell on _ForgeSessionsScreenState {
  Widget render(BuildContext context) {
    final strings = AppStrings.of(context);
    final inputs = _projectInputs();
    final selection = _projectSelection(inputs);
    final runner = _projectRunner(inputs, selection);
    final receipts = _projectReceipts(inputs, selection, runner);
    final display = (
      inputs: inputs,
      selection: selection,
      runner: runner,
      receipts: receipts,
    );
    // The import cards are intentionally discoverable on desktop, but a
    // narrow AppBar must keep its title, sign-out, refresh, and import entry
    // point usable on phone-sized surfaces. The compact menu retains every
    // local import without making the AppBar horizontally overflow.
    final compactAppBar = MediaQuery.sizeOf(context).width < 720;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Forge Sessions')),
        actions: [
          IconButton(
            tooltip: context.tr('Sign out of Forge on this device'),
            onPressed: _signingOut ? null : _signOutThisDevice,
            icon: const Icon(Icons.logout_outlined),
          ),
          if (!_sessionViewInvalidated && !compactAppBar) ...[
            _runnerLeaseFencingImportAction(context),
            _executionLeaseCheckpointImportAction(context),
            _sessionRunnerReceiptVectorsImportAction(context),
            _sessionRunnerReceiptHistoryImportAction(context),
            _sessionRunnerReconciliationProjectionImportAction(context),
            _deviceInventoryV2ImportAction(context),
            _deviceInventoryPlacementEvaluationV2ImportAction(context),
            _deviceInventoryPlacementBatchEvaluationImportAction(context),
            if (widget.enableRunnerAttemptBoundaryProjection &&
                widget.runnerAttemptBoundaryScope != null)
              _runnerAttemptBoundaryImportAction(context),
          ],
          if (!_sessionViewInvalidated && compactAppBar)
            _compactImportMenu(context),
          IconButton(
            tooltip: strings.refresh,
            onPressed: _sessionViewInvalidated ? null : _refreshAndSync,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAndSync,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_sessionViewInvalidated)
              _signOutStateCard(context)
            else ...[
              ..._operationNoticesItems(context, display),
              ..._localPreviewsItems(context, display),
              ..._schedulerItems(context, display),
              ..._runnerItems(context, display),
              ..._readErrorsItems(context, display),
              ..._staleReadsItems(context, display),
              ..._conversationsItems(context, display),
              ..._loadingReadsItems(context, display),
              ..._inventoryItems(context, display),
              ..._pendingWorkspaceItems(context, display),
              ..._receiptLoadingItems(context, display),
              ..._runBindingsItems(context, display),
            ],
          ],
        ),
      ),
      floatingActionButton: _sessionViewInvalidated
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _clientInstanceSessionViewImportAction(context),
                _clientInstanceResourceViewImportAction(context),
                _deviceResourceSummaryImportAction(context),
                _deviceInventoryPlacementEvaluationImportAction(context),
              ],
            ),
    );
  }
}

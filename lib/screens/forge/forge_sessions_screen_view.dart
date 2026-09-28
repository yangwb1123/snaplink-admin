part of 'forge_sessions_screen.dart';

class _ForgeSessionsView extends StatelessWidget {
  final _ForgeSessionsScreenState state;

  const _ForgeSessionsView({required this.state});

  @override
  Widget build(BuildContext context) => state.render(context);
}

extension on _ForgeSessionsScreenState {
  static const _allClientInstanceFilter = '\u0000all-client-instances';

  Widget render(BuildContext context) {
    final strings = AppStrings.of(context);
    final selectedConversationID = _selected?.conversation.id;
    final selectedRunID = _selectedRun?.runID;
    final schedulerSelectionLeaseCandidateEnabled =
        (widget.schedulerSelectionLeaseRequest != null &&
            widget.schedulerSelectionLeaseReader != null) ||
        (widget.schedulerSelectionLeaseRenewalRequest != null &&
            widget.schedulerSelectionLeaseRenewalReader != null);
    final schedulerSelectionLeaseReleaseCandidateEnabled =
        widget.schedulerSelectionLeaseReleaseRequest != null &&
        widget.schedulerSelectionLeaseReleaseReader != null;
    final staticObservation = widget.deviceObservation;
    final runIntentObservation = widget.runIntentObservation;
    final runnerExecutionIntentObservation =
        widget.runnerExecutionIntentObservation ??
        _fetchedRunnerExecutionIntent;
    final runObserved = _strictRunObserved(widget.runObserved);
    final fetchedRunObserved = _strictRunObserved(_fetchedRunObserved);
    final runExecutionEvidence =
        _strictRunExecutionEvidence(widget.runExecutionEvidence) ??
        _strictRunExecutionEvidence(_fetchedRunExecutionEvidence);
    final clientInstanceSessionView =
        _strictClientInstanceSessionView(
          widget.clientInstanceSessionViewPreview,
        ) ??
        _strictClientInstanceSessionView(_fetchedClientInstanceSessionView) ??
        _strictClientInstanceSessionView(_clientInstanceSessionViewPreview);
    final inventoryResourceConvergence =
        _strictDeviceInventoryResourceConvergence(
          _fetchedDeviceInventoryResourceConvergence,
        );
    final clientInstanceResourceView =
        _strictClientInstanceResourceView(
          widget.clientInstanceResourceViewPreview,
        ) ??
        _strictClientInstanceResourceView(_fetchedClientInstanceResourceView) ??
        _strictClientInstanceResourceView(_clientInstanceResourceViewPreview) ??
        inventoryResourceConvergence?.resourceView;
    final executionLeaseCheckpoint = _strictExecutionLeaseCheckpoint(
      _executionLeaseCheckpointPreview,
    );
    final sessionRunnerReceiptVectors = _safeSessionRunnerReceiptVectorsPreview(
      _sessionRunnerReceiptVectorsPreview,
    );
    final sessionRunnerReceiptHistory = _safeSessionRunnerReceiptHistoryPreview(
      _sessionRunnerReceiptHistoryPreview,
    );
    final sessionRunnerReconciliationProjection =
        _safeSessionRunnerReconciliationProjectionPreview(
          _sessionRunnerReconciliationProjectionPreview,
        );
    final fetchedSessionRunnerReconciliationProjection =
        _safeSessionRunnerReconciliationProjectionPreview(
          _fetchedSessionRunnerReconciliationProjection,
        );
    final deviceInventoryV2Preview = _safeDeviceInventoryV2Preview(
      _deviceInventoryV2Preview,
    );
    final deviceResourceSummaryPreview = _safeDeviceResourceSummaryPreview(
      _deviceResourceSummaryPreview,
    );
    final deviceInventoryPlacementEvaluationV2Preview =
        _safeDeviceInventoryPlacementEvaluationV2Preview(
          _deviceInventoryPlacementEvaluationV2Preview,
        );
    final deviceInventoryPlacementEvaluationPreview =
        _safeDeviceInventoryPlacementEvaluationPreview(
          _deviceInventoryPlacementEvaluationPreview,
        );
    final deviceInventoryPlacementBatchEvaluationPreview =
        _safeDeviceInventoryPlacementBatchEvaluationPreview(
          _deviceInventoryPlacementBatchEvaluationPreview,
        );
    final lifecycleRegistry = _strictLifecycleRegistry(
      _fetchedLifecycleRegistry,
    );
    final deviceCredentialCandidate = _strictDeviceCredentialCandidate(
      _fetchedDeviceCredentialCandidate,
    );
    final registryPlacementPreview = _strictRegistryPlacementPreview(
      _fetchedDeviceInventoryRegistryPlacementPreview,
    );
    final schedulerSelectionPreview = _schedulerSelectionPreviewFor(
      _strictSchedulerSelectionPreview(widget.schedulerSelectionPreview),
      _strictSchedulerSelectionPreview(_fetchedSchedulerSelectionPreview),
      selectedConversationID,
      selectedRunID,
    );
    final schedulerSelectionLease = _schedulerSelectionLeaseFor(
      _strictSchedulerSelectionLease(widget.schedulerSelectionLease),
      _strictSchedulerSelectionLease(_fetchedSchedulerSelectionLease),
      selectedConversationID,
      selectedRunID,
      widget.schedulerSelectionLeaseRequest?.attemptID ??
          widget.schedulerSelectionLeaseRenewalRequest?.attemptID,
    );
    final schedulerSelectionLeaseRelease = _schedulerSelectionLeaseReleaseFor(
      _strictSchedulerSelectionLeaseRelease(
        widget.schedulerSelectionLeaseRelease,
      ),
      _strictSchedulerSelectionLeaseRelease(
        _fetchedSchedulerSelectionLeaseRelease,
      ),
      selectedConversationID,
      selectedRunID,
      widget.schedulerSelectionLeaseReleaseRequest?.attemptID,
    );
    // Prefer the dedicated session view, but allow the composed resource view
    // to drive the same local filter when only that observation was supplied.
    // Use the same projection gate as owner reads. When independent
    // session/resource readers are loading, stale, or divergent, the local
    // instance filter must not fall back to one side and show a mixed session
    // image.
    final clientInstanceFilterInstances = _declaredClientInstanceRows();
    final clientInstanceFilterActive = _selectedClientInstanceID != null;
    final selectedClientInstanceDeclared =
        clientInstanceFilterInstances?.any(
          (instance) => instance.instanceID == _selectedClientInstanceID,
        ) ==
        true;
    final clientInstanceProjectionInvalid =
        clientInstanceFilterActive && !selectedClientInstanceDeclared;
    final selectedClientInstanceID = selectedClientInstanceDeclared
        ? _selectedClientInstanceID
        : null;
    final visibleConversations = clientInstanceProjectionInvalid
        ? const <ForgeOwnedConversation>[]
        : conversationsForClientInstance(
            clientInstanceFilterInstances,
            selectedClientInstanceID,
          );
    final selectedConversationVisible =
        selectedConversationID == null ||
        (_conversationVisibleFromSelectedClientInstance(
              selectedConversationID,
            ) &&
            visibleConversations.any(
              (entry) => entry.conversation.id == selectedConversationID,
            ));
    final selectedRunVisible =
        selectedConversationVisible &&
        selectedConversationID != null &&
        selectedRunID != null;
    // Keep existing request-free, caller-injected previews visible when no
    // client-instance filter is active. Once a local instance is selected,
    // every Run-bound value must belong to the selected Conversation and Run.
    final runResourceVisible =
        !clientInstanceFilterActive || selectedRunVisible;
    final fetchedSessionRunnerReceiptHistory = runResourceVisible
        ? _safeSessionRunnerReceiptHistoryPreview(
            _fetchedSessionRunnerReceiptHistory,
          )
        : null;
    final staticRunAttemptLeaseDispatchPreflight = runResourceVisible
        ? _strictRunAttemptLeaseDispatchPreflight(
            widget.runAttemptLeaseDispatchPreflightPreview,
          )
        : null;
    final fetchedRunAttemptLeaseDispatchPreflight =
        _strictRunAttemptLeaseDispatchPreflight(
          _fetchedRunAttemptLeaseDispatchPreflight,
        );
    final runAttemptLeaseDispatchPreflight = !runResourceVisible
        ? null
        : staticRunAttemptLeaseDispatchPreflight ??
              (fetchedRunAttemptLeaseDispatchPreflight?.isFor(
                        selectedConversationID ?? '',
                        selectedRunID ?? '',
                      ) ==
                      true
                  ? fetchedRunAttemptLeaseDispatchPreflight
                  : null);
    final staticRunnerDispatchPlanPreviewCandidate =
        _strictRunnerDispatchPlanPreview(
          runResourceVisible ? widget.runnerDispatchPlanPreview : null,
        );
    final staticRunnerDispatchPlanPreview =
        staticRunnerDispatchPlanPreviewCandidate != null &&
            _runnerDispatchPlanTargetsMatchResources(
              staticRunnerDispatchPlanPreviewCandidate,
            )
        ? staticRunnerDispatchPlanPreviewCandidate
        : null;
    final fetchedRunnerDispatchPlanPreviewCandidate =
        _strictRunnerDispatchPlanPreview(_fetchedRunnerDispatchPlanPreview);
    final fetchedRunnerDispatchPlanPreview =
        fetchedRunnerDispatchPlanPreviewCandidate != null &&
            _runnerDispatchPlanTargetsMatchResources(
              fetchedRunnerDispatchPlanPreviewCandidate,
            )
        ? fetchedRunnerDispatchPlanPreviewCandidate
        : null;
    final runnerDispatchPlanPreview = !runResourceVisible
        ? null
        : staticRunnerDispatchPlanPreview ??
              (fetchedRunnerDispatchPlanPreview?.isFor(
                        selectedConversationID ?? '',
                        selectedRunID ?? '',
                      ) ==
                      true
                  ? fetchedRunnerDispatchPlanPreview
                  : null);
    final staticRunnerDispatchAdmissionCandidate = runResourceVisible
        ? _strictRunnerDispatchAdmission(widget.runnerDispatchAdmission)
        : null;
    final staticRunnerDispatchAdmission =
        staticRunnerDispatchAdmissionCandidate != null &&
            selectedConversationID != null &&
            selectedRunID != null &&
            staticRunnerDispatchAdmissionCandidate.conversationID ==
                selectedConversationID &&
            staticRunnerDispatchAdmissionCandidate.runID == selectedRunID &&
            (widget.runnerDispatchAdmissionRequest == null ||
                staticRunnerDispatchAdmissionCandidate.attemptID ==
                    widget.runnerDispatchAdmissionRequest!.attemptID) &&
            _runnerAdmissionTargetMatchesResources(
              staticRunnerDispatchAdmissionCandidate.owner,
              staticRunnerDispatchAdmissionCandidate.targetID,
            )
        ? staticRunnerDispatchAdmissionCandidate
        : null;
    final fetchedRunnerDispatchAdmission = _strictRunnerDispatchAdmission(
      _fetchedRunnerDispatchAdmission,
    );
    final runnerDispatchAdmission = !runResourceVisible
        ? null
        : staticRunnerDispatchAdmission ??
              (fetchedRunnerDispatchAdmission != null &&
                      fetchedRunnerDispatchAdmission.isFor(
                        selectedConversationID ?? '',
                        selectedRunID ?? '',
                        widget.runnerDispatchAdmissionRequest?.attemptID ?? '',
                      ) &&
                      _runnerAdmissionTargetMatchesResources(
                        fetchedRunnerDispatchAdmission.owner,
                        fetchedRunnerDispatchAdmission.targetID,
                      )
                  ? fetchedRunnerDispatchAdmission
                  : null);
    final staticRunnerTransportAdmissionCandidate = runResourceVisible
        ? _strictRunnerTransportAdmission(widget.runnerTransportAdmission)
        : null;
    final staticRunnerTransportAdmission =
        staticRunnerTransportAdmissionCandidate != null &&
            selectedConversationID != null &&
            selectedRunID != null &&
            staticRunnerTransportAdmissionCandidate.conversationID ==
                selectedConversationID &&
            staticRunnerTransportAdmissionCandidate.runID == selectedRunID &&
            (widget.runnerTransportAdmissionRequest == null ||
                staticRunnerTransportAdmissionCandidate.attemptID ==
                    widget.runnerTransportAdmissionRequest!.attemptID) &&
            _runnerAdmissionTargetMatchesResources(
              staticRunnerTransportAdmissionCandidate.owner,
              staticRunnerTransportAdmissionCandidate.targetID,
            )
        ? staticRunnerTransportAdmissionCandidate
        : null;
    final fetchedRunnerTransportAdmission = _strictRunnerTransportAdmission(
      _fetchedRunnerTransportAdmission,
    );
    final runnerTransportAdmission = !runResourceVisible
        ? null
        : staticRunnerTransportAdmission ??
              (fetchedRunnerTransportAdmission != null &&
                      fetchedRunnerTransportAdmission.isFor(
                        selectedConversationID ?? '',
                        selectedRunID ?? '',
                        widget.runnerTransportAdmissionRequest?.attemptID ?? '',
                      ) &&
                      _runnerAdmissionTargetMatchesResources(
                        fetchedRunnerTransportAdmission.owner,
                        fetchedRunnerTransportAdmission.targetID,
                      )
                  ? fetchedRunnerTransportAdmission
                  : null);
    final staticRunnerExecutionBoundaryCandidate = runResourceVisible
        ? _strictRunnerExecutionBoundary(widget.runnerExecutionBoundary)
        : null;
    final staticRunnerExecutionBoundary =
        staticRunnerExecutionBoundaryCandidate != null &&
            _runnerAdmissionTargetMatchesResources(
              staticRunnerExecutionBoundaryCandidate.owner,
              staticRunnerExecutionBoundaryCandidate.targetID,
            )
        ? staticRunnerExecutionBoundaryCandidate
        : null;
    final fetchedRunnerExecutionBoundaryCandidate =
        _strictRunnerExecutionBoundary(_fetchedRunnerExecutionBoundary);
    final fetchedRunnerExecutionBoundary =
        fetchedRunnerExecutionBoundaryCandidate != null &&
            _runnerAdmissionTargetMatchesResources(
              fetchedRunnerExecutionBoundaryCandidate.owner,
              fetchedRunnerExecutionBoundaryCandidate.targetID,
            )
        ? fetchedRunnerExecutionBoundaryCandidate
        : null;
    final runnerExecutionBoundary = !runResourceVisible
        ? null
        : staticRunnerExecutionBoundary ??
              (fetchedRunnerExecutionBoundary?.isFor(
                        selectedConversationID ?? '',
                        selectedRunID ?? '',
                        widget.runnerExecutionBoundaryRequest?.attemptID ?? '',
                      ) ==
                      true
                  ? fetchedRunnerExecutionBoundary
                  : null);
    final staticRunnerAttemptBoundary = _strictRunnerAttemptBoundary(
      widget.runnerAttemptBoundaryPreview,
      selectedConversationID,
      selectedRunID,
    );
    final importedRunnerAttemptBoundary = _strictRunnerAttemptBoundary(
      _runnerAttemptBoundaryPreview,
      selectedConversationID,
      selectedRunID,
    );
    final fetchedRunnerAttemptBoundary = _strictFetchedRunnerAttemptBoundary(
      _fetchedRunnerAttemptBoundary,
      selectedConversationID,
      selectedRunID,
    );
    final runnerAttemptBoundary = !runResourceVisible
        ? null
        : staticRunnerAttemptBoundary ??
              importedRunnerAttemptBoundary ??
              fetchedRunnerAttemptBoundary;
    final staticLocalRunnerPreview = _strictLocalRunnerPreview(
      runResourceVisible ? widget.localRunnerPreview : null,
    );
    final fetchedLocalRunnerPreview = _strictLocalRunnerPreview(
      runResourceVisible ? _fetchedLocalRunnerPreview : null,
    );
    final localRunnerPreview =
        staticLocalRunnerPreview ?? fetchedLocalRunnerPreview;
    final observation = !runResourceVisible
        ? null
        : staticObservation?.isFor(
                selectedConversationID ?? '',
                selectedRunID ?? '',
              ) ==
              true
        ? staticObservation
        : _fetchedDeviceObservation?.isFor(
                selectedConversationID ?? '',
                selectedRunID ?? '',
              ) ==
              true
        ? _fetchedDeviceObservation
        : _importedDeviceObservation?.isFor(
                selectedConversationID ?? '',
                selectedRunID ?? '',
              ) ==
              true
        ? _importedDeviceObservation
        : null;
    final displayRunIntentObservation = !runResourceVisible
        ? null
        : runIntentObservation?.isFor(
                    selectedConversationID ?? '',
                    selectedRunID ?? '',
                  ) ==
                  true &&
              runIntentObservation!.isDisplayOnly
        ? runIntentObservation
        : null;
    final displayRunnerExecutionIntentObservation = !runResourceVisible
        ? null
        : runnerExecutionIntentObservation?.isFor(
                    selectedConversationID ?? '',
                    selectedRunID ?? '',
                  ) ==
                  true &&
              runnerExecutionIntentObservation!.isDisplayOnly
        ? runnerExecutionIntentObservation
        : _importedRunnerExecutionIntentObservation?.isFor(
                    selectedConversationID ?? '',
                    selectedRunID ?? '',
                  ) ==
                  true &&
              _importedRunnerExecutionIntentObservation!.isDisplayOnly
        ? _importedRunnerExecutionIntentObservation
        : null;
    final sessionRunnerReceiptObservation = runResourceVisible
        ? widget.sessionRunnerReceiptObservationReader != null
              ? _fetchedSessionRunnerReceiptObservation
              : _fetchedSessionRunnerReceiptObservation ??
                    widget.sessionRunnerReceiptObservation
        : null;
    final executionReconciliationObservation = !runResourceVisible
        ? null
        : _strictExecutionReconciliationObservation(
                widget.executionReconciliationObservation,
              ) ??
              _strictExecutionReconciliationObservation(
                _fetchedExecutionReconciliationObservation,
              );
    final executionConsentPreview = selectedConversationVisible
        ? _strictExecutionConsentPreview(
            _fetchedExecutionConsentPreview,
            selectedConversationID ?? '',
          )
        : null;
    final attemptRequestPreview = runResourceVisible
        ? widget.attemptRequestPreview
        : null;
    final pendingRunIntentPreview = selectedConversationVisible
        ? widget.pendingRunIntentPreview
        : null;
    final pendingRunIntentReader = widget.pendingRunIntentReader;
    final pendingRunIntentPageReader = widget.pendingRunIntentPageReader;
    final displaySessionRunnerReceiptObservation = !runResourceVisible
        ? null
        : sessionRunnerReceiptObservation?.isFor(
                    selectedConversationID ?? '',
                    selectedRunID ?? '',
                  ) ==
                  true &&
              sessionRunnerReceiptObservation!.isDisplayOnly
        ? sessionRunnerReceiptObservation
        : _importedSessionRunnerReceiptObservation?.isFor(
                    selectedConversationID ?? '',
                    selectedRunID ?? '',
                  ) ==
                  true &&
              _importedSessionRunnerReceiptObservation!.isDisplayOnly
        ? _importedSessionRunnerReceiptObservation
        : null;
    final displaySessionRunnerReceiptHistory = !runResourceVisible
        ? null
        : fetchedSessionRunnerReceiptHistory?.isFor(
                    selectedConversationID ?? '',
                    selectedRunID ?? '',
                  ) ==
                  true &&
              fetchedSessionRunnerReceiptHistory!.isDisplayOnly
        ? fetchedSessionRunnerReceiptHistory
        : null;
    final displaySessionRunnerReconciliationProjection = !runResourceVisible
        ? null
        : fetchedSessionRunnerReconciliationProjection?.isFor(
                    selectedConversationID ?? '',
                    selectedRunID ?? '',
                  ) ==
                  true &&
              fetchedSessionRunnerReconciliationProjection!.isDisplayOnly
        ? fetchedSessionRunnerReconciliationProjection
        : null;
    final displayExecutionReconciliationObservation = !runResourceVisible
        ? null
        : executionReconciliationObservation?.isFor(
                    selectedConversationID ?? '',
                    selectedRunID ?? '',
                  ) ==
                  true &&
              executionReconciliationObservation!.isDisplayOnly
        ? executionReconciliationObservation
        : null;
    final displayRunExecutionEvidence = !runResourceVisible
        ? null
        : runExecutionEvidence?.isFor(
                    selectedConversationID ?? '',
                    selectedRunID ?? '',
                  ) ==
                  true &&
              runExecutionEvidence!.isDisplayOnly
        ? runExecutionEvidence
        : null;
    ForgeRunObserved? displayRunObserved;
    for (final candidate
        in runResourceVisible
            ? widget.sessionRunnerReceiptObservationReader != null
                  ? <ForgeRunObserved?>[fetchedRunObserved]
                  : <ForgeRunObserved?>[fetchedRunObserved, runObserved]
            : const <ForgeRunObserved?>[]) {
      if (candidate?.isFor(selectedConversationID ?? '', selectedRunID ?? '') ==
              true &&
          candidate!.isDisplayOnly) {
        displayRunObserved = candidate;
        break;
      }
    }
    final requestMatchesSelectedRun =
        widget.deviceObservationRequest != null &&
        widget.deviceObservationRequest!.conversationID ==
            selectedConversationID &&
        widget.deviceObservationRequest!.runID == selectedRunID;
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
              if (_signOutError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    context.tr(_signOutError!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_runnerLeaseFencingError != null)
                _errorCard(context, _runnerLeaseFencingError!, _signIn),
              if (_executionLeaseCheckpointError != null)
                _errorCard(context, _executionLeaseCheckpointError!, _signIn),
              if (_sessionRunnerReceiptVectorsPreviewError != null)
                _errorCard(
                  context,
                  _sessionRunnerReceiptVectorsPreviewError!,
                  _signIn,
                ),
              if (_sessionRunnerReceiptHistoryPreviewError != null)
                _errorCard(
                  context,
                  _sessionRunnerReceiptHistoryPreviewError!,
                  _signIn,
                ),
              if (_sessionRunnerReconciliationProjectionPreviewError != null)
                _errorCard(
                  context,
                  _sessionRunnerReconciliationProjectionPreviewError!,
                  _signIn,
                ),
              if (_runnerAttemptBoundaryPreviewError != null)
                _errorCard(
                  context,
                  _runnerAttemptBoundaryPreviewError!,
                  _signIn,
                ),
              if (runResourceVisible && _runnerAttemptBoundaryError != null)
                _errorCard(context, _runnerAttemptBoundaryError!, _signIn),
              if (_deviceInventoryV2PreviewError != null)
                _errorCard(context, _deviceInventoryV2PreviewError!, _signIn),
              if (_deviceInventoryResourceConvergenceError != null)
                _errorCard(
                  context,
                  _deviceInventoryResourceConvergenceError!,
                  _signIn,
                ),
              if (_deviceResourceSummaryPreviewError != null)
                _errorCard(
                  context,
                  _deviceResourceSummaryPreviewError!,
                  _signIn,
                ),
              if (_clientInstanceResourceViewPreviewError != null)
                _errorCard(
                  context,
                  _clientInstanceResourceViewPreviewError!,
                  _signIn,
                ),
              if (_clientInstanceSessionViewPreviewError != null)
                _errorCard(
                  context,
                  _clientInstanceSessionViewPreviewError!,
                  _signIn,
                ),
              if (_deviceInventoryPlacementEvaluationV2PreviewError != null)
                _errorCard(
                  context,
                  _deviceInventoryPlacementEvaluationV2PreviewError!,
                  _signIn,
                ),
              if (_deviceInventoryPlacementEvaluationPreviewError != null)
                _errorCard(
                  context,
                  _deviceInventoryPlacementEvaluationPreviewError!,
                  _signIn,
                ),
              if (_deviceInventoryPlacementBatchEvaluationPreviewError != null)
                _errorCard(
                  context,
                  _deviceInventoryPlacementBatchEvaluationPreviewError!,
                  _signIn,
                ),
              if (_runnerLeaseFencingPreview != null)
                ForgeRunnerLeaseFencingPreviewCard(
                  fixture: _runnerLeaseFencingPreview!,
                ),
              if (executionLeaseCheckpoint != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgeExecutionLeaseCheckpointPreviewCard(
                    fixture: executionLeaseCheckpoint,
                  ),
                ),
              if (sessionRunnerReceiptVectors != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgeSessionRunnerReceiptVectorsPanel(
                    fixture: sessionRunnerReceiptVectors,
                  ),
                ),
              if (sessionRunnerReceiptHistory != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgeSessionRunnerReceiptHistoryPanel(
                    history: sessionRunnerReceiptHistory,
                  ),
                ),
              if (sessionRunnerReconciliationProjection != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgeSessionRunnerReconciliationProjectionPanel(
                    projection: sessionRunnerReconciliationProjection,
                  ),
                ),
              if (clientInstanceSessionView != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgeClientInstanceSessionViewPanel(
                    fixture: clientInstanceSessionView,
                  ),
                ),
              if (clientInstanceResourceView != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgeClientInstanceResourceViewPanel(
                    fixture: clientInstanceResourceView,
                  ),
                ),
              if (lifecycleRegistry != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgeLifecycleRegistryPanel(
                    registry: lifecycleRegistry,
                  ),
                ),
              if (deviceCredentialCandidate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgeDeviceCredentialCandidatePanel(
                    candidate: deviceCredentialCandidate,
                  ),
                ),
              if (registryPlacementPreview != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgeDeviceRegistryPlacementPreviewPanel(
                    preview: registryPlacementPreview,
                  ),
                ),
              if (schedulerSelectionPreview != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgeSchedulerSelectionPreviewPanel(
                    preview: schedulerSelectionPreview,
                  ),
                ),
              if (schedulerSelectionLease != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgeSchedulerSelectionLeasePanel(
                    lease: schedulerSelectionLease,
                  ),
                ),
              if (schedulerSelectionLeaseRelease != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgeSchedulerSelectionLeaseReleasePanel(
                    release: schedulerSelectionLeaseRelease,
                  ),
                ),
              if (clientInstanceProjectionInvalid ||
                  (clientInstanceFilterInstances != null &&
                      clientInstanceFilterInstances.isNotEmpty))
                _clientInstanceSessionFilter(
                  context,
                  clientInstanceFilterInstances ??
                      const <ForgeClientInstanceSessionViewInstance>[],
                  selectedClientInstanceID,
                ),
              if (runAttemptLeaseDispatchPreflight != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgePreflightFixtureCard(
                    fixture: runAttemptLeaseDispatchPreflight,
                  ),
                ),
              if (runnerDispatchPlanPreview != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgeRunnerDispatchPlanPreviewCard(
                    key: const ValueKey(
                      'forge-runner-dispatch-plan-preview-card',
                    ),
                    preview: runnerDispatchPlanPreview,
                  ),
                ),
              if (runnerDispatchAdmission != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgeRunnerDispatchAdmissionCard(
                    admission: runnerDispatchAdmission,
                  ),
                ),
              if (runnerTransportAdmission != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgeRunnerTransportAdmissionCard(
                    admission: runnerTransportAdmission,
                  ),
                ),
              if (runnerExecutionBoundary != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgeRunnerExecutionBoundaryCard(
                    observation: runnerExecutionBoundary,
                  ),
                ),
              if (runnerAttemptBoundary != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgeRunnerAttemptBoundaryCard(
                    observation: runnerAttemptBoundary,
                  ),
                ),
              if (localRunnerPreview != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgeLocalRunnerPreviewCard(
                    observation: localRunnerPreview,
                  ),
                ),
              if (executionConsentPreview != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgeExecutionConsentPreviewCard(
                    preview: executionConsentPreview,
                  ),
                ),
              _createCard(context),
              if (_conversationError != null)
                _errorCard(context, _conversationError!, _signIn),
              if (_changeError != null)
                _errorCard(context, _changeError!, _signIn),
              if (widget.deviceInventoryOwner != null &&
                  widget.deviceInventoryReader != null &&
                  _deviceInventoryError != null)
                _errorCard(context, _deviceInventoryError!, _signIn),
              if (widget.deviceInventoryOwner != null &&
                  widget.deviceInventoryV2Reader != null &&
                  _deviceInventoryV2Error != null)
                _errorCard(context, _deviceInventoryV2Error!, _signIn),
              if (widget.deviceInventoryResourceConvergenceOwner != null &&
                  widget.deviceInventoryResourceConvergenceReader != null &&
                  _deviceInventoryResourceConvergenceError != null)
                _errorCard(
                  context,
                  _deviceInventoryResourceConvergenceError!,
                  _signIn,
                ),
              if (widget.deviceInventoryOwner != null &&
                  widget.deviceInventoryRegistryPlacementRequirements != null &&
                  widget.deviceInventoryRegistryPlacementPreviewReader !=
                      null &&
                  _deviceInventoryRegistryPlacementPreviewError != null)
                _errorCard(
                  context,
                  _deviceInventoryRegistryPlacementPreviewError!,
                  _signIn,
                ),
              if (widget.schedulerSelectionPreviewRequest != null &&
                  widget.schedulerSelectionPreviewReader != null &&
                  _schedulerSelectionPreviewError != null)
                _errorCard(context, _schedulerSelectionPreviewError!, _signIn),
              if (schedulerSelectionLeaseCandidateEnabled &&
                  _schedulerSelectionLeaseError != null)
                _errorCard(context, _schedulerSelectionLeaseError!, _signIn),
              if (schedulerSelectionLeaseReleaseCandidateEnabled &&
                  _schedulerSelectionLeaseReleaseError != null)
                _errorCard(
                  context,
                  _schedulerSelectionLeaseReleaseError!,
                  _signIn,
                ),
              if (widget.clientInstanceResourceViewOwner != null &&
                  widget.clientInstanceResourceViewReader != null &&
                  _clientInstanceResourceViewError != null)
                _errorCard(context, _clientInstanceResourceViewError!, _signIn),
              if (widget.clientInstanceSessionViewOwner != null &&
                  widget.clientInstanceSessionViewReader != null &&
                  _clientInstanceSessionViewError != null)
                _errorCard(context, _clientInstanceSessionViewError!, _signIn),
              if (widget.clientInstanceSessionResourceConvergenceOwner !=
                      null &&
                  widget.clientInstanceSessionResourceConvergenceReader !=
                      null &&
                  _clientInstanceSessionResourceConvergenceError != null)
                _errorCard(
                  context,
                  _clientInstanceSessionResourceConvergenceError!,
                  _signIn,
                ),
              if (widget.lifecycleRegistryOwner != null &&
                  widget.lifecycleRegistryReader != null &&
                  _lifecycleRegistryError != null)
                _errorCard(context, _lifecycleRegistryError!, _signIn),
              if (widget.deviceCredentialCandidateOwner != null &&
                  widget.deviceCredentialCandidateRequest != null &&
                  widget.deviceCredentialCandidateReader != null &&
                  _deviceCredentialCandidateError != null)
                _errorCard(context, _deviceCredentialCandidateError!, _signIn),
              if (runResourceVisible &&
                  widget.runAttemptLeaseDispatchPreflightRequest != null &&
                  widget.runAttemptLeaseDispatchPreflightReader != null &&
                  _runAttemptLeaseDispatchPreflightError != null)
                _errorCard(
                  context,
                  _runAttemptLeaseDispatchPreflightError!,
                  _signIn,
                ),
              if (runResourceVisible &&
                  widget.runnerDispatchPlanPreviewRequest != null &&
                  widget.runnerDispatchPlanPreviewReader != null &&
                  _runnerDispatchPlanPreviewError != null)
                _errorCard(context, _runnerDispatchPlanPreviewError!, _signIn),
              if (runResourceVisible &&
                  widget.runnerDispatchAdmissionRequest != null &&
                  widget.runnerDispatchAdmissionReader != null &&
                  _runnerDispatchAdmissionError != null)
                _errorCard(context, _runnerDispatchAdmissionError!, _signIn),
              if (runResourceVisible &&
                  widget.runnerTransportAdmissionRequest != null &&
                  widget.runnerTransportAdmissionReader != null &&
                  _runnerTransportAdmissionError != null)
                _errorCard(context, _runnerTransportAdmissionError!, _signIn),
              if (runResourceVisible &&
                  widget.runnerExecutionBoundaryRequest != null &&
                  widget.runnerExecutionBoundaryReader != null &&
                  _runnerExecutionBoundaryError != null)
                _errorCard(context, _runnerExecutionBoundaryError!, _signIn),
              if (runResourceVisible &&
                  widget.localRunnerPreviewRequest != null &&
                  widget.localRunnerPreviewReader != null &&
                  _localRunnerPreviewError != null)
                _errorCard(context, _localRunnerPreviewError!, _signIn),
              if (runResourceVisible &&
                  widget.runObservedReader != null &&
                  _runObservedError != null)
                _errorCard(context, _runObservedError!, _signIn),
              if (selectedConversationVisible &&
                  widget.executionConsentPreviewOwner != null &&
                  widget.executionConsentPreviewReader != null &&
                  _executionConsentPreviewError != null)
                _errorCard(context, _executionConsentPreviewError!, _signIn),
              if (widget.deviceInventoryOwner != null &&
                  widget.deviceInventoryReader != null &&
                  _deviceInventoryStale)
                _staleDeviceInventoryCard(context),
              if (widget.deviceInventoryOwner != null &&
                  widget.deviceInventoryV2Reader != null &&
                  _deviceInventoryV2Stale)
                _staleDeviceInventoryV2Card(context),
              if (widget.deviceInventoryResourceConvergenceOwner != null &&
                  widget.deviceInventoryResourceConvergenceReader != null &&
                  _deviceInventoryResourceConvergenceStale)
                _staleDeviceInventoryResourceConvergenceCard(context),
              if (widget.deviceInventoryOwner != null &&
                  widget.deviceInventoryRegistryPlacementRequirements != null &&
                  widget.deviceInventoryRegistryPlacementPreviewReader !=
                      null &&
                  _deviceInventoryRegistryPlacementPreviewStale)
                _staleRegistryPlacementPreviewCard(context),
              if (widget.schedulerSelectionPreviewRequest != null &&
                  widget.schedulerSelectionPreviewReader != null &&
                  _schedulerSelectionPreviewStale)
                _staleSchedulerSelectionPreviewCard(context),
              if (schedulerSelectionLeaseCandidateEnabled &&
                  _schedulerSelectionLeaseStale)
                _staleSchedulerSelectionLeaseCard(context),
              if (schedulerSelectionLeaseReleaseCandidateEnabled &&
                  _schedulerSelectionLeaseReleaseStale)
                _staleSchedulerSelectionLeaseReleaseCard(context),
              if (widget.clientInstanceResourceViewOwner != null &&
                  widget.clientInstanceResourceViewReader != null &&
                  _clientInstanceResourceViewStale)
                _staleClientInstanceResourceViewCard(context),
              if (widget.clientInstanceSessionViewOwner != null &&
                  widget.clientInstanceSessionViewReader != null &&
                  _clientInstanceSessionViewStale)
                _staleClientInstanceSessionViewCard(context),
              if (widget.clientInstanceSessionResourceConvergenceOwner !=
                      null &&
                  widget.clientInstanceSessionResourceConvergenceReader !=
                      null &&
                  _clientInstanceSessionResourceConvergenceStale)
                _staleClientInstanceSessionResourceConvergenceCard(context),
              if (widget.lifecycleRegistryOwner != null &&
                  widget.lifecycleRegistryReader != null &&
                  _lifecycleRegistryStale)
                _staleLifecycleRegistryCard(context),
              if (widget.deviceCredentialCandidateOwner != null &&
                  widget.deviceCredentialCandidateRequest != null &&
                  widget.deviceCredentialCandidateReader != null &&
                  _deviceCredentialCandidateStale)
                _staleDeviceCredentialCandidateCard(context),
              if (runResourceVisible &&
                  widget.runAttemptLeaseDispatchPreflightRequest != null &&
                  widget.runAttemptLeaseDispatchPreflightReader != null &&
                  _runAttemptLeaseDispatchPreflightStale)
                _staleRunAttemptLeaseDispatchPreflightCard(context),
              if (runResourceVisible &&
                  widget.runnerDispatchPlanPreviewRequest != null &&
                  widget.runnerDispatchPlanPreviewReader != null &&
                  _runnerDispatchPlanPreviewStale)
                _staleRunnerDispatchPlanPreviewCard(context),
              if (runResourceVisible &&
                  widget.runnerDispatchAdmissionRequest != null &&
                  widget.runnerDispatchAdmissionReader != null &&
                  _runnerDispatchAdmissionStale)
                _staleRunnerDispatchAdmissionCard(context),
              if (runResourceVisible &&
                  widget.runnerTransportAdmissionRequest != null &&
                  widget.runnerTransportAdmissionReader != null &&
                  _runnerTransportAdmissionStale)
                _staleRunnerTransportAdmissionCard(context),
              if (runResourceVisible &&
                  widget.runnerExecutionBoundaryRequest != null &&
                  widget.runnerExecutionBoundaryReader != null &&
                  _runnerExecutionBoundaryStale)
                _staleRunnerExecutionBoundaryCard(context),
              if (runResourceVisible &&
                  widget.runnerAttemptBoundaryRequest != null &&
                  widget.runnerAttemptBoundaryReader != null &&
                  _runnerAttemptBoundaryStale)
                _staleRunnerAttemptBoundaryCard(context),
              if (runResourceVisible &&
                  widget.localRunnerPreviewRequest != null &&
                  widget.localRunnerPreviewReader != null &&
                  _localRunnerPreviewStale)
                _staleLocalRunnerPreviewCard(context),
              if (runResourceVisible &&
                  widget.runObservedReader != null &&
                  _runObservedStale)
                _staleRunObservedCard(context),
              if (selectedConversationVisible &&
                  widget.executionConsentPreviewOwner != null &&
                  widget.executionConsentPreviewReader != null &&
                  _executionConsentPreviewStale)
                _staleExecutionConsentPreviewCard(context),
              if (requestMatchesSelectedRun &&
                  runResourceVisible &&
                  _deviceObservationError != null)
                _errorCard(context, _deviceObservationError!, _signIn),
              if (_conversationsStale) _staleConversationsCard(context),
              if (_loadingConversations && _conversations.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (!_loadingConversations &&
                  _conversationError == null &&
                  _conversations.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(context.tr('No Forge conversations yet.')),
                ),
              if (!_loadingConversations &&
                  _conversationError == null &&
                  _conversations.isNotEmpty &&
                  visibleConversations.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    context.tr(
                      'No conversations are visible from this client instance.',
                    ),
                  ),
                ),
              for (final item in visibleConversations)
                _conversationTile(context, item),
              if (_hasMoreConversations)
                Center(
                  child: TextButton(
                    onPressed: _loadingConversations
                        ? null
                        : () => _refreshConversations(loadMore: true),
                    child: Text(context.tr('Load more conversations')),
                  ),
                ),
              if (widget.deviceInventoryOwner != null &&
                  widget.deviceInventoryReader != null &&
                  _loadingDeviceInventory)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (widget.deviceInventoryOwner != null &&
                  widget.deviceInventoryV2Reader != null &&
                  _loadingDeviceInventoryV2)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (widget.deviceInventoryOwner != null &&
                  widget.deviceInventoryRegistryPlacementRequirements != null &&
                  widget.deviceInventoryRegistryPlacementPreviewReader !=
                      null &&
                  _loadingDeviceInventoryRegistryPlacementPreview)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (widget.schedulerSelectionPreviewRequest != null &&
                  widget.schedulerSelectionPreviewReader != null &&
                  _loadingSchedulerSelectionPreview)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (schedulerSelectionLeaseCandidateEnabled &&
                  _loadingSchedulerSelectionLease)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (schedulerSelectionLeaseReleaseCandidateEnabled &&
                  _loadingSchedulerSelectionLeaseRelease)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (widget.clientInstanceResourceViewOwner != null &&
                  widget.clientInstanceResourceViewReader != null &&
                  _loadingClientInstanceResourceView)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (widget.clientInstanceSessionViewOwner != null &&
                  widget.clientInstanceSessionViewReader != null &&
                  _loadingClientInstanceSessionView)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (widget.clientInstanceSessionResourceConvergenceOwner !=
                      null &&
                  widget.clientInstanceSessionResourceConvergenceReader !=
                      null &&
                  _loadingClientInstanceSessionResourceConvergence)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (widget.lifecycleRegistryOwner != null &&
                  widget.lifecycleRegistryReader != null &&
                  _loadingLifecycleRegistry)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (runResourceVisible &&
                  widget.runAttemptLeaseDispatchPreflightRequest != null &&
                  widget.runAttemptLeaseDispatchPreflightReader != null &&
                  _loadingRunAttemptLeaseDispatchPreflight)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (runResourceVisible &&
                  widget.runnerDispatchPlanPreviewRequest != null &&
                  widget.runnerDispatchPlanPreviewReader != null &&
                  _loadingRunnerDispatchPlanPreview)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (runResourceVisible &&
                  widget.runnerDispatchAdmissionRequest != null &&
                  widget.runnerDispatchAdmissionReader != null &&
                  _loadingRunnerDispatchAdmission)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (runResourceVisible &&
                  widget.runnerTransportAdmissionRequest != null &&
                  widget.runnerTransportAdmissionReader != null &&
                  _loadingRunnerTransportAdmission)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (runResourceVisible &&
                  widget.localRunnerPreviewRequest != null &&
                  widget.localRunnerPreviewReader != null &&
                  _loadingLocalRunnerPreview)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (selectedConversationVisible &&
                  widget.executionConsentPreviewOwner != null &&
                  widget.executionConsentPreviewReader != null &&
                  _loadingExecutionConsentPreview)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (widget.deviceInventoryOwner != null &&
                  widget.deviceInventoryReader != null &&
                  _fetchedDeviceInventory != null)
                _authenticatedDeviceInventoryPanel(
                  context,
                  _fetchedDeviceInventory!,
                ),
              if (widget.deviceInventoryOwner != null &&
                  widget.deviceInventoryV2Reader != null &&
                  _fetchedDeviceInventoryV2 != null)
                _authenticatedDeviceInventoryV2Panel(
                  context,
                  _fetchedDeviceInventoryV2!,
                ),
              if (inventoryResourceConvergence != null)
                _authenticatedDeviceInventoryResourceConvergencePanel(
                  context,
                  inventoryResourceConvergence,
                ),
              if (deviceInventoryV2Preview != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgeDeviceInventoryV2Panel(
                    page: deviceInventoryV2Preview,
                  ),
                ),
              if (deviceResourceSummaryPreview != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgeDeviceResourceSummaryPanel(
                    fixture: deviceResourceSummaryPreview,
                  ),
                ),
              if (deviceInventoryPlacementEvaluationV2Preview != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgeDeviceInventoryPlacementEvaluationV2Panel(
                    evaluation: deviceInventoryPlacementEvaluationV2Preview,
                  ),
                ),
              if (deviceInventoryPlacementEvaluationPreview != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgeDeviceInventoryPlacementEvaluationPanel(
                    evaluation: deviceInventoryPlacementEvaluationPreview,
                  ),
                ),
              if (deviceInventoryPlacementBatchEvaluationPreview != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgeDeviceInventoryPlacementBatchEvaluationPanel(
                    evaluation: deviceInventoryPlacementBatchEvaluationPreview,
                  ),
                ),
              if (selectedConversationVisible &&
                  (pendingRunIntentReader != null ||
                      pendingRunIntentPageReader != null) &&
                  _pendingRunIntentError != null)
                _errorCard(context, _pendingRunIntentError!, _signIn),
              if (selectedConversationVisible &&
                  (pendingRunIntentReader != null ||
                      pendingRunIntentPageReader != null) &&
                  (_loadingPendingRunIntents || _loadingMorePendingRunIntents))
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (selectedConversationVisible &&
                  (pendingRunIntentReader != null ||
                      pendingRunIntentPageReader != null) &&
                  _fetchedPendingRunIntents != null)
                ForgePendingRunIntentMetadataPanel(
                  page: _fetchedPendingRunIntents!,
                  timelines: _fetchedPendingRunIntentTimelines,
                  loadingTimelineIntentIDs: _loadingPendingRunIntentTimelines,
                  timelineErrors: _pendingRunIntentTimelineErrors,
                  onTimelineExpanded:
                      widget.pendingRunIntentTimelineReader == null
                      ? null
                      : (intentID) =>
                            unawaited(_loadPendingRunIntentTimeline(intentID)),
                  onLoadMore: pendingRunIntentPageReader == null
                      ? null
                      : () => unawaited(_loadMorePendingRunIntents()),
                  loadingMore: _loadingMorePendingRunIntents,
                ),
              if (_selected != null && selectedConversationVisible)
                _promptPanel(context),
              if (_selected != null &&
                  selectedConversationVisible &&
                  _pendingRunIntentSubmission != null &&
                  widget.pendingRunIntentOwner != null)
                ForgePendingRunIntentSubmissionCard(
                  submission: _pendingRunIntentSubmission!,
                  owner: widget.pendingRunIntentOwner!,
                ),
              if (_selected != null && selectedConversationVisible)
                _runPanel(context),
              if (requestMatchesSelectedRun &&
                  runResourceVisible &&
                  _loadingDeviceObservation)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (runResourceVisible &&
                  widget.runObservedReader != null &&
                  _loadingRunObserved)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (runResourceVisible &&
                  widget.runExecutionEvidenceReader != null &&
                  _runExecutionEvidenceError != null)
                _errorCard(context, _runExecutionEvidenceError!, _signIn),
              if (runResourceVisible &&
                  widget.runExecutionEvidenceReader != null &&
                  _loadingRunExecutionEvidence)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (runResourceVisible &&
                  widget.sessionRunnerReceiptHistoryReader != null &&
                  _sessionRunnerReceiptHistoryError != null)
                _errorCard(
                  context,
                  _sessionRunnerReceiptHistoryError!,
                  _signIn,
                ),
              if (runResourceVisible &&
                  widget.sessionRunnerReceiptHistoryReader != null &&
                  _loadingSessionRunnerReceiptHistory)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (runResourceVisible &&
                  widget.sessionRunnerReconciliationProjectionReader != null &&
                  _sessionRunnerReconciliationProjectionError != null)
                _errorCard(
                  context,
                  _sessionRunnerReconciliationProjectionError!,
                  _signIn,
                ),
              if (runResourceVisible &&
                  widget.sessionRunnerReconciliationProjectionReader != null &&
                  _loadingSessionRunnerReconciliationProjection)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (runResourceVisible &&
                  widget.executionReconciliationReader != null &&
                  _executionReconciliationError != null)
                _errorCard(context, _executionReconciliationError!, _signIn),
              if (runResourceVisible &&
                  widget.executionReconciliationReader != null &&
                  _loadingExecutionReconciliation)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (observation != null)
                ForgeSessionDeviceObservationPanel(observation: observation),
              if (displayRunIntentObservation != null)
                ForgeRunIntentObservationCard(
                  observation: displayRunIntentObservation,
                ),
              if (displayRunnerExecutionIntentObservation != null)
                ForgeRunnerExecutionIntentCard(
                  observation: displayRunnerExecutionIntentObservation,
                ),
              if (runResourceVisible &&
                  widget.runnerExecutionIntentReader != null &&
                  _runnerExecutionIntentError != null)
                _errorCard(context, _runnerExecutionIntentError!, _signIn),
              if (runResourceVisible &&
                  widget.runnerExecutionIntentReader != null &&
                  _loadingRunnerExecutionIntent)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (displaySessionRunnerReceiptObservation != null)
                ForgeSessionRunnerReceiptObservationCard(
                  observation: displaySessionRunnerReceiptObservation,
                ),
              if (displaySessionRunnerReceiptHistory != null)
                Padding(
                  key: const ValueKey(
                    'forge-session-runner-receipt-history-remote-panel',
                  ),
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgeSessionRunnerReceiptHistoryPanel(
                    history: displaySessionRunnerReceiptHistory,
                  ),
                ),
              if (displaySessionRunnerReconciliationProjection != null)
                Padding(
                  key: const ValueKey(
                    'forge-session-runner-reconciliation-projection-remote-panel',
                  ),
                  padding: const EdgeInsets.only(top: 12),
                  child: ForgeSessionRunnerReconciliationProjectionPanel(
                    projection: displaySessionRunnerReconciliationProjection,
                  ),
                ),
              if (displayExecutionReconciliationObservation != null)
                ForgeExecutionReconciliationObservationCard(
                  observation: displayExecutionReconciliationObservation,
                ),
              if (displayRunExecutionEvidence != null)
                ForgeRunExecutionEvidenceCard(
                  evidence: displayRunExecutionEvidence,
                ),
              if (displayRunObserved != null)
                ForgeRunObservedCard(observation: displayRunObserved),
              if (attemptRequestPreview != null)
                ForgeAttemptRequestPreviewCard(fixture: attemptRequestPreview),
              if (pendingRunIntentPreview != null)
                ForgePendingRunIntentCard(fixture: pendingRunIntentPreview),
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

  ForgeRunExecutionEvidence? _strictRunExecutionEvidence(
    ForgeRunExecutionEvidence? candidate,
  ) {
    if (candidate == null) return null;
    try {
      // Re-decode the caller-supplied wire projection so a manually
      // constructed value cannot bypass the strict fixture contract.
      return ForgeRunExecutionEvidence.fromJson(candidate.toJson());
    } on FormatException {
      return null;
    }
  }

  ForgeExecutionReconciliationObservation?
  _strictExecutionReconciliationObservation(
    ForgeExecutionReconciliationObservation? candidate,
  ) {
    if (candidate == null) return null;
    try {
      // Re-decode the caller-supplied wire projection so a manually
      // constructed value cannot bypass the strict observation contract.
      return ForgeExecutionReconciliationObservation.fromJson(
        candidate.toJson(),
      );
    } on FormatException {
      return null;
    }
  }

  ForgeExecutionConsentPreview? _strictExecutionConsentPreview(
    ForgeExecutionConsentPreview? candidate,
    String? selectedConversationID,
  ) {
    if (candidate == null || selectedConversationID == null) return null;
    try {
      final validated = ForgeExecutionConsentPreview.fromJson(
        candidate.toJson(),
      );
      return validated.conversationID == selectedConversationID
          ? validated
          : null;
    } on FormatException {
      return null;
    }
  }

  ForgeRunObserved? _strictRunObserved(ForgeRunObserved? candidate) {
    if (candidate == null) return null;
    try {
      // Re-decode the caller-supplied wire projection so a manually
      // constructed value cannot bypass the strict observer contract.
      return ForgeRunObserved.fromJson(candidate.toJson());
    } on FormatException {
      return null;
    }
  }

  ForgeClientInstanceSessionView? _strictClientInstanceSessionView(
    ForgeClientInstanceSessionView? candidate,
  ) {
    if (candidate == null) return null;
    try {
      return ForgeClientInstanceSessionView.fromJson(candidate.toJson());
    } on FormatException {
      return null;
    }
  }

  ForgeClientInstanceResourceView? _strictClientInstanceResourceView(
    ForgeClientInstanceResourceView? candidate,
  ) {
    if (candidate == null) return null;
    try {
      return ForgeClientInstanceResourceView.fromJson(candidate.toJson());
    } on FormatException {
      return null;
    }
  }

  ForgeDeviceInventoryResourceConvergence?
  _strictDeviceInventoryResourceConvergence(
    ForgeDeviceInventoryResourceConvergence? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeDeviceInventoryResourceConvergence.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeExecutionLeaseCheckpointFixture? _strictExecutionLeaseCheckpoint(
    ForgeExecutionLeaseCheckpointFixture? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeExecutionLeaseCheckpointFixture.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeDeviceEnrollmentHeartbeatLifecycleRegistry? _strictLifecycleRegistry(
    ForgeDeviceEnrollmentHeartbeatLifecycleRegistry? candidate,
  ) {
    if (candidate == null) return null;
    try {
      return ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJson(
        candidate.toJson(),
      );
    } on FormatException {
      return null;
    }
  }

  ForgeDeviceCredentialLifecycleCandidate? _strictDeviceCredentialCandidate(
    ForgeDeviceCredentialLifecycleCandidate? candidate,
  ) {
    if (candidate == null) return null;
    try {
      return ForgeDeviceCredentialLifecycleCandidate.fromJson(
        candidate.toJson(),
      );
    } on FormatException {
      return null;
    }
  }

  ForgeDeviceRegistryPlacementPreview? _strictRegistryPlacementPreview(
    ForgeDeviceRegistryPlacementPreview? candidate,
  ) {
    if (candidate == null) return null;
    try {
      return ForgeDeviceRegistryPlacementPreview.fromJson(candidate.toJson());
    } on FormatException {
      return null;
    }
  }

  ForgeSchedulerSelectionPreview? _strictSchedulerSelectionPreview(
    ForgeSchedulerSelectionPreview? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeSchedulerSelectionPreview.fromJson(
        candidate.toJson(),
      );
      return validated.authority.anyGranted || !validated.previewOnly
          ? null
          : validated;
    } on FormatException {
      return null;
    }
  }

  ForgeSchedulerSelectionPreview? _schedulerSelectionPreviewFor(
    ForgeSchedulerSelectionPreview? staticPreview,
    ForgeSchedulerSelectionPreview? fetchedPreview,
    String? conversationID,
    String? runID,
  ) {
    for (final candidate in [staticPreview, fetchedPreview]) {
      if (candidate != null &&
          conversationID != null &&
          runID != null &&
          candidate.isFor(conversationID, runID) &&
          _schedulerSelectionTargetMatchesResources(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  ForgeSchedulerSelectionLease? _strictSchedulerSelectionLease(
    ForgeSchedulerSelectionLease? candidate,
  ) {
    if (candidate == null) return null;
    try {
      return ForgeSchedulerSelectionLease.fromJson(candidate.toJson());
    } on FormatException {
      return null;
    }
  }

  ForgeSchedulerSelectionLeaseRelease? _strictSchedulerSelectionLeaseRelease(
    ForgeSchedulerSelectionLeaseRelease? candidate,
  ) {
    if (candidate == null) return null;
    try {
      return ForgeSchedulerSelectionLeaseRelease.fromJson(candidate.toJson());
    } on FormatException {
      return null;
    }
  }

  ForgeSchedulerSelectionLeaseRelease? _schedulerSelectionLeaseReleaseFor(
    ForgeSchedulerSelectionLeaseRelease? staticRelease,
    ForgeSchedulerSelectionLeaseRelease? fetchedRelease,
    String? conversationID,
    String? runID,
    String? attemptID,
  ) {
    for (final candidate in [staticRelease, fetchedRelease]) {
      if (candidate != null &&
          conversationID != null &&
          runID != null &&
          candidate.isFor(
            conversationID,
            runID,
            attemptID ?? candidate.attemptID,
          ) &&
          (attemptID == null || candidate.attemptID == attemptID)) {
        return candidate;
      }
    }
    return null;
  }

  ForgeSchedulerSelectionLease? _schedulerSelectionLeaseFor(
    ForgeSchedulerSelectionLease? staticLease,
    ForgeSchedulerSelectionLease? fetchedLease,
    String? conversationID,
    String? runID,
    String? attemptID,
  ) {
    for (final candidate in [staticLease, fetchedLease]) {
      if (candidate != null &&
          conversationID != null &&
          runID != null &&
          candidate.isFor(
            conversationID,
            runID,
            attemptID ?? candidate.attemptID,
          ) &&
          (attemptID == null || candidate.attemptID == attemptID)) {
        return candidate;
      }
    }
    return null;
  }

  ForgePreflightFixture? _strictRunAttemptLeaseDispatchPreflight(
    ForgePreflightFixture? candidate,
  ) {
    if (candidate == null) return null;
    try {
      return ForgePreflightFixture.fromJson(candidate.toJson());
    } on FormatException {
      return null;
    }
  }

  ForgeRunnerDispatchPlanPreview? _strictRunnerDispatchPlanPreview(
    ForgeRunnerDispatchPlanPreview? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeRunnerDispatchPlanPreview.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeRunnerDispatchAdmission? _strictRunnerDispatchAdmission(
    ForgeRunnerDispatchAdmission? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeRunnerDispatchAdmission.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeRunnerTransportAdmission? _strictRunnerTransportAdmission(
    ForgeRunnerTransportAdmission? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeRunnerTransportAdmission.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeRunnerExecutionBoundaryObservation? _strictRunnerExecutionBoundary(
    ForgeRunnerExecutionBoundaryObservation? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeRunnerExecutionBoundaryObservation.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeRunnerAttemptBoundaryObservation? _strictRunnerAttemptBoundary(
    ForgeRunnerAttemptBoundaryObservation? candidate,
    String? selectedConversationID,
    String? selectedRunID,
  ) {
    final scope = widget.runnerAttemptBoundaryScope;
    if (!widget.enableRunnerAttemptBoundaryProjection ||
        candidate == null ||
        scope == null ||
        !scope.matchesSelected(selectedConversationID, selectedRunID)) {
      return null;
    }
    try {
      final validated = ForgeRunnerAttemptBoundaryObservation.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly && scope.matches(validated)
          ? validated
          : null;
    } on FormatException {
      return null;
    }
  }

  ForgeRunnerAttemptBoundaryObservation? _strictFetchedRunnerAttemptBoundary(
    ForgeRunnerAttemptBoundaryObservation? candidate,
    String? selectedConversationID,
    String? selectedRunID,
  ) {
    final request = widget.runnerAttemptBoundaryRequest;
    if (candidate == null ||
        request == null ||
        selectedConversationID == null ||
        selectedRunID == null ||
        request.conversationID != selectedConversationID ||
        request.runID != selectedRunID) {
      return null;
    }
    try {
      final validated = ForgeRunnerAttemptBoundaryObservation.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly &&
              validated.owner == request.owner &&
              validated.isFor(
                selectedConversationID,
                selectedRunID,
                request.attemptID,
              ) &&
              validated.currentAttemptState == request.attemptState &&
              validated.transition == request.transition
          ? validated
          : null;
    } on FormatException {
      return null;
    }
  }

  Widget _authenticatedDeviceInventoryPanel(
    BuildContext context,
    ForgeDeviceInventoryPage page,
  ) => KeyedSubtree(
    key: const ValueKey('forge-authenticated-device-inventory'),
    child: Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('Authenticated device inventory observation'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            context.tr(
              'This owner-scoped candidate is read-only and remains unverified.',
            ),
          ),
          const SizedBox(height: 8),
          ForgeDeviceInventoryPanel(
            key: const ValueKey('forge-authenticated-device-inventory-panel'),
            page: page,
          ),
        ],
      ),
    ),
  );

  Widget _clientInstanceSessionFilter(
    BuildContext context,
    Iterable<ForgeClientInstanceSessionViewInstance> instances,
    String? selectedInstanceID,
  ) {
    return Card(
      key: const ValueKey('forge-client-instance-session-filter'),
      margin: const EdgeInsets.only(top: 12),
      child: ListTile(
        title: Text(context.tr('Session visibility scope')),
        subtitle: Text(
          context.tr(
            'Local display filter over the owner session list; instance metadata is unverified.',
          ),
        ),
        trailing: PopupMenuButton<String>(
          key: const ValueKey('forge-client-instance-session-filter-menu'),
          enabled: !_sessionViewInvalidated,
          tooltip: context.tr('Select a client-instance session scope'),
          child: Text(selectedInstanceID ?? context.tr('All client instances')),
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: _allClientInstanceFilter,
              child: Text(context.tr('All client instances')),
            ),
            for (final instance in instances)
              PopupMenuItem<String>(
                value: instance.instanceID,
                child: Text(instance.instanceID),
              ),
          ],
          onSelected: (value) => selectClientInstanceFilter(
            instances,
            value == _allClientInstanceFilter ? null : value,
          ),
        ),
      ),
    );
  }

  Widget _authenticatedDeviceInventoryV2Panel(
    BuildContext context,
    ForgeDeviceInventoryPageV2 page,
  ) => KeyedSubtree(
    key: const ValueKey('forge-authenticated-device-inventory-v2'),
    child: Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ForgeDeviceInventoryV2Panel(page: page),
    ),
  );

  Widget _authenticatedDeviceInventoryResourceConvergencePanel(
    BuildContext context,
    ForgeDeviceInventoryResourceConvergence convergence,
  ) => Card(
    key: const ValueKey(
      'forge-authenticated-device-inventory-resource-convergence',
    ),
    margin: const EdgeInsets.only(top: 12),
    child: ListTile(
      leading: const Icon(Icons.compare_arrows_outlined),
      title: Text(context.tr('Converged device resources')),
      subtitle: Text(
        context.tr(
          '${convergence.inventory.devices.length} device resources share the same Runner identity and lifecycle counters. This is an unverified display-only observation.',
        ),
      ),
      trailing: const Icon(Icons.visibility_outlined),
    ),
  );

  Widget _signOutStateCard(BuildContext context) => Card(
    child: ListTile(
      leading: _signingOut
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.lock_outline),
      title: Text(
        context.tr(
          _signingOut
              ? 'Signing out of Forge…'
              : 'Forge owner data is hidden until sign-out is retried.',
        ),
      ),
      subtitle: _signOutError == null ? null : Text(context.tr(_signOutError!)),
      trailing: _signingOut
          ? null
          : TextButton(
              onPressed: _signOutThisDevice,
              child: Text(context.tr('Retry sign out')),
            ),
    ),
  );

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

  Widget _deviceInventoryV2ImportAction(BuildContext context) => Card(
    key: const ValueKey('forge-device-inventory-v2-import-card'),
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Tooltip(
      message: context.tr('Import Forge v2 device inventory JSON'),
      child: Semantics(
        button: true,
        label: context.tr('Local Forge v2 device inventory preview'),
        child: IconButton(
          key: const ValueKey('forge-import-device-inventory-v2'),
          tooltip: context.tr('Import Forge v2 device inventory JSON'),
          onPressed: _loadingDeviceInventoryV2Preview
              ? null
              : _importDeviceInventoryV2Preview,
          icon: _loadingDeviceInventoryV2Preview
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_open_outlined),
        ),
      ),
    ),
  );

  Widget _clientInstanceSessionViewImportAction(BuildContext context) => Card(
    key: const ValueKey('forge-client-instance-session-view-import-card'),
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Tooltip(
      message: context.tr('Import Forge client-instance session view JSON'),
      child: Semantics(
        button: true,
        label: context.tr('Local Forge client-instance session view preview'),
        child: IconButton(
          key: const ValueKey('forge-import-client-instance-session-view'),
          tooltip: context.tr('Import Forge client-instance session view JSON'),
          onPressed: _loadingClientInstanceSessionViewPreview
              ? null
              : _importClientInstanceSessionViewPreview,
          icon: _loadingClientInstanceSessionViewPreview
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.devices_other_outlined),
        ),
      ),
    ),
  );

  Widget _clientInstanceResourceViewImportAction(BuildContext context) => Card(
    key: const ValueKey('forge-client-instance-resource-view-import-card'),
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Tooltip(
      message: context.tr('Import Forge client-instance resource view JSON'),
      child: Semantics(
        button: true,
        label: context.tr('Local Forge client-instance resource view preview'),
        child: IconButton(
          key: const ValueKey('forge-import-client-instance-resource-view'),
          tooltip: context.tr(
            'Import Forge client-instance resource view JSON',
          ),
          onPressed: _loadingClientInstanceResourceViewPreview
              ? null
              : _importClientInstanceResourceViewPreview,
          icon: _loadingClientInstanceResourceViewPreview
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.account_tree_outlined),
        ),
      ),
    ),
  );

  Widget _deviceResourceSummaryImportAction(BuildContext context) => Card(
    key: const ValueKey('forge-device-resource-summary-import-card'),
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Tooltip(
      message: context.tr('Import Forge device resource summary JSON'),
      child: Semantics(
        button: true,
        label: context.tr('Local Forge device resource summary preview'),
        child: IconButton(
          key: const ValueKey('forge-import-device-resource-summary'),
          tooltip: context.tr('Import Forge device resource summary JSON'),
          onPressed: _loadingDeviceResourceSummaryPreview
              ? null
              : _importDeviceResourceSummaryPreview,
          icon: _loadingDeviceResourceSummaryPreview
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_open_outlined),
        ),
      ),
    ),
  );

  Widget _deviceInventoryPlacementEvaluationV2ImportAction(
    BuildContext context,
  ) => Card(
    key: const ValueKey('forge-device-placement-evaluation-v2-import-card'),
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Tooltip(
      message: context.tr('Import Forge v2 placement evaluation JSON'),
      child: Semantics(
        button: true,
        label: context.tr('Local Forge v2 placement evaluation preview'),
        child: IconButton(
          key: const ValueKey('forge-import-device-placement-evaluation-v2'),
          tooltip: context.tr('Import Forge v2 placement evaluation JSON'),
          onPressed: _loadingDeviceInventoryPlacementEvaluationV2Preview
              ? null
              : _importDeviceInventoryPlacementEvaluationV2Preview,
          icon: _loadingDeviceInventoryPlacementEvaluationV2Preview
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_open_outlined),
        ),
      ),
    ),
  );

  Widget _deviceInventoryPlacementEvaluationImportAction(
    BuildContext context,
  ) => Card(
    key: const ValueKey('forge-device-placement-evaluation-import-card'),
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Tooltip(
      message: context.tr('Import Forge placement evaluation JSON'),
      child: Semantics(
        button: true,
        label: context.tr('Local Forge placement evaluation preview'),
        child: IconButton(
          key: const ValueKey('forge-import-device-placement-evaluation'),
          tooltip: context.tr('Import Forge placement evaluation JSON'),
          onPressed: _loadingDeviceInventoryPlacementEvaluationPreview
              ? null
              : _importDeviceInventoryPlacementEvaluationPreview,
          icon: _loadingDeviceInventoryPlacementEvaluationPreview
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_open_outlined),
        ),
      ),
    ),
  );

  Widget _deviceInventoryPlacementBatchEvaluationImportAction(
    BuildContext context,
  ) => Card(
    key: const ValueKey('forge-device-placement-batch-import-card'),
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Tooltip(
      message: context.tr('Import Forge placement batch JSON'),
      child: Semantics(
        button: true,
        label: context.tr('Local Forge placement batch preview'),
        child: IconButton(
          key: const ValueKey('forge-import-device-placement-batch'),
          tooltip: context.tr('Import Forge placement batch JSON'),
          onPressed: _loadingDeviceInventoryPlacementBatchEvaluationPreview
              ? null
              : _importDeviceInventoryPlacementBatchEvaluationPreview,
          icon: _loadingDeviceInventoryPlacementBatchEvaluationPreview
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_open_outlined),
        ),
      ),
    ),
  );

  Widget _createCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('Create a conversation'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            enabled: !_creating && _pendingCreate == null,
            decoration: InputDecoration(
              labelText: context.tr('Title'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _scopeKind,
            decoration: InputDecoration(
              labelText: context.tr('Scope'),
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final kind in const ['global', 'project', 'group'])
                DropdownMenuItem(value: kind, child: Text(context.tr(kind))),
            ],
            onChanged: _creating || _pendingCreate != null
                ? null
                : _setScopeKind,
          ),
          if (_scopeKind != 'global') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _scopeIDController,
              enabled: !_creating && _pendingCreate == null,
              decoration: InputDecoration(
                labelText: context.tr('Project or group ID'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          if (_createError != null)
            _inlineError(context, _createError!, _signIn),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed:
                _creating ||
                    _appending ||
                    _pendingPrompt != null ||
                    _submittingPendingRunIntent
                ? null
                : _createConversation,
            icon: _creating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: Text(
              _pendingCreate == null
                  ? context.tr('Create conversation')
                  : context.tr('Retry create'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _conversationTile(BuildContext context, ForgeOwnedConversation item) {
    final selected = item.conversation.id == _selected?.conversation.id;
    return Card(
      child: ListTile(
        key: ValueKey('forge-conversation-${item.conversation.id}'),
        selected: selected,
        title: Text(
          item.conversation.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(item.conversation.scope.label),
        trailing: selected ? const Icon(Icons.chevron_right) : null,
        onTap:
            _appending || _pendingPrompt != null || _submittingPendingRunIntent
            ? null
            : () => _selectConversation(item),
      ),
    );
  }

  Widget _promptPanel(BuildContext context) {
    final selected = _selected!;
    final schedulingReviewInventoryResourceError =
        _inventoryResourceObservationErrorFor('Scheduling review');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Prompt history'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(selected.conversation.title),
            if (_promptError != null)
              _inlineError(context, _promptError!, _signIn),
            if (_loadingPrompts && _prompts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_hasMorePrompts)
              TextButton(
                onPressed: _loadingPrompts
                    ? null
                    : () => _loadPrompts(
                        selected.conversation.id,
                        loadOlder: true,
                      ),
                child: Text(context.tr('Load older prompts')),
              ),
            for (final prompt in _prompts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr(prompt.role)),
                subtitle: SelectableText(prompt.content),
                dense: true,
              ),
            TextField(
              controller: _promptController,
              enabled: !_appending && _pendingPrompt == null,
              minLines: 2,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: context.tr('Prompt'),
                border: const OutlineInputBorder(),
              ),
            ),
            if (_appendError != null)
              _inlineError(context, _appendError!, _signIn),
            if (_promptAppendInventoryResourceConvergenceError != null)
              _inlineError(
                context,
                _promptAppendInventoryResourceConvergenceError!,
                _signIn,
              ),
            if (_pendingRunIntentSubmitError != null)
              _inlineError(context, _pendingRunIntentSubmitError!, _signIn),
            if (schedulingReviewInventoryResourceError != null)
              _inlineError(
                context,
                schedulingReviewInventoryResourceError,
                _signIn,
              ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed:
                      _appending ||
                          _submittingPendingRunIntent ||
                          _promptAppendInventoryResourceConvergenceError != null
                      ? null
                      : _appendPrompt,
                  icon: _appending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _pendingPrompt == null
                        ? context.tr('Append prompt')
                        : context.tr('Retry prompt'),
                  ),
                ),
                if (widget.pendingRunIntentSubmitter != null &&
                    widget.pendingRunIntentOwner != null)
                  OutlinedButton.icon(
                    key: const ValueKey('forge-request-scheduling-review'),
                    onPressed:
                        _appending ||
                            _submittingPendingRunIntent ||
                            schedulingReviewInventoryResourceError != null
                        ? null
                        : _submitPendingRunIntent,
                    icon: _submittingPendingRunIntent
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.playlist_add_check),
                    label: LocalizedText(
                      _pendingRunIntentRequest == null
                          ? 'Request scheduling review'
                          : 'Retry scheduling review',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard(
    BuildContext context,
    String message,
    VoidCallback onSignIn,
  ) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(child: Text(context.tr(message))),
          if (message == _forgeAuthRequiredMessage)
            TextButton(onPressed: onSignIn, child: Text(context.tr('Sign in'))),
        ],
      ),
    ),
  );

  Widget _staleConversationsCard(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge is offline or unavailable. Showing cached session metadata; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleDeviceInventoryCard(BuildContext context) => Card(
    key: const ValueKey('forge-device-inventory-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge device inventory is refreshing or unavailable. Showing the last verified snapshot; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleDeviceInventoryV2Card(BuildContext context) => Card(
    key: const ValueKey('forge-device-inventory-v2-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge v2 device inventory is refreshing or unavailable. Showing the last verified snapshot; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleDeviceInventoryResourceConvergenceCard(
    BuildContext context,
  ) => Card(
    key: const ValueKey('forge-device-inventory-resource-convergence-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge converged device resources are refreshing or unavailable. Showing the last validated pair; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleRegistryPlacementPreviewCard(BuildContext context) => Card(
    key: const ValueKey('forge-device-registry-placement-preview-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const ListTile(
      leading: Icon(Icons.cloud_off_outlined),
      title: LocalizedText(
        'Forge registry placement preview is refreshing or unavailable. Showing the last validated comparison; it may be stale.',
      ),
    ),
  );

  Widget _staleSchedulerSelectionPreviewCard(BuildContext context) => Card(
    key: const ValueKey('forge-scheduler-selection-preview-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const ListTile(
      leading: Icon(Icons.cloud_off_outlined),
      title: LocalizedText(
        'Forge scheduler selection is refreshing or unavailable. Showing the last validated preview; it may be stale.',
      ),
    ),
  );

  Widget _staleSchedulerSelectionLeaseCard(BuildContext context) => Card(
    key: const ValueKey('forge-scheduler-selection-lease-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const ListTile(
      leading: Icon(Icons.cloud_off_outlined),
      title: LocalizedText(
        'Forge scheduler lease is unavailable. The displayed lease was not renewed.',
      ),
    ),
  );

  Widget _staleSchedulerSelectionLeaseReleaseCard(BuildContext context) => Card(
    key: const ValueKey('forge-scheduler-selection-lease-release-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const ListTile(
      leading: Icon(Icons.cloud_off_outlined),
      title: LocalizedText(
        'Forge scheduler lease release is unavailable. The displayed release receipt may be stale.',
      ),
    ),
  );

  Widget _staleClientInstanceResourceViewCard(BuildContext context) => Card(
    key: const ValueKey('forge-client-instance-resource-view-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge client-instance resources are refreshing or unavailable. Showing the last validated view; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleClientInstanceSessionViewCard(BuildContext context) => Card(
    key: const ValueKey('forge-client-instance-session-view-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge client-instance sessions are refreshing or unavailable. Showing the last validated view; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleClientInstanceSessionResourceConvergenceCard(
    BuildContext context,
  ) => Card(
    key: const ValueKey(
      'forge-client-instance-session-resource-convergence-stale',
    ),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge client-instance session and resource observations are refreshing or unavailable. Showing the last validated pair; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleLifecycleRegistryCard(BuildContext context) => Card(
    key: const ValueKey('forge-lifecycle-registry-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge lifecycle registry is refreshing or unavailable. Showing the last validated snapshot; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleDeviceCredentialCandidateCard(BuildContext context) => Card(
    key: const ValueKey('forge-device-credential-candidate-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge credential lifecycle candidate is unavailable. No credential material was retained.',
        ),
      ),
    ),
  );

  Widget _staleRunObservedCard(BuildContext context) => Card(
    key: const ValueKey('forge-run-observed-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge Run metadata is refreshing or unavailable. Showing the last validated observation; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleRunAttemptLeaseDispatchPreflightCard(
    BuildContext context,
  ) => Card(
    key: const ValueKey('forge-run-attempt-lease-dispatch-preflight-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge Run-Attempt lease preflight is refreshing or unavailable. Showing the last validated preview; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleRunnerDispatchPlanPreviewCard(BuildContext context) => Card(
    key: const ValueKey('forge-runner-dispatch-plan-preview-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge Runner dispatch-plan preview is refreshing or unavailable. Showing the last validated comparison; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleRunnerDispatchAdmissionCard(BuildContext context) => Card(
    key: const ValueKey('forge-runner-dispatch-admission-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge Runner dispatch admission is refreshing or unavailable. Showing the last validated recheck; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleRunnerTransportAdmissionCard(BuildContext context) => Card(
    key: const ValueKey('forge-runner-transport-admission-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge Runner transport admission is refreshing or unavailable. Showing the last validated preview; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleRunnerExecutionBoundaryCard(BuildContext context) => Card(
    key: const ValueKey('forge-runner-execution-boundary-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge Runner execution boundary is refreshing or unavailable. Showing the last validated preview; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleRunnerAttemptBoundaryCard(BuildContext context) => Card(
    key: const ValueKey('forge-runner-attempt-boundary-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge Runner Attempt boundary is refreshing or unavailable. Showing the last validated preview; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleLocalRunnerPreviewCard(BuildContext context) => Card(
    key: const ValueKey('forge-local-runner-preview-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Local Runner execution-readiness preview is refreshing or unavailable. Showing the last validated observation; it may be stale.',
        ),
      ),
    ),
  );

  Widget _staleExecutionConsentPreviewCard(BuildContext context) => Card(
    key: const ValueKey('forge-execution-consent-preview-stale'),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(
        context.tr(
          'Forge execution consent preview is refreshing or unavailable. Showing the last validated metadata; it may be stale.',
        ),
      ),
    ),
  );

  Widget _inlineError(
    BuildContext context,
    String message,
    VoidCallback onSignIn,
  ) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            context.tr(message),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        if (message == _forgeAuthRequiredMessage)
          TextButton(onPressed: onSignIn, child: Text(context.tr('Sign in'))),
      ],
    ),
  );
}

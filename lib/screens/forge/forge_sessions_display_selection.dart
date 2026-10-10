part of 'forge_sessions_screen.dart';

extension _ForgeSessionsDisplaySelection on _ForgeSessionsScreenState {
  _ForgeSessionSelection _projectSelection(_ForgeSessionInputs inputs) {
    final selectedConversationID = inputs.selectedConversationID;
    final selectedRunID = inputs.selectedRunID;
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
    return (
      schedulerSelectionPreview: schedulerSelectionPreview,
      schedulerSelectionLease: schedulerSelectionLease,
      schedulerSelectionLeaseRelease: schedulerSelectionLeaseRelease,
      clientInstanceFilterInstances: clientInstanceFilterInstances,
      clientInstanceProjectionInvalid: clientInstanceProjectionInvalid,
      selectedClientInstanceID: selectedClientInstanceID,
      visibleConversations: visibleConversations,
      selectedConversationVisible: selectedConversationVisible,
      runResourceVisible: runResourceVisible,
    );
  }
}

part of 'forge_conversations_api.dart';

extension ForgeConversationsApiSessionRunnerReconciliationProjection
    on ForgeConversationsApi {
  /// Runs the explicit two-step observation chain for one owner-bound Run:
  /// first canonicalize the caller-supplied history, then derive the manual
  /// reconciliation projection from that returned value. Both requests are
  /// stateless read-only previews; neither request retries, selects a target,
  /// creates a lease, contacts a Runner, persists a receipt, or publishes
  /// Audit state.
  Future<ForgeSessionRunnerReconciliationProjection>
  previewSessionRunnerReconciliationFromHistory({
    required String conversationID,
    required String runID,
    required ForgeSessionRunnerReceiptHistory history,
  }) async {
    final canonicalHistory = await previewSessionRunnerReceiptHistory(
      conversationID: conversationID,
      runID: runID,
      history: history,
    );
    return previewSessionRunnerReconciliationProjection(
      conversationID: conversationID,
      runID: runID,
      history: canonicalHistory,
    );
  }

  /// Derives one owner-bound, display-only reconciliation projection from a
  /// caller-supplied receipt history through the authenticated preview
  /// candidate. The route is stateless and never retries, selects a target,
  /// creates a lease, contacts a Runner, persists a receipt, or publishes
  /// Audit state.
  Future<ForgeSessionRunnerReconciliationProjection>
  previewSessionRunnerReconciliationProjection({
    required String conversationID,
    required String runID,
    required ForgeSessionRunnerReceiptHistory history,
  }) async {
    if (!_validRunRequestID(conversationID) || !_validRunRequestID(runID)) {
      throw ArgumentError.value('$conversationID/$runID', 'run IDs');
    }
    final validatedHistory = ForgeSessionRunnerReceiptHistory.fromJson(
      history.toJson(),
    );
    if (!validatedHistory.isDisplayOnly ||
        !validatedHistory.isFor(conversationID, runID)) {
      throw const FormatException(
        'Session Runner receipt history is not bound to the selected Run.',
      );
    }
    final path =
        '/conversations/${Uri.encodeComponent(conversationID)}/runs/'
        '${Uri.encodeComponent(runID)}/runner-reconciliation/preview';
    final root = await _requestJson(
      'POST',
      path,
      body: validatedHistory.toJson(),
      retryUnauthorized: false,
    );
    final returned = ForgeSessionRunnerReconciliationProjection.fromJson(root);
    if (!returned.isDisplayOnly ||
        !returned.isFor(conversationID, runID) ||
        returned.owner != validatedHistory.owner ||
        returned.source.owner != validatedHistory.owner ||
        returned.source.conversationID != validatedHistory.conversationID ||
        returned.source.promptID != validatedHistory.promptID ||
        returned.source.runID != validatedHistory.runID ||
        returned.source.attemptCount != validatedHistory.attemptCount ||
        returned.source.latestAttemptID != validatedHistory.latestAttemptID ||
        returned.source.latestCommandID != validatedHistory.latestCommandID ||
        returned.source.latestTargetID != validatedHistory.latestTargetID ||
        returned.source.latestDispositionKind !=
            validatedHistory.latestDispositionKind ||
        returned.source.latestObservedAtMS !=
            validatedHistory.latestObservedAtMS) {
      throw const FormatException(
        'Forge returned another or authority-bearing reconciliation projection.',
      );
    }
    return returned;
  }
}

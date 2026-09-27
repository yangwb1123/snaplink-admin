part of 'forge_conversations_api.dart';

extension ForgeConversationsApiRunExecutionEvidence on ForgeConversationsApi {
  /// Binds one caller-supplied Run observation to one session Runner receipt.
  /// The authenticated candidate returns content-free metadata only; it does
  /// not persist evidence, select a target, or grant execution authority.
  Future<ForgeRunExecutionEvidence> previewRunExecutionEvidence({
    required String conversationID,
    required String runID,
    required ForgeRunObserved runObserved,
    required ForgeSessionRunnerReceiptObservation sessionReceiptObserved,
  }) async {
    if (!_validRunRequestID(conversationID) || !_validRunRequestID(runID)) {
      throw ArgumentError.value('$conversationID/$runID', 'run IDs');
    }
    final validatedRun = ForgeRunObserved.fromJson(runObserved.toJson());
    final validatedReceipt = ForgeSessionRunnerReceiptObservation.fromJson(
      sessionReceiptObserved.toJson(),
    );
    if (!validatedRun.isFor(conversationID, runID) ||
        !validatedReceipt.isFor(conversationID, runID) ||
        validatedRun.promptID != validatedReceipt.promptID ||
        !validatedRun.isDisplayOnly ||
        !validatedReceipt.isDisplayOnly) {
      throw const FormatException(
        'Run execution evidence inputs are not bound to the selected Run.',
      );
    }
    final root = await _requestJson(
      'POST',
      '/conversations/${Uri.encodeComponent(conversationID)}/runs/'
          '${Uri.encodeComponent(runID)}/execution-evidence/preview',
      body: {
        'run_observed': validatedRun.toJson(),
        'session_receipt_observed': validatedReceipt.toJson(),
      },
      retryUnauthorized: false,
    );
    final evidence = ForgeRunExecutionEvidence.fromJson(root);
    final receipt = validatedReceipt.receiptObservation;
    if (!evidence.isFor(conversationID, runID) ||
        evidence.ownerRef != validatedRun.ownerRef ||
        evidence.promptID != validatedRun.promptID ||
        evidence.runStatus != validatedRun.status ||
        evidence.attemptID != receipt.attemptID ||
        evidence.targetID != receipt.targetID ||
        evidence.commandID != receipt.commandID ||
        evidence.commandSHA256 != receipt.commandSHA256 ||
        evidence.dispositionKind != receipt.dispositionKind ||
        evidence.receiptObservedAtMS != receipt.observedAtMS ||
        evidence.uncertain != receipt.uncertain ||
        evidence.reconciliationRequired != receipt.reconciliationRequired ||
        !evidence.isDisplayOnly) {
      throw const FormatException(
        'Forge returned another or authority-bearing Run execution evidence.',
      );
    }
    return evidence;
  }
}

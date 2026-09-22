part of 'forge_conversations_api.dart';

extension ForgeConversationsApiExecutionReconciliation
    on ForgeConversationsApi {
  /// Posts one caller-supplied restart image to the authenticated,
  /// metadata-only execution reconciliation candidate.
  ///
  /// This is a single POST and deliberately disables bearer refresh/replay.
  /// The production Forge session constructor does not mount this candidate
  /// route until its governance decision is accepted; a 404 therefore keeps
  /// the production execution surface closed.
  Future<ForgeExecutionReconciliationObservation>
  previewExecutionReconciliation({
    required String conversationID,
    required String runID,
    required ForgeExecutionReconciliationInput input,
  }) async {
    final validated = ForgeExecutionReconciliationInput.fromJson(
      input.toJson(),
    );
    if (!_validRunRequestID(conversationID) || !_validRunRequestID(runID)) {
      throw ArgumentError.value('$conversationID/$runID', 'run IDs');
    }
    if (!validated.isFor(conversationID, runID)) {
      throw const FormatException(
        'Forge execution reconciliation input is not bound to the selected Run.',
      );
    }
    final path =
        '/conversations/${Uri.encodeComponent(conversationID)}/runs/'
        '${Uri.encodeComponent(runID)}/execution-reconciliation/preview';
    final root = await _requestJson(
      'POST',
      path,
      body: validated.toJson(),
      retryUnauthorized: false,
    );
    final returned = ForgeExecutionReconciliationObservation.fromJson(root);
    final expected = observeForgeExecutionReconciliation(validated);
    if (!returned.isDisplayOnly ||
        !returned.isFor(conversationID, runID) ||
        returned.owner != validated.owner ||
        jsonEncode(returned.toJson()) != jsonEncode(expected.toJson())) {
      throw const FormatException(
        'Forge returned another execution reconciliation observation.',
      );
    }
    return returned;
  }
}

part of 'forge_conversations_api.dart';

extension ForgeConversationsApiSessionRunnerReceipt on ForgeConversationsApi {
  /// Sends one caller-supplied, display-only session receipt observation to
  /// the authenticated preview seam. The Coordinator only checks the owner
  /// and path binding and echoes the canonical value; it does not persist a
  /// receipt or infer execution authority.
  Future<ForgeSessionRunnerReceiptObservation>
  previewSessionRunnerReceiptObservation({
    required String conversationID,
    required String runID,
    required ForgeSessionRunnerReceiptObservation observation,
  }) async {
    if (!_validRunRequestID(conversationID) || !_validRunRequestID(runID)) {
      throw ArgumentError.value('$conversationID/$runID', 'run IDs');
    }
    if (!observation.isDisplayOnly ||
        !observation.isFor(conversationID, runID)) {
      throw const FormatException(
        'Session Runner receipt observation is not bound to the selected Run.',
      );
    }
    final path =
        '/conversations/${Uri.encodeComponent(conversationID)}/runs/'
        '${Uri.encodeComponent(runID)}/runner-receipt-observation/preview';
    final root = await _requestJson('POST', path, body: observation.toJson());
    final returned = ForgeSessionRunnerReceiptObservation.fromJson(root);
    if (!returned.isDisplayOnly ||
        !returned.isFor(conversationID, runID) ||
        returned.owner != observation.owner ||
        jsonEncode(returned.toJson()) != jsonEncode(observation.toJson())) {
      throw const FormatException(
        'Forge returned another session Runner receipt observation.',
      );
    }
    return returned;
  }
}

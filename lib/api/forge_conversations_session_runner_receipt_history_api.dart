part of 'forge_conversations_api.dart';

extension ForgeConversationsApiSessionRunnerReceiptHistory
    on ForgeConversationsApi {
  /// Reduces one caller-supplied, owner-bound receipt history through the
  /// authenticated EXECUTE preview candidate. The route is stateless and
  /// read-only: it does not read or persist receipts, issue a lease, contact a
  /// Runner, retry an uncertain attempt, or grant execution authority.
  Future<ForgeSessionRunnerReceiptHistory> previewSessionRunnerReceiptHistory({
    required String conversationID,
    required String runID,
    required ForgeSessionRunnerReceiptHistory history,
  }) async {
    if (!_validRunRequestID(conversationID) || !_validRunRequestID(runID)) {
      throw ArgumentError.value('$conversationID/$runID', 'run IDs');
    }
    final validated = ForgeSessionRunnerReceiptHistory.fromJson(
      history.toJson(),
    );
    if (!validated.isDisplayOnly || !validated.isFor(conversationID, runID)) {
      throw const FormatException(
        'Session Runner receipt history is not bound to the selected Run.',
      );
    }
    final path =
        '/conversations/${Uri.encodeComponent(conversationID)}/runs/'
        '${Uri.encodeComponent(runID)}/runner-receipt-history/preview';
    final root = await _requestJson(
      'POST',
      path,
      body: validated.toJson(),
      retryUnauthorized: false,
    );
    final returned = ForgeSessionRunnerReceiptHistory.fromJson(root);
    if (!returned.isDisplayOnly ||
        !returned.isFor(conversationID, runID) ||
        returned.owner != validated.owner ||
        jsonEncode(returned.toJson()) != jsonEncode(validated.toJson())) {
      throw const FormatException(
        'Forge returned another or authority-bearing session Runner receipt history.',
      );
    }
    return returned;
  }
}

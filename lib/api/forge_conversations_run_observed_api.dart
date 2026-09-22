part of 'forge_conversations_api.dart';

extension ForgeConversationsApiRunObserved on ForgeConversationsApi {
  /// Reads one authenticated, content-free Run observation candidate.
  ///
  /// The candidate is intentionally separate from the ordinary Run list and
  /// timeline reads: it returns only the minimized metadata evidence value and
  /// never grants device, reservation, dispatch, Runner, or execution
  /// authority. Production callers must keep this path disabled until its
  /// read-only governance decision is accepted.
  Future<ForgeRunObserved> readRunObservedCandidate({
    required String conversationID,
    required String runID,
  }) async {
    if (!_validConversationRequestID(conversationID) ||
        !_validRunRequestID(runID)) {
      throw ArgumentError.value('$conversationID/$runID', 'run IDs');
    }
    final path =
        '/conversations/${Uri.encodeComponent(conversationID)}/runs/'
        '${Uri.encodeComponent(runID)}/observation';
    // This is an opt-in status observation, not the owner session snapshot.
    // Do not replay it with a rotated bearer after a 401.
    final root = await _requestJson('GET', path, retryUnauthorized: false);
    final observed = ForgeRunObserved.fromJson(root);
    if (!observed.isFor(conversationID, runID) || !observed.isDisplayOnly) {
      throw const FormatException('Forge returned an invalid Run observation.');
    }
    return observed;
  }
}

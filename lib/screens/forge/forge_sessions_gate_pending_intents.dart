part of 'forge_sessions_gate.dart';

extension _ForgeSessionsGatePendingIntents on _ForgeSessionsGateState {
  void _configurePendingRunIntentCandidate(String? token) {
    final expectedOwner = widget.pendingRunIntentOwner;
    final origin = widget.pendingRunIntentCandidateApiOrigin;
    if (token == null ||
        !widget.enablePendingRunIntentCandidate ||
        expectedOwner == null ||
        origin == null ||
        origin.trim().isEmpty) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl: origin,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _pendingRunIntentCandidateApi = api;
    _pendingRunIntentCandidateSubmitter =
        ({
          required ForgeDeviceOwner owner,
          required conversationID,
          required content,
          required expectedVersion,
          required idempotencyKey,
        }) {
          if (owner != expectedOwner) {
            return Future<ForgePendingRunIntentSubmission>.error(
              const FormatException(
                'Forge pending Run-intent owner binding changed.',
              ),
            );
          }
          return api.submitPendingRunIntent(
            conversationID: conversationID,
            content: content,
            expectedVersion: expectedVersion,
            idempotencyKey: idempotencyKey,
          );
        };
    _pendingRunIntentCandidateReader = (conversationID) =>
        api.listPendingRunIntents(conversationID: conversationID);
    _pendingRunIntentCandidatePageReader = (conversationID, before) => api
        .listPendingRunIntents(conversationID: conversationID, before: before);
    _pendingRunIntentCandidateTimelineReader = (conversationID, intentID) =>
        api.listPendingRunIntentTimeline(
          conversationID: conversationID,
          intentID: intentID,
        );
  }

  void _configurePromptAppendReceiptCandidate(String? token) {
    final expectedOwner = widget.promptAppendReceiptOwner;
    final origin = widget.promptAppendReceiptCandidateApiOrigin;
    if (token == null ||
        !widget.enablePromptAppendReceiptCandidate ||
        widget.promptAppendReceiptSubmitter != null ||
        expectedOwner == null ||
        origin == null ||
        origin.trim().isEmpty) {
      return;
    }
    final api = ForgeConversationsApi(
      baseUrl: origin,
      accessToken: token,
      httpClient: widget.httpClient,
    );
    _promptAppendReceiptCandidateApi = api;
    _promptAppendReceiptCandidateSubmitter =
        ({
          required ForgeDeviceOwner owner,
          required conversationID,
          required content,
          required expectedVersion,
          required idempotencyKey,
        }) {
          if (owner != expectedOwner) {
            return Future<ForgePromptAppendReceiptObservation>.error(
              const FormatException(
                'Forge Prompt append receipt owner binding changed.',
              ),
            );
          }
          return api.appendPromptReceipt(
            owner: expectedOwner,
            conversationID: conversationID,
            content: content,
            expectedVersion: expectedVersion,
            idempotencyKey: idempotencyKey,
          );
        };
  }
}

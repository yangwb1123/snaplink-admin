part of 'forge_conversations_api.dart';

extension ForgeConversationsApiLocalRunnerPreview on ForgeConversationsApi {
  /// Posts one authenticated, test-only local Runner preview request.
  ///
  /// This is deliberately a single POST: it does not retry transient errors
  /// and it does not refresh/replay the bearer after a 401. The production
  /// Forge session constructor leaves the candidate route unmounted, so this
  /// call remains unavailable there (404) until a separately accepted
  /// governance decision wires an injected adapter.
  Future<ForgeLocalRunnerPreviewObservation>
  previewLocalRunnerExecutionReadiness({
    required String conversationID,
    required String intentID,
    required ForgeLocalRunnerPreviewRequest request,
  }) async {
    request.validateForPath(conversationID, intentID);
    final path =
        '/conversations/${Uri.encodeComponent(conversationID)}/run-intents/'
        '${Uri.encodeComponent(intentID)}/execution-readiness-preview';
    final root = await _requestJson(
      'POST',
      path,
      body: request.toJson(),
      retryUnauthorized: false,
    );
    return ForgeLocalRunnerPreviewObservation.fromJson(
      root,
      request: request,
      conversationID: conversationID,
      intentID: intentID,
    );
  }
}

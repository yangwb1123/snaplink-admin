part of 'forge_conversations_api.dart';

extension ForgeConversationsApiRunnerExecutionIntent on ForgeConversationsApi {
  /// Posts one owner-bound Prompt/Run/Runner command binding to the explicit
  /// metadata-only preview candidate. The candidate never selects a target,
  /// persists a command, reserves capacity, or dispatches work.
  Future<ForgeRunnerExecutionIntentObservation> previewRunnerExecutionIntent({
    required ForgeRunnerExecutionIntentRequest request,
    required String candidateOrigin,
  }) async {
    final parsedCandidateOrigin = ForgeConversationsApi._parseOrigin(
      candidateOrigin,
    );
    if (parsedCandidateOrigin != _origin) {
      throw const FormatException(
        'Forge Runner execution-intent candidate origin changed.',
      );
    }
    if (!_validConversationRequestID(request.conversationID) ||
        !_validRunRequestID(request.run.runID)) {
      throw ArgumentError.value(
        '${request.conversationID}/${request.run.runID}',
        'run IDs',
      );
    }
    final expected = observeForgeRunnerExecutionIntent(request);
    if (expected.conversationID != request.conversationID ||
        expected.runID != request.run.runID ||
        request.binding.selectedTargetID != null) {
      throw const FormatException(
        'Forge Runner execution-intent request binding is invalid.',
      );
    }
    final validatedRequest = _runnerExecutionIntentRequestJson(request);
    final path =
        '/conversations/${Uri.encodeComponent(request.conversationID)}'
        '/runs/${Uri.encodeComponent(request.run.runID)}'
        '/runner-execution-intent/preview';
    final root = await _requestJson(
      'POST',
      path,
      body: validatedRequest,
      retryUnauthorized: false,
    );
    final preview = ForgeRunnerExecutionIntentObservation.fromJson(root);
    if (!preview.isDisplayOnly ||
        !preview.isFor(request.conversationID, request.run.runID) ||
        jsonEncode(preview.toJson()) != jsonEncode(expected.toJson())) {
      throw const FormatException(
        'Forge returned another or authority-bearing Runner execution-intent preview.',
      );
    }
    return preview;
  }
}

Map<String, dynamic> _runnerExecutionIntentRequestJson(
  ForgeRunnerExecutionIntentRequest request,
) => request.toJson();

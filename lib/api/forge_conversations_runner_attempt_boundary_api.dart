part of 'forge_conversations_api.dart';

extension ForgeConversationsApiRunnerAttemptBoundary on ForgeConversationsApi {
  /// Posts one explicit owner-bound Attempt lifecycle preview. The request is
  /// strict, origin pinned, and single-shot; it never retries a 401 and the
  /// response remains preview-only with all Attempt/effect authority false.
  Future<ForgeRunnerAttemptBoundaryObservation> previewRunnerAttemptBoundary({
    required ForgeRunnerAttemptBoundaryPreviewRequest request,
    required String candidateOrigin,
  }) async {
    final parsedCandidateOrigin = ForgeConversationsApi._parseOrigin(
      candidateOrigin,
    );
    if (parsedCandidateOrigin != _origin) {
      throw const FormatException(
        'Forge Runner Attempt boundary candidate origin changed.',
      );
    }
    final validatedRequest = ForgeRunnerAttemptBoundaryPreviewRequest.fromJson(
      request.toJson(),
    );
    final root = await _requestJson(
      'POST',
      '/conversations/${Uri.encodeComponent(validatedRequest.conversationID)}'
          '/runs/${Uri.encodeComponent(validatedRequest.runID)}'
          '/runner-attempt-boundary/preview',
      body: validatedRequest.toJson(),
      retryUnauthorized: false,
    );
    final observation = ForgeRunnerAttemptBoundaryObservation.fromJson(root);
    if (!observation.isDisplayOnly ||
        !observation.isFor(
          validatedRequest.conversationID,
          validatedRequest.runID,
          validatedRequest.attemptID,
        ) ||
        observation.owner != validatedRequest.owner ||
        observation.commandID != validatedRequest.command.commandID ||
        observation.targetID != validatedRequest.command.leaseProof.targetID ||
        observation.leaseEpoch != validatedRequest.command.leaseProof.epoch ||
        observation.currentAttemptState != validatedRequest.attemptState ||
        observation.transition != validatedRequest.transition) {
      throw const FormatException(
        'Forge returned another or authority-bearing Runner Attempt boundary.',
      );
    }
    return observation;
  }
}

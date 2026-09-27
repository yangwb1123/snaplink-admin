part of 'forge_conversations_api.dart';

extension ForgeConversationsApiRunnerExecutionBoundary
    on ForgeConversationsApi {
  /// Posts one explicit owner-bound execution-boundary preview. Activation,
  /// authority, lease state, and evaluation time remain server-owned; this
  /// adapter never retries an authorization failure.
  Future<ForgeRunnerExecutionBoundaryObservation>
  previewRunnerExecutionBoundary({
    required ForgeRunnerExecutionBoundaryPreviewRequest request,
    required String candidateOrigin,
  }) async {
    final parsedCandidateOrigin = ForgeConversationsApi._parseOrigin(
      candidateOrigin,
    );
    if (parsedCandidateOrigin != _origin) {
      throw const FormatException(
        'Forge Runner execution boundary candidate origin changed.',
      );
    }
    final validatedRequest =
        ForgeRunnerExecutionBoundaryPreviewRequest.fromJson(request.toJson());
    final root = await _requestJson(
      'POST',
      '/conversations/${Uri.encodeComponent(validatedRequest.conversationID)}'
          '/runs/${Uri.encodeComponent(validatedRequest.runID)}'
          '/runner-execution-boundary/preview',
      body: validatedRequest.toJson(),
      retryUnauthorized: false,
    );
    final observation = ForgeRunnerExecutionBoundaryObservation.fromJson(root);
    final expectedTransportPath =
        '/api/v1/runners/${validatedRequest.command.leaseProof.targetID}/dispatch';
    final expectedTransportBinding =
        validatedRequest.transport.method == 'POST' &&
        validatedRequest.transport.path == expectedTransportPath &&
        validatedRequest.transport.payloadSHA256 ==
            validatedRequest.expectedPayloadSHA256;
    if (!observation.isFor(
          validatedRequest.conversationID,
          validatedRequest.runID,
          validatedRequest.attemptID,
        ) ||
        observation.owner != validatedRequest.owner ||
        observation.commandID != validatedRequest.command.commandID ||
        observation.commandSHA256 != validatedRequest.command.commandSHA256() ||
        observation.targetID != validatedRequest.command.leaseProof.targetID ||
        observation.leaseEpoch != validatedRequest.command.leaseProof.epoch ||
        observation.transportAdmissionReady != expectedTransportBinding ||
        !observation.isDisplayOnly) {
      throw const FormatException(
        'Forge returned another or authority-bearing Runner execution boundary.',
      );
    }
    return observation;
  }
}

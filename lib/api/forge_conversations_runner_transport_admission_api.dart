part of 'forge_conversations_api.dart';

extension ForgeConversationsApiRunnerTransportAdmission
    on ForgeConversationsApi {
  /// Posts one explicit owner-bound transport admission preview. The request
  /// is already a metadata-only observation from a separately reviewed
  /// verifier; this adapter never retries an authorization failure.
  Future<ForgeRunnerTransportAdmission> previewRunnerTransportAdmission({
    required ForgeRunnerTransportAdmissionRequest request,
    required String candidateOrigin,
  }) async {
    final parsedCandidateOrigin = ForgeConversationsApi._parseOrigin(
      candidateOrigin,
    );
    if (parsedCandidateOrigin != _origin) {
      throw const FormatException(
        'Forge Runner transport admission candidate origin changed.',
      );
    }
    final validatedRequest = ForgeRunnerTransportAdmissionRequest.fromJson(
      request.toJson(),
    );
    final root = await _requestJson(
      'POST',
      '/conversations/${Uri.encodeComponent(validatedRequest.conversationID)}'
          '/runs/${Uri.encodeComponent(validatedRequest.runID)}'
          '/runner-transport-admission/preview',
      body: validatedRequest.toJson(),
      retryUnauthorized: false,
    );
    final admission = ForgeRunnerTransportAdmission.fromJson(root);
    final expectedPath =
        '/api/v1/runners/${validatedRequest.command.leaseProof.targetID}/dispatch';
    final expectedTransportBinding =
        validatedRequest.transport.method == 'POST' &&
        validatedRequest.transport.path == expectedPath &&
        validatedRequest.transport.payloadSHA256 ==
            validatedRequest.expectedPayloadSHA256;
    if (!admission.isFor(
          validatedRequest.conversationID,
          validatedRequest.runID,
          validatedRequest.attemptID,
        ) ||
        admission.owner != validatedRequest.owner ||
        admission.commandID != validatedRequest.command.commandID ||
        admission.commandSHA256 != validatedRequest.command.commandSHA256() ||
        admission.targetID != validatedRequest.command.leaseProof.targetID ||
        admission.leaseEpoch != validatedRequest.command.leaseProof.epoch ||
        admission.transportPath != validatedRequest.transport.path ||
        admission.transportPayloadSHA256 !=
            validatedRequest.transport.payloadSHA256 ||
        admission.transportBindingValid != expectedTransportBinding) {
      throw const FormatException(
        'Forge returned another or authority-bearing Runner transport admission.',
      );
    }
    return admission;
  }
}

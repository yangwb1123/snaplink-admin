part of 'forge_conversations_api.dart';

extension ForgeConversationsApiRunnerDispatchAdmission
    on ForgeConversationsApi {
  /// Posts one explicit owner-bound durable lease recheck. The candidate is
  /// one-shot and metadata-only; it never retries after an authorization
  /// failure and never exposes the fencing token in its response model.
  Future<ForgeRunnerDispatchAdmission> previewRunnerDispatchAdmission({
    required ForgeRunnerDispatchAdmissionRequest request,
    required String candidateOrigin,
  }) async {
    final parsedCandidateOrigin = ForgeConversationsApi._parseOrigin(
      candidateOrigin,
    );
    if (parsedCandidateOrigin != _origin) {
      throw const FormatException(
        'Forge Runner dispatch admission candidate origin changed.',
      );
    }
    final validatedRequest = ForgeRunnerDispatchAdmissionRequest.fromJson(
      request.toJson(),
    );
    final root = await _requestJson(
      'POST',
      '/conversations/${Uri.encodeComponent(validatedRequest.conversationID)}'
          '/runs/${Uri.encodeComponent(validatedRequest.runID)}'
          '/runner-dispatch-admission/preview',
      body: validatedRequest.toJson(),
      retryUnauthorized: false,
    );
    final admission = ForgeRunnerDispatchAdmission.fromJson(root);
    if (!admission.isFor(
          validatedRequest.conversationID,
          validatedRequest.runID,
          validatedRequest.attemptID,
        ) ||
        admission.owner != validatedRequest.owner ||
        admission.commandID != validatedRequest.command.commandID ||
        admission.commandSHA256 != validatedRequest.command.commandSHA256() ||
        admission.targetID != validatedRequest.command.leaseProof.targetID ||
        admission.leaseEpoch != validatedRequest.command.leaseProof.epoch) {
      throw const FormatException(
        'Forge returned another or authority-bearing Runner dispatch admission.',
      );
    }
    return admission;
  }
}

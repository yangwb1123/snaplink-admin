part of 'forge_conversations_api.dart';

extension ForgeConversationsRunAttemptLeaseDispatchPreflightApi
    on ForgeConversationsApi {
  /// Posts one explicitly supplied Run/Attempt/lease/placement declaration to
  /// the private preflight candidate and strictly decodes its metadata-only
  /// result. The caller must inject this method into a reader; the Sessions
  /// screen never calls it by default.
  Future<ForgePreflightFixture> previewRunAttemptLeaseDispatchPreflight({
    required ForgeRunAttemptLeaseDispatchPreflightRequest request,
  }) async {
    final validatedRequest =
        ForgeRunAttemptLeaseDispatchPreflightRequest.fromJson(request.toJson());
    final path =
        '/conversations/${Uri.encodeComponent(validatedRequest.conversationID)}'
        '/runs/${Uri.encodeComponent(validatedRequest.runID)}'
        '/attempt-lease-dispatch-preflight/preview';
    final root = await _requestJson(
      'POST',
      path,
      body: validatedRequest.toJson(),
      // The candidate is a POST and must never replay caller-supplied
      // Run/Attempt/lease material after a bearer refresh. It is currently a
      // pure preview, but keeping the transport one-shot preserves the same
      // boundary if the adapter gains persistence later.
      retryUnauthorized: false,
    );
    final result = ForgePreflightFixture.fromJson(root);
    if (!result.isFor(
          validatedRequest.conversationID,
          validatedRequest.runID,
        ) ||
        result.issuer != validatedRequest.owner.issuer ||
        result.subject != validatedRequest.owner.subject ||
        result.tenantId != validatedRequest.owner.tenantID ||
        result.runStatus != validatedRequest.runStatus ||
        result.attemptId !=
            validatedRequest.dispatchPlan.runnerExecutionIntent.attemptID ||
        result.attemptState != validatedRequest.dispatchPlan.attemptState ||
        result.commandId !=
            validatedRequest.dispatchPlan.runnerExecutionIntent.commandID ||
        result.intentTargetId !=
            validatedRequest.dispatchPlan.runnerExecutionIntent.targetID ||
        result.leaseEpoch !=
            validatedRequest.dispatchPlan.lease.epoch.toInt() ||
        result.evaluatedAtMs !=
            validatedRequest.dispatchPlan.placement.evaluatedAtMS ||
        result.candidateCount !=
            validatedRequest.dispatchPlan.placement.devices.length) {
      throw const FormatException(
        'Forge returned another Run/Attempt/lease preflight.',
      );
    }
    return result;
  }
}

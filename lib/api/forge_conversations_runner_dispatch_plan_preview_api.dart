part of 'forge_conversations_api.dart';

extension ForgeConversationsApiRunnerDispatchPlanPreview
    on ForgeConversationsApi {
  /// Posts one explicitly supplied, owner-bound Runner dispatch-plan
  /// declaration to the authenticated candidate route.
  ///
  /// The candidate origin must be repeated by the caller so an opt-in adapter
  /// cannot silently redirect this POST to a production origin. The body is
  /// a declaration only: Core does not read an Attempt or lease store, select
  /// a target, reserve capacity, authorize execution, or dispatch a Runner.
  /// Unauthorized responses are one-shot and are never replayed through the
  /// bearer refresh path.
  Future<ForgeRunnerDispatchPlanPreview> previewRunnerDispatchPlan({
    required ForgeDeviceOwner owner,
    required String conversationID,
    required String runID,
    required ForgeRunAttemptLeaseDispatchPlan dispatchPlan,
    required String candidateOrigin,
  }) async {
    final parsedCandidateOrigin = ForgeConversationsApi._parseOrigin(
      candidateOrigin,
    );
    if (parsedCandidateOrigin != _origin) {
      throw const FormatException(
        'Forge Runner dispatch-plan candidate origin changed.',
      );
    }
    if (!_validConversationRequestID(conversationID) ||
        !_validRunRequestID(runID)) {
      throw ArgumentError.value('$conversationID/$runID', 'run IDs');
    }

    // Re-decode the caller declaration before sending it. This gives the
    // candidate transport the same exact-key and safe-integer boundary as the
    // cross-language request model rather than trusting mutable object fields.
    final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
    final validatedPlan = ForgeRunAttemptLeaseDispatchPlan.fromJson(
      dispatchPlan.toJson(),
    );
    final intent = validatedPlan.runnerExecutionIntent;
    if (validatedPlan.placement.owner != expectedOwner ||
        intent.owner != expectedOwner ||
        intent.conversationID != conversationID ||
        intent.runID != runID ||
        intent.targetID != validatedPlan.lease.targetID ||
        intent.attemptID != validatedPlan.lease.attemptID) {
      throw const FormatException(
        'Forge Runner dispatch-plan request has mismatched owner or identity.',
      );
    }

    final path =
        '/conversations/${Uri.encodeComponent(conversationID)}/runs/'
        '${Uri.encodeComponent(runID)}/runner-dispatch-plan-preview';
    final root = await _requestJson(
      'POST',
      path,
      body: validatedPlan.toJson(),
      retryUnauthorized: false,
    );
    final preview = ForgeRunnerDispatchPlanPreview.fromJson(root);
    if (!preview.isDisplayOnly ||
        !preview.isFor(conversationID, runID) ||
        preview.owner != expectedOwner ||
        preview.attemptID != intent.attemptID ||
        preview.attemptState != validatedPlan.attemptState ||
        preview.commandID != intent.commandID ||
        preview.commandSHA256 != intent.commandSHA256 ||
        preview.intentTargetID != intent.targetID ||
        preview.leaseEpoch != validatedPlan.lease.epoch.toInt() ||
        preview.evaluatedAtMS != validatedPlan.placement.evaluatedAtMS ||
        preview.candidateCount != validatedPlan.placement.devices.length) {
      throw const FormatException(
        'Forge returned another or authority-bearing Runner dispatch-plan preview.',
      );
    }
    return preview;
  }
}

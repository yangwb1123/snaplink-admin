part of 'forge_conversations_api.dart';

extension ForgeConversationsApiSchedulerSelectionLease
    on ForgeConversationsApi {
  /// Performs one explicit authenticated scheduler lease claim. The POST is
  /// single-shot; the supplied idempotency key is preserved for an explicit
  /// caller retry and is never generated or changed by this adapter.
  Future<ForgeSchedulerSelectionLease> claimSchedulerSelectionLease({
    required ForgeSchedulerSelectionLeaseRequest request,
    required String idempotencyKey,
    required String candidateOrigin,
  }) async {
    final parsedCandidateOrigin = ForgeConversationsApi._parseOrigin(
      candidateOrigin,
    );
    if (parsedCandidateOrigin != _origin) {
      throw const FormatException(
        'Forge scheduler lease candidate origin changed.',
      );
    }
    if (idempotencyKey.trim().isEmpty ||
        idempotencyKey.length > 256 ||
        idempotencyKey.contains(RegExp(r'[\r\n\x00]'))) {
      throw const FormatException(
        'Forge scheduler lease idempotency key is invalid.',
      );
    }
    final validatedRequest = ForgeSchedulerSelectionLeaseRequest.fromJson(
      request.toJson(),
    );
    final root = await _requestJson(
      'POST',
      '/device-placement/scheduler-lease',
      body: validatedRequest.toJson(),
      idempotencyKey: idempotencyKey,
      retryUnauthorized: false,
    );
    final lease = ForgeSchedulerSelectionLease.fromJson(root);
    if (!lease.isFor(
      validatedRequest.conversationID,
      validatedRequest.runID,
      validatedRequest.attemptID,
    )) {
      throw const FormatException(
        'Forge returned another scheduler lease binding.',
      );
    }
    return lease;
  }

  /// Renews one explicit authenticated scheduler lease proof. The request is
  /// sent once; callers retain the same idempotency key for an explicit retry.
  Future<ForgeSchedulerSelectionLease> renewSchedulerSelectionLease({
    required ForgeSchedulerSelectionLeaseRenewalRequest request,
    required String idempotencyKey,
    required String candidateOrigin,
  }) async {
    final parsedCandidateOrigin = ForgeConversationsApi._parseOrigin(
      candidateOrigin,
    );
    if (parsedCandidateOrigin != _origin) {
      throw const FormatException(
        'Forge scheduler lease renewal candidate origin changed.',
      );
    }
    if (idempotencyKey.trim().isEmpty ||
        idempotencyKey.length > 256 ||
        idempotencyKey.contains(RegExp(r'[\r\n\x00]'))) {
      throw const FormatException(
        'Forge scheduler lease renewal idempotency key is invalid.',
      );
    }
    final validatedRequest =
        ForgeSchedulerSelectionLeaseRenewalRequest.fromJson(request.toJson());
    final root = await _requestJson(
      'POST',
      '/device-placement/scheduler-lease/renew',
      body: validatedRequest.toJson(),
      idempotencyKey: idempotencyKey,
      retryUnauthorized: false,
    );
    final lease = ForgeSchedulerSelectionLease.fromJson(root);
    final expectedEpoch = validatedRequest.epoch + 1;
    if (!lease.isFor(
          validatedRequest.conversationID,
          validatedRequest.runID,
          validatedRequest.attemptID,
        ) ||
        lease.instanceID != validatedRequest.targetID ||
        lease.grant.epoch != expectedEpoch) {
      throw const FormatException(
        'Forge returned another scheduler lease renewal binding.',
      );
    }
    return lease;
  }

  /// Releases one explicit authenticated scheduler lease proof. The request
  /// is sent once; callers retain the same idempotency key for an explicit
  /// retry.
  Future<ForgeSchedulerSelectionLeaseRelease> releaseSchedulerSelectionLease({
    required ForgeSchedulerSelectionLeaseReleaseRequest request,
    required String idempotencyKey,
    required String candidateOrigin,
  }) async {
    final parsedCandidateOrigin = ForgeConversationsApi._parseOrigin(
      candidateOrigin,
    );
    if (parsedCandidateOrigin != _origin) {
      throw const FormatException(
        'Forge scheduler lease release candidate origin changed.',
      );
    }
    if (idempotencyKey.trim().isEmpty ||
        idempotencyKey.length > 256 ||
        idempotencyKey.contains(RegExp(r'[\r\n\x00]'))) {
      throw const FormatException(
        'Forge scheduler lease release idempotency key is invalid.',
      );
    }
    final validatedRequest =
        ForgeSchedulerSelectionLeaseReleaseRequest.fromJson(request.toJson());
    final root = await _requestJson(
      'POST',
      '/device-placement/scheduler-lease/release',
      body: validatedRequest.toJson(),
      idempotencyKey: idempotencyKey,
      retryUnauthorized: false,
    );
    final release = ForgeSchedulerSelectionLeaseRelease.fromJson(root);
    if (!release.isFor(
          validatedRequest.conversationID,
          validatedRequest.runID,
          validatedRequest.attemptID,
        ) ||
        release.instanceID != validatedRequest.targetID ||
        release.epoch != validatedRequest.epoch) {
      throw const FormatException(
        'Forge returned another scheduler lease release binding.',
      );
    }
    return release;
  }
}

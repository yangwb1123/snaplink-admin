part of 'forge_conversations_api.dart';

extension ForgeConversationsApiDeviceCredentialCandidate
    on ForgeConversationsApi {
  /// Posts one explicit owner-bound metadata-only credential lifecycle plan.
  ///
  /// The candidate origin is repeated at the call site so a reviewed adapter
  /// cannot silently redirect this opt-in POST to the ordinary production
  /// origin. Core derives the owner from the verified bearer; [owner] is a
  /// caller declaration used to bind the response before it is displayed.
  /// Unauthorized responses are one-shot and are never replayed through the
  /// token refresh path. The request contains no bearer or credential
  /// material, and the response is rejected if it carries any authority.
  Future<ForgeDeviceCredentialLifecycleCandidate>
  previewDeviceCredentialCandidate({
    required ForgeDeviceOwner owner,
    required ForgeDeviceCredentialLifecycleRequest request,
    required String candidateOrigin,
  }) async {
    final parsedCandidateOrigin = ForgeConversationsApi._parseOrigin(
      candidateOrigin,
    );
    if (parsedCandidateOrigin != _origin) {
      throw const FormatException('Forge credential candidate origin changed.');
    }
    final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
    final validatedRequest = ForgeDeviceCredentialLifecycleRequest.fromJson(
      request.toJson(),
    );
    final root = await _requestJson(
      'POST',
      '/device-enrollment-heartbeat/credential-candidate',
      body: validatedRequest.toJson(),
      retryUnauthorized: false,
    );
    final candidate = ForgeDeviceCredentialLifecycleCandidate.fromJson(root);
    if (candidate.owner != expectedOwner ||
        candidate.deviceID != validatedRequest.deviceID ||
        candidate.action != validatedRequest.action ||
        candidate.revision != validatedRequest.expectedDeviceRevision ||
        !candidate.isDisplayOnly) {
      throw const FormatException(
        'Forge returned another or authority-bearing credential candidate.',
      );
    }
    return candidate;
  }
}

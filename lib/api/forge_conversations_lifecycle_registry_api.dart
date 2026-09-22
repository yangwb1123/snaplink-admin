part of 'forge_conversations_api.dart';

extension ForgeConversationsApiLifecycleRegistry on ForgeConversationsApi {
  /// Reads one complete, owner-bound lifecycle registry image from the
  /// read-only Core route. The ordinary Core constructor keeps this route
  /// closed; an explicitly accepted Fabric assembly may mount the same
  /// candidate-shaped GET for inventory/observation use.
  ///
  /// The owner is a caller-supplied binding used to verify the envelope after
  /// the authenticated request. It is never placed in a query or request
  /// body, so the server must derive ownership from the verified bearer.
  /// [candidateOrigin] is required even though this API instance already has
  /// an origin. Keeping the candidate origin explicit at the call site makes
  /// it impossible for a reviewed candidate reader to silently fall back to
  /// the production origin.
  Future<ForgeDeviceEnrollmentHeartbeatLifecycleRegistry>
  readLifecycleRegistryCandidate({
    required ForgeDeviceOwner owner,
    required String candidateOrigin,
  }) async {
    final parsedCandidateOrigin = ForgeConversationsApi._parseOrigin(
      candidateOrigin,
    );
    if (parsedCandidateOrigin != _origin) {
      throw const FormatException(
        'Forge lifecycle registry candidate origin changed.',
      );
    }
    final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
    final root = await _requestJson(
      'GET',
      '/device-enrollment-heartbeat/lifecycle-registry',
      retryUnauthorized: false,
    );
    final registry = ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJson(
      root,
    );
    if (registry.owner != expectedOwner || !registry.isDisplayOnly) {
      throw const FormatException(
        'Forge returned a lifecycle registry for another owner.',
      );
    }
    return registry;
  }
}

part of 'forge_conversations_api.dart';

extension ForgeConversationsApiRegistryPlacementPreview
    on ForgeConversationsApi {
  /// Performs one explicit authenticated registry-backed placement preview.
  ///
  /// The candidate origin must be repeated by the caller so a reviewed
  /// adapter cannot silently redirect this request to the production origin.
  /// Unauthorized responses are not replayed through the token refresh path;
  /// the caller must decide whether its session remains valid.
  Future<ForgeDeviceRegistryPlacementPreview>
  previewDevicePlacementFromRegistry({
    required ForgeDeviceOwner owner,
    required ForgeDevicePlacementRequirements requirements,
    required String candidateOrigin,
  }) async {
    final parsedCandidateOrigin = ForgeConversationsApi._parseOrigin(
      candidateOrigin,
    );
    if (parsedCandidateOrigin != _origin) {
      throw const FormatException(
        'Forge registry placement candidate origin changed.',
      );
    }
    final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
    final validatedRequirements = ForgeDevicePlacementRequirements.fromJson(
      requirements.toJson(),
    );
    final root = await _requestJson(
      'POST',
      '/device-placement/registry-preview',
      body: {'requirements': validatedRequirements.toJson()},
      retryUnauthorized: false,
    );
    final preview = ForgeDeviceRegistryPlacementPreview.fromJson(root);
    if (preview.evaluationOwner != expectedOwner ||
        !identical(preview.selectedDeviceID, null) ||
        !identical(preview.selectedInstanceID, null) ||
        preview.authority.anyGranted) {
      throw const FormatException(
        'Forge returned another or authority-bearing registry placement preview.',
      );
    }
    return preview;
  }
}

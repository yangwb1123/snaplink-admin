part of 'forge_conversations_api.dart';

extension ForgeConversationsApiSchedulerSelectionPreview
    on ForgeConversationsApi {
  /// Performs one explicit authenticated scheduler-selection preview.
  ///
  /// The candidate origin is repeated by the caller so an opted-in adapter
  /// cannot silently redirect this request to another service. The POST is
  /// intentionally single-shot: an uncertain response must not be replayed.
  Future<ForgeSchedulerSelectionPreview> previewSchedulerSelection({
    required ForgeSchedulerSelectionPreviewRequest request,
    required String candidateOrigin,
  }) async {
    final parsedCandidateOrigin = ForgeConversationsApi._parseOrigin(
      candidateOrigin,
    );
    if (parsedCandidateOrigin != _origin) {
      throw const FormatException(
        'Forge scheduler selection candidate origin changed.',
      );
    }
    final validatedRequest = ForgeSchedulerSelectionPreviewRequest.fromJson(
      request.toJson(),
    );
    final root = await _requestJson(
      'POST',
      '/device-placement/scheduler-preview',
      body: validatedRequest.toJson(),
      retryUnauthorized: false,
    );
    final preview = ForgeSchedulerSelectionPreview.fromJson(root);
    if (preview.conversationID != validatedRequest.conversationID ||
        preview.runID != validatedRequest.runID ||
        preview.attemptID != validatedRequest.attemptID ||
        !preview.previewOnly ||
        preview.authority.anyGranted) {
      throw const FormatException(
        'Forge returned another or authority-bearing scheduler selection preview.',
      );
    }
    return preview;
  }
}

part of 'forge_conversations_api.dart';

extension ForgeConversationsApiExecutionConsent on ForgeConversationsApi {
  /// Reads the owner-scoped execution profile preview for one Conversation.
  ///
  /// This candidate is intentionally read-only. A successful response only
  /// describes the server-selected project/profile and the maximum consent
  /// lifetime; it does not grant consent or enable Run/device execution.
  /// Production Forge keeps this route behind the execution governance gate.
  Future<ForgeExecutionConsentPreview> getExecutionConsentPreview({
    required String conversationID,
    bool retryUnauthorized = true,
  }) async {
    if (!_validConversationRequestID(conversationID)) {
      throw ArgumentError.value(conversationID, 'conversationID');
    }
    final path =
        '/conversations/${Uri.encodeComponent(conversationID)}'
        '/execution-consents';
    final root = await _requestJson(
      'GET',
      path,
      retryUnauthorized: retryUnauthorized,
    );
    final preview = ForgeExecutionConsentPreview.fromJson(root);
    if (preview.conversationID != conversationID) {
      throw const FormatException(
        'Forge returned an execution consent preview for another conversation.',
      );
    }
    return preview;
  }
}

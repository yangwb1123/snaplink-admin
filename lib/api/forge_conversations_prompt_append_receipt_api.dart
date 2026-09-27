part of 'forge_conversations_api.dart';

extension ForgeConversationsApiPromptAppendReceipt on ForgeConversationsApi {
  /// Appends one owner-scoped user Prompt and returns only its content-free
  /// compatibility receipt.
  ///
  /// The authenticated `/prompts` write remains the single Prompt operation;
  /// this adapter consumes its strict response and immediately projects the
  /// result into `forge.prompt-append-receipt/v1`. Prompt content is required
  /// by the existing append API but is never present in the returned value or
  /// any receipt JSON. The POST is single-shot, including on 401, because an
  /// uncertain write must not be replayed by this metadata consumer.
  Future<ForgePromptAppendReceiptObservation> appendPromptReceipt({
    required ForgeDeviceOwner owner,
    required String conversationID,
    required String content,
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    final validatedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
    if (!_validConversationRequestID(conversationID)) {
      throw ArgumentError.value(conversationID, 'conversationID');
    }
    if (content.trim().isEmpty ||
        utf8.encode(content).length > forgePromptAppendReceiptMaxContentBytes) {
      throw ArgumentError.value(content, 'content');
    }
    if (!_validIdempotencyKey(idempotencyKey) ||
        utf8.encode(idempotencyKey).length >
            forgePromptAppendReceiptMaxIdempotencyKeyBytes) {
      throw ArgumentError.value(idempotencyKey, 'idempotencyKey');
    }
    if (expectedVersion < 1 ||
        expectedVersion > forgePromptAppendReceiptMaxSafeInteger) {
      throw ArgumentError.value(expectedVersion, 'expectedVersion');
    }
    final path =
        '/conversations/${Uri.encodeComponent(conversationID)}/prompts';
    final root = await _requestJson(
      'POST',
      path,
      body: {'content': content, 'expected_version': expectedVersion},
      idempotencyKey: idempotencyKey,
      retryUnauthorized: false,
      expectedStatuses: const {200, 201},
    );
    final result = ForgePromptAppendResult.fromJson(root);
    final nextVersion = expectedVersion + 1;
    if (result.prompt.conversationID != conversationID ||
        result.prompt.role != 'user' ||
        result.prompt.content != content ||
        result.aggregateVersion != nextVersion) {
      throw const FormatException(
        'Forge returned an append receipt with invalid owner/CAS binding.',
      );
    }
    final receipt = ForgePromptAppendReceiptObservation.fromInput(
      owner: validatedOwner,
      conversationID: conversationID,
      expectedVersion: expectedVersion,
      content: content,
      idempotencyKey: idempotencyKey,
      promptID: result.prompt.id,
      createdAtMS: result.prompt.createdAtMS,
      replayed: result.replayed,
    );
    if (receipt.request.conversationID != conversationID ||
        receipt.request.expectedVersion != expectedVersion ||
        receipt.receipt.aggregateVersion != result.aggregateVersion ||
        receipt.receipt.promptID != result.prompt.id ||
        !receipt.isDisplayOnly ||
        receipt.receipt.contentIncluded ||
        !receipt.receipt.storageCommitObserved) {
      throw const FormatException(
        'Forge returned an invalid content-free Prompt append receipt.',
      );
    }
    return receipt;
  }
}

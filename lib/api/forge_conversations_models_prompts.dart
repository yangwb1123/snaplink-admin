part of 'forge_conversations_models.dart';

class ForgePromptCursor {
  final int createdAtMS;
  final String promptID;

  const ForgePromptCursor({required this.createdAtMS, required this.promptID});

  factory ForgePromptCursor.fromJson(ForgeJson json) {
    _requireExactKeys(json, const {'created_at_ms', 'prompt_id'});
    final createdAtMS = _requiredNonNegativeInt(json, 'created_at_ms');
    final promptID = _requiredExactText(json, 'prompt_id');
    if (createdAtMS > _maxSafeForgeCursor || !_validFeedID(promptID)) {
      throw const FormatException('Invalid Forge prompt cursor.');
    }
    return ForgePromptCursor(createdAtMS: createdAtMS, promptID: promptID);
  }
}

class ForgeConversationPrompt {
  final String id;
  final String conversationID;
  final String role;
  final String content;
  final int createdAtMS;

  const ForgeConversationPrompt({
    required this.id,
    required this.conversationID,
    required this.role,
    required this.content,
    required this.createdAtMS,
  });

  factory ForgeConversationPrompt.fromJson(ForgeJson json) {
    _requireExactKeys(json, const {
      'id',
      'conversation_id',
      'role',
      'content',
      'created_at_ms',
    });
    final createdAtMS = _requiredNonNegativeInt(json, 'created_at_ms');
    if (createdAtMS > _maxSafeForgeCursor) {
      throw const FormatException('Invalid Forge prompt.');
    }
    return ForgeConversationPrompt(
      id: _requiredExactText(json, 'id'),
      conversationID: _requiredExactText(json, 'conversation_id'),
      role: _requiredExactText(json, 'role'),
      content: _requiredExactText(json, 'content'),
      createdAtMS: createdAtMS,
    );
  }
}

class ForgeConversationPromptPage {
  final String conversationID;
  final List<ForgeConversationPrompt> prompts;
  final ForgePromptCursor? nextCursor;
  final bool hasMore;

  const ForgeConversationPromptPage({
    required this.conversationID,
    required this.prompts,
    required this.nextCursor,
    required this.hasMore,
  });

  factory ForgeConversationPromptPage.fromJson(
    ForgeJson json, {
    int limit = _maxForgePromptPageSize,
  }) {
    const required = {'conversation_id', 'prompts', 'has_more'};
    const allowed = {...required, 'next_cursor'};
    if (!required.every(json.containsKey) ||
        json.keys.any((key) => !allowed.contains(key))) {
      throw const FormatException('Forge returned unexpected response fields.');
    }
    if (limit < 1 || limit > _maxForgePromptPageSize) {
      throw const FormatException('Invalid Forge prompt page limit.');
    }
    final raw = json['prompts'];
    if (raw is! List || raw.any((value) => value is! Map)) {
      throw const FormatException('Invalid Forge prompt page.');
    }
    final rawCursor = json['next_cursor'];
    final cursor = rawCursor == null
        ? null
        : ForgePromptCursor.fromJson(_asObject(rawCursor));
    final hasMore = json['has_more'];
    if (hasMore is! bool) {
      throw const FormatException('Invalid Forge prompt page.');
    }
    final page = ForgeConversationPromptPage(
      conversationID: _requiredExactText(json, 'conversation_id'),
      prompts: List.unmodifiable(
        raw.map(
          (value) => ForgeConversationPrompt.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        ),
      ),
      nextCursor: cursor,
      hasMore: hasMore,
    );
    _validateForgePromptPage(page, limit);
    return page;
  }
}

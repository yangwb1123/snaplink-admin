part of 'forge_conversations_models.dart';

void _validateForgePromptPage(ForgeConversationPromptPage page, int limit) {
  if (page.conversationID.trim().isEmpty || page.prompts.length > limit) {
    throw const FormatException('Invalid Forge prompt page.');
  }
  var contentBytes = 0;
  ForgeConversationPrompt? previous;
  final promptIDs = <String>{};
  for (final prompt in page.prompts) {
    final idBytes = utf8.encode(prompt.id).length;
    final roleBytes = utf8.encode(prompt.role).length;
    final promptBytes = utf8.encode(prompt.content).length;
    if (prompt.conversationID != page.conversationID ||
        prompt.id.trim().isEmpty ||
        idBytes > _maxForgePromptIDBytes ||
        prompt.id.runes.any(_isForgeControlRune) ||
        prompt.role.isEmpty ||
        roleBytes > _maxForgePromptRoleBytes ||
        promptBytes > _maxForgePromptContentBytes ||
        !promptIDs.add(prompt.id)) {
      throw const FormatException('Invalid Forge prompt page.');
    }
    contentBytes += promptBytes;
    if (contentBytes > _maxForgePromptContentBytes ||
        (previous != null &&
            (previous.createdAtMS < prompt.createdAtMS ||
                (previous.createdAtMS == prompt.createdAtMS &&
                    _compareForgePromptIDs(previous.id, prompt.id) <= 0)))) {
      throw const FormatException('Invalid Forge prompt page.');
    }
    previous = prompt;
  }

  final cursor = page.nextCursor;
  if (page.hasMore) {
    if (page.prompts.isEmpty ||
        cursor == null ||
        cursor.createdAtMS != page.prompts.last.createdAtMS ||
        cursor.promptID != page.prompts.last.id) {
      throw const FormatException('Invalid Forge prompt page cursor.');
    }
  } else if (cursor != null) {
    throw const FormatException('Invalid Forge prompt page cursor.');
  }
}

bool _isForgeControlRune(int rune) =>
    rune < 0x20 || (rune >= 0x7f && rune <= 0x9f);

int _compareForgePromptIDs(String left, String right) {
  final leftBytes = utf8.encode(left);
  final rightBytes = utf8.encode(right);
  final sharedLength = leftBytes.length < rightBytes.length
      ? leftBytes.length
      : rightBytes.length;
  for (var index = 0; index < sharedLength; index++) {
    final difference = leftBytes[index] - rightBytes[index];
    if (difference != 0) return difference;
  }
  return leftBytes.length.compareTo(rightBytes.length);
}

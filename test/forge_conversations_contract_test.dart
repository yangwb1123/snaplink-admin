import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_conversations_models.dart';

void main() {
  final fixturePath = Platform.environment['FORGE_CONTRACT_FIXTURE'];
  final sessionFixturePath =
      Platform.environment['FORGE_SESSION_CONTRACT_FIXTURE'];

  test(
    'accepts the shared owner-scoped conversation page fixture',
    () {
      final json = jsonDecode(File(fixturePath!).readAsStringSync());
      final page = ForgeConversationPage.fromJson(
        Map<String, dynamic>.from(json as Map),
        limit: 128,
      );

      expect(page.conversations, hasLength(2));
      expect(page.conversations.first.conversation.id, 'conversation-001');
      expect(
        page.conversations.first.conversation.scope.label,
        'project · project-7',
      );
      expect(page.conversations.last.conversation.scope.kind, 'global');
      expect(page.hasMore, isFalse);
      expect(page.nextAfterID, isNull);
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'accepts the shared session list, history, feed, and append fixtures',
    () {
      final root =
          jsonDecode(File(sessionFixturePath!).readAsStringSync()) as Map;
      final fixture = Map<String, dynamic>.from(root);
      expect(fixture.keys.toSet(), {
        'conversation_page',
        'conversation_detail',
        'prompt_page',
        'change_page',
        'append_prompt',
      });
      final conversationPage = ForgeConversationPage.fromJson(
        Map<String, dynamic>.from(fixture['conversation_page'] as Map),
        limit: 2,
      );
      final conversationDetail = ForgeOwnedConversation.fromJson(
        Map<String, dynamic>.from(fixture['conversation_detail'] as Map),
      );
      final promptPage = ForgeConversationPromptPage.fromJson(
        Map<String, dynamic>.from(fixture['prompt_page'] as Map),
        limit: 2,
      );
      final changePage = ForgeConversationChangePage.fromJson(
        Map<String, dynamic>.from(fixture['change_page'] as Map),
        requestedAfterCursor: 0,
        limit: 2,
      );
      final append = ForgePromptAppendResult.fromJson(
        Map<String, dynamic>.from(fixture['append_prompt'] as Map),
      );

      expect(conversationPage.conversations, hasLength(2));
      expect(conversationDetail.conversation.id, 'conversation-001');
      expect(conversationDetail.aggregateVersion, 2);
      expect(promptPage.conversationID, 'conversation-001');
      expect(promptPage.prompts.first.id, 'prompt-002');
      expect(promptPage.nextCursor?.promptID, 'prompt-001');
      expect(changePage.changes, hasLength(2));
      expect(changePage.scannedThroughCursor, 2);
      expect(append.prompt.conversationID, 'conversation-001');
      expect(append.aggregateVersion, 3);
      expect(append.replayed, isFalse);
    },
    skip: sessionFixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );
}

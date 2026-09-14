import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_conversations_models.dart';

Map<String, Object> _historyPrompt(
  String id,
  int createdAtMS, {
  String content = 'prompt',
}) => {
  'id': id,
  'conversation_id': 'conversation-1',
  'role': 'user',
  'content': content,
  'created_at_ms': createdAtMS,
};

void main() {
  test('parses an owner-scoped conversation page and pagination cursor', () {
    final page = ForgeConversationPage.fromJson(
      {
        'conversations': [
          {
            'conversation': {
              'id': 'conversation-1',
              'scope': {'kind': 'project', 'id': 'project-7'},
              'title': 'Build release',
              'created_at_ms': 100,
              'updated_at_ms': 200,
            },
            'aggregate_version': 3,
          },
        ],
        'next_after_id': 'conversation-1',
        'has_more': true,
      },
      limit: 1,
      afterID: 'conversation-0',
    );

    expect(page.conversations.single.conversation.id, 'conversation-1');
    expect(
      page.conversations.single.conversation.scope.label,
      'project · project-7',
    );
    expect(page.conversations.single.aggregateVersion, 3);
    expect(page.nextAfterID, 'conversation-1');
    expect(page.hasMore, isTrue);
    expect(() => page.conversations.clear(), throwsUnsupportedError);
  });

  test('parses prompt history cursors and append versions', () {
    final page = ForgeConversationPromptPage.fromJson({
      'conversation_id': 'conversation-1',
      'prompts': [
        {
          'id': 'prompt-1',
          'conversation_id': 'conversation-1',
          'role': 'user',
          'content': 'run tests',
          'created_at_ms': 300,
        },
      ],
      'next_cursor': {'created_at_ms': 300, 'prompt_id': 'prompt-1'},
      'has_more': true,
    });
    final appended = ForgePromptAppendResult.fromJson({
      'prompt': {
        'id': 'prompt-2',
        'conversation_id': 'conversation-1',
        'role': 'user',
        'content': 'ship it',
        'created_at_ms': 400,
      },
      'aggregate_version': 4,
      'replayed': false,
    });

    expect(page.prompts.single.content, 'run tests');
    expect(page.nextCursor?.createdAtMS, 300);
    expect(page.nextCursor?.promptID, 'prompt-1');
    expect(page.hasMore, isTrue);
    expect(appended.prompt.role, 'user');
    expect(appended.aggregateVersion, 4);
    expect(appended.replayed, isFalse);
  });

  test('accepts a content-budget partial page and rejects bad cursors', () {
    final large = 'x' * (200 * 1024);
    final page = ForgeConversationPromptPage.fromJson({
      'conversation_id': 'conversation-1',
      'prompts': [_historyPrompt('prompt-2', 20, content: large)],
      'next_cursor': {'created_at_ms': 20, 'prompt_id': 'prompt-2'},
      'has_more': true,
    });
    expect(page.prompts, hasLength(1));
    expect(page.hasMore, isTrue);

    expect(
      () => ForgeConversationPromptPage.fromJson({
        'conversation_id': 'conversation-1',
        'prompts': [_historyPrompt('prompt-2', 20, content: large)],
        'next_cursor': {'created_at_ms': 19, 'prompt_id': 'prompt-2'},
        'has_more': true,
      }),
      throwsFormatException,
    );
    expect(
      () => ForgeConversationPromptPage.fromJson({
        'conversation_id': 'conversation-1',
        'prompts': [
          _historyPrompt('prompt-2', 20, content: large),
          _historyPrompt('prompt-1', 10, content: 'y' * (80 * 1024)),
        ],
        'next_cursor': {'created_at_ms': 10, 'prompt_id': 'prompt-1'},
        'has_more': true,
      }),
      throwsFormatException,
    );
  });

  test('accepts only dense owner-local replay progress', () {
    Map<String, Object> change(int cursor) => {
      'cursor': cursor,
      'schema_version': 1,
      'conversation_id': 'conversation-1',
      'entity_id': 'prompt-$cursor',
      'aggregate_version': cursor,
      'kind': 'prompt_appended',
      'created_at_ms': cursor,
    };

    final page = ForgeConversationChangePage.fromJson(
      {
        'after_cursor': 4,
        'scanned_through_cursor': 6,
        'has_more': true,
        'changes': [change(5), change(6)],
      },
      requestedAfterCursor: 4,
      limit: 2,
    );
    expect(page.scannedThroughCursor, 6);
    expect(page.changes.length, 2);

    for (final response in [
      {
        'after_cursor': 4,
        'scanned_through_cursor': 6,
        'has_more': false,
        'changes': [change(6)],
      },
      {
        'after_cursor': 4,
        'scanned_through_cursor': 5,
        'has_more': false,
        'changes': <Object>[],
      },
      {
        'after_cursor': 4,
        'scanned_through_cursor': 5,
        'has_more': true,
        'changes': [change(5)],
      },
    ]) {
      expect(
        () => ForgeConversationChangePage.fromJson(
          response,
          requestedAfterCursor: 4,
          limit: 2,
        ),
        throwsFormatException,
      );
    }
  });

  test('rejects unknown or structurally invalid scope and version values', () {
    expect(
      () => ForgeConversationScope.fromJson({'kind': 'device'}),
      throwsFormatException,
    );
    expect(
      () => ForgeConversationScope.fromJson({'kind': 'global', 'id': 'g1'}),
      throwsFormatException,
    );
    expect(
      () => ForgeConversationScope.fromJson({'kind': 'project'}),
      throwsFormatException,
    );
    expect(
      () => ForgeConversationPage.fromJson({
        'conversations': [],
        'next_after_id': '',
        'has_more': false,
      }),
      throwsFormatException,
    );
    expect(
      () => ForgeOwnedConversation.fromJson({
        'conversation': {
          'id': 'conversation-1',
          'scope': {'kind': 'global'},
          'title': 'Build',
          'created_at_ms': 1,
          'updated_at_ms': 1,
        },
        'aggregate_version': 0,
      }),
      throwsFormatException,
    );
  });

  test('rejects conversation pages with inconsistent pagination or fields', () {
    final entry = {
      'conversation': {
        'id': 'conversation-1',
        'scope': {'kind': 'global'},
        'title': 'Build',
        'created_at_ms': 1,
        'updated_at_ms': 1,
      },
      'aggregate_version': 1,
    };
    final page = {
      'conversations': [entry],
      'next_after_id': 'conversation-1',
      'has_more': true,
    };

    expect(
      () => ForgeConversationPage.fromJson(page, limit: 2),
      throwsFormatException,
    );
    expect(
      () => ForgeConversationPage.fromJson({
        ...page,
        'next_after_id': 'conversation-2',
      }, limit: 1),
      throwsFormatException,
    );
    expect(
      () => ForgeConversationPage.fromJson({
        ...page,
        'unexpected': true,
      }, limit: 1),
      throwsFormatException,
    );
    expect(
      () => ForgeConversationPage.fromJson(
        page,
        limit: 1,
        afterID: 'conversation-1',
      ),
      throwsFormatException,
    );
  });
}

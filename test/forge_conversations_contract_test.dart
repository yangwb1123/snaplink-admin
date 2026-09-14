import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_conversations_models.dart';

void main() {
  final fixturePath = Platform.environment['FORGE_CONTRACT_FIXTURE'];

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
}

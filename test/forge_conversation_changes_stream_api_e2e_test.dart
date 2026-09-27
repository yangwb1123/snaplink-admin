import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';

class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath = Platform
      .environment['FORGE_CONVERSATION_CHANGES_STREAM_CONSOLE_E2E_INPUT'];

  test(
    'Flutter consumes one authenticated Conversation SSE page',
    () async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final api = ForgeConversationsApi(
        baseUrl: apiURL,
        accessToken: accessToken,
        timeout: const Duration(seconds: 5),
      );
      try {
        final page = await api.conversationChangesStream(
          afterCursor: 0,
          limit: 128,
          waitMS: 0,
        );
        expect(page, isNotNull);
        expect(page!.afterCursor, 0);
        expect(page.scannedThroughCursor, 1);
        expect(page.hasMore, isFalse);
        expect(page.changes, hasLength(1));
        expect(
          page.changes.single.conversationID,
          'console-stream-conversation',
        );
        expect(page.changes.single.kind, 'conversation_created');
      } finally {
        api.close();
      }
    },
    skip: inputPath == null
        ? 'Run through the opt-in real Snaplink JWT Console SSE harness.'
        : false,
  );
}

Map<String, dynamic> _readInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException(
      'Invalid Conversation change stream Console E2E input.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing Conversation change stream $key.');
  }
  return value;
}

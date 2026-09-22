import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';

class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath = Platform.environment['FORGE_CONSOLE_E2E_INPUT'];

  testWidgets(
    'Console Sessions renders owner-scoped pending Run-intent metadata over HTTP',
    (tester) async {
      final input = Map<String, dynamic>.from(
        jsonDecode(File(inputPath!).readAsStringSync()) as Map,
      );
      final apiURL = input['api_url'];
      final accessToken = input['access_token'];
      final conversationID = input['conversation_id'];
      final pendingIntentID = input['pending_intent_id'];
      if (apiURL is! String ||
          accessToken is! String ||
          conversationID is! String ||
          pendingIntentID is! String ||
          pendingIntentID.isEmpty) {
        throw const FormatException(
          'Invalid Forge pending Run-intent widget E2E input.',
        );
      }

      final api = ForgeConversationsApi(
        baseUrl: apiURL,
        accessToken: accessToken,
      );
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: ForgeSessionsScreen(
              accessToken: accessToken,
              apiOrigin: apiURL,
              pendingRunIntentReader: (requestedConversationID) {
                if (requestedConversationID != conversationID) {
                  throw const FormatException(
                    'Pending Run-intent conversation binding drift.',
                  );
                }
                return api.listPendingRunIntents(
                  conversationID: requestedConversationID,
                );
              },
              pendingRunIntentTimelineReader:
                  (requestedConversationID, requestedIntentID) {
                    if (requestedConversationID != conversationID ||
                        requestedIntentID != pendingIntentID) {
                      throw const FormatException(
                        'Pending Run-intent timeline binding drift.',
                      );
                    }
                    return api.listPendingRunIntentTimeline(
                      conversationID: requestedConversationID,
                      intentID: requestedIntentID,
                    );
                  },
            ),
          ),
        );
        await _pumpUntil(
          tester,
          () => find
              .byKey(const ValueKey('forge-pending-run-intent-metadata-card'))
              .evaluate()
              .isNotEmpty,
          waitFor: 'pending Run-intent metadata panel',
        );
        expect(
          find.byKey(const ValueKey('forge-pending-run-intent-metadata-card')),
          findsOneWidget,
        );
        expect(find.text(pendingIntentID), findsOneWidget);
        expect(
          find.text(
            'Read-only receipt metadata. Prompt content is hidden and no Run was started.',
          ),
          findsOneWidget,
        );
        final timelineTile = find.byKey(
          ValueKey('forge-pending-run-intent-timeline-$pendingIntentID'),
        );
        final timelineTitle = find.descendant(
          of: timelineTile,
          matching: find.text('Timeline metadata'),
        );
        for (var attempt = 0; attempt < 6; attempt++) {
          final rect = tester.getRect(timelineTitle);
          if (rect.top >= 0 && rect.bottom <= 600) break;
          await tester.drag(find.byType(ListView), const Offset(0, -400));
          await tester.pumpAndSettle();
        }
        await tester.tap(timelineTitle);
        await _pumpUntil(
          tester,
          () => find.text('Event').evaluate().isNotEmpty,
          waitFor: 'pending Run-intent timeline metadata',
        );
        expect(find.text('submitted'), findsWidgets);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      } finally {
        api.close();
      }
    },
    skip: inputPath == null,
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String waitFor,
}) async {
  for (var count = 0; count < 250; count++) {
    if (condition()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(
    condition(),
    isTrue,
    reason: 'Timed out waiting for $waitFor from the live pending-intent API.',
  );
}

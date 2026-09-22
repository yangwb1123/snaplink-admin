import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_attempt_request_preview.dart';
import 'package:sso_admin/screens/forge/forge_attempt_request_preview_card.dart';

void main() {
  final fixturePath = Platform.environment['FORGE_ATTEMPT_REQUEST_FIXTURE'];

  testWidgets(
    'renders a read-only Attempt request preview without actions',
    (tester) async {
      final fixture = ForgeAttemptRequestPreviewFixture.fromJsonText(
        File(fixturePath!).readAsStringSync(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SingleChildScrollView(
            child: ForgeAttemptRequestPreviewCard(fixture: fixture),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('forge-attempt-request-preview-card')),
        findsOneWidget,
      );
      expect(find.text('Attempt request preview'), findsOneWidget);
      expect(find.text('Schema'), findsOneWidget);
      expect(find.text(forgeAttemptRequestSchema), findsOneWidget);
      expect(find.text('valid_normalizes_order'), findsOneWidget);
      expect(find.text('read.repo, write.file'), findsNWidgets(18));
      expect(find.text('Authority granted'), findsOneWidget);
      expect(find.text('false'), findsWidgets);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    },
    skip: fixturePath == null,
  );
}

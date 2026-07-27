import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/error_boundary.dart';

void main() {
  group('ErrorBoundary', () {
    testWidgets('shows child when no error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ErrorBoundary(child: Text('Hello'))),
        ),
      );
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('shows custom label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorBoundary(
              label: 'Custom error',
              child: const Text('Hello'),
            ),
          ),
        ),
      );
      // Initially shows child
      expect(find.text('Hello'), findsOneWidget);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';

void main() {
  group('ConfirmDialog', () {
    testWidgets('shows title and message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ConfirmDialog.show(
                  context,
                  title: 'Delete?',
                  message: 'Are you sure?',
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      expect(find.text('Delete?'), findsOneWidget);
      expect(find.text('Are you sure?'), findsOneWidget);
    });

    testWidgets('confirm button closes dialog', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await ConfirmDialog.show(
                    context,
                    title: 'Confirm?',
                    message: 'Proceed?',
                  );
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(result, true);
    });

    testWidgets('cancel button closes dialog', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await ConfirmDialog.show(
                    context,
                    title: 'Cancel?',
                    message: 'Cancel?',
                  );
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, false);
    });

    testWidgets('destructive style applies red button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ConfirmDialog.show(
                  context,
                  title: 'Delete',
                  message: 'Delete?',
                  destructive: true,
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Confirm'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(
        button.style?.backgroundColor?.resolve({}),
        AppColors.danger,
      );
    });

    testWidgets('type-to-confirm requires matching text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ConfirmDialog.show(
                  context,
                  title: 'Delete client',
                  message: 'Type the client ID to confirm.',
                  destructive: true,
                  confirmText: 'my-client',
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Confirm button should be disabled initially
      expect(find.text('Confirm'), findsOneWidget);

      // Type wrong text - button should remain disabled
      await tester.enterText(find.byType(TextField), 'wrong');
      await tester.pumpAndSettle();
      final button1 = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Confirm'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button1.onPressed, isNull);

      // Type correct text - button should enable
      await tester.enterText(find.byType(TextField), 'my-client');
      await tester.pumpAndSettle();
      final button2 = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Confirm'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button2.onPressed, isNotNull);
    });

    testWidgets('danger action tile forwards its resource confirmation text', (
      tester,
    ) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DangerActionTile(
              label: 'Revoke resource',
              confirmTitle: 'Revoke?',
              confirmMessage: 'This is immediate.',
              confirmText: 'resource-1',
              onConfirmed: () => called = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Revoke resource'));
      await tester.pumpAndSettle();
      final confirm = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Revoke resource'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(confirm.onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'resource-1');
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Revoke resource'),
        ),
      );
      await tester.pumpAndSettle();

      expect(called, isTrue);
    });
  });
}

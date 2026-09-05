import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/admin/client_detail_secret_card.dart';

void main() {
  testWidgets('R211: non-copyable secret keeps reveal control accessible', (
    tester,
  ) async {
    const secret = 'fixture-secret-value';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ClientSecretDialog(
            secret: secret,
            introKey: 'Intro',
            acknowledgeKey: 'Acknowledge',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final semantics = tester.ensureSemantics();
    final hideControl = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Hide',
    );
    expect(find.byType(IconButton), findsOneWidget);
    expect(
      tester.getSize(hideControl),
      const Size(kMinInteractiveDimension, kMinInteractiveDimension),
    );
    expect(
      tester.getSize(find.byIcon(Icons.visibility_off_outlined)),
      const Size(24, 24),
    );
    expect(find.byTooltip('Hide'), findsOneWidget);
    expect(find.byTooltip('Copy to clipboard'), findsNothing);
    expect(
      tester.getSemantics(hideControl),
      matchesSemantics(
        tooltip: 'Hide',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );

    // The existing default is revealed; masking is local and does not expose
    // the sensitive value through the hidden state's semantics.
    expect(find.text(secret), findsOneWidget);
    await tester.tap(hideControl);
    await tester.pump();
    expect(find.text(secret), findsNothing);
    expect(find.bySemanticsLabel(secret), findsNothing);
    expect(find.byTooltip('Show'), findsOneWidget);

    final showControl = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Show',
    );
    expect(
      tester.getSize(showControl),
      const Size(kMinInteractiveDimension, kMinInteractiveDimension),
    );
    expect(
      tester.getSemantics(showControl),
      matchesSemantics(
        tooltip: 'Show',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    await tester.tap(showControl);
    await tester.pump();
    expect(find.text(secret), findsOneWidget);
    expect(find.byTooltip('Hide'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'R211: copyable secret has independent 48px controls and copy feedback',
    (tester) async {
      const secret = 'fixture-secret-value';
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<Object?, Object?>;
            clipboardText = args['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClientSecretDialog(
              secret: secret,
              introKey: 'Intro',
              acknowledgeKey: 'Acknowledge',
              copyable: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semantics = tester.ensureSemantics();
      final hideControl = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Hide',
      );
      final copyControl = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.tooltip == 'Copy to clipboard',
      );
      expect(find.byType(IconButton), findsNWidgets(2));
      expect(
        tester.getSize(find.byIcon(Icons.visibility_off_outlined)),
        const Size(24, 24),
      );
      expect(
        tester.getSize(find.byIcon(Icons.copy_outlined)),
        const Size(24, 24),
      );
      for (final control in [hideControl, copyControl]) {
        expect(
          tester.getSize(control),
          const Size(kMinInteractiveDimension, kMinInteractiveDimension),
        );
        expect(
          tester.getSemantics(control),
          matchesSemantics(
            tooltip: control == hideControl ? 'Hide' : 'Copy to clipboard',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
            hasTapAction: true,
            hasFocusAction: true,
          ),
        );
      }

      await tester.tap(copyControl);
      await tester.pump();
      expect(clipboardText, secret);
      expect(find.text('Copied to clipboard'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets('rotated client secret requires explicit save acknowledgement', (
    tester,
  ) async {
    const secret = 'fixture-secret-value';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showClientDetailSecret(context, secret),
              child: const Text('Rotate'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Rotate'));
    await tester.pumpAndSettle();
    expect(find.text(secret), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text(secret), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(secret), findsOneWidget);

    await tester.tap(find.text('I have saved it — clear secret'));
    await tester.pumpAndSettle();
    expect(find.text(secret), findsNothing);
  });
}

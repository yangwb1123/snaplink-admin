import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/widgets/section_header.dart';

/// SectionHeader (design §2.4; T-SH-01..03).
Future<void> _pump(WidgetTester tester, Widget header) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: header)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('T-SH-01: title + count badge render', (tester) async {
    await _pump(tester, const SectionHeader('Recent events', count: 12));
    expect(find.text('Recent events'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('T-SH-02: count null → no badge', (tester) async {
    await _pump(tester, const SectionHeader('Recent events'));
    expect(find.text('Recent events'), findsOneWidget);
    expect(find.textContaining('12'), findsNothing);
    // No pill container with a number.
    expect(
      find.descendant(
        of: find.byType(SectionHeader),
        matching: find.byType(Text),
      ),
      findsOneWidget,
    );
  });

  testWidgets('T-SH-03: trailing action renders', (tester) async {
    await _pump(
      tester,
      SectionHeader(
        'Recent events',
        action: IconButton(
          onPressed: () {},
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ),
    );
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });
}

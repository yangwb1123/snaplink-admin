import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/widgets/empty_state.dart';

/// EmptyState variants (design §2.7; T-ES-01..03). The default ctor is
/// unchanged: variant defaults to `empty` → 'No data' + inbox icon
/// (shared_widgets_test stays green unedited).
Future<void> _pump(WidgetTester tester, Widget state) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: state)));
  await tester.pumpAndSettle();
}

Size _iconBoxSize(WidgetTester tester, IconData icon) {
  final container = find.ancestor(
    of: find.byIcon(icon),
    matching: find.byType(Container),
  );
  return tester.getSize(container.first);
}

Widget _constrained(
  Widget child, {
  required double width,
  double textScale = 1,
  double height = 640,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: SizedBox(width: width, height: height, child: child),
          ),
        ),
      ),
    ),
  );
}

EmptyState _clientAction({bool compact = false, VoidCallback? onAction}) {
  return EmptyState(
    compact: compact,
    title: 'No clients',
    subtitle: 'Create your first client to get started.',
    actionLabel: 'Create client',
    onAction: onAction ?? () {},
  );
}

void main() {
  testWidgets('T-ES-01: notEnabled variant → pinned title + toggle icon', (
    tester,
  ) async {
    await _pump(
      tester,
      const EmptyState(variant: EmptyStateVariant.notEnabled),
    );
    expect(
      find.text('This feature is not enabled on the connected replica.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.toggle_off_outlined), findsOneWidget);
  });

  testWidgets('T-ES-01b: noMatch and error variant defaults', (tester) async {
    await _pump(tester, const EmptyState(variant: EmptyStateVariant.noMatch));
    expect(find.text('No matches'), findsOneWidget);
    expect(find.byIcon(Icons.search_off), findsOneWidget);

    await _pump(tester, const EmptyState(variant: EmptyStateVariant.error));
    expect(find.text('Error'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('T-ES-02: compact sizes (48px icon container / 22px icon)', (
    tester,
  ) async {
    await _pump(tester, const EmptyState(compact: true));
    expect(_iconBoxSize(tester, Icons.inbox_outlined), const Size(48, 48));

    await _pump(tester, const EmptyState());
    expect(_iconBoxSize(tester, Icons.inbox_outlined), const Size(72, 72));
  });

  testWidgets('T-ES-03: empty default unchanged (title + icon + action)', (
    tester,
  ) async {
    await _pump(
      tester,
      EmptyState(
        title: 'No clients',
        subtitle: 'Create your first client to get started.',
        actionLabel: 'Create client',
        onAction: () {},
      ),
    );
    expect(find.text('No clients'), findsOneWidget);
    expect(
      find.text('Create your first client to get started.'),
      findsOneWidget,
    );
    expect(find.text('Create client'), findsOneWidget);
    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
  });

  testWidgets('T-ES-04: 96px parent lays out default and compact actions', (
    tester,
  ) async {
    for (final compact in <bool>[false, true]) {
      await tester.pumpWidget(
        _constrained(_clientAction(compact: compact), width: 96),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'compact=$compact must not overflow a 96px parent',
      );
      final iconSize = compact ? 48.0 : 72.0;
      // Baseline fixed padding (32/24) squeezes the 72px default icon inside
      // a 96px parent; narrow layouts must yield padding instead. Compact
      // already has a 48px content box there and must keep its 48px icon.
      expect(
        _iconBoxSize(tester, Icons.inbox_outlined),
        Size(iconSize, iconSize),
        reason: 'compact=$compact keeps its variant icon size',
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Create client'),
        findsOneWidget,
        reason: 'compact=$compact keeps the Create client action',
      );
    }
  });

  testWidgets('T-ES-05: 280px at 3x text scale scrolls and taps once', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _constrained(
        _clientAction(onAction: () => taps++),
        width: 280,
        textScale: 3,
        height: 360,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final action = find.widgetWithText(OutlinedButton, 'Create client');
    expect(action, findsOneWidget);
    expect(taps, 0);
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}

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
}

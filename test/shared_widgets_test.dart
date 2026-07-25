import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/section_selector.dart';
import 'package:flutter/material.dart';

void main() {
  group('EmptyState', () {
    testWidgets('renders default state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EmptyState())),
      );
      expect(find.text('No data'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('renders custom title and subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(
          body: EmptyState(
            icon: Icons.person,
            title: 'Custom title',
            subtitle: 'Custom subtitle',
          ),
        )),
      );
      expect(find.text('Custom title'), findsOneWidget);
      expect(find.text('Custom subtitle'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('renders action button when provided', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(
          body: EmptyState(
            title: 'Empty',
            actionLabel: 'Create',
            onAction: () => tapped = true,
          ),
        )),
      );
      expect(find.text('Create'), findsOneWidget);
      await tester.tap(find.text('Create'));
      expect(tapped, true);
    });
  });

  group('SectionDef', () {
    test('creates with id, label, icon', () {
      final s = SectionDef('test', 'Test', Icons.star);
      expect(s.id, 'test');
      expect(s.label, 'Test');
      expect(s.icon, Icons.star);
    });

    test('provides dollar accessors', () {
      final s = SectionDef('x', 'Y', Icons.home);
      expect(s.$1, 'x');
      expect(s.$2, 'Y');
      expect(s.$3, Icons.home);
    });
  });

  group('SectionSelector', () {
    testWidgets('renders all section chips', (tester) async {
      final sections = [
        const SectionDef('all', 'All', Icons.dashboard),
        const SectionDef('a', 'A', Icons.star),
        const SectionDef('b', 'B', Icons.home),
      ];
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(
          body: SectionSelector(
            sections: sections,
            current: 'all',
            onSelected: (_) {},
          ),
        )),
      );
      expect(find.text('All'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('highlights current selection', (tester) async {
      final sections = [
        const SectionDef('all', 'All', Icons.dashboard),
        const SectionDef('a', 'A', Icons.star),
      ];
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(
          body: SectionSelector(
            sections: sections,
            current: 'a',
            onSelected: (_) {},
          ),
        )),
      );
      expect(find.text('All'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('calls onSelected when chip tapped', (tester) async {
      String? selected;
      final sections = [
        const SectionDef('all', 'All', Icons.dashboard),
        const SectionDef('a', 'A', Icons.star),
      ];
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(
          body: SectionSelector(
            sections: sections,
            current: 'all',
            onSelected: (s) => selected = s,
          ),
        )),
      );
      await tester.tap(find.text('A'));
      expect(selected, 'a');
    });
  });
}

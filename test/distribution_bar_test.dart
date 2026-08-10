import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/distribution_bar.dart';

/// DistributionBar honesty rules (design §2.5; T-DB-01..05).
Future<void> _pump(WidgetTester tester, Widget bar) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: bar)));
  await tester.pumpAndSettle();
}

Finder _barColoredBoxes() => find.descendant(
  of: find.byType(DistributionBar),
  matching: find.byType(ColoredBox),
);

void main() {
  test('T-DB-01: fractions sum to 1 for a non-zero total', () {
    const segments = [
      DistributionSegment(label: 'A', value: 3, color: AppColors.primary),
      DistributionSegment(label: 'B', value: 1, color: AppColors.success),
    ];
    final total = 4;
    final sum = segments.fold<double>(0, (acc, s) => acc + s.fractionOf(total));
    expect(sum, 1.0);
    expect(segments[0].fractionOf(0), 0); // guarded against non-positive
  });

  testWidgets('T-DB-02: legend renders "label · value" for each segment', (
    tester,
  ) async {
    await _pump(
      tester,
      const DistributionBar(
        segments: [
          DistributionSegment(
            label: 'Running',
            value: 3,
            color: AppColors.primary,
          ),
          DistributionSegment(
            label: 'Documented-only',
            value: 1,
            color: AppColors.warning,
          ),
        ],
      ),
    );
    expect(find.text('Running · 3'), findsOneWidget);
    expect(find.text('Documented-only · 1'), findsOneWidget);
  });

  testWidgets('T-DB-03: single segment renders a full bar + legend', (
    tester,
  ) async {
    await _pump(
      tester,
      const DistributionBar(
        segments: [
          DistributionSegment(
            label: 'Active',
            value: 5,
            color: AppColors.success,
          ),
        ],
      ),
    );
    expect(find.text('Active · 5'), findsOneWidget);
    // Track + slice are both ColoredBoxes.
    expect(_barColoredBoxes(), findsNWidgets(2));
  });

  testWidgets('T-DB-04: zero total → muted placeholder, no legend, no crash', (
    tester,
  ) async {
    await _pump(
      tester,
      const DistributionBar(
        segments: [
          DistributionSegment(
            label: 'Active',
            value: 0,
            color: AppColors.success,
          ),
        ],
      ),
    );
    expect(find.textContaining('·'), findsNothing);
    expect(_barColoredBoxes(), findsNothing);
  });

  testWidgets('T-DB-05: zero-valued segment renders no slice/legend entry', (
    tester,
  ) async {
    await _pump(
      tester,
      const DistributionBar(
        segments: [
          DistributionSegment(
            label: 'Active',
            value: 2,
            color: AppColors.success,
          ),
          DistributionSegment(
            label: 'Inactive',
            value: 0,
            color: AppColors.muted,
          ),
        ],
      ),
    );
    expect(find.text('Active · 2'), findsOneWidget);
    expect(find.textContaining('Inactive'), findsNothing);
    expect(_barColoredBoxes(), findsNWidgets(2));
  });

  testWidgets('T-DB-06: emphasized segment renders bold + first', (
    tester,
  ) async {
    await _pump(
      tester,
      const DistributionBar(
        segments: [
          DistributionSegment(
            label: 'Active',
            value: 1,
            color: AppColors.success,
          ),
          DistributionSegment(
            label: 'Inactive',
            value: 3,
            color: AppColors.muted,
          ),
        ],
        emphasizedLabel: 'Inactive',
      ),
    );
    // Emphasized legend first.
    final inactive = tester.getTopLeft(find.text('Inactive · 3'));
    final active = tester.getTopLeft(find.text('Active · 1'));
    expect(inactive.dx, lessThan(active.dx));
    final bold = tester.widget<Text>(find.text('Inactive · 3'));
    expect(bold.style?.fontWeight, FontWeight.w700);
    final normal = tester.widget<Text>(find.text('Active · 1'));
    expect(normal.style?.fontWeight, FontWeight.w400);
  });
}

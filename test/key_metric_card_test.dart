import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/key_metric_card.dart';
import 'package:sso_admin/widgets/sparkline.dart';

/// KeyMetricCard honesty rules (design §2.1; T-KM-01..05):
/// delta == null → no arrow of any kind; empty sparkline → no Sparkline;
/// icon null → no icon circle; real delta/sparkline render.
Future<void> _pump(WidgetTester tester, Widget card) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: card)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('T-KM-01: value renders after CountUp settles', (tester) async {
    await _pump(
      tester,
      KeyMetricCard(label: 'Live endpoints', value: 42, icon: Icons.hub),
    );
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Live endpoints'), findsOneWidget);
  });

  testWidgets('T-KM-02: delta == null → no arrow icon of any kind', (
    tester,
  ) async {
    await _pump(
      tester,
      KeyMetricCard(label: 'Total', value: 7, icon: Icons.tag),
    );
    expect(find.byIcon(Icons.trending_up), findsNothing);
    expect(find.byIcon(Icons.arrow_upward), findsNothing);
    expect(find.byIcon(Icons.arrow_downward), findsNothing);
  });

  testWidgets('T-KM-03: delta > 0 → arrow_upward + +x%', (tester) async {
    await _pump(
      tester,
      KeyMetricCard(
        label: 'Total',
        value: 10,
        delta: 5,
        color: AppColors.primary,
      ),
    );
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    expect(find.text('+5%'), findsOneWidget);
    expect(find.byIcon(Icons.trending_up), findsNothing);
  });

  testWidgets('T-KM-04: delta < 0 → arrow_downward + danger color', (
    tester,
  ) async {
    await _pump(
      tester,
      KeyMetricCard(
        label: 'Total',
        value: 10,
        delta: -3,
        color: AppColors.primary,
      ),
    );
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.text('-3%'), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.arrow_downward));
    expect(icon.color, AppColors.danger);
    expect(find.byIcon(Icons.trending_up), findsNothing);
  });

  testWidgets('T-KM-05: sparkline empty → no Sparkline; non-empty → present', (
    tester,
  ) async {
    await _pump(
      tester,
      KeyMetricCard(
        label: 'Total',
        value: 10,
        sparkline: const [],
        color: AppColors.primary,
      ),
    );
    expect(find.byType(Sparkline), findsNothing);

    await _pump(
      tester,
      KeyMetricCard(
        label: 'Total',
        value: 10,
        sparkline: const [1, 2, 3],
        color: AppColors.primary,
      ),
    );
    expect(find.byType(Sparkline), findsOneWidget);
  });

  testWidgets('icon null → no icon circle', (tester) async {
    await _pump(tester, KeyMetricCard(label: 'Total', value: 3));
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('MetricStrip wraps fixed-width cards', (tester) async {
    await _pump(
      tester,
      MetricStrip(
        cards: [
          KeyMetricCard(label: 'A', value: 1),
          KeyMetricCard(label: 'B', value: 2),
        ],
      ),
    );
    expect(find.byType(KeyMetricCard), findsNWidgets(2));
    expect(find.byType(SizedBox), findsWidgets);
  });
}

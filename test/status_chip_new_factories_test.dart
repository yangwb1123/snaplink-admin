import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/status_chip.dart';

/// New StatusChip factories (design §2.6; T-SC-01..03). The existing five
/// factories are byte-for-byte untouched; colors stay inside the
/// dark_mode_test WCAG loop set (success/danger/warning/accentBlue/muted).
Future<void> _pump(WidgetTester tester, Widget chip) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: chip)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'T-SC-01: pending/failed/degraded/info/unknown render label+icon',
    (tester) async {
      await _pump(tester, StatusChip.pending());
      expect(find.text('Pending'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_top), findsOneWidget);

      await _pump(tester, StatusChip.failed());
      expect(find.text('Failed'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);

      await _pump(tester, StatusChip.degraded());
      expect(find.text('Degraded'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);

      await _pump(tester, StatusChip.info());
      expect(find.text('Info'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);

      await _pump(tester, StatusChip.unknown());
      expect(find.text('Unknown'), findsOneWidget);
      expect(find.byIcon(Icons.help_outline), findsOneWidget);
    },
  );

  test('T-SC-02: factory colors are inside the WCAG loop set', () {
    final loopSet = <Color>{
      AppColors.success,
      AppColors.danger,
      AppColors.warning,
      AppColors.accentBlue,
      AppColors.muted,
      AppColors.primary,
    };
    for (final factory in [
      StatusChip.pending,
      StatusChip.failed,
      StatusChip.degraded,
      StatusChip.info,
      StatusChip.unknown,
    ]) {
      expect(loopSet.contains(factory().color), isTrue);
    }
    // Per-factory expectations from the design.
    expect(StatusChip.pending().color, AppColors.warning);
    expect(StatusChip.failed().color, AppColors.danger);
    expect(StatusChip.degraded().color, AppColors.warning);
    expect(StatusChip.info().color, AppColors.accentBlue);
    expect(StatusChip.unknown().color, AppColors.muted);
  });

  testWidgets('T-SC-03: custom labels are honored', (tester) async {
    await _pump(tester, StatusChip.pending(label: '待处理'));
    expect(find.text('待处理'), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_top), findsOneWidget);
  });
}

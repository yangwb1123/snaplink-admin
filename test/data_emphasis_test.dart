import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/widgets/data_emphasis.dart';

/// DataEmphasis (design §2.2; T-DE-01..02).
void main() {
  test('T-DE-01: dataEmphasisStyle produces distinct theme-derived styles', () {
    final light = ThemeData.light();
    final dark = ThemeData.dark();
    for (final theme in [light, dark]) {
      final primary = dataEmphasisStyle(DataEmphasisLevel.primary, theme);
      final secondary = dataEmphasisStyle(DataEmphasisLevel.secondary, theme);
      final tertiary = dataEmphasisStyle(DataEmphasisLevel.tertiary, theme);
      expect(primary.fontWeight, FontWeight.w700);
      expect(primary.color, theme.colorScheme.onSurface);
      expect(secondary.fontWeight, FontWeight.w600);
      expect(secondary.color, theme.colorScheme.onSurface);
      expect(tertiary.fontWeight, isNot(FontWeight.w700));
      expect(tertiary.color, theme.colorScheme.onSurfaceVariant);
      expect(primary, isNot(equals(secondary)));
      expect(secondary, isNot(equals(tertiary)));
    }
  });

  testWidgets('T-DE-02: DataEmphasis renders translated text with maxLines', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DataEmphasis(
            level: DataEmphasisLevel.secondary,
            text: 'Client ID',
            maxLines: 2,
          ),
        ),
      ),
    );
    expect(find.text('Client ID'), findsOneWidget);
    final text = tester.widget<Text>(find.text('Client ID'));
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.style?.fontWeight, FontWeight.w600);
  });
}

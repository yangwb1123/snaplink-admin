import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/app_settings.dart';
import 'package:sso_admin/widgets/info_row.dart';

void main() {
  testWidgets('R206: InfoRow copy target stays accessible on narrow rows', (
    tester,
  ) async {
    final originalLocale = AppSettings.instance.locale;
    AppSettings.instance.locale = const Locale('en');
    addTearDown(() => AppSettings.instance.locale = originalLocale);

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(240, 600);
    addTearDown(tester.view.reset);

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
          body: InfoRow(
            label: 'Client ID',
            value: 'visible-client-value',
            copyValue: 'opaque-client-value',
            icon: Icons.key_outlined,
            danger: true,
          ),
        ),
      ),
    );
    await tester.pump();

    final copyControl = find.byType(IconButton);
    expect(copyControl, findsOneWidget);
    final size = tester.getSize(copyControl);
    expect(size.width, greaterThanOrEqualTo(kMinInteractiveDimension));
    expect(size.height, greaterThanOrEqualTo(kMinInteractiveDimension));
    expect(
      tester.getSize(find.byIcon(Icons.copy_outlined)),
      const Size(16, 16),
    );
    expect(find.byTooltip('Copy to clipboard'), findsOneWidget);
    expect(find.byIcon(Icons.key_outlined), findsOneWidget);
    expect(find.text('visible-client-value'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(copyControl),
      matchesSemantics(
        tooltip: 'Copy to clipboard',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );

    await tester.tap(copyControl);
    await tester.pump();
    expect(clipboardText, 'opaque-client-value');
    expect(find.text('Copied to clipboard'), findsOneWidget);
    semantics.dispose();
  });
}

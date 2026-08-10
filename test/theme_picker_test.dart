import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/app_settings.dart';
import 'package:sso_admin/screens/settings_screen.dart';

/// WS1：设置页主题选择器 = 图标瓦片行。
///
/// 覆盖：3 项图标 + caption 渲染；选中态 primaryContainer 填充 +
/// check_circle 徽标；键盘遍历（Tab，非 tap）产生 primary 焦点边框；
/// Tooltip 悬停专属（本 SDK 无 hover/never，manual = 触屏永不触发、
/// 鼠标 hover 仍显示）；Semantics(selected:) 无 label 拼接；
/// AppSettings.themeMode 保存/恢复。
void main() {
  late ThemeMode originalThemeMode;
  late Locale originalLocale;

  setUp(() {
    originalThemeMode = AppSettings.instance.themeMode;
    originalLocale = AppSettings.instance.locale;
    AppSettings.instance.themeMode = ThemeMode.system;
    AppSettings.instance.locale = const Locale('en');
  });

  tearDown(() {
    AppSettings.instance.themeMode = originalThemeMode;
    AppSettings.instance.locale = originalLocale;
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();
  }

  Finder tileContainer(IconData icon) => find
      .ancestor(of: find.byIcon(icon), matching: find.byType(AnimatedContainer))
      .first;

  BoxDecoration tileDecoration(WidgetTester tester, IconData icon) {
    final container = tester.widget<AnimatedContainer>(tileContainer(icon));
    return container.decoration! as BoxDecoration;
  }

  ColorScheme colorSchemeOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(SettingsScreen))).colorScheme;

  testWidgets('renders three icon tiles with captions', (tester) async {
    await pumpSettings(tester);

    expect(find.byIcon(Icons.brightness_auto), findsOneWidget);
    expect(find.byIcon(Icons.light_mode), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('selected tile gets primaryContainer fill, primary border and '
      'check_circle badge; tap moves the selection', (tester) async {
    AppSettings.instance.themeMode = ThemeMode.dark;
    await pumpSettings(tester);

    final colorScheme = colorSchemeOf(tester);
    final dark = tileDecoration(tester, Icons.dark_mode);
    expect(dark.color, colorScheme.primaryContainer);
    expect((dark.border! as Border).top.color, colorScheme.primary);

    // check_circle 只出现在选中瓦片。
    expect(
      find.descendant(
        of: tileContainer(Icons.dark_mode),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tileContainer(Icons.light_mode),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsNothing,
    );

    // 点击（选择语义；焦点边框另测键盘遍历）。
    await tester.ensureVisible(find.byIcon(Icons.light_mode));
    await tester.tap(find.byIcon(Icons.light_mode));
    await tester.pumpAndSettle();

    expect(AppSettings.instance.themeMode, ThemeMode.light);
    expect(
      tileDecoration(tester, Icons.light_mode).color,
      colorScheme.primaryContainer,
    );
    expect(
      find.descendant(
        of: tileContainer(Icons.light_mode),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tileContainer(Icons.dark_mode),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsNothing,
    );
  });

  testWidgets('Tab traversal produces a primary focus border (no tap: '
      'InkWell taps do not request focus)', (tester) async {
    // light 选中 → dark 未选中，可独立观察焦点边框。
    AppSettings.instance.themeMode = ThemeMode.light;
    await pumpSettings(tester);

    for (var i = 0; i < 12; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final element = tester.element(find.byIcon(Icons.dark_mode).first);
      if (Focus.of(element).hasFocus) break;
    }
    final darkTile = tester.element(find.byIcon(Icons.dark_mode).first);
    expect(
      Focus.of(darkTile).hasFocus,
      isTrue,
      reason: 'Tab traversal must focus the dark theme tile',
    );

    final colorScheme = colorSchemeOf(tester);
    final border = tileDecoration(tester, Icons.dark_mode).border! as Border;
    expect(border.top.color, colorScheme.primary);
    // 未选中且未聚焦的 system 瓦片不应有 primary 边框（focus/selected
    // 边框不得泄漏；light 是选中态，其 primary 边框属选中样式）。
    final systemBorder =
        tileDecoration(tester, Icons.brightness_auto).border! as Border;
    expect(
      systemBorder.top.color,
      isNot(colorScheme.primary),
      reason: 'selected-only border must not leak to unfocused tiles',
    );
  });

  testWidgets('tooltip is hover-only on web and never on touch', (
    tester,
  ) async {
    await pumpSettings(tester);

    final tooltip = tester.widget<Tooltip>(
      find
          .ancestor(
            of: find.byIcon(Icons.brightness_auto),
            matching: find.byType(Tooltip),
          )
          .first,
    );
    // 本 SDK（Flutter 3.47 master）TooltipTriggerMode 仅有 manual/longPress/
    // tap（设计引用的 hover/never 不存在）；manual = 触屏永不触发，
    // 鼠标 hover 仍显示（triggerMode 不影响鼠标设备）——即设计意图。
    expect(tooltip.triggerMode, TooltipTriggerMode.manual);
    expect(tooltip.message, isNotEmpty);
  });

  testWidgets('selected tile exposes selected semantics without label glue', (
    tester,
  ) async {
    AppSettings.instance.themeMode = ThemeMode.dark;
    final handle = tester.ensureSemantics();
    await pumpSettings(tester);

    // 无 "System System" / "Dark Dark" 式 label 拼接。
    expect(find.bySemanticsLabel(RegExp('System System')), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Dark Dark')), findsNothing);

    // Semantics(selected:) 恰好一个选中主题瓦片（导航模式 SegmentedButton
    // 的选中段也在树中，因此按 label 过滤），label 为单一 caption
    // （无 "Dark Dark" 拼接）。
    final selectedNodes = <SemanticsNode>[];
    bool visit(SemanticsNode node) {
      if (node.getSemanticsData().flagsCollection.isSelected ==
          Tristate.isTrue) {
        selectedNodes.add(node);
      }
      node.visitChildren(visit);
      return true;
    }

    final root = tester.binding.pipelineOwner.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
    expect(
      selectedNodes.where((node) => node.label == 'Dark'),
      hasLength(1),
      reason: 'exactly one selected theme tile, labeled once',
    );
    handle.dispose();
  });
}

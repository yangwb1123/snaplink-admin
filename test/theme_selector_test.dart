import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/app_settings.dart';
import 'package:sso_admin/widgets/theme_selector.dart';

void main() {
  tearDown(() {
    AppSettings.instance.themeMode = ThemeMode.system;
  });

  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  Finder menuItem(String label) => find.descendant(
    of: find.byType(MenuItemButton).hitTestable(),
    matching: find.text(label),
  );

  testWidgets('theme menu opens BELOW the control', (tester) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: ThemeDropdown(compact: true),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(DropdownMenu<ThemeMode>));
    await tester.pumpAndSettle();

    final control = tester.getRect(find.byType(DropdownMenu<ThemeMode>));
    final item = tester.getRect(menuItem('System'));
    expect(item.top, greaterThanOrEqualTo(control.bottom - 1),
        reason: 'theme menu must open below the control');
  });

  testWidgets('selecting a theme updates AppSettings and checks the item', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const ThemeDropdown()));
    await tester.tap(find.byType(DropdownMenu<ThemeMode>));
    await tester.pumpAndSettle();

    // 当前主题（system）带勾选。
    expect(
      find.descendant(
        of: find.byType(MenuItemButton).hitTestable(),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    await tester.tap(menuItem('Dark'));
    await tester.pumpAndSettle();

    expect(AppSettings.instance.themeMode, ThemeMode.dark);
  });

  testWidgets('theme items carry colored leading icons', (tester) async {
    await tester.pumpWidget(wrap(const ThemeDropdown()));
    await tester.tap(find.byType(DropdownMenu<ThemeMode>));
    await tester.pumpAndSettle();

    // 每个菜单项都有图标（彩色由 Icon.color 提供，此处验证存在且着色）。
    for (final icon in [Icons.brightness_auto, Icons.light_mode, Icons.dark_mode]) {
      final icons = tester.widgetList<Icon>(
        find.descendant(
          of: find.byType(MenuItemButton).hitTestable(),
          matching: find.byIcon(icon),
        ),
      );
      expect(icons, isNotEmpty, reason: '$icon must render in the menu');
      for (final iconWidget in icons) {
        expect(iconWidget.color, isNotNull, reason: '$icon must be colored');
      }
    }
  });

  // F2（审计对齐）：选中项边框横贯整个菜单项宽度、与 select item 对齐
  // （不再内缩 28px），2px primary、圆角 8；未选中项同宽透明占位；内容
  // 高亮仍在；选中/未选中条目几何一致（≤0.1px）。
  testWidgets('selected entry border spans the full item width', (tester) async {
    await tester.pumpWidget(wrap(const ThemeDropdown()));
    await tester.tap(find.byType(DropdownMenu<ThemeMode>));
    await tester.pumpAndSettle();

    final buttons = find.byType(MenuItemButton).hitTestable();
    final item = tester.getRect(buttons.first);

    // 内容区高亮框几何一致（≤0.1px），且选中项仍渲染 primaryContainer
    // 背景（内容高亮不丢失）。
    final boxes = tester
        .renderObjectList<RenderBox>(
          find.descendant(of: buttons, matching: find.byType(AnimatedContainer)),
        )
        .toList();
    Rect boxRect(RenderBox box) => box.localToGlobal(Offset.zero) & box.size;
    final rects = boxes.map(boxRect).toList();
    for (final rect in rects.skip(1)) {
      expect(rect.left, closeTo(rects.first.left, 0.1),
          reason: 'entry boxes must share the left edge');
      expect(rect.width, closeTo(rects.first.width, 0.1),
          reason: 'entry boxes must have identical widths');
      expect(rect.height, closeTo(rects.first.height, 0.1),
          reason: 'entry boxes must have identical heights');
    }

    final theme = Theme.of(tester.element(find.byType(ThemeDropdown)));
    final highlightColors = tester
        .widgetList<AnimatedContainer>(
          find.descendant(of: buttons, matching: find.byType(AnimatedContainer)),
        )
        .map((c) => (c.decoration! as BoxDecoration).color)
        .toList();
    expect(
      highlightColors,
      contains(theme.colorScheme.primaryContainer.withValues(alpha: 0.45)),
      reason: 'selected entry keeps the content highlight background',
    );

    // 外圈边框在 MenuItemButton 的 Material shape side 上：2px、圆角 8；
    // 选中（高亮）项 primary、未选中透明同宽占位。
    final shapes = tester
        .widgetList<Material>(
          find.descendant(
            of: buttons,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Material && widget.shape is RoundedRectangleBorder,
            ),
          ),
        )
        .map((m) => m.shape! as RoundedRectangleBorder)
        .toList();
    expect(shapes.length, 3, reason: 'one bordered shape per theme entry');
    for (final shape in shapes) {
      expect(shape.side.width, 2,
          reason: 'entry border must match the 2px system tiles');
    }
    final selected =
        shapes.singleWhere((s) => s.side.color == theme.colorScheme.primary);
    expect(selected.borderRadius, const BorderRadius.all(Radius.circular(8)),
        reason: 'selected border must keep the 8px rounded corners');
    expect(
      shapes
          .where((s) => s.side.color != theme.colorScheme.primary)
          .every((s) => s.side.color == Colors.transparent),
      isTrue,
      reason: 'unselected entries keep a transparent 2px placeholder',
    );

    // 选中边框盒（Material 整宽绘制）与 MenuItemButton 同框：横贯整个
    // 菜单项宽度。
    final ringBox = tester.renderObject<RenderBox>(
      find
          .descendant(
            of: buttons,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Material &&
                  widget.shape is RoundedRectangleBorder &&
                  (widget.shape! as RoundedRectangleBorder).side.color ==
                      theme.colorScheme.primary,
            ),
          )
          .first,
    );
    final ring = ringBox.localToGlobal(Offset.zero) & ringBox.size;
    expect(ring.left, closeTo(item.left, 1),
        reason: 'selected border must start at the item left edge');
    expect(ring.width, closeTo(item.width, 1),
        reason: 'selected border box must span the full MenuItemButton width');
    expect(ring.right, closeTo(item.right, 1),
        reason: 'selected border must end at the item right edge');
  });

  // F1：紧凑变体箭头在收起/展开两态下均 20×20、垂直居中于字段、右缘
  // 贴齐（间隙一致）。
  testWidgets('compact trailing arrow is centered in collapsed and open states', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const ThemeDropdown(compact: true)));
    await tester.pumpAndSettle();

    final field = tester.getRect(find.byType(DropdownMenu<ThemeMode>));
    void checkArrow(IconData data) {
      final rect = tester.getRect(
        find.descendant(
          of: find.byType(InputDecorator),
          matching: find.byIcon(data),
        ),
      );
      expect(rect.size, const Size(20, 20),
          reason: 'arrow must keep the 20x20 icon region');
      expect(rect.center.dy, closeTo(field.center.dy, 1.5),
          reason: 'arrow must be vertically centered in the field');
      expect(field.right - rect.right, closeTo(0, 0.5),
          reason: 'arrow gap from the right edge must be consistent');
    }

    checkArrow(Icons.arrow_drop_down);
    await tester.tap(find.byType(DropdownMenu<ThemeMode>));
    await tester.pumpAndSettle();
    checkArrow(Icons.arrow_drop_up);
  });
}

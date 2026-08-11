import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/app_settings.dart';
import 'package:sso_admin/services/language_catalog.dart';
import 'package:sso_admin/widgets/language_selector.dart';

void main() {
  tearDown(() {
    // 恢复单例状态，避免测试间串扰。
    AppSettings.instance
      ..languageOptions = defaultLanguageOptions
      ..locale = const Locale('en');
  });

  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  Future<void> openMenu(WidgetTester tester, Finder selector) async {
    await tester.tap(selector);
    await tester.pumpAndSettle();
  }

  /// 打开的菜单项（MenuItemButton 内的文本）。DropdownMenu 为宽度计算会
  /// 额外渲染一份菜单项副本（不可点击），因此必须限定 hitTestable。
  Finder menuItem(String label) => find.descendant(
    of: find.byType(MenuItemButton).hitTestable(),
    matching: find.text(label),
  );

  Finder menuCheckIcon() => find.descendant(
    of: find.byType(MenuItemButton).hitTestable(),
    matching: find.byIcon(Icons.check),
  );

  testWidgets(
    'compact selector (login header) opens the menu BELOW the control',
    (tester) async {
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
                child: SizedBox(width: 190, child: LanguageDropdown(compact: true)),
              ),
            ),
          ),
        ),
      );
      await openMenu(tester, find.byType(DropdownMenu<Locale>));

      final control = tester.getRect(find.byType(DropdownMenu<Locale>));
      // F3：紧凑控件触摸目标 ≥44px（Material/Apple 指导线）。
      expect(control.height, greaterThanOrEqualTo(44),
          reason: 'compact tap target must meet Apple HIG 44px');
      final item = tester.getRect(menuItem('English'));
      // 菜单从控件下方展开（DropdownButton 在顶部控件上会向上弹）。
      expect(item.top, greaterThanOrEqualTo(control.bottom - 1),
          reason: 'compact menu must open below the header control');
      expect(item.left, greaterThanOrEqualTo(control.left - 1),
          reason: 'menu aligns with the control edge');
    },
  );

  testWidgets(
    'form selector (settings) opens the menu BELOW the control',
    (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.center,
              child: SizedBox(width: 320, child: LanguageDropdown()),
            ),
          ),
        ),
      );
      await openMenu(tester, find.byType(DropdownMenu<Locale>));

      final control = tester.getRect(find.byType(DropdownMenu<Locale>));
      final item = tester.getRect(menuItem('English'));
      expect(item.top, greaterThanOrEqualTo(control.bottom - 1),
          reason: 'settings menu must open below the control');
    },
  );

  testWidgets('menu items come from the backend languages list', (
    tester,
  ) async {
    AppSettings.instance.languageOptions = const [Locale('en'), Locale('ja')];
    await tester.pumpWidget(wrap(const LanguageDropdown()));

    await openMenu(tester, find.byType(DropdownMenu<Locale>));
    expect(menuItem('English'), findsOneWidget);
    expect(menuItem('日本語'), findsOneWidget);
    // 后端未公布的语言不出现在菜单里。
    expect(menuItem('中文'), findsNothing);
  });

  testWidgets('current locale absent from the backend list is appended', (
    tester,
  ) async {
    AppSettings.instance
      ..languageOptions = const [Locale('en'), Locale('zh')]
      ..locale = const Locale('ja');
    await tester.pumpWidget(wrap(const LanguageDropdown()));

    await openMenu(tester, find.byType(DropdownMenu<Locale>));
    expect(menuItem('日本語'), findsOneWidget, reason: 'dropdown value safety');
    expect(menuItem('中文'), findsOneWidget);
  });

  testWidgets('selecting an entry updates the app locale and checks it', (
    tester,
  ) async {
    AppSettings.instance.languageOptions = const [Locale('en'), Locale('zh')];
    await tester.pumpWidget(wrap(const LanguageDropdown()));

    await openMenu(tester, find.byType(DropdownMenu<Locale>));
    // 当前语言带勾选。
    expect(menuCheckIcon(), findsOneWidget);
    await tester.tap(menuItem('中文'));
    await tester.pumpAndSettle();

    expect(AppSettings.instance.locale.languageCode, 'zh');
    // 输入框文本跟随（EditableText 只匹配输入框，避开宽度测量副本）。
    final input = tester.widget<EditableText>(
      find.byType(EditableText).hitTestable().first,
    );
    expect(input.controller?.text, '中文');
  });

  testWidgets('default options render when no backend list was loaded', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const LanguageDropdown()));
    await openMenu(tester, find.byType(DropdownMenu<Locale>));
    expect(menuItem('English'), findsOneWidget);
    expect(menuItem('中文'), findsOneWidget);
  });

  // F2：选中项高亮框 + 边框占满菜单项内容宽度，边框宽度 2px（与设置页
  // 主题瓦片一致）；选中/未选中条目几何完全一致（文字不位移）。
  testWidgets('selected entry border spans the item width with a 2px border', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const LanguageDropdown()));
    await openMenu(tester, find.byType(DropdownMenu<Locale>));

    final item =
        tester.getRect(find.byType(MenuItemButton).hitTestable().first);
    final boxes = tester
        .renderObjectList<RenderBox>(
          find.descendant(
            of: find.byType(MenuItemButton).hitTestable(),
            matching: find.byType(AnimatedContainer),
          ),
        )
        .toList();
    expect(boxes.length, greaterThanOrEqualTo(2),
        reason: 'menu shows selected and unselected entries');

    Rect boxRect(RenderBox box) => box.localToGlobal(Offset.zero) & box.size;
    final rects = boxes.map(boxRect).toList();
    // 所有条目（选中/未选中）边框几何一致 → 文字不位移（≤0.5px）。
    for (final rect in rects.skip(1)) {
      expect(rect.left, closeTo(rects.first.left, 0.1),
          reason: 'entry boxes must share the left edge');
      expect(rect.width, closeTo(rects.first.width, 0.1),
          reason: 'entry boxes must have identical widths');
      expect(rect.height, closeTo(rects.first.height, 0.1),
          reason: 'entry boxes must have identical heights');
    }
    // 高亮框占满菜单项内容宽度（菜单项宽度 - 左右 padding 12x2 -
    // startGap 4），选中与未选中一致。
    expect(rects.first.width, closeTo(item.width - 28, 1.5),
        reason: 'highlight must span the full item content width');

    // 边框宽度 2px：选中 = primary，未选中 = 透明（几何占位）。
    final borderBoxes = find
        .descendant(
          of: find.byType(MenuItemButton).hitTestable(),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is AnimatedContainer &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).border != null,
          ),
        )
        .hitTestable();
    final decorations = tester
        .widgetList<AnimatedContainer>(borderBoxes)
        .map((container) => container.decoration! as BoxDecoration)
        .toList();
    expect(decorations.length, greaterThanOrEqualTo(2));
    for (final decoration in decorations) {
      final border = decoration.border! as Border;
      expect(border.top.width, 2,
          reason: 'entry border must match the 2px system tiles');
      expect(border.bottom.width, 2);
    }
    final primary = Theme.of(
      tester.element(find.byType(LanguageDropdown)),
    ).colorScheme.primary;
    expect(
      decorations.any(
        (d) => (d.border! as Border).top.color == primary,
      ),
      isTrue,
      reason: 'selected entry border must use the primary color',
    );
    expect(
      decorations.any(
        (d) => (d.border! as Border).top.color == Colors.transparent,
      ),
      isTrue,
      reason: 'unselected entries keep a transparent 2px placeholder',
    );
  });

  // F1：箭头在收起/展开两态、紧凑/表单两变体下均为 20×20、垂直居中于
  // 字段（容差 1.5px）、右缘贴齐（间隙一致，不超出字段）。
  testWidgets('trailing arrow is centered in both states and variants', (
    tester,
  ) async {
    for (final compact in [true, false]) {
      // 每次迭代全新元素树：否则重 pump 时 DropdownMenu 状态被复用，
      // 上一迭代未关闭的菜单会让新实例的 isOpen 仍为 true。
      await tester.pumpWidget(
        wrap(LanguageDropdown(key: UniqueKey(), compact: compact)),
      );
      await tester.pumpAndSettle();

      final field = tester.getRect(find.byType(DropdownMenu<Locale>));
      Rect arrowRect(IconData data) {
        final arrow = find.descendant(
          of: find.byType(InputDecorator),
          matching: find.byIcon(data),
        );
        expect(arrow, findsOneWidget);
        final rect = tester.getRect(arrow);
        expect(rect.size, const Size(20, 20),
            reason: 'arrow must keep the 20x20 icon region');
        expect(rect.center.dy, closeTo(field.center.dy, 1.5),
            reason: 'arrow must be vertically centered in the field');
        expect(field.right - rect.right, closeTo(0, 0.5),
            reason: 'arrow must sit flush with the field right edge');
        return rect;
      }

      final collapsed = arrowRect(Icons.arrow_drop_down);
      await openMenu(tester, find.byType(DropdownMenu<Locale>));
      final open = arrowRect(Icons.arrow_drop_up);
      expect(
        field.right - open.right,
        closeTo(field.right - collapsed.right, 0.5),
        reason: 'arrow gap from the right edge must match across states',
      );
    }
  });

  // F2：国旗 emoji 必须携带文本标签，原始 emoji 不进语义树；收起态前导
  // 国旗被排除（字段值 "English" 已由输入框朗读）。
  testWidgets('flags carry accessible labels and never announce raw emoji', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(wrap(const LanguageDropdown()));
    // 语义树在 ensureSemantics 后随帧构建完成。
    await tester.pumpAndSettle();

    // 收起态：前导国旗被 ExcludeSemantics 包裹。
    final leadingFlag = find
        .descendant(
          of: find.byType(DropdownMenu<Locale>),
          matching: find.text('🇬🇧'),
        )
        .hitTestable();
    expect(leadingFlag, findsOneWidget);
    expect(
      find.ancestor(
        of: leadingFlag,
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
      reason: 'collapsed leading flag must be excluded from semantics',
    );

    Iterable<SemanticsNode> walk(SemanticsNode node) sync* {
      yield node;
      final children = <SemanticsNode>[];
      node.visitChildren((child) {
        children.add(child);
        return true;
      });
      for (final child in children) {
        yield* walk(child);
      }
    }

    final owner = tester.binding.pipelineOwner.semanticsOwner;
    expect(owner, isNotNull, reason: 'semantics must be enabled');
    final nodes = walk(owner!.rootSemanticsNode!).toList();
    for (final node in nodes) {
      expect(node.label.contains('🇬🇧'), isFalse,
          reason: 'raw flag emoji must not be a semantics label');
      expect(node.value.contains('🇬🇧'), isFalse,
          reason: 'raw flag emoji must not be a semantics value');
    }
    // 字段值仍可读（收起态选择器朗读 "English"）。
    expect(
      nodes.any((node) => node.label == 'English' || node.value == 'English'),
      isTrue,
      reason: 'the field value must remain announced',
    );

    // 打开菜单：国旗所在的语义节点标签 == 语言名（非 emoji）。
    await openMenu(tester, find.byType(DropdownMenu<Locale>));
    // 菜单打开后：语义树中语言名以节点 label 存在（字段值或菜单项），且
    // 原始 emoji 依然不进入 label/value。
    final nodesAfterOpen = walk(owner!.rootSemanticsNode!).toList();
    expect(
      nodesAfterOpen.any(
        (node) => node.label == 'English' || node.value == 'English',
      ),
      isTrue,
      reason: 'menu flag must carry the language name as its label',
    );
    for (final node in nodesAfterOpen) {
      expect(node.label.contains('🇬🇧'), isFalse,
          reason: 'raw flag emoji must not be a semantics label');
    }
    handle.dispose();
  });

  // F6：enabled=false 透传到 DropdownMenu，且点击不打开菜单。
  testWidgets('enabled: false disables the dropdown entirely', (tester) async {
    await tester.pumpWidget(wrap(const LanguageDropdown(enabled: false)));

    final menu =
        tester.widget<DropdownMenu<Locale>>(find.byType(DropdownMenu<Locale>));
    expect(menu.enabled, isFalse);

    await tester.tap(find.byType(DropdownMenu<Locale>));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton).hitTestable(), findsNothing,
        reason: 'disabled dropdown must not open on tap');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';

/// WS3：AdminDataTable 窄视口卡片模式。
///
/// 覆盖：≥640 表格模式 / <640 卡片模式（主字段 + 细节字段 + chevron）；
/// onRowTap；onSort == null 无排序条；无界宽度（横向滚动宿主）守卫回退
/// 表格模式；cardPrimary/cardDetail 标记覆盖自动派生。teardown 恢复 view。
void main() {
  const itemCount = 2;

  List<AdminDataColumn> columns({bool flagOverrides = false}) => [
    AdminDataColumn(
      id: 'a',
      label: 'A',
      builder: (context, i) => TableCellText('Row $i A'),
    ),
    AdminDataColumn(
      id: 'b',
      label: 'B',
      cardPrimary: flagOverrides,
      builder: (context, i) => TableCellText('Row $i B'),
    ),
    AdminDataColumn(
      id: 'c',
      label: 'C',
      cardDetail: flagOverrides,
      builder: (context, i) => TableCellText('Row $i C'),
    ),
    AdminDataColumn(
      id: 'd',
      label: 'D',
      builder: (context, i) => TableCellText('Row $i D'),
    ),
  ];

  Future<void> pumpTable(
    WidgetTester tester, {
    required double width,
    List<AdminDataColumn>? cols,
    ValueChanged<String>? onSort,
    void Function(int)? onRowTap,
    Widget? host,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final table = AdminDataTable(
      columns: cols ?? columns(),
      itemCount: itemCount,
      rowBuilder: (context, i) => const SizedBox.shrink(),
      onSort: onSort,
      onRowTap: onRowTap,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: host ?? Center(child: table)),
      ),
    );
    await tester.pump();
  }

  testWidgets('wide parent (800) keeps the table mode', (tester) async {
    await pumpTable(tester, width: 800);

    // 表格模式：表头 label 在，无卡片 chevron。
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('Row 0 A'), findsOneWidget);
  });

  testWidgets(
    'narrow parent (600) switches to cards with primary/detail/chevron',
    (tester) async {
      await pumpTable(tester, width: 600);

      expect(find.byIcon(Icons.chevron_right), findsNWidgets(itemCount));
      // 表头不在卡片模式出现。
      expect(find.text('A'), findsNothing);
      // 自动派生：主字段 = 首个具名列（值，无 label 前缀）；
      // 细节字段 = 后续 2 个具名列（"label: value"）。
      expect(find.text('Row 0 A'), findsOneWidget);
      expect(find.text('B: Row 0 B'), findsOneWidget);
      expect(find.text('C: Row 0 C'), findsOneWidget);
      expect(find.text('D: Row 0 D'), findsNothing);
    },
  );

  testWidgets('card tap fires onRowTap with the row index', (tester) async {
    final tapped = <int>[];
    await pumpTable(tester, width: 600, onRowTap: tapped.add);

    await tester.tap(find.text('Row 1 A'));
    await tester.pump();
    expect(tapped, [1]);
  });

  testWidgets(
    'onSort == null renders no sort chips; chips appear with onSort',
    (tester) async {
      final sorted = <String>[];
      final sortable = [
        AdminDataColumn(
          id: 'a',
          label: 'A',
          sortable: true,
          builder: (context, i) => TableCellText('Row $i A'),
        ),
        AdminDataColumn(
          id: 'b',
          label: 'B',
          sortable: true,
          builder: (context, i) => TableCellText('Row $i B'),
        ),
      ];

      await pumpTable(tester, width: 600, cols: sortable, onSort: null);
      expect(find.byType(ChoiceChip), findsNothing);

      await pumpTable(tester, width: 600, cols: sortable, onSort: sorted.add);
      expect(find.byType(ChoiceChip), findsNWidgets(2));
      await tester.tap(find.widgetWithText(ChoiceChip, 'A'));
      await tester.pump();
      expect(sorted, ['a']);
    },
  );

  testWidgets('unbounded width (horizontal scroll host) falls back to table', (
    tester,
  ) async {
    await pumpTable(
      tester,
      width: 600,
      host: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: AdminDataTable(
          columns: columns(),
          itemCount: itemCount,
          rowBuilder: (context, i) => const SizedBox.shrink(),
        ),
      ),
    );

    // 无界宽度守卫：回退表格模式（无卡片 chevron，表头在）。
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('R51: each card exposes one row-level semantics label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpTable(tester, width: 600);
    await tester.pumpAndSettle();

    // 一卡一行语义：label = 主字段值 + 细节 "label: value"（与可视文本同源）。
    expect(
      find.bySemanticsLabel('Row 0 A, B: Row 0 B, C: Row 0 C'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Row 1 A, B: Row 1 B, C: Row 1 C'),
      findsOneWidget,
    );
    // 文本已收敛进行级 label，不再作为独立节点重复朗读。
    expect(find.bySemanticsLabel('Row 0 A'), findsNothing);
    handle.dispose();
  });

  testWidgets('R51: leading checkbox stays independently operable in card', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var checked = false;
    final cols = [
      AdminDataColumn(
        id: 'select',
        label: '',
        width: 44,
        builder: (context, i) =>
            Checkbox(value: checked, onChanged: (_) => checked = !checked),
      ),
      AdminDataColumn(
        id: 'a',
        label: 'A',
        builder: (context, i) => TableCellText('Row $i A'),
      ),
      AdminDataColumn(
        id: 'b',
        label: 'B',
        builder: (context, i) => TableCellText('Row $i B'),
      ),
    ];
    await pumpTable(tester, width: 600, cols: cols);
    await tester.pumpAndSettle();

    // 行语义 label 与可视文本同源；复选框仍独立存在于语义树（未被吞并）。
    expect(find.byType(Checkbox), findsNWidgets(2));
    expect(find.bySemanticsLabel('Row 0 A, B: Row 0 B'), findsOneWidget);
    // 点击复选框独立生效（卡片行语义不拦截）。
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(checked, isTrue);
    handle.dispose();
  });

  testWidgets('cardPrimary/cardDetail flags override auto-derivation', (
    tester,
  ) async {
    await pumpTable(tester, width: 600, cols: columns(flagOverrides: true));

    // 主字段 = B（cardPrimary）；细节 = C（cardDetail）；A/D 忽略。
    expect(find.text('Row 0 B'), findsOneWidget);
    expect(find.text('C: Row 0 C'), findsOneWidget);
    expect(find.text('Row 0 A'), findsNothing);
    expect(find.text('D: Row 0 D'), findsNothing);
    expect(find.text('B: Row 0 B'), findsNothing);
  });
}

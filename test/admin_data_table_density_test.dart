import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';

/// TableDensity (design §2.3; T-DEN-01..03): default `comfortable` renders
/// today's padding exactly (10/10 header/row); `compact` tightens row
/// (10→5) and header (10→6) vertical padding — spacing only, never fonts.
Widget _table({TableDensity density = TableDensity.comfortable}) =>
    AdminDataTable(
      density: density,
      columns: [
        AdminDataColumn(
          id: 'id',
          label: 'ID',
          width: 160,
          builder: (context, i) => TableCellText('row-$i'),
        ),
      ],
      itemCount: 2,
      rowBuilder: (context, i) => const SizedBox.shrink(),
    );

List<double> _cellVerticals(WidgetTester tester) => tester
    .widgetList<Padding>(
      find.descendant(
        of: find.byType(AdminDataTable),
        matching: find.byType(Padding),
      ),
    )
    .map((p) => p.padding as EdgeInsets)
    .where((e) => e.left == 12 && e.right == 12)
    .map((e) => e.top)
    .toList();

Future<void> _pump(WidgetTester tester, TableDensity density) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: _table(density: density)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('T-DEN-01: compact table is shorter than comfortable', (
    tester,
  ) async {
    await _pump(tester, TableDensity.comfortable);
    final comfortableHeight = tester
        .getSize(find.byType(AdminDataTable))
        .height;
    await _pump(tester, TableDensity.compact);
    final compactHeight = tester.getSize(find.byType(AdminDataTable)).height;
    expect(compactHeight, lessThan(comfortableHeight));
  });

  testWidgets('T-DEN-02: compact header padding (6) < comfortable (10)', (
    tester,
  ) async {
    await _pump(tester, TableDensity.comfortable);
    expect(_cellVerticals(tester).toSet(), {10.0});
    await _pump(tester, TableDensity.compact);
    expect(_cellVerticals(tester).toSet(), {6.0, 5.0});
  });

  testWidgets('T-DEN-03: default renders today’s padding exactly (10/10)', (
    tester,
  ) async {
    await _pump(tester, TableDensity.comfortable);
    expect(_cellVerticals(tester).toSet(), {10.0});
  });
}

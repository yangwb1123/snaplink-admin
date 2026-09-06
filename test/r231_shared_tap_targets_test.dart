import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/admin_data_table/header_cell.dart';
import 'package:sso_admin/widgets/brand_logo.dart';

Future<void> _focusWithTab(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 24; i++) {
    if (tester
            .getSemantics(finder)
            .getSemanticsData()
            .flagsCollection
            .isFocused ==
        ui.Tristate.isTrue) {
      return;
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  fail('target did not receive keyboard focus');
}

void main() {
  testWidgets('R231: tappable BrandLogo keeps a 32px visual and 48px target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: BrandLogo(onTap: () => taps++)),
        ),
      ),
    );

    final logo = find.byType(BrandLogo);
    final visual = find.descendant(of: logo, matching: find.byType(Container));
    final control = find.descendant(of: logo, matching: find.byType(InkWell));
    expect(tester.getSize(visual), const Size(32, 32));
    expect(tester.getSize(control).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
    expect(find.byTooltip('Snaplink Admin'), findsOneWidget);

    final node = tester.getSemantics(control);
    expect(node.rect.width, greaterThanOrEqualTo(48));
    expect(node.rect.height, greaterThanOrEqualTo(48));
    expect(node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    expect(node.getSemanticsData().hasAction(ui.SemanticsAction.focus), isTrue);
    expect(
      node.getSemanticsData().flagsCollection.isFocused,
      isNot(ui.Tristate.none),
    );

    await tester.tap(control);
    expect(taps, 1);
    await _focusWithTab(tester, control);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, 2);
    semantics.dispose();
  });

  testWidgets('R231: compact sortable header exposes a 48px header target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var sortColumn = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AdminDataTableHeaderCell(
              column: AdminDataColumn(
                id: 'name',
                label: 'Name',
                sortable: true,
                builder: (context, index) => const SizedBox.shrink(),
              ),
              sorted: true,
              ascending: true,
              sortable: true,
              density: TableDensity.compact,
              onTap: () => sortColumn = 'name',
            ),
          ),
        ),
      ),
    );

    final header = find.byType(AdminDataTableHeaderCell);
    final control = find.descendant(of: header, matching: find.byType(InkWell));
    expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(find.byIcon(Icons.arrow_upward)), const Size(12, 12));

    final node = tester.getSemantics(control);
    expect(node.rect.height, greaterThanOrEqualTo(48));
    expect(node.getSemanticsData().flagsCollection.isHeader, isTrue);
    expect(node.label, contains('Name'));
    expect(node.label, contains('Ascending'));
    expect(node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    expect(node.getSemanticsData().hasAction(ui.SemanticsAction.focus), isTrue);

    await tester.tap(control);
    expect(sortColumn, 'name');
    sortColumn = '';
    await _focusWithTab(tester, control);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(sortColumn, 'name');
    semantics.dispose();
  });

  testWidgets('R231: enabled CopyableCell has a 48px target and feedback', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
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
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => CopyableCell(
                text: 'client-1',
                contextProvider: () => context,
              ),
            ),
          ),
        ),
      ),
    );

    final cell = find.byType(CopyableCell);
    final control = find.descendant(of: cell, matching: find.byType(InkWell));
    expect(
      tester.getSize(find.byIcon(Icons.copy_outlined)),
      const Size(12, 12),
    );
    expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
    expect(find.byTooltip('Click to copy'), findsOneWidget);

    final node = tester.getSemantics(control);
    expect(node.rect.height, greaterThanOrEqualTo(48));
    expect(node.tooltip, 'Click to copy');
    expect(node.label, 'client-1');
    expect(node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    expect(node.getSemanticsData().hasAction(ui.SemanticsAction.focus), isTrue);

    await tester.tap(control);
    await tester.pump();
    expect(clipboardText, 'client-1');
    expect(find.text('Copied to clipboard'), findsOneWidget);
    clipboardText = null;
    await _focusWithTab(tester, control);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(clipboardText, 'client-1');
    semantics.dispose();
  });

  testWidgets('R231: card copy action stays nested outside row action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    String? clipboardText;
    var rowTaps = 0;
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
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: AdminDataTable(
              columns: [
                AdminDataColumn(
                  id: 'id',
                  label: 'ID',
                  builder: (context, index) => CopyableCell(
                    text: 'id-$index',
                    contextProvider: () => context,
                  ),
                ),
                AdminDataColumn(
                  id: 'kind',
                  label: 'Kind',
                  builder: (context, index) => TableCellText('kind-$index'),
                ),
              ],
              itemCount: 1,
              rowBuilder: (context, index) => const SizedBox.shrink(),
              onRowTap: (_) => rowTaps++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final copyControl = find.byType(IconButton);
    expect(tester.getSize(copyControl).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(copyControl).height, greaterThanOrEqualTo(48));
    await tester.tap(copyControl);
    await tester.pump();
    expect(clipboardText, 'id-0');
    expect(rowTaps, 0);
    await _focusWithTab(tester, copyControl);
    clipboardText = null;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(clipboardText, 'id-0');
    expect(rowTaps, 0);

    await tester.tap(find.text('Kind: kind-0'));
    expect(rowTaps, 1);
    final rowControl = find
        .ancestor(of: find.text('Kind: kind-0'), matching: find.byType(InkWell))
        .first;
    await _focusWithTab(tester, rowControl);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(rowTaps, 2);
    semantics.dispose();
  });
}

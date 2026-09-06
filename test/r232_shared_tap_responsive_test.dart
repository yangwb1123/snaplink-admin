import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/admin_data_table/header_cell.dart';
import 'package:sso_admin/widgets/brand_logo.dart';

const _widths = <double>[240, 320, 400, 640, 768, 1200];

List<AdminDataColumn> _columns(BuildContext Function() contextProvider) => [
  AdminDataColumn(
    id: 'id',
    label: 'Identifier',
    width: 160,
    sortable: true,
    builder: (context, index) => CopyableCell(
      text: 'a-very-long-identifier-that-must-stay-contained-$index',
      contextProvider: contextProvider,
    ),
  ),
  AdminDataColumn(
    id: 'kind',
    label: 'Relationship',
    width: 160,
    builder: (context, index) =>
        TableCellText('a-very-long-relationship-value-$index'),
  ),
];

Widget _tableApp({
  required double width,
  bool horizontalHost = false,
  bool largeText = false,
  ValueChanged<String>? onSort,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          final table = AdminDataTable(
            columns: _columns(() => context),
            itemCount: 1,
            onSort: onSort,
            rowBuilder: (context, index) => const SizedBox.shrink(),
          );
          final body = horizontalHost
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: table,
                )
              : table;
          return largeText
              ? MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: body,
                )
              : body;
        },
      ),
    ),
  );
}

void main() {
  testWidgets(
    'R232: shared surfaces stay contained at viewport widths and text scale',
    (tester) async {
      for (final width in _widths) {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_tableApp(width: width, largeText: true));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$width px');
        expect(find.byIcon(Icons.copy_outlined), findsWidgets);
        if (width >= 640) {
          expect(find.text('Identifier'), findsOneWidget);
        } else {
          expect(find.byIcon(Icons.chevron_right), findsOneWidget);
        }
      }
    },
  );

  testWidgets(
    'R232: relationship table remains usable in an unbounded horizontal host',
    (tester) async {
      tester.view.physicalSize = const Size(240, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var sorted = '';
      await tester.pumpWidget(
        _tableApp(
          width: 240,
          horizontalHost: true,
          onSort: (id) => sorted = id,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final header = find.byType(AdminDataTableHeaderCell).first;
      final control = find.descendant(
        of: header,
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
      expect(
        tester
            .getSemantics(control)
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );
      await tester.tap(control);
      expect(sorted, 'id');
    },
  );

  testWidgets('R232: AppBar logo keeps visual and focusable bounds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(240, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              leading: BrandLogo(onTap: () => taps++),
              title: const Text('Long title that must not move the logo'),
            ),
          ),
        ),
      ),
    );
    final logo = find.byType(BrandLogo);
    final visual = find.descendant(of: logo, matching: find.byType(Container));
    final control = find.descendant(of: logo, matching: find.byType(InkWell));
    expect(tester.getSize(visual), const Size(32, 32));
    expect(tester.getSize(control).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
    expect(
      tester
          .getSemantics(control)
          .getSemanticsData()
          .hasAction(ui.SemanticsAction.focus),
      isTrue,
    );
    await tester.tap(control);
    expect(taps, 1);
    semantics.dispose();
  });

  testWidgets('R232: Tab and Enter preserve copy callback', (tester) async {
    tester.view.physicalSize = const Size(640, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
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
    await tester.pumpWidget(_tableApp(width: 640));
    await tester.pumpAndSettle();
    final control = find.descendant(
      of: find.byType(CopyableCell),
      matching: find.byType(InkWell),
    );
    await tester.tap(control);
    await tester.pump();
    copied = null;
    for (var i = 0; i < 10; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final data = tester.getSemantics(control).getSemanticsData();
      if (data.flagsCollection.isFocused == ui.Tristate.isTrue) break;
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(copied, startsWith('a-very-long-identifier'));
  });
}

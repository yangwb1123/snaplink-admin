import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/app_settings.dart';
import 'package:sso_admin/widgets/paginated_list.dart';
import 'package:sso_admin/widgets/search_filter_bar.dart';

/// WS4：统一列表 chrome（PaginationControls + SearchFilterBar）。
///
/// 覆盖：page: null 无 "Page null"；summaryLabel en/zh 渲染（含
/// '第 1–25 条，共 100 条' zh 断言，使 tr() 接线非空洞）；'0 results'；
/// <560 Wrap 路径；SearchFilterBar debounce: false 同步 / 默认 300ms
/// 防抖；labelText 渲染。
void main() {
  Widget wrap(Widget child, {Locale? locale}) => MaterialApp(
    locale: locale,
    supportedLocales: AppSettings.supportedLocales,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: Center(child: child)),
  );

  PaginationControls pager({
    int? page,
    int? total,
    String? summaryLabel,
    Map<String, String>? summaryArgs,
  }) => PaginationControls(
    page: page,
    total: total,
    summaryLabel: summaryLabel,
    summaryArgs: summaryArgs,
    canGoBack: false,
    canGoNext: false,
    onPrevious: () {},
    onNext: () {},
  );

  testWidgets('page: null renders no "Page null" pill', (tester) async {
    await tester.pumpWidget(wrap(pager(page: null)));
    expect(find.textContaining('Page'), findsNothing);
  });

  testWidgets('summaryLabel renders en "{start}–{end} of {total}"', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        pager(
          page: null,
          summaryLabel: '{start}–{end} of {total}',
          summaryArgs: const {'start': '1', 'end': '25', 'total': '100'},
        ),
      ),
    );
    expect(find.text('1–25 of 100'), findsOneWidget);
  });

  testWidgets('summaryLabel renders zh "第 1–25 条，共 100 条"', (tester) async {
    await tester.pumpWidget(
      wrap(
        pager(
          page: null,
          summaryLabel: '{start}–{end} of {total}',
          summaryArgs: const {'start': '1', 'end': '25', 'total': '100'},
        ),
        locale: const Locale('zh'),
      ),
    );
    expect(find.text('第 1–25 条，共 100 条'), findsOneWidget);
  });

  testWidgets('"0 results" reuses the existing key', (tester) async {
    await tester.pumpWidget(wrap(pager(page: null, summaryLabel: '0 results')));
    expect(find.text('0 results'), findsOneWidget);
  });

  testWidgets('narrow parent uses the Wrap path, wide keeps the Row path', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    tester.view.physicalSize = const Size(400, 600);
    await tester.pumpWidget(wrap(pager(page: 2, total: 42)));
    expect(find.byType(Wrap), findsOneWidget);

    tester.view.physicalSize = const Size(800, 600);
    await tester.pumpWidget(wrap(pager(page: 2, total: 42)));
    expect(find.byType(Wrap), findsNothing);
    expect(find.text('Page 2'), findsOneWidget);
    expect(find.text('42 total'), findsOneWidget);
  });

  group('SearchFilterBar', () {
    testWidgets('debounce: false emits synchronously without a timer', (
      tester,
    ) async {
      final emitted = <String>[];
      await tester.pumpWidget(
        wrap(SearchFilterBar(debounce: false, onSearchChanged: emitted.add)),
      );

      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump(const Duration(milliseconds: 100));
      expect(emitted, ['a']);
    });

    testWidgets('default debounce emits after 300ms', (tester) async {
      final emitted = <String>[];
      await tester.pumpWidget(
        wrap(SearchFilterBar(onSearchChanged: emitted.add)),
      );

      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump(const Duration(milliseconds: 100));
      expect(emitted, isEmpty); // debounce window still open
      await tester.pump(const Duration(milliseconds: 250));
      expect(emitted, ['a']);
    });

    testWidgets('labelText renders instead of hintText', (tester) async {
      await tester.pumpWidget(
        wrap(SearchFilterBar(labelText: 'Filter', onSearchChanged: (_) {})),
      );
      expect(find.widgetWithText(TextField, 'Filter'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/widgets/paginated_list.dart';

/// 分页高风险路径（R46）组件级测试：PaginatedListMixin 游标状态机 +
/// EmptyPageState 非首页空页。
///
/// 覆盖：① 初始第一页；② goNext 推进并记录游标；③ null token 拒绝；
/// ④ 同帧双触发防重入（连点 Next 只进一页）；⑤ goPrevious 与首页守卫；
/// ⑥ resetPagination 回第一页；⑦ EmptyPageState 文案 + 回首页动作。
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  Future<_PaginationHostState> mountHost(WidgetTester tester) async {
    final key = GlobalKey<_PaginationHostState>();
    await tester.pumpWidget(wrap(_PaginationHost(key: key)));
    return key.currentState!;
  }

  group('PaginatedListMixin', () {
    testWidgets('starts on the first page with no token', (tester) async {
      final host = await mountHost(tester);
      expect(host.onFirstPage, isTrue);
      expect(host.canGoBack, isFalse);
      expect(host.currentPage, 1);
      expect(host.currentPageToken, isNull);
    });

    testWidgets('goNext advances and records the cursor', (tester) async {
      final host = await mountHost(tester);
      host.goNext('page-2', page: Object());
      await tester.pump();
      expect(host.onFirstPage, isFalse);
      expect(host.canGoBack, isTrue);
      expect(host.currentPage, 2);
      expect(host.currentPageToken, 'page-2');

      host.goNext('page-3', page: Object());
      await tester.pump();
      expect(host.currentPage, 3);
      expect(host.currentPageToken, 'page-3');
    });

    testWidgets('goNext without a page arg still advances (R69 哨兵修复)', (
      tester,
    ) async {
      final host = await mountHost(tester);
      host.goNext('page-2');
      await tester.pump();
      expect(host.currentPage, 2);
      expect(host.currentPageToken, 'page-2');
      // 同 null 页再次调用：视为同帧重复，拒绝推进。
      host.goNext('page-3');
      await tester.pump();
      expect(host.currentPage, 2);
    });

    testWidgets('goNext ignores a null token', (tester) async {
      final host = await mountHost(tester);
      host.goNext(null, page: Object());
      await tester.pump();
      expect(host.currentPage, 1);
      expect(host.canGoNext, isTrue);
    });

    testWidgets('same-frame double trigger advances only once (R46 防重入)', (
      tester,
    ) async {
      final host = await mountHost(tester);
      final page = Object();
      host.goNext('page-2', page: page);
      host.goNext('page-3', page: page); // 同帧第二次：忽略
      await tester.pump();
      expect(host.currentPage, 2);
      expect(host.currentPageToken, 'page-2');
    });

    testWidgets('a new page object re-enables advancing', (tester) async {
      final host = await mountHost(tester);
      host.goNext('page-2', page: Object());
      await tester.pump();
      host.goNext('page-3', page: Object());
      await tester.pump();
      expect(host.currentPage, 3);
      expect(host.currentPageToken, 'page-3');
    });

    testWidgets('goPrevious walks back and is guarded at the first page', (
      tester,
    ) async {
      final host = await mountHost(tester);
      host.goNext('page-2', page: Object());
      host.goNext('page-3', page: Object());
      await tester.pump();
      host.goPrevious();
      await tester.pump();
      expect(host.currentPage, 2);
      expect(host.currentPageToken, 'page-2');
      host.goPrevious();
      await tester.pump();
      expect(host.currentPage, 1);
      expect(host.currentPageToken, isNull);
      host.goPrevious(); // 首页再退：no-op
      await tester.pump();
      expect(host.currentPage, 1);
    });

    testWidgets('resetPagination returns to the first page', (tester) async {
      final host = await mountHost(tester);
      host.goNext('page-2', page: Object());
      host.goNext('page-3', page: Object());
      await tester.pump();
      host.resetPagination();
      await tester.pump();
      expect(host.onFirstPage, isTrue);
      expect(host.canGoBack, isFalse);
      expect(host.currentPage, 1);
      expect(host.currentPageToken, isNull);
    });
  });

  group('EmptyPageState', () {
    testWidgets('renders the non-first-page guidance and back action', (
      tester,
    ) async {
      var back = false;
      await tester.pumpWidget(
        wrap(EmptyPageState(onBackToFirst: () => back = true)),
      );
      expect(find.text('No data on this page'), findsOneWidget);
      expect(find.text('Back to first page'), findsOneWidget);
      await tester.tap(find.text('Back to first page'));
      expect(back, isTrue);
    });
  });
}

/// PaginatedListMixin 测试宿主：真实 StatefulWidget 状态以触发 setState，
/// canGoNext 由宿主提供（首帧为 true）。
class _PaginationHost extends StatefulWidget {
  const _PaginationHost({super.key});

  @override
  State<_PaginationHost> createState() => _PaginationHostState();
}

class _PaginationHostState extends State<_PaginationHost>
    with PaginatedListMixin<_PaginationHost> {
  @override
  bool? get canGoNext => true;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

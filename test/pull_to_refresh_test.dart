import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';

/// PullToRefresh（R56 新增共享组件）组件级测试。
///
/// 覆盖：① 子内容渲染；② 短内容（不足一屏）仍可下拉触发
/// （ScrollConfiguration 注入 AlwaysScrollableScrollPhysics）；③ 下拉触发
/// onRefresh；④ onRefresh 抛错被吞（错误由页面自身呈现，不外泄到框架）。
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders the wrapped scrollable child', (tester) async {
    await tester.pumpWidget(
      wrap(
        PullToRefresh(
          onRefresh: () async {},
          child: ListView(
            children: [
              for (var i = 0; i < 3; i++) ListTile(title: Text('Item $i')),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Item 0'), findsOneWidget);
    expect(find.text('Item 2'), findsOneWidget);
    // 包裹层仍是一个 RefreshIndicator。
    expect(
      find.descendant(
        of: find.byType(PullToRefresh),
        matching: find.byType(RefreshIndicator),
      ),
      findsOneWidget,
    );
  });

  testWidgets('short content can still be pulled to refresh (physics)', (
    tester,
  ) async {
    // 内容不足一屏：ListView 默认 physics 在内容不满时会禁用 overscroll，
    // 由 PullToRefresh 注入 AlwaysScrollableScrollPhysics 保证可下拉。
    var refreshed = 0;
    await tester.pumpWidget(
      wrap(
        PullToRefresh(
          onRefresh: () async => refreshed++,
          child: ListView(
            children: [
              ListTile(title: const Text('Only item')),
            ],
          ),
        ),
      ),
    );
    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // 滚动动画
    await tester.pump(const Duration(seconds: 1)); // 指示器收拢
    await tester.pump(const Duration(seconds: 1)); // 指示器隐藏
    expect(refreshed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pull-to-refresh invokes onRefresh', (tester) async {
    var refreshed = 0;
    await tester.pumpWidget(
      wrap(
        PullToRefresh(
          onRefresh: () async => refreshed++,
          child: ListView(
            children: [
              for (var i = 0; i < 20; i++) ListTile(title: Text('Item $i')),
            ],
          ),
        ),
      ),
    );
    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(refreshed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a second pull re-invokes onRefresh (no sticky state)', (
    tester,
  ) async {
    var refreshed = 0;
    await tester.pumpWidget(
      wrap(
        PullToRefresh(
          onRefresh: () async => refreshed++,
          child: ListView(
            children: [
              for (var i = 0; i < 20; i++) ListTile(title: Text('Item $i')),
            ],
          ),
        ),
      ),
    );
    for (var round = 0; round < 2; round++) {
      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
    expect(refreshed, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onRefresh errors are swallowed, not surfaced to the framework', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        PullToRefresh(
          onRefresh: () async => throw Exception('page surfaces this itself'),
          child: ListView(
            children: [
              for (var i = 0; i < 20; i++) ListTile(title: Text('Item $i')),
            ],
          ),
        ),
      ),
    );
    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    // RefreshIndicator 的 onRefresh future 不得把异常抛给框架测试。
    expect(tester.takeException(), isNull);
  });
}

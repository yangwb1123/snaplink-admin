import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/widgets/batch_action_bar.dart';
import 'package:sso_admin/widgets/batch_feedback.dart';
import 'package:sso_admin/widgets/batch_selection.dart';

/// 批量组件（BatchActionBar / showBatchResultSnackBar / BatchSelection mixin）
/// 组件级测试。
///
/// 覆盖：① 栏的显隐与计数；② 动作渲染与破坏性样式；③ isLoading 禁用 +
/// 行内进度；④ 退出选择回调；⑤ 窄屏 Wrap 不溢出；⑥ 批量结果 SnackBar
/// 成功/部分失败两态 + 失败明细对话框；⑦ 选择 mixin 的 toggle/clear/rowTap。
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('BatchActionBar', () {
    testWidgets('hidden entirely when nothing is selected', (tester) async {
      await tester.pumpWidget(
        wrap(
          BatchActionBar(
            selectedCount: 0,
            actions: const [],
            onClearSelection: () {},
          ),
        ),
      );
      expect(find.byType(BatchActionBar), findsOneWidget);
      expect(find.byType(Container), findsNothing);
      expect(find.text('0 selected'), findsNothing);
    });

    testWidgets('shows the selected count and action labels', (tester) async {
      var fired = '';
      await tester.pumpWidget(
        wrap(
          BatchActionBar(
            selectedCount: 3,
            actions: [
              BatchAction(
                label: 'Approve',
                icon: Icons.check,
                onPressed: () => fired = 'approve',
              ),
              BatchAction(
                label: 'Delete',
                icon: Icons.delete,
                onPressed: () => fired = 'delete',
                destructive: true,
              ),
            ],
            onClearSelection: () => fired = 'clear',
          ),
        ),
      );
      expect(find.text('3 selected'), findsOneWidget);
      await tester.tap(find.text('Approve'));
      expect(fired, 'approve');
      await tester.tap(find.text('Delete'));
      expect(fired, 'delete');
    });

    testWidgets('destructive action uses the error color', (tester) async {
      await tester.pumpWidget(
        wrap(
          BatchActionBar(
            selectedCount: 1,
            actions: [
              BatchAction(
                label: 'Delete',
                icon: Icons.delete,
                onPressed: () {},
                destructive: true,
              ),
            ],
            onClearSelection: () {},
          ),
        ),
      );
      final button = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Delete'),
          matching: find.byType(TextButton),
        ),
      );
      final style = button.style;
      expect(
        style?.foregroundColor?.resolve({}),
        Theme.of(tester.element(find.text('Delete'))).colorScheme.error,
      );
    });

    testWidgets('isLoading shows spinner and disables actions and clear', (
      tester,
    ) async {
      var fired = false;
      await tester.pumpWidget(
        wrap(
          BatchActionBar(
            selectedCount: 2,
            isLoading: true,
            actions: [
              BatchAction(
                label: 'Approve',
                icon: Icons.check,
                onPressed: () => fired = true,
              ),
            ],
            onClearSelection: () => fired = true,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Running'), findsOneWidget);
      final approve = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Approve'),
          matching: find.byType(TextButton),
        ),
      );
      expect(approve.onPressed, isNull);
      final clear = tester.widget<IconButton>(find.byType(IconButton));
      expect(clear.onPressed, isNull);
      await tester.tap(find.text('Approve'), warnIfMissed: false);
      expect(fired, isFalse);
    });

    testWidgets('clear selection fires the callback', (tester) async {
      var cleared = false;
      await tester.pumpWidget(
        wrap(
          BatchActionBar(
            selectedCount: 5,
            actions: const [],
            onClearSelection: () => cleared = true,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.close));
      expect(cleared, isTrue);
    });

    testWidgets('narrow viewport wraps without overflow', (tester) async {
      tester.view.physicalSize = const Size(375, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrap(
          BatchActionBar(
            selectedCount: 12,
            actions: [
              BatchAction(
                label: 'Approve',
                icon: Icons.check,
                onPressed: () {},
              ),
              BatchAction(label: 'Reject', icon: Icons.close, onPressed: () {}),
              BatchAction(
                label: 'Delete',
                icon: Icons.delete,
                onPressed: () {},
                destructive: true,
              ),
            ],
            onClearSelection: () {},
          ),
        ),
      );
      expect(find.text('12 selected'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('showBatchResultSnackBar', () {
    Future<void> pumpFeedback(
      WidgetTester tester, {
      required List<String> failures,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showBatchResultSnackBar(
                  context,
                  message: 'Updated 2 items',
                  failures: failures,
                ),
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
    }

    testWidgets('all-succeeded shows the summary without an action', (
      tester,
    ) async {
      await pumpFeedback(tester, failures: const []);
      expect(find.text('Updated 2 items'), findsOneWidget);
      expect(find.text('View details'), findsNothing);
    });

    testWidgets('partial failure shows error snackbar with detail entry', (
      tester,
    ) async {
      await pumpFeedback(
        tester,
        failures: const ['id-1: rejected', 'id-2: not found', 'id-3: timeout'],
      );
      expect(find.text('Updated 2 items'), findsOneWidget);
      expect(find.text('View details'), findsOneWidget);
      // 明细对话框逐项列出全部失败项（R25 不再截断到前 3 条）。
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      expect(find.text('Failed items (3)'), findsOneWidget);
      expect(find.text('id-1: rejected'), findsOneWidget);
      expect(find.text('id-2: not found'), findsOneWidget);
      expect(find.text('id-3: timeout'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Failed items (3)'), findsNothing);
    });
  });

  group('BatchSelection mixin', () {
    Future<_HostHarnessState> mountHost(WidgetTester tester) async {
      final key = GlobalKey<_HostHarnessState>();
      await tester.pumpWidget(wrap(_HostHarness(key: key)));
      return key.currentState!;
    }

    testWidgets('toggleSelect toggles membership and drives selecting', (
      tester,
    ) async {
      final host = await mountHost(tester);
      expect(host.selecting, isFalse);

      host.toggleSelect('a');
      await tester.pump();
      expect(host.selecting, isTrue);
      expect(host.selected, {'a'});

      host.toggleSelect('b');
      await tester.pump();
      expect(host.selected, {'a', 'b'});

      host.toggleSelect('a');
      await tester.pump();
      expect(host.selected, {'b'});
    });

    testWidgets('clearSelection empties the set', (tester) async {
      final host = await mountHost(tester);
      host.toggleSelect('a');
      host.toggleSelect('b');
      await tester.pump();
      host.clearSelection();
      await tester.pump();
      expect(host.selected, isEmpty);
      expect(host.selecting, isFalse);
    });

    testWidgets('rowTap: selection mode routes to toggle, otherwise default', (
      tester,
    ) async {
      final host = await mountHost(tester);

      var defaultFired = 0;
      final idleTap = host.rowTap('a', () => defaultFired++);
      expect(idleTap, isNotNull);
      idleTap!();
      expect(defaultFired, 1);
      expect(host.selected, isEmpty);

      host.toggleSelect('b');
      await tester.pump();
      final selectTap = host.rowTap('b', () => defaultFired++);
      expect(selectTap, isNotNull);
      selectTap!();
      expect(host.selected, isEmpty); // 选择模式下点击 = 取消选择
      expect(defaultFired, 1);
    });
  });
}

/// BatchSelection 测试宿主：真实 StatefulWidget 状态以触发 setState。
class _HostHarness extends StatefulWidget {
  const _HostHarness({super.key});

  @override
  State<_HostHarness> createState() => _HostHarnessState();
}

class _HostHarnessState extends State<_HostHarness>
    with BatchSelection<_HostHarness> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/widgets/session_list_rows.dart';

/// sessionTile / deviceHint（portal 会话列表行，R53 新增 busy 防重入）
/// 组件级测试。
///
/// 覆盖：① 行渲染（id、since/expires 元信息、UA 设备提示、信任标签）；
/// ② Revoke 触发 onRevoke(id)；③ busy 置位时行尾 spinner 且无按钮；
/// ④ deviceHint 的 UA 归约（浏览器/OS 组合、未知 UA 截断）。
void main() {
  /// Builder 桥接：sessionTile 需要 BuildContext（tr/主题），在树内取得。
  Widget wrapSession(
    Map<String, dynamic> session,
    Future<void> Function(String) onRevoke, {
    bool busy = false,
  }) => MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) =>
            sessionTile(context, session, onRevoke, busy: busy),
      ),
    ),
  );

  testWidgets('renders id, meta lines and device posture', (tester) async {
    final session = {
      'id': 'sess-1',
      'created_at': '2026-08-01T10:00:00Z',
      'expires_at': '2026-09-01T10:00:00Z',
      'ip': '10.0.0.7',
      'user_agent':
          'Mozilla/5.0 (Windows NT 10.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36',
      'device_name': 'Work laptop',
      'device_platform': 'desktop',
      'device_browser': 'chrome',
      'trust_label': 'Trusted',
    };
    await tester.pumpWidget(
      wrapSession(session, (_) async {}),
    );
    expect(find.text('sess-1'), findsOneWidget);
    expect(find.textContaining('since '), findsOneWidget);
    expect(find.textContaining('expires '), findsOneWidget);
    expect(find.textContaining('10.0.0.7'), findsOneWidget);
    expect(find.textContaining('Chrome on Windows'), findsOneWidget);
    expect(find.textContaining('Work laptop'), findsOneWidget);
    expect(find.textContaining('Trusted'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Revoke fires onRevoke with the session id', (tester) async {
    String? revoked;
    await tester.pumpWidget(
      wrapSession({'id': 'sess-9'}, (id) async => revoked = id),
    );
    await tester.tap(find.text('Revoke'));
    expect(revoked, 'sess-9');
  });

  testWidgets('busy replaces the button with an in-row spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapSession({'id': 'sess-2'}, (_) async {}, busy: true),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Revoke'), findsNothing);
  });

  group('deviceHint', () {
    /// 在 Localizations 之下取 context（MaterialApp 元素本身在其上）。
    late BuildContext captured;
    Widget probe() => MaterialApp(
      home: Scaffold(
        body: _ContextProbe((context) => captured = context),
      ),
    );
    String hint(String ua) => deviceHint(captured, ua);

    testWidgets('maps Chrome on Windows', (tester) async {
      await tester.pumpWidget(probe());
      expect(
        hint('Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0'),
        'Chrome on Windows',
      );
    });

    testWidgets('maps Firefox on Android and Edge on macOS', (tester) async {
      await tester.pumpWidget(probe());
      expect(hint('Mozilla/5.0 (Android 14) Firefox/126.0'), 'Firefox on Android');
      expect(
        hint('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Edg/125.0'),
        'Edge on macOS',
      );
    });

    testWidgets('falls back to the truncated raw UA when unknown', (
      tester,
    ) async {
      await tester.pumpWidget(probe());
      final long = 'Some-Unknown-Client/${'x' * 60}';
      expect(hint(long), '${long.substring(0, 40)}…');
    });
  });
}

/// 挂载时捕获其下的 BuildContext（Localizations 之下）。
class _ContextProbe extends StatelessWidget {
  final void Function(BuildContext) onContext;
  const _ContextProbe(this.onContext);

  @override
  Widget build(BuildContext context) {
    onContext(context);
    return const SizedBox.shrink();
  }
}

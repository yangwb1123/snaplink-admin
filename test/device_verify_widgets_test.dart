import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/device/device_verify_widgets.dart';

/// device 入口共享组件（DeviceRequestPreview / DeviceDecisionButtons /
/// DeviceStatusBlock / DeviceInlineNotice）组件级测试。
///
/// 页面级（device_verify_screen）已由 entry_ux_test 覆盖；本文件补齐
/// 纯组件分支：预览回退、决策按钮 busy/checking 态、状态块 spinner 态、
/// 内联提示 contained/liveRegion 变体。
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('DeviceRequestPreview', () {
    testWidgets('renders client name and requested scopes', (tester) async {
      await tester.pumpWidget(
        wrap(
          DeviceRequestPreview(
            preview: {
              'client_name': 'My App',
              'scopes': ['openid', 'profile'],
            },
          ),
        ),
      );
      expect(find.text('My App'), findsOneWidget);
      expect(find.textContaining('openid, profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('falls back to client_id when client_name is absent', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          DeviceRequestPreview(
            preview: {
              'client_id': 'client-abc',
              'scopes': ['openid'],
            },
          ),
        ),
      );
      expect(find.text('client-abc'), findsOneWidget);
      expect(find.textContaining('openid'), findsOneWidget);
    });

    testWidgets('renders without crashing when preview is minimal', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(DeviceRequestPreview(preview: {'scopes': <Object>[]})),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('DeviceDecisionButtons', () {
    testWidgets('approve and deny fire their callbacks', (tester) async {
      var approved = false;
      var denied = false;
      await tester.pumpWidget(
        wrap(
          DeviceDecisionButtons(
            busy: false,
            checking: false,
            onDeny: () => denied = true,
            onApprove: () => approved = true,
          ),
        ),
      );
      await tester.tap(find.text('Deny'));
      expect(denied, isTrue);
      await tester.tap(find.text('Approve'));
      expect(approved, isTrue);
    });

    testWidgets('busy shows spinner on approve, checking keeps the icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          DeviceDecisionButtons(
            busy: true,
            checking: false,
            onDeny: () {},
            onApprove: () {},
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);

      await tester.pumpWidget(
        wrap(
          DeviceDecisionButtons(
            busy: true,
            checking: true,
            onDeny: () {},
            onApprove: () {},
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('disabled when callbacks are null', (tester) async {
      await tester.pumpWidget(
        wrap(
          DeviceDecisionButtons(
            busy: false,
            checking: false,
            onDeny: null,
            onApprove: null,
          ),
        ),
      );
      final deny = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      final approve = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(deny.onPressed, isNull);
      expect(approve.onPressed, isNull);
    });
  });

  group('DeviceStatusBlock', () {
    testWidgets('spinner mode shows progress instead of an icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const DeviceStatusBlock(spinner: true, title: 'Checking code')),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Checking code'), findsOneWidget);
    });

    testWidgets('icon mode shows icon, title and subtitle', (tester) async {
      await tester.pumpWidget(
        wrap(
          const DeviceStatusBlock(
            icon: Icons.check_circle,
            title: 'Approved',
            subtitle: 'You may close this page',
          ),
        ),
      );
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('You may close this page'), findsOneWidget);
    });
  });

  group('DeviceInlineNotice', () {
    testWidgets('renders text and icon', (tester) async {
      await tester.pumpWidget(
        wrap(
          DeviceInlineNotice(
            text: 'Enter the code from your device',
            icon: Icons.devices_other,
            color: Colors.grey,
          ),
        ),
      );
      expect(find.text('Enter the code from your device'), findsOneWidget);
      expect(find.byIcon(Icons.devices_other), findsOneWidget);
    });

    testWidgets('contained variant and liveRegion semantics apply', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          DeviceInlineNotice(
            text: 'Something went wrong',
            icon: Icons.error_outline,
            color: Colors.red,
            contained: true,
            liveRegion: true,
          ),
        ),
      );
      final semantics = tester.widgetList<Semantics>(find.byType(Semantics));
      expect(
        semantics.any((s) => s.properties.liveRegion == true),
        isTrue,
        reason: 'liveRegion 应标记在某个 Semantics 节点上',
      );
      expect(tester.takeException(), isNull);
    });
  });
}

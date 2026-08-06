import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, SystemChannels;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/audit_log_tab.dart';
import 'package:sso_admin/screens/admin/change_approvals_tab.dart';
import 'package:sso_admin/screens/admin/tenant_detail_tabs.dart';
import 'package:sso_admin/screens/admin/user_detail_widgets.dart';
import 'package:sso_admin/screens/admin/user_support_tab.dart';
import 'package:sso_admin/services/audit_log_service.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/shortcuts_dialog.dart';

SnaplinkAdminApi _api(
  Map<String, http.Response Function(http.Request)> routes,
) => SnaplinkAdminApi(
  baseUrl: 'https://sso.example.test',
  accessToken: 'admin-token',
  httpClient: MockClient((request) async {
    final handler = routes[request.url.path];
    if (handler != null) return handler(request);
    return http.Response('{"error":"not found"}', 404);
  }),
);

SnaplinkAdminCapabilities _caps(List<String> paths) =>
    SnaplinkAdminCapabilities([
      for (final path in paths)
        SnaplinkAdminEndpoint(method: 'GET', path: path, feature: 'core'),
    ]);

String? _clipboardText;

void main() {
  setUp(() {
    BrowserNavigation.resetForTest();
  });

  group('AdminBreadcrumb', () {
    testWidgets('renders without throwing on a bare route', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AdminBreadcrumb())),
      );
      expect(find.byType(AdminBreadcrumb), findsOneWidget);
    });
  });

  group('ShortcutsDialog', () {
    testWidgets('lists the reference shortcuts', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ShortcutsDialog())),
      );
      expect(find.textContaining('Ctrl'), findsWidgets);
    });
  });

  group('AuditLogTab', () {
    testWidgets('lists, filters and clears local audit entries', (
      tester,
    ) async {
      final service = AuditLogService();
      addTearDown(service.clear);
      service.record(
        AuditEntry(
          timestamp: DateTime.now(),
          method: 'POST',
          path: '/api/v1/admin/clients',
          statusCode: 200,
          label: 'clients POST',
        ),
      );
      service.record(
        AuditEntry(
          timestamp: DateTime.now(),
          method: 'DELETE',
          path: '/api/v1/admin/users',
          statusCode: 200,
          label: 'users DELETE',
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AuditLogTab())),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 entries'), findsOneWidget);
      expect(find.textContaining('/api/v1/admin/clients'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'clients');
      await tester.pumpAndSettle();
      expect(find.textContaining('/api/v1/admin/users'), findsNothing);

      await tester.tap(find.byIcon(Icons.delete_sweep));
      await tester.pumpAndSettle();
      expect(find.text('0 entries'), findsOneWidget);
    });

    testWidgets('exports filtered entries as CSV with injection guard', (
      tester,
    ) async {
      // Mock the platform clipboard so setData/getData resolve in tests.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<Object?, Object?>;
            _clipboardText = args['text'] as String?;
            return null;
          }
          if (call.method == 'Clipboard.getData') {
            return _clipboardText == null ? null : {'text': _clipboardText};
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      final service = AuditLogService();
      addTearDown(service.clear);
      service.record(
        AuditEntry(
          timestamp: DateTime.utc(2026, 8, 5, 12),
          method: 'POST',
          path: '/api/v1/admin/clients',
          statusCode: 200,
          label: '=SUM(A1:A2)',  // formula-injection bait
        ),
      );
      service.record(
        AuditEntry(
          timestamp: DateTime.utc(2026, 8, 5, 13),
          method: 'GET',
          path: '/api/v1/admin/users',
          statusCode: 200,
          label: 'plain label',
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AuditLogTab())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.file_download_outlined));
      await tester.pumpAndSettle();

      // SnackBar reports the exported count (feedback loop).
      expect(find.textContaining('2 entries as CSV'), findsOneWidget);

      // Clipboard holds the CSV with the = cell neutralized to '=SUM...
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      expect(data, isNotNull);
      final csv = data!.text!;
      expect(csv, contains('"POST","/api/v1/admin/clients"'));
      expect(csv, contains('\'=SUM(A1:A2)'));
      expect(csv, contains('"GET","/api/v1/admin/users"'));
      // Filtering narrows the export: search only clients.
      await tester.enterText(find.byType(TextField), 'clients');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.file_download_outlined));
      await tester.pumpAndSettle();
      final filtered = (await Clipboard.getData(Clipboard.kTextPlain))!.text!;
      expect(filtered, contains('/api/v1/admin/clients'));
      expect(filtered, isNot(contains('/api/v1/admin/users')));
    });
  });

  group('ChangeApprovalsTab', () {
    testWidgets('lists changes and approves one with typed confirmation', (
      tester,
    ) async {
      var approved = <String>[];
      final api = _api({
        '/api/v1/admin/changes': (_) => http.Response(
          jsonEncode({
            'changes': [
              {
                'id': 'change-1',
                'action_type': 'rotate_secret',
                'status': 'pending',
                'proposed_by': 'admin-1',
              },
            ],
          }),
          200,
        ),
        '/api/v1/admin/changes/change-1/approve': (request) {
          approved.add(request.url.path);
          return http.Response('{}', 200);
        },
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeApprovalsTab(
              api: api,
              capabilities: _caps(['/api/v1/admin/changes']),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('rotate_secret'), findsOneWidget);
      // The change card is an ExpansionTile; open it to reach the actions.
      await tester.tap(find.text('rotate_secret'));
      await tester.pumpAndSettle();
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      expect(find.text('Approve this change?'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'change-1',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve').last);
      await tester.pumpAndSettle();

      expect(approved, ['/api/v1/admin/changes/change-1/approve']);
      expect(find.text('Change approved.'), findsOneWidget);
    });
  });

  group('TenantDetailTabs', () {
    testWidgets('renders member, invitation and usage tabs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TenantMembersTab(
              members: [
                {'user_id': 'user-1', 'role': 'admin'},
              ],
              error: null,
              onRetry: () {},
              onRemove: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('user-1'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TenantUsageTab(
              usage: {'logins': 5},
              error: null,
              onRetry: () {},
            ),
          ),
        ),
      );
      expect(find.text('5'), findsWidgets);
    });
  });

  group('UserDetailWidgets', () {
    testWidgets('renders the sessions widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserSessionsView(
              sessions: [
                {'id': 'session-1', 'ip': '203.0.113.9'},
              ],
            ),
          ),
        ),
      );
      expect(find.text('session-1'), findsOneWidget);
    });
  });

  group('UserSupportTab', () {
    testWidgets('searches a user and shows sessions', (tester) async {
      final api = _api({
        '/api/v1/admin/users': (_) => http.Response(
          jsonEncode({
            'users': [
              {'id': 'user-1', 'provider': 'local'},
            ],
          }),
          200,
        ),
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserSupportTab(
              api: api,
              capabilities: _caps(['/api/v1/admin/users']),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'User ID'),
        'user-1',
      );
      await tester.tap(find.text('Load account support data'));
      await tester.pumpAndSettle();
      expect(find.text('user-1'), findsOneWidget);
    });
  });
}

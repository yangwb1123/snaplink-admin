import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, SystemChannels;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/admin_route.dart';
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

    testWidgets(
      'module and resource links have 44px targets, button semantics, and route',
      (tester) async {
        AdminRoute.go(
          'clients',
          resourceId: 'client-1',
          subresource: 'sessions',
        );
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: AdminBreadcrumb())),
        );
        await tester.pump();

        final moduleLink = find.widgetWithText(TextButton, 'Clients');
        final resourceLink = find.widgetWithText(TextButton, 'client-1');
        expect(moduleLink, findsOneWidget);
        expect(resourceLink, findsOneWidget);
        expect(tester.getSize(moduleLink).width, greaterThanOrEqualTo(44));
        expect(tester.getSize(moduleLink).height, greaterThanOrEqualTo(44));
        expect(tester.getSize(resourceLink).width, greaterThanOrEqualTo(44));
        expect(tester.getSize(resourceLink).height, greaterThanOrEqualTo(44));
        expect(find.text('Sessions'), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Sessions'), findsNothing);
        expect(
          tester
              .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
              .scrollDirection,
          Axis.horizontal,
        );

        final semantics = tester.ensureSemantics();
        expect(
          tester.getSemantics(moduleLink),
          matchesSemantics(
            label: 'Clients',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
            hasTapAction: true,
            hasFocusAction: true,
          ),
        );
        expect(
          tester.getSemantics(resourceLink),
          matchesSemantics(
            label: 'client-1',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
            hasTapAction: true,
            hasFocusAction: true,
          ),
        );

        await tester.tap(moduleLink);
        await tester.pump();
        expect(BrowserNavigation.currentUri.path, '/admin/clients');

        // Restore the detail route through the existing route API before
        // exercising the resource link; no URL construction is duplicated.
        AdminRoute.go(
          'clients',
          resourceId: 'client-1',
          subresource: 'sessions',
        );
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: AdminBreadcrumb())),
        );
        await tester.pump();
        await tester.tap(find.widgetWithText(TextButton, 'client-1'));
        await tester.pump();
        expect(BrowserNavigation.currentUri.path, '/admin/clients/client-1');
        semantics.dispose();
      },
    );
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
    testWidgets('lists and filters server audit events; ring clear is inert', (
      tester,
    ) async {
      // Seed the local ring so the Clear action is enabled — the timeline
      // must never render these rows (T-12: ring is not evidence).
      final service = AuditLogService();
      addTearDown(service.clear);
      service.record(
        AuditEntry(
          timestamp: DateTime.now(),
          method: 'POST',
          path: '/api/v1/admin/forged',
          statusCode: 200,
          label: 'forged entry',
        ),
      );
      final api = _api({
        '/api/v1/audit/events': (_) => http.Response(
          jsonEncode({
            'events': [
              {
                'id': 'e-1',
                'type': 'admin_client_created',
                'outcome': 'success',
                'timestamp': '2026-08-05T12:00:00Z',
                'actor_id': 'admin-1',
                'client_id': 'console',
                'tenant_id': 'acme',
              },
              {
                'id': 'e-2',
                'type': 'admin_user_deleted',
                'outcome': 'failure',
                'timestamp': '2026-08-05T13:00:00Z',
                'actor_id': 'admin-2',
                'client_id': 'console',
                'tenant_id': 'acme',
              },
            ],
            'count': 2,
          }),
          200,
        ),
      });

      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuditLogTab(
              api: api,
              capabilities: _caps(['/api/v1/audit/events']),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 entries'), findsOneWidget);
      expect(find.textContaining('admin_client_created'), findsOneWidget);
      expect(find.textContaining('admin_user_deleted'), findsOneWidget);
      expect(find.textContaining('/api/v1/admin/forged'), findsNothing);
      expect(find.textContaining('forged entry'), findsNothing);

      // Search filters the fetched page client-side.
      await tester.enterText(find.byType(TextField), 'admin_client');
      await tester.pumpAndSettle();
      expect(find.textContaining('admin_client_created'), findsOneWidget);
      expect(find.textContaining('admin_user_deleted'), findsNothing);

      // Clear clears the ring only — server rows keep rendering.
      await tester.tap(find.byIcon(Icons.delete_sweep));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear local debug records').last);
      await tester.pumpAndSettle();
      expect(service.count, 0);
      // Server truth is untouched by the ring clear — the header count is
      // the served page size, and the ring rows stay absent.
      expect(find.text('2 entries'), findsOneWidget);
      expect(find.textContaining('admin_client_created'), findsOneWidget);
      expect(find.textContaining('forged entry'), findsNothing);
    });

    testWidgets('exports server rows as CSV with injection guard', (
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
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      // Bait rows are served by the MockClient (server response), never
      // seeded through the ring.
      final api = _api({
        '/api/v1/audit/events': (_) => http.Response(
          jsonEncode({
            'events': [
              {
                'id': 'r-1',
                'type': '=SUM(A1:A2)', // formula-injection bait
                'outcome': 'success',
                'timestamp': '2026-08-05T12:00:00Z',
                'actor_id': 'admin-1',
                'client_id': 'console',
                'tenant_id': 'acme',
              },
              {
                'id': 'r-2',
                'type': 'plain label',
                'outcome': 'failure',
                // null timestamp: exports as -- without throwing
                'actor_id': '',
                'client_id': '',
                'tenant_id': '',
              },
            ],
            'count': 2,
          }),
          200,
        ),
      });

      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuditLogTab(
              api: api,
              capabilities: _caps(['/api/v1/audit/events']),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.file_download_outlined));
      await tester.pumpAndSettle();

      // SnackBar reports the exported count (feedback loop).
      expect(find.textContaining('2 entries as CSV'), findsOneWidget);

      // Clipboard holds the CSV: constant header, neutralized = cell,
      // null timestamp as --, empty identities as empty cells.
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      expect(data, isNotNull);
      final csv = data!.text!;
      final lines = csv.split('\n').where((line) => line.isNotEmpty).toList();
      expect(
        lines.first,
        'timestamp,type,outcome,id,actor_id,client_id,tenant_id',
      );
      expect(csv, contains('"\'=SUM(A1:A2)"'));
      expect(csv, contains('"plain label"'));
      // Null timestamp exports as -- without throwing; as a `-`-leading
      // cell it also receives the hardened formula-prefix neutralization.
      expect(csv, contains('"\'--"'));
      expect(csv, isNot(contains('\r')));

      // Filtering narrows the export: search only the plain row.
      await tester.enterText(find.byType(TextField), 'plain');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.file_download_outlined));
      await tester.pumpAndSettle();
      final filtered = (await Clipboard.getData(Clipboard.kTextPlain))!.text!;
      expect(filtered, contains('"plain label"'));
      expect(filtered, isNot(contains('=SUM(A1:A2)')));
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

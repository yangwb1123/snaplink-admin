import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/screens/admin/clients_tab.dart';
import 'package:sso_admin/screens/admin/tenants_tab.dart';
import 'package:sso_admin/screens/admin/users_tab.dart';

/// Widget tests for the highest-frequency admin workflows: client, tenant
/// and user list management. Every destructive action must go through
/// ConfirmDialog (with type-to-confirm for permanent operations), and client
/// secret rotation must surface the new secret exactly once in an isolated
/// dialog.
MockClient _mock(Map<String, http.Response Function(http.Request)> routes) =>
    MockClient((request) async {
      final handler = routes[request.url.path];
      if (handler != null) return handler(request);
      return http.Response('{"error":"not found"}', 404);
    });

SSOAdminClient _client(
  Map<String, http.Response Function(http.Request)> routes,
) => SSOAdminClient('https://sso.example.test', httpClient: _mock(routes));

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('ClientsTab', () {
    const clientRow = {
      'id': 'portal-client',
      'name': 'Portal client',
      'active': true,
      'tokenStrategy': 'opaque',
      'client_secret_expires_at': 0,
    };
    const pendingRow = {
      'id': 'pending-app',
      'name': 'Pending app',
      'active': false,
      'tokenStrategy': 'jwt',
      'client_secret_expires_at': 0,
    };

    testWidgets('renders the client list with pagination', (tester) async {
      var requestedQuery = '';
      final client = _client({
        '/api/v1/admin/clients': (request) {
          requestedQuery = request.url.query;
          return http.Response(
            jsonEncode({
              'clients': [clientRow, pendingRow],
              'next_page_token': 'page-2',
              'total_size': 42,
            }),
            200,
          );
        },
      });
      await tester.pumpWidget(_wrap(ClientsTab(client: client)));
      await tester.pumpAndSettle();

      expect(find.text('portal-client'), findsOneWidget);
      expect(find.text('Portal client'), findsOneWidget);
      expect(find.text('Never expires'), findsWidgets);
      expect(find.text('pending-app'), findsOneWidget);
      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('42 total'), findsOneWidget);

      // First request must carry default pagination parameters.
      expect(requestedQuery, contains('page_size=100'));
      expect(requestedQuery, contains('order_by=id'));

      await tester.ensureVisible(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(requestedQuery, contains('page_token=page-2'));
      expect(find.text('Page 2'), findsOneWidget);
      expect(find.text('42 total'), findsOneWidget);

      await tester.ensureVisible(find.text('Previous'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Previous'));
      await tester.pumpAndSettle();
      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('42 total'), findsOneWidget);
    });

    testWidgets('applies a filter query on submit', (tester) async {
      var requestedQuery = '';
      final client = _client({
        '/api/v1/admin/clients': (request) {
          requestedQuery = request.url.query;
          return http.Response(
            jsonEncode({
              'clients': [clientRow],
              'total_size': 1,
            }),
            200,
          );
        },
      });
      await tester.pumpWidget(_wrap(ClientsTab(client: client)));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Filter'),
        'name:portal',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(requestedQuery, contains('filter=name%3Aportal'));
    });

    testWidgets('approves a pending client after confirmation', (tester) async {
      var approved = <String>[];
      final client = _client({
        '/api/v1/admin/clients': (_) => http.Response(
          jsonEncode({
            'clients': [pendingRow],
            'total_size': 1,
          }),
          200,
        ),
        '/api/v1/admin/clients/pending-app/approve': (request) {
          approved.add(request.url.path);
          return http.Response('{}', 200);
        },
      });
      await tester.pumpWidget(_wrap(ClientsTab(client: client)));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve').last);
      await tester.pumpAndSettle();

      expect(approved, ['/api/v1/admin/clients/pending-app/approve']);
      expect(find.text('Client pending-app approved.'), findsOneWidget);
    });

    testWidgets('rejects a pending client with typed confirmation', (
      tester,
    ) async {
      var rejected = <String>[];
      final client = _client({
        '/api/v1/admin/clients': (_) => http.Response(
          jsonEncode({
            'clients': [pendingRow],
            'total_size': 1,
          }),
          200,
        ),
        '/api/v1/admin/clients/pending-app/reject': (request) {
          rejected.add(request.url.path);
          return http.Response('{}', 200);
        },
      });
      await tester.pumpWidget(_wrap(ClientsTab(client: client)));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      expect(find.text('Reject client?'), findsOneWidget);
      // Confirm stays disabled until the client id is typed.
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'wrong-id',
      );
      await tester.pumpAndSettle();
      var button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Reject'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'pending-app',
      );
      await tester.pumpAndSettle();
      button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Reject'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNotNull);
      await tester.tap(find.text('Reject').last);
      await tester.pumpAndSettle();

      expect(rejected, ['/api/v1/admin/clients/pending-app/reject']);
      expect(find.text('Client pending-app rejected.'), findsOneWidget);
    });

    testWidgets('deletes a client with typed confirmation', (tester) async {
      var deleted = <String>[];
      final client = _client({
        '/api/v1/admin/clients': (_) => http.Response(
          jsonEncode({
            'clients': [clientRow],
            'total_size': 1,
          }),
          200,
        ),
        '/api/v1/admin/clients/portal-client': (request) {
          if (request.method == 'DELETE') deleted.add(request.url.path);
          return http.Response('{}', 200);
        },
      });
      await tester.pumpWidget(_wrap(ClientsTab(client: client)));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete client?'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'portal-client',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete permanently'));
      await tester.pumpAndSettle();

      expect(deleted, ['/api/v1/admin/clients/portal-client']);
    });

    testWidgets('rotates a secret and shows the one-time value once', (
      tester,
    ) async {
      var rotated = <String>[];
      final client = _client({
        '/api/v1/admin/clients': (_) => http.Response(
          jsonEncode({
            'clients': [clientRow],
            'total_size': 1,
          }),
          200,
        ),
        '/api/v1/admin/clients/portal-client/rotate-secret': (request) {
          rotated.add(request.body);
          return http.Response(
            jsonEncode({
              'secret': 'ONE-TIME-SECRET',
              'client_secret_expires_at':
                  DateTime.now()
                      .add(const Duration(days: 2))
                      .millisecondsSinceEpoch ~/
                  1000,
            }),
            200,
          );
        },
      });
      await tester.pumpWidget(_wrap(ClientsTab(client: client)));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rotate secret'));
      await tester.pumpAndSettle();
      expect(find.text('Rotate client secret?'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'portal-client',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rotate secret').last);
      await tester.pumpAndSettle();

      expect(rotated, isNotEmpty);
      expect(jsonDecode(rotated.single), isEmpty); // policy defaults
      // The one-time secret lives in an isolated, non-dismissible dialog.
      expect(find.text('New client secret'), findsOneWidget);
      expect(find.text('ONE-TIME-SECRET'), findsOneWidget);
      expect(find.text('This secret will not be shown again.'), findsOneWidget);
      expect(find.text('Expires in <1 day(s) · '), findsNothing);

      // The dialog cannot be dismissed by tapping the barrier.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('ONE-TIME-SECRET'), findsOneWidget);

      await tester.tap(find.text('I have saved it'));
      await tester.pumpAndSettle();
      expect(find.text('ONE-TIME-SECRET'), findsNothing);
    });

    testWidgets('empty state offers to create the first client', (
      tester,
    ) async {
      final client = _client({
        '/api/v1/admin/clients': (_) =>
            http.Response(jsonEncode({'clients': [], 'total_size': 0}), 200),
      });
      await tester.pumpWidget(_wrap(ClientsTab(client: client)));
      await tester.pumpAndSettle();

      expect(find.text('No clients'), findsOneWidget);
      expect(
        find.text('Create your first client to get started.'),
        findsOneWidget,
      );
      // The header's primary action (now a labeled button) and the
      // empty-state action both lead to the create flow.
      expect(find.text('Create client'), findsNWidgets(2));
    });

    testWidgets('batch approve selected clients with success report', (
      tester,
    ) async {
      var approveCalls = <String>[];
      final client = _client({
        '/api/v1/admin/clients': (request) => http.Response(
          jsonEncode({
            'clients': [clientRow, pendingRow],
            'total_size': 2,
          }),
          200,
        ),
        '/api/v1/admin/clients/portal-client/approve': (request) {
          approveCalls.add('portal-client');
          return http.Response('{}', 200);
        },
        '/api/v1/admin/clients/pending-app/approve': (request) {
          approveCalls.add('pending-app');
          return http.Response('{}', 200);
        },
      });
      await tester.pumpWidget(_wrap(ClientsTab(client: client)));
      await tester.pumpAndSettle();

      // Selection mode: long-press enters it, then taps toggle.
      await tester.ensureVisible(find.text('portal-client'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('portal-client'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('pending-app'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('pending-app'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

      // Confirm dialog shows the affected count; confirming runs both.
      await tester.ensureVisible(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();
      expect(find.textContaining('2'), findsWidgets);
      await tester.tap(find.text('Approve').last);
      await tester.pumpAndSettle();
      expect(approveCalls, containsAll(['portal-client', 'pending-app']));
    });

    testWidgets('batch reject reports partial failure details', (tester) async {
      var rejected = 0;
      final client = _client({
        '/api/v1/admin/clients': (request) => http.Response(
          jsonEncode({
            'clients': [clientRow, pendingRow],
            'total_size': 2,
          }),
          200,
        ),
        '/api/v1/admin/clients/portal-client/reject': (request) {
          rejected++;
          return http.Response('{}', 200);
        },
        '/api/v1/admin/clients/pending-app/reject': (request) {
          return http.Response('{"error":"locked"}', 409);
        },
      });
      await tester.pumpWidget(_wrap(ClientsTab(client: client)));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('portal-client'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('portal-client'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('pending-app'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('pending-app'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byIcon(Icons.cancel_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.cancel_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reject').last);
      await tester.pumpAndSettle();

      expect(rejected, 1);
      // Partial-failure report: succeeded count + failure details.
      expect(find.textContaining('1 succeeded'), findsOneWidget);
      expect(find.textContaining('1 failed'), findsOneWidget);
    });

    testWidgets('status filter narrows the server query', (tester) async {
      var requestedQuery = '';
      final client = _client({
        '/api/v1/admin/clients': (request) {
          requestedQuery = request.url.query;
          return http.Response(
            jsonEncode({
              'clients': [clientRow],
              'total_size': 1,
            }),
            200,
          );
        },
      });
      await tester.pumpWidget(_wrap(ClientsTab(client: client)));
      await tester.pumpAndSettle();

      // 打开状态筛选菜单（Dropdown 当前值文本）。
      await tester.tap(find.text('All statuses'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Active only').last);
      await tester.pumpAndSettle();
      expect(requestedQuery, contains('active%3Atrue'));
    });

    testWidgets('batch approve cancels without executing', (tester) async {
      var approveCalls = 0;
      final client = _client({
        '/api/v1/admin/clients': (request) => http.Response(
          jsonEncode({
            'clients': [clientRow],
            'total_size': 1,
          }),
          200,
        ),
        '/api/v1/admin/clients/portal-client/approve': (request) {
          approveCalls++;
          return http.Response('{}', 200);
        },
      });
      await tester.pumpWidget(_wrap(ClientsTab(client: client)));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('portal-client'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('portal-client'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      // 打开确认框后取消——不执行任何调用。
      await tester.ensureVisible(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(approveCalls, 0);
      // 选择保留（用户可继续操作或清除）。
      expect(find.text('1 selected'), findsOneWidget);
    });
  });

  group('TenantsTab', () {
    const activeTenant = {
      'id': 'tenant-a',
      'name': 'Acme Corp',
      'slug': 'acme',
      'status': 'active',
    };
    const suspendedTenant = {
      'id': 'tenant-b',
      'name': 'Globex',
      'slug': 'globex',
      'status': 'suspended',
    };

    testWidgets('renders tenants with their status', (tester) async {
      final client = _client({
        '/api/v1/admin/tenants': (_) => http.Response(
          jsonEncode({
            'tenants': [activeTenant, suspendedTenant],
            'total_size': 2,
          }),
          200,
        ),
      });
      await tester.pumpWidget(_wrap(TenantsTab(client: client)));
      await tester.pumpAndSettle();

      expect(find.text('Acme Corp'), findsOneWidget);
      expect(find.text('acme'), findsOneWidget);
      expect(find.text('Active'), findsWidgets); // StatusChip label
      expect(find.text('globex'), findsOneWidget);
      expect(find.text('Suspended'), findsWidgets);
    });

    testWidgets('batch suspends selected tenants', (tester) async {
      var setStatus = <String>[];
      final client = _client({
        '/api/v1/admin/tenants': (_) => http.Response(
          jsonEncode({
            'tenants': [activeTenant, suspendedTenant],
            'total_size': 2,
          }),
          200,
        ),
        '/api/v1/admin/tenants/tenant-a:set-status': (request) {
          setStatus.add(request.body);
          return http.Response('{}', 200);
        },
        '/api/v1/admin/tenants/tenant-b:set-status': (request) {
          setStatus.add(request.body);
          return http.Response('{}', 200);
        },
      });
      await tester.pumpWidget(_wrap(TenantsTab(client: client)));
      await tester.pumpAndSettle();

      // 长按进入选择 → 勾选两行 → 批量挂起。
      await tester.ensureVisible(find.text('Acme Corp'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Acme Corp'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Globex'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Globex'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      await tester.ensureVisible(find.byIcon(Icons.pause_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.pause_circle_outline));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Suspend tenants').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suspend tenants').last);
      await tester.pumpAndSettle();

      expect(setStatus, hasLength(2));
      expect(
        setStatus.every((b) => b.contains('"status":"suspended"')),
        isTrue,
      );
    });

    testWidgets('suspends a tenant with typed confirmation', (tester) async {
      var setStatus = <String>[];
      final client = _client({
        '/api/v1/admin/tenants': (_) => http.Response(
          jsonEncode({
            'tenants': [activeTenant],
            'total_size': 1,
          }),
          200,
        ),
        '/api/v1/admin/tenants/tenant-a:set-status': (request) {
          setStatus.add(request.body);
          return http.Response('{}', 200);
        },
      });
      await tester.pumpWidget(_wrap(TenantsTab(client: client)));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suspend'));
      await tester.pumpAndSettle();
      expect(find.text('Suspend tenant?'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'tenant-a',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suspend tenant'));
      await tester.pumpAndSettle();

      expect(setStatus.single, contains('"status":"suspended"'));
      expect(find.textContaining('Tenant suspended.'), findsOneWidget);
    });

    testWidgets('activates a suspended tenant', (tester) async {
      var setStatus = <String>[];
      final client = _client({
        '/api/v1/admin/tenants': (_) => http.Response(
          jsonEncode({
            'tenants': [suspendedTenant],
            'total_size': 1,
          }),
          200,
        ),
        '/api/v1/admin/tenants/tenant-b:set-status': (request) {
          setStatus.add(request.body);
          return http.Response('{}', 200);
        },
      });
      await tester.pumpWidget(_wrap(TenantsTab(client: client)));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activate tenant'));
      await tester.pumpAndSettle();

      expect(setStatus.single, contains('"status":"active"'));
      expect(find.text('Tenant activated.'), findsOneWidget);
    });

    testWidgets('deletes a tenant with typed confirmation', (tester) async {
      var deleted = <String>[];
      final client = _client({
        '/api/v1/admin/tenants': (_) => http.Response(
          jsonEncode({
            'tenants': [activeTenant],
            'total_size': 1,
          }),
          200,
        ),
        '/api/v1/admin/tenants/tenant-a': (request) {
          if (request.method == 'DELETE') deleted.add(request.url.path);
          return http.Response('{}', 200);
        },
      });
      await tester.pumpWidget(_wrap(TenantsTab(client: client)));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'tenant-a',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete tenant'));
      await tester.pumpAndSettle();

      expect(deleted, ['/api/v1/admin/tenants/tenant-a']);
    });

    testWidgets('batch deletes selected users', (tester) async {
      var deleted = <String>[];
      final client = _client({
        '/api/v1/admin/users': (_) => http.Response(
          jsonEncode({
            'users': [
              {'id': 'user-1', 'provider': 'local'},
              {'id': 'user-2', 'provider': 'local'},
            ],
            'total_size': 2,
          }),
          200,
        ),
        '/api/v1/admin/users/user-1': (request) {
          if (request.method == 'DELETE') deleted.add('user-1');
          return http.Response('{}', 200);
        },
        '/api/v1/admin/users/user-2': (request) {
          if (request.method == 'DELETE') deleted.add('user-2');
          return http.Response('{}', 200);
        },
      });
      await tester.pumpWidget(_wrap(UsersTab(client: client)));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('user-1'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('user-1'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('user-2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('user-2'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      await tester.ensureVisible(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete users').last);
      await tester.pumpAndSettle();

      expect(deleted, containsAll(['user-1', 'user-2']));
    });
  });

  group('UsersTab', () {
    testWidgets('renders users and deletes one with typed confirmation', (
      tester,
    ) async {
      var deleted = <String>[];
      final client = _client({
        '/api/v1/admin/users': (_) => http.Response(
          jsonEncode({
            'users': [
              {'id': 'user-1', 'provider': 'local'},
            ],
            'total_size': 1,
          }),
          200,
        ),
        '/api/v1/admin/users/user-1': (request) {
          if (request.method == 'DELETE') deleted.add(request.url.path);
          return http.Response('{}', 200);
        },
      });
      await tester.pumpWidget(_wrap(UsersTab(client: client)));
      await tester.pumpAndSettle();

      expect(find.text('user-1'), findsOneWidget);
      expect(find.text('local'), findsWidgets);

      await tester.ensureVisible(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete user?'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'user-1',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete user'));
      await tester.pumpAndSettle();

      expect(deleted, ['/api/v1/admin/users/user-1']);
    });

    testWidgets('shows an empty state for a filtered result', (tester) async {
      final client = _client({
        '/api/v1/admin/users': (_) =>
            http.Response(jsonEncode({'users': [], 'total_size': 0}), 200),
      });
      await tester.pumpWidget(_wrap(UsersTab(client: client)));
      await tester.pumpAndSettle();

      expect(find.text('No users'), findsOneWidget);
      expect(find.text('No users match the current filter.'), findsOneWidget);
    });
  });
}

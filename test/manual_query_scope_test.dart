import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/admin_route.dart';
import 'package:sso_admin/screens/admin/permissions_tab.dart';
import 'package:sso_admin/screens/admin/usage_analytics_tab.dart';
import 'package:sso_admin/screens/admin/user_support_tab.dart';
import 'package:sso_admin/services/browser_navigation.dart';

const _caps = SnaplinkAdminCapabilities([]);
SnaplinkAdminApi _api(Future<http.Response> Function(http.Request) send) =>
    SnaplinkAdminApi(
      baseUrl: 'https://sso.test',
      accessToken: 'fixture',
      httpClient: MockClient(send),
    )..maxRetries = 0;
http.Response _json(Object value) => http.Response(jsonEncode(value), 200);
Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1400, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.widgetWithText(TextField, label);

void main() {
  setUp(BrowserNavigation.resetForTest);
  tearDown(BrowserNavigation.resetForTest);

  testWidgets(
    'permission search loads both named protobuf collections and refreshes both',
    (tester) async {
      AdminRoute.go('permissions');
      var roleCalls = 0, assignmentCalls = 0;
      final api = _api((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), contains('/permissions/client%2Fone/'));
        if (request.url.path.endsWith('/roles')) {
          roleCalls++;
          return _json({
            'totalSize': 1,
            'roles': [
              {
                'code': 'reader-$roleCalls',
                'name': 'Role $roleCalls',
                'permissions': ['read'],
              },
            ],
          });
        }
        assignmentCalls++;
        return _json({
          'totalSize': 1,
          'assignments': [
            {
              'userId': 'alice-$assignmentCalls',
              'roles': ['reader-$assignmentCalls'],
            },
          ],
        });
      });
      await _pump(tester, PermissionsTab(api: api, capabilities: _caps));
      expect(roleCalls, 0);
      await tester.enterText(_field('Client ID'), 'client/one');
      expect(find.text('No roles loaded.'), findsNothing);
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(find.text('Role 1'), findsOneWidget);
      expect(find.text('alice-1'), findsOneWidget);
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(roleCalls, 2);
      expect(assignmentCalls, 2);
      expect(find.text('Role 2'), findsOneWidget);
      expect(find.text('alice-2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('permission submenu history loads only the selected source', (
    tester,
  ) async {
    AdminRoute.go(
      'permissions',
      resourceId: 'client-one',
      subresource: 'roles',
    );
    final paths = <String>[];
    final api = _api((request) async {
      paths.add(request.url.path);
      return request.url.path.endsWith('/roles')
          ? _json({
              'roles': [
                {'code': 'reader', 'name': 'Reader'},
              ],
            })
          : _json({
              'assignments': [
                {
                  'userId': 'alice',
                  'roles': ['reader'],
                },
              ],
            });
    });
    await _pump(tester, PermissionsTab(api: api, capabilities: _caps));
    expect(paths, ['/api/v1/admin/permissions/client-one/roles']);
    AdminRoute.go(
      'permissions',
      resourceId: 'client-one',
      subresource: 'assignments',
    );
    await tester.pumpAndSettle();
    expect(paths.last, '/api/v1/admin/permissions/client-one/assignments');
    expect(paths.length, 2);
    expect(find.text('alice'), findsOneWidget);
  });

  testWidgets(
    'permission partial 403 preserves roles and does not fabricate empty assignments',
    (tester) async {
      AdminRoute.go('permissions');
      final api = _api(
        (request) async => request.url.path.endsWith('/roles')
            ? _json({
                'roles': [
                  {'code': 'reader', 'name': 'Readable role'},
                ],
              })
            : http.Response(
                '{"error":{"code":"forbidden","message":"assignment denied"}}',
                403,
              ),
      );
      await _pump(tester, PermissionsTab(api: api, capabilities: _caps));
      await tester.enterText(_field('Client ID'), 'client-one');
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(find.text('Readable role'), findsOneWidget);
      expect(find.textContaining('assignment denied'), findsOneWidget);
      expect(find.text('No assignments loaded.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editing permission client invalidates prior data and late responses',
    (tester) async {
      AdminRoute.go('permissions');
      final old = Completer<http.Response>();
      final api = _api((request) async {
        expect(request.method, 'GET');
        if (request.url.path.contains('/old/')) return old.future;
        return request.url.path.endsWith('/roles')
            ? _json({
                'roles': [
                  {'code': 'new-role', 'name': 'New role'},
                ],
              })
            : _json({
                'assignments': [
                  {
                    'userId': 'new-user',
                    'roles': ['new-role'],
                  },
                ],
              });
      });
      await _pump(tester, PermissionsTab(api: api, capabilities: _caps));
      await tester.enterText(_field('Client ID'), 'old');
      await tester.tap(find.text('Search'));
      await tester.pump();
      await tester.enterText(_field('Client ID'), 'new');
      await tester.pump();
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      old.complete(
        _json({
          'roles': [
            {'code': 'old-role', 'name': 'Old role'},
          ],
          'assignments': [
            {'userId': 'old-user'},
          ],
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('New role'), findsOneWidget);
      expect(find.text('new-user'), findsOneWidget);
      expect(find.text('Old role'), findsNothing);
      await tester.enterText(_field('Client ID'), 'unqueried');
      await tester.pump();
      expect(find.text('New role'), findsNothing);
      expect(find.text('Assign roles'), findsNothing);
    },
  );

  testWidgets(
    'support typing alone is not a loaded account; all reads refresh',
    (tester) async {
      var sessionCalls = 0;
      final api = _api((request) async {
        expect(request.method, 'GET');
        if (request.url.path.endsWith('/sessions')) {
          sessionCalls++;
          return _json({
            'sessions': [
              {'id': 'session-$sessionCalls'},
            ],
          });
        }
        return _json({});
      });
      await _pump(tester, UserSupportTab(api: api, capabilities: _caps));
      await tester.enterText(find.byKey(const Key('support-user-id')), 'alice');
      await tester.pump();
      expect(find.text('No active sessions.'), findsNothing);
      expect(find.text('Credential recovery and containment'), findsNothing);
      expect(sessionCalls, 0);
      await tester.tap(find.text('Load account support data'));
      await tester.pumpAndSettle();
      expect(find.text('session-1'), findsOneWidget);
      expect(find.text('Current state: Unknown'), findsOneWidget);
      expect(find.text('Current state: active'), findsNothing);
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(sessionCalls, 2);
      expect(find.text('session-2'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('support-user-id')), 'bob');
      await tester.pump();
      expect(find.text('session-2'), findsNothing);
      expect(find.text('Credential recovery and containment'), findsNothing);
    },
  );

  testWidgets('support late responses cannot populate another user', (
    tester,
  ) async {
    final old = Completer<http.Response>();
    final api = _api((request) async {
      if (request.url.path.contains('/old/')) return old.future;
      return request.url.path.endsWith('/sessions')
          ? _json({
              'sessions': [
                {'id': 'new-session'},
              ],
            })
          : _json({});
    });
    await _pump(tester, UserSupportTab(api: api, capabilities: _caps));
    await tester.enterText(find.byKey(const Key('support-user-id')), 'old');
    await tester.tap(find.text('Load account support data'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('support-user-id')), 'new');
    await tester.pump();
    await tester.tap(find.text('Load account support data'));
    await tester.pumpAndSettle();
    old.complete(
      _json({
        'sessions': [
          {'id': 'old-session'},
        ],
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('new-session'), findsOneWidget);
    expect(find.text('old-session'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'support 403 retains source detail, not a fake empty session list',
    (tester) async {
      final api = _api(
        (request) async => request.url.path.endsWith('/sessions')
            ? http.Response(
                '{"error":"forbidden","error_description":"session access denied"}',
                403,
              )
            : _json({}),
      );
      await _pump(tester, UserSupportTab(api: api, capabilities: _caps));
      await tester.enterText(find.byKey(const Key('support-user-id')), 'alice');
      await tester.tap(find.text('Load account support data'));
      await tester.pumpAndSettle();
      expect(find.textContaining('session access denied'), findsOneWidget);
      expect(find.text('No active sessions.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'role dialog cannot retarget a draft when history changes the client',
    (tester) async {
      AdminRoute.go(
        'permissions',
        resourceId: 'old-client',
        subresource: 'roles',
      );
      final api = _api((request) async {
        expect(
          request.method,
          'GET',
          reason: 'Changing client must not submit the role draft',
        );
        return _json({'roles': []});
      });
      await _pump(tester, PermissionsTab(api: api, capabilities: _caps));
      await tester.tap(find.text('Create role'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Role code'),
        'draft-role',
      );
      AdminRoute.go(
        'permissions',
        resourceId: 'new-client',
        subresource: 'roles',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Create role?'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'subject investigation sends bounded queries and refreshes both sources',
    (tester) async {
      var tokens = 0, sessions = 0;
      final api = _api((request) async {
        expect(request.method, 'GET');
        if (request.url.path.contains('/tokens/subjects/')) {
          tokens++;
          expect(request.url.queryParameters, {'client_id': 'client-one'});
          expect(request.url.toString(), contains('/alice%2Fone?'));
          return _json({
            'subject': 'alice/one',
            'counted': true,
            'active_refresh_tokens': tokens,
          });
        }
        if (request.url.path.contains('/sessions/linked/')) {
          sessions++;
          expect(request.url.queryParameters, isEmpty);
          return _json({
            'total': sessions,
            'linked_sessions': [
              {'global_sid': 'global-$sessions', 'legs': []},
            ],
          });
        }
        return request.url.path.endsWith('/top-tenants')
            ? _json({'tenants': []})
            : _json({'buckets': []});
      });
      await _pump(tester, UsageAnalyticsTab(api: api, capabilities: _caps));
      expect(tokens, 0);
      expect(sessions, 0);
      await tester.enterText(_field('Client ID filter'), 'client-one');
      await tester.enterText(_field('Subject'), 'alice/one');
      await tester.tap(find.text('Inspect'));
      await tester.pumpAndSettle();
      expect(find.textContaining('global-1'), findsOneWidget);
      await tester.tap(find.text('Inspect'));
      await tester.pumpAndSettle();
      expect(tokens, 2);
      expect(sessions, 2);
      expect(find.textContaining('"active_refresh_tokens": 2'), findsOneWidget);
      await tester.enterText(_field('Subject'), 'unqueried');
      await tester.pump();
      expect(find.textContaining('global-2'), findsNothing);
    },
  );
}

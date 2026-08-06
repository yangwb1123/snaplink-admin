import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/portal_api.dart';
import 'package:sso_admin/screens/portal/consents_tab.dart';
import 'package:sso_admin/screens/portal/devices_tab.dart';
import 'package:sso_admin/screens/portal/identities_tab.dart';
import 'package:sso_admin/screens/portal/organizations_tab.dart';
import 'package:sso_admin/screens/portal/overview_tab.dart';
import 'package:sso_admin/screens/portal/passkey_enrollment_card.dart';
import 'package:sso_admin/screens/portal/privacy_tab.dart';
import 'package:sso_admin/screens/portal/recovery_codes_card.dart';
import 'package:sso_admin/screens/portal/security_account_credentials.dart';
import 'package:sso_admin/screens/portal/security_tab.dart';
import 'package:sso_admin/screens/portal/sessions_tab.dart';
import 'package:sso_admin/screens/portal/trusted_devices_card.dart';

String _jwt(Map<String, dynamic> claims) {
  final payload = base64Url
      .encode(utf8.encode(jsonEncode(claims)))
      .replaceAll('=', '');
  return 'header.$payload.signature';
}

MockClient _client(Map<String, http.Response Function(http.Request)> routes) =>
    MockClient((request) async {
      final response = routes[request.url.path];
      if (response != null) return response(request);
      return http.Response('{"error":"not found"}', 404);
    });

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('OverviewTab', () {
    testWidgets('renders profile, attributes and authz disclosures', (
      tester,
    ) async {
      final api = PortalApi(
        httpClient: _client({
          '/me': (_) => http.Response(
            jsonEncode({
              'sub': 'user-1',
              'active_sessions': 2,
              'granted_apps': 3,
              'user': {
                'name': 'Ada Lovelace',
                'email': 'ada@example.com',
                'attributes': {'department': 'R&D'},
              },
            }),
            200,
          ),
          '/roles/me': (_) => http.Response(
            jsonEncode({
              'roles': [
                {'name': 'admin'},
              ],
            }),
            200,
          ),
          '/permissions/me': (_) => http.Response(
            jsonEncode({
              'permissions': [
                {'code': 'users:read', 'resource': 'users'},
              ],
            }),
            200,
          ),
          '/menus/me': (_) => http.Response(
            jsonEncode({
              'menus': [
                {'name': 'Settings', 'path': '/settings'},
              ],
            }),
            200,
          ),
        }),
      );

      await tester.pumpWidget(_wrap(OverviewTab(api: api)));
      await tester.pumpAndSettle();

      expect(find.text('user-1'), findsOneWidget);
      // The display name is rendered in the profile row and the edit field.
      expect(find.text('Ada Lovelace'), findsNWidgets(2));
      expect(find.text('ada@example.com'), findsOneWidget);
      // The attribute value renders inside its TextField; the label is the key.
      expect(find.text('department'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'department'))
            .controller
            ?.text,
        'R&D',
      );
      await tester.scrollUntilVisible(
        find.text('Roles and access'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Roles and access'), findsOneWidget);
      expect(find.text('users:read'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('saves display name and custom attributes', (tester) async {
      final patches = <Object?>[];
      final api = PortalApi(
        httpClient: _client({
          '/me': (request) {
            if (request.method == 'PATCH') {
              patches.add(jsonDecode(request.body));
              return http.Response('{}', 200);
            }
            return http.Response(
              jsonEncode({
                'sub': 'user-1',
                'user': {
                  'name': 'Ada Lovelace',
                  'attributes': {'department': 'R&D'},
                },
              }),
              200,
            );
          },
          '/roles/me': (_) => http.Response(jsonEncode({'roles': []}), 200),
          '/permissions/me': (_) =>
              http.Response(jsonEncode({'permissions': []}), 200),
          '/menus/me': (_) => http.Response(jsonEncode({'menus': []}), 200),
        }),
      );

      await tester.pumpWidget(_wrap(OverviewTab(api: api)));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Display name'),
        'Grace Hopper',
      );
      await tester.tap(find.text('Save name'));
      await tester.pumpAndSettle();
      expect(patches.first, {'name': 'Grace Hopper'});
      expect(find.text('Display name saved.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'department'),
        'Compiler Lab',
      );
      await tester.tap(find.text('Save attributes'));
      await tester.pumpAndSettle();
      expect(patches.last, {
        'attributes': {'department': 'Compiler Lab'},
      });
      expect(find.text('Attributes saved.'), findsOneWidget);
    });
  });

  group('SessionsTab', () {
    testWidgets('lists sessions and revokes another device', (tester) async {
      var deleted = <String>[];
      final api = PortalApi(
        httpClient: _client({
          '/me/sessions/enriched': (_) => http.Response(
            jsonEncode({
              'sessions': [
                {
                  'id': 'session-2',
                  'created_at': '2026-08-01T00:00:00Z',
                  'ip': '203.0.113.9',
                  'user_agent': 'Firefox/120 on Linux',
                },
              ],
            }),
            200,
          ),
          '/sessions/me/session-2': (request) {
            if (request.method == 'DELETE') deleted.add(request.url.path);
            return http.Response('{}', 200);
          },
        }),
      );

      await tester.pumpWidget(
        _wrap(SessionsTab(api: api, onCurrentSessionRevoked: () {})),
      );
      await tester.pumpAndSettle();

      expect(find.text('session-2'), findsOneWidget);
      expect(find.textContaining('Firefox on Linux'), findsOneWidget);

      await tester.tap(find.text('Revoke'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revoke').last);
      await tester.pumpAndSettle();
      expect(deleted, ['/sessions/me/session-2']);
    });

    testWidgets('revoking the current session signs the browser out', (
      tester,
    ) async {
      var currentRevoked = false;
      final token = _jwt({'sid': 'session-1'});
      final api = PortalApi(
        httpClient: _client({
          '/me': (_) => http.Response(jsonEncode({'sub': 'user-1'}), 200),
          '/me/sessions/enriched': (_) => http.Response(
            jsonEncode({
              'sessions': [
                {'id': 'session-1'},
              ],
            }),
            200,
          ),
          '/sessions/me/session-1': (_) => http.Response('{}', 200),
        }),
      );
      await api.login(token);

      await tester.pumpWidget(
        _wrap(
          SessionsTab(
            api: api,
            onCurrentSessionRevoked: () => currentRevoked = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Revoke'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(currentRevoked, isTrue);
      expect(api.hasToken, isFalse);
    });

    testWidgets('signs out of other devices via bulk revoke', (tester) async {
      var query = '';
      final token = _jwt({'sid': 'session-1'});
      final api = PortalApi(
        httpClient: _client({
          '/me': (_) => http.Response(jsonEncode({'sub': 'user-1'}), 200),
          '/me/sessions/enriched': (_) => http.Response(
            jsonEncode({
              'sessions': [
                {'id': 'session-1'},
                {'id': 'session-2'},
              ],
            }),
            200,
          ),
          '/sessions/me': (request) {
            query = request.url.query;
            return http.Response('{}', 200);
          },
        }),
      );
      await api.login(token);

      await tester.pumpWidget(
        _wrap(SessionsTab(api: api, onCurrentSessionRevoked: () {})),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign out of other devices'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out other devices'));
      await tester.pumpAndSettle();
      expect(query, isEmpty); // current session preserved => no ?all=true
      expect(api.hasToken, isTrue);
      // The list reloads after revocation.
      expect(find.text('session-1'), findsOneWidget);
    });

    testWidgets('shows empty state', (tester) async {
      final api = PortalApi(
        httpClient: _client({
          '/me/sessions/enriched': (_) =>
              http.Response(jsonEncode({'sessions': []}), 200),
        }),
      );
      await tester.pumpWidget(
        _wrap(SessionsTab(api: api, onCurrentSessionRevoked: () {})),
      );
      await tester.pumpAndSettle();
      expect(find.text('No active sessions.'), findsOneWidget);
    });
  });

  group('DevicesTab', () {
    final device = {
      'id': 'device-1',
      'device_name': 'Work laptop',
      'platform': 'Linux',
      'browser_name': 'Firefox',
      'last_ip': '203.0.113.9',
      'last_seen_at': '2026-08-01T00:00:00Z',
      'trust_label': 'trusted',
      'trust_score': 0.9,
      'active_sessions': 1,
      'suspicious': true,
    };

    testWidgets('renders physical devices and opens details', (tester) async {
      final api = PortalApi(
        httpClient: _client({
          '/me/devices': (_) => http.Response(
            jsonEncode({
              'devices': [device],
            }),
            200,
          ),
          '/me/devices/device-1/activity': (_) =>
              http.Response(jsonEncode({'events': []}), 200),
        }),
      );
      await tester.pumpWidget(_wrap(DevicesTab(api: api)));
      await tester.pumpAndSettle();

      expect(find.text('Work laptop'), findsOneWidget);
      expect(find.text('Suspicious'), findsOneWidget);
      expect(find.textContaining('1 active sessions'), findsOneWidget);

      await tester.tap(find.text('Work laptop'));
      await tester.pumpAndSettle();
      // Device detail dialog opened.
      expect(find.text('View details'), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('marks device trusted through the menu', (tester) async {
      var posted = <String>[];
      final api = PortalApi(
        httpClient: _client({
          '/me/devices': (_) => http.Response(
            jsonEncode({
              'devices': [device],
            }),
            200,
          ),
          '/me/devices/device-1/trust': (request) {
            posted.add(request.url.path);
            return http.Response('{}', 200);
          },
        }),
      );
      await tester.pumpWidget(_wrap(DevicesTab(api: api)));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark trusted'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark trusted').last);
      await tester.pumpAndSettle();
      expect(posted, ['/me/devices/device-1/trust']);
      expect(find.textContaining('Device posture marked trusted.'), findsOne);
    });

    testWidgets('reports device lost with typed confirmation', (tester) async {
      var posted = <String>[];
      final api = PortalApi(
        httpClient: _client({
          '/me/devices': (_) => http.Response(
            jsonEncode({
              'devices': [device],
            }),
            200,
          ),
          '/me/devices/device-1/lost': (request) {
            posted.add(request.url.path);
            return http.Response('{}', 200);
          },
        }),
      );
      await tester.pumpWidget(_wrap(DevicesTab(api: api)));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report lost'));
      await tester.pumpAndSettle();
      // The confirmation requires typing the device id.
      expect(find.text('Report this device lost?'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'device-1');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report lost').last);
      await tester.pumpAndSettle();
      expect(posted, ['/me/devices/device-1/lost']);
    });

    testWidgets('renames a device', (tester) async {
      var patched = <String>[];
      final api = PortalApi(
        httpClient: _client({
          '/me/devices': (_) => http.Response(
            jsonEncode({
              'devices': [device],
            }),
            200,
          ),
          '/me/devices/device-1': (request) {
            patched.add(request.body);
            return http.Response('{}', 200);
          },
        }),
      );
      await tester.pumpWidget(_wrap(DevicesTab(api: api)));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename / notes'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'New name');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(patched, isNotEmpty);
      expect(jsonDecode(patched.single), {'name': 'New name', 'notes': ''});
    });

    testWidgets('deletes a device with typed confirmation', (tester) async {
      var deleted = <String>[];
      final api = PortalApi(
        httpClient: _client({
          '/me/devices': (_) => http.Response(
            jsonEncode({
              'devices': [device],
            }),
            200,
          ),
          '/me/devices/device-1': (request) {
            if (request.method == 'DELETE') deleted.add(request.url.path);
            return http.Response('{}', 200);
          },
        }),
      );
      await tester.pumpWidget(_wrap(DevicesTab(api: api)));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete device'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'device-1');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete device').last);
      await tester.pumpAndSettle();
      expect(deleted, ['/me/devices/device-1']);
    });

    testWidgets('falls back cleanly when device tracking is not enabled', (
      tester,
    ) async {
      final api = PortalApi(
        httpClient: _client({'/me/devices': (_) => http.Response('{}', 404)}),
      );
      await tester.pumpWidget(_wrap(DevicesTab(api: api)));
      await tester.pumpAndSettle();
      expect(
        find.text('Physical-device tracking is not enabled.'),
        findsOneWidget,
      );
    });

    testWidgets('refuses to act on trusted-grant payloads at /me/devices', (
      tester,
    ) async {
      final api = PortalApi(
        httpClient: _client({
          '/me/devices': (_) => http.Response(
            jsonEncode({
              'devices': [
                {'label': 'grant', 'client_id': 'client-1'},
              ],
            }),
            200,
          ),
        }),
      );
      await tester.pumpWidget(_wrap(DevicesTab(api: api)));
      await tester.pumpAndSettle();
      expect(find.textContaining('MFA trusted-browser grants'), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });
  });

  group('SecurityTab', () {
    testWidgets('lists MFA factors and removes one', (tester) async {
      var deleted = <String>[];
      final api = PortalApi(
        httpClient: _client({
          '/me/mfa': (request) {
            if (request.method == 'DELETE') {
              deleted.add(request.url.path);
            }
            return http.Response(
              jsonEncode({
                'factors': [
                  {'id': 'totp-1', 'type': 'totp', 'label': 'Authenticator'},
                ],
              }),
              200,
            );
          },
          '/me/mfa/totp-1': (request) {
            deleted.add(request.url.path);
            return http.Response('{}', 200);
          },
          '/me/mfa/recovery-codes': (_) =>
              http.Response(jsonEncode({'remaining': 5}), 200),
          '/me/trusted-devices': (_) =>
              http.Response(jsonEncode({'devices': []}), 200),
        }),
      );
      await tester.pumpWidget(_wrap(SecurityTab(api: api)));
      await tester.pumpAndSettle();

      expect(find.text('Authenticator'), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();
      expect(deleted, contains('/me/mfa/totp-1'));
      expect(find.text('Second factor removed.'), findsOneWidget);
    });

    testWidgets('enrolls a TOTP factor end to end', (tester) async {
      final posts = <String>[];
      final api = PortalApi(
        httpClient: _client({
          '/me/mfa': (_) => http.Response(jsonEncode({'factors': []}), 200),
          '/me/mfa/totp/begin': (_) => http.Response(
            jsonEncode({
              'secret': 'BASE32SECRET',
              'otpauth_uri': 'otpauth://totp/Snaplink:user?secret=BASE32SECRET',
            }),
            200,
          ),
          '/me/mfa/totp/confirm': (request) {
            posts.add(request.body);
            return http.Response('{}', 201);
          },
          '/me/mfa/recovery-codes': (_) =>
              http.Response(jsonEncode({'remaining': 5}), 200),
          '/me/trusted-devices': (_) =>
              http.Response(jsonEncode({'devices': []}), 200),
        }),
      );
      await tester.pumpWidget(_wrap(SecurityTab(api: api)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add authenticator app'));
      await tester.pumpAndSettle();
      expect(find.text('BASE32SECRET'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, '6-digit code'),
        '123456',
      );
      await tester.tap(find.text('Verify and save'));
      await tester.pumpAndSettle();
      expect(posts.single, contains('"secret":"BASE32SECRET"'));
      expect(posts.single, contains('"code":"123456"'));
    });

    testWidgets('shows fallback when MFA management is not enabled', (
      tester,
    ) async {
      final api = PortalApi(
        httpClient: _client({
          '/me/mfa': (_) => http.Response('{}', 404),
          '/me/mfa/recovery-codes': (_) => http.Response('{}', 404),
          '/me/trusted-devices': (_) => http.Response('{}', 404),
        }),
      );
      await tester.pumpWidget(_wrap(SecurityTab(api: api)));
      await tester.pumpAndSettle();
      expect(find.text('Factor management is not enabled.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Recovery codes are not enabled.'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Recovery codes are not enabled.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Trusted devices are not enabled.'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Trusted devices are not enabled.'), findsOneWidget);
    });
  });

  group('IdentitiesTab', () {
    testWidgets('lists and unlinks external identities', (tester) async {
      var deleted = <String>[];
      final api = PortalApi(
        httpClient: _client({
          '/me/identities': (request) {
            if (request.method == 'DELETE') {
              deleted.add(request.url.path);
            }
            return http.Response(
              jsonEncode({
                'identities': [
                  {
                    'id': 'idp-1',
                    'provider': 'GitHub',
                    'subject': 'octocat',
                    'linked_at': '2026-01-01T00:00:00Z',
                  },
                ],
              }),
              200,
            );
          },
          '/me/identities/idp-1': (request) {
            deleted.add(request.url.path);
            return http.Response('{}', 200);
          },
        }),
      );
      await tester.pumpWidget(_wrap(IdentitiesTab(api: api)));
      await tester.pumpAndSettle();

      expect(find.text('GitHub'), findsOneWidget);
      await tester.tap(find.text('Unlink'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unlink').last);
      await tester.pumpAndSettle();
      expect(deleted, ['/me/identities/idp-1']);
    });

    testWidgets('shows fallback when identity linking is not enabled', (
      tester,
    ) async {
      final api = PortalApi(
        httpClient: _client({
          '/me/identities': (_) => http.Response('{}', 404),
        }),
      );
      await tester.pumpWidget(_wrap(IdentitiesTab(api: api)));
      await tester.pumpAndSettle();
      expect(
        find.text('Linked-identity management is not enabled.'),
        findsOneWidget,
      );
    });
  });

  group('ConsentsTab', () {
    testWidgets('lists connected apps and revokes access', (tester) async {
      var deleted = <String>[];
      var listCalls = 0;
      final api = PortalApi(
        httpClient: _client({
          '/consents/me': (request) {
            listCalls++;
            if (request.method == 'DELETE') {
              deleted.add(request.url.path);
            }
            return http.Response(
              jsonEncode({
                'consents': [
                  {
                    'client_id': 'app-1',
                    'scopes': ['openid', 'profile'],
                  },
                ],
              }),
              200,
            );
          },
          '/consents/me/app-1': (request) {
            deleted.add(request.url.path);
            return http.Response('{}', 200);
          },
        }),
      );
      await tester.pumpWidget(_wrap(ConsentsTab(api: api)));
      await tester.pumpAndSettle();

      expect(find.text('app-1'), findsOneWidget);
      expect(find.text('openid profile'), findsOneWidget);
      await tester.tap(find.text('Revoke'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revoke').last);
      await tester.pumpAndSettle();
      expect(deleted, ['/consents/me/app-1']);
      expect(listCalls, greaterThanOrEqualTo(2)); // reload after revoke
    });

    testWidgets('shows empty state', (tester) async {
      final api = PortalApi(
        httpClient: _client({
          '/consents/me': (_) =>
              http.Response(jsonEncode({'consents': []}), 200),
        }),
      );
      await tester.pumpWidget(_wrap(ConsentsTab(api: api)));
      await tester.pumpAndSettle();
      expect(find.text('No connected applications.'), findsOneWidget);
    });
  });

  group('OrganizationsTab', () {
    testWidgets('lists organizations, leaves, and accepts invitations', (
      tester,
    ) async {
      var deleted = <String>[];
      var accepted = <String>[];
      final api = PortalApi(
        httpClient: _client({
          '/me/organizations': (request) {
            if (request.method == 'DELETE') deleted.add(request.url.path);
            return http.Response(
              jsonEncode({
                'organizations': [
                  {'tenant_id': 'tenant-a', 'role': 'member'},
                  {'tenant_id': 'tenant-b', 'role': 'admin'},
                ],
              }),
              200,
            );
          },
          '/me/organizations/tenant-a': (request) {
            deleted.add(request.url.path);
            return http.Response('{}', 200);
          },
          '/me/invitations/accept': (request) {
            accepted.add(request.body);
            return http.Response('{}', 200);
          },
        }),
      );
      await tester.pumpWidget(_wrap(OrganizationsTab(api: api)));
      await tester.pumpAndSettle();

      expect(find.text('tenant-a'), findsOneWidget);
      expect(find.text('tenant-b'), findsOneWidget);
      // Admin role gets the Manage action.
      expect(find.text('Manage'), findsOneWidget);

      await tester.tap(find.text('Leave').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave').last);
      await tester.pumpAndSettle();
      expect(deleted, ['/me/organizations/tenant-a']);

      await tester.enterText(
        find.widgetWithText(TextField, 'Invitation token'),
        'invite-token-1',
      );
      await tester.tap(find.text('Join organization'));
      await tester.pumpAndSettle();
      expect(accepted.single, contains('"token":"invite-token-1"'));
      expect(find.text('You have joined the organization.'), findsOneWidget);
    });

    testWidgets('shows fallback when organizations are unavailable', (
      tester,
    ) async {
      final api = PortalApi(
        httpClient: _client({
          '/me/organizations': (_) => http.Response('{}', 404),
        }),
      );
      await tester.pumpWidget(_wrap(OrganizationsTab(api: api)));
      await tester.pumpAndSettle();
      expect(
        find.text('Organizations are not available for this account.'),
        findsOneWidget,
      );
    });
  });

  group('PrivacyTab', () {
    testWidgets('exports data and previews account deletion', (tester) async {
      final posts = <String>[];
      final api = PortalApi(
        httpClient: _client({
          '/me/data-export': (_) => http.Response('{"user": {...}}', 200),
          '/me/account/erase': (request) {
            posts.add(request.body);
            return http.Response(
              jsonEncode({
                'refresh_tokens_deleted': 2,
                'sessions_destroyed': 1,
                'user_deleted': true,
                'skipped': [],
              }),
              200,
            );
          },
        }),
      );
      await tester.pumpWidget(
        _wrap(PrivacyTab(api: api, mySub: 'user-1', onAccountDeleted: () {})),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Export my data'));
      await tester.pumpAndSettle();
      // VM shells cannot download; the UI must say so honestly.
      expect(
        find.text('Data export download is available in the web console.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Preview deletion (dry run)'));
      await tester.pumpAndSettle();
      expect(posts.first, contains('"dry_run":true'));
      expect(find.textContaining('Refresh tokens: 2'), findsOneWidget);
    });

    testWidgets('requires the exact subject before deleting the account', (
      tester,
    ) async {
      var erased = false;
      final api = PortalApi(
        httpClient: _client({
          '/me/account/erase': (_) {
            erased = true;
            return http.Response('{}', 200);
          },
        }),
      );
      await tester.pumpWidget(
        _wrap(PrivacyTab(api: api, mySub: 'user-1', onAccountDeleted: () {})),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Type your subject to confirm'),
        'wrong-subject',
      );
      await tester.tap(find.text('Permanently delete my account'));
      await tester.pumpAndSettle();
      expect(erased, isFalse);
      expect(find.text('Type your subject exactly to confirm.'), findsOne);

      await tester.enterText(
        find.widgetWithText(TextField, 'Type your subject to confirm'),
        'user-1',
      );
      await tester.tap(find.text('Permanently delete my account'));
      await tester.pumpAndSettle();
      expect(erased, isTrue);
    });
  });

  group('RecoveryCodesCard', () {
    testWidgets('regenerates and hides codes after saving', (tester) async {
      final api = PortalApi(
        httpClient: MockClient((request) async {
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode({
                'recovery_codes': ['CODE-1', 'CODE-2'],
              }),
              201,
            );
          }
          return http.Response(jsonEncode({'remaining': 3}), 200);
        }),
      );
      await tester.pumpWidget(_wrap(RecoveryCodesCard(api: api)));
      await tester.pumpAndSettle();

      expect(find.text('Recovery codes remaining: 3'), findsOneWidget);
      await tester.tap(find.text('Generate new recovery codes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace codes'));
      await tester.pumpAndSettle();
      // Recovery codes render in a SelectableText (RichText), not a Text.
      expect(find.textContaining('CODE-1', findRichText: true), findsOneWidget);
      expect(
        find.text('Save these codes now. They cannot be shown again.'),
        findsOneWidget,
      );

      await tester.tap(find.text('I have saved these codes'));
      await tester.pumpAndSettle();
      expect(find.textContaining('CODE-1', findRichText: true), findsNothing);
    });
  });

  group('TrustedDevicesCard', () {
    testWidgets('trusts the current browser and revokes a grant', (
      tester,
    ) async {
      final posts = <String>[];
      final deletes = <String>[];
      final api = PortalApi(
        httpClient: MockClient((request) async {
          switch (request.url.path) {
            case '/me':
              return http.Response(jsonEncode({'sub': 'user-1'}), 200);
            case '/me/trusted-devices':
              if (request.method == 'DELETE') deletes.add(request.url.path);
              return http.Response(
                jsonEncode({
                  'devices': [
                    {
                      'id': 'grant-1',
                      'label': 'Firefox on Linux',
                      'client_id': 'client-1',
                      'expires_at': '2026-09-01T00:00:00Z',
                    },
                  ],
                }),
                200,
              );
            case '/me/trusted-devices/trust':
              posts.add(request.url.path);
              return http.Response(
                jsonEncode({'device_token': 'grant-token'}),
                201,
              );
            case '/me/trusted-devices/grant-1':
              deletes.add(request.url.path);
              return http.Response('{}', 200);
          }
          return http.Response('{}', 404);
        }),
      );
      await api.login(_jwt({'sid': 'session-1', 'aud': 'client-1'}));

      await tester.pumpWidget(_wrap(TrustedDevicesCard(api: api)));
      await tester.pumpAndSettle();

      expect(find.text('Firefox on Linux'), findsOneWidget);

      await tester.tap(find.text('Trust this browser'));
      await tester.pumpAndSettle();
      expect(posts, ['/me/trusted-devices/trust']);

      await tester.tap(find.text('Revoke'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revoke').last);
      await tester.pumpAndSettle();
      expect(deletes, ['/me/trusted-devices/grant-1']);
    });

    testWidgets('blocks revocation of non-grant payloads', (tester) async {
      final api = PortalApi(
        httpClient: _client({
          '/me': (_) => http.Response(jsonEncode({'sub': 'user-1'}), 200),
          '/me/trusted-devices': (_) => http.Response(
            jsonEncode({
              'devices': [
                {'device_name': 'laptop', 'trust_score': 0.9},
              ],
            }),
            200,
          ),
        }),
      );
      await api.login(_jwt({'sid': 'session-1', 'aud': 'client-1'}));
      await tester.pumpWidget(_wrap(TrustedDevicesCard(api: api)));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('invalid physical-device payload'),
        findsOneWidget,
      );
      expect(find.text('Revoke'), findsNothing);
    });
  });

  group('SecurityAccountCredentials', () {
    testWidgets('changes password and clears trusted-device grants', (
      tester,
    ) async {
      var posted = <String>[];
      final api = PortalApi(
        httpClient: MockClient((request) async {
          if (request.url.path == '/me') {
            return http.Response(jsonEncode({'sub': 'user-1'}), 200);
          }
          if (request.url.path == '/me/password') {
            posted.add(request.body);
            return http.Response('', 204);
          }
          return http.Response('{}', 404);
        }),
      );
      await api.login(_jwt({'sid': 'session-1', 'aud': 'client-1'}));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SecurityAccountCredentials(api: api),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Current password'),
        'old-password',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'New password'),
        'new-password',
      );
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();
      expect(posted.single, contains('"current_password":"old-password"'));
      expect(posted.single, contains('"new_password":"new-password"'));
      expect(
        find.textContaining('trusted-browser grants were revoked'),
        findsOneWidget,
      );
    });

    testWidgets('requires both fields and changes email with a code', (
      tester,
    ) async {
      final posts = <String>[];
      final api = PortalApi(
        httpClient: MockClient((request) async {
          posts.add('${request.method} ${request.url.path} ${request.body}');
          if (request.url.path == '/me/email/change') {
            return http.Response('{}', 200);
          }
          if (request.url.path == '/me/email/verify') {
            return http.Response('{}', 200);
          }
          return http.Response('{}', 404);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SecurityAccountCredentials(api: api),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Update password'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();
      expect(find.text('Fill in both fields.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'New email'),
        'new@example.com',
      );
      await tester.scrollUntilVisible(
        find.text('Send verification code'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Send verification code'));
      await tester.pumpAndSettle();
      expect(posts.any((p) => p.contains('/me/email/change')), isTrue);
      expect(find.textContaining('We sent a verification token'), findsOne);

      await tester.enterText(
        find.widgetWithText(TextField, 'Verification code'),
        '123456',
      );
      await tester.scrollUntilVisible(
        find.text('Confirm new email'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Confirm new email'));
      await tester.pumpAndSettle();
      expect(posts.any((p) => p.contains('/me/email/verify')), isTrue);
      expect(find.text('Your email has been updated.'), findsOneWidget);
    });
  });

  group('PasskeyEnrollmentCard', () {
    testWidgets('falls back when passkey enrollment is not enabled', (
      tester,
    ) async {
      var enrolled = false;
      final api = PortalApi(
        httpClient: _client({
          '/me/mfa/webauthn/begin': (_) => http.Response('{}', 404),
        }),
      );
      await tester.pumpWidget(
        _wrap(
          PasskeyEnrollmentCard(api: api, onEnrolled: () => enrolled = true),
        ),
      );
      await tester.pumpAndSettle();

      // 'Add a passkey' is both the card title and the button label.
      await tester.tap(find.text('Add a passkey').last);
      await tester.pumpAndSettle();
      expect(find.text('Passkey enrollment is not enabled.'), findsOneWidget);
      expect(enrolled, isFalse);
    });
  });
}

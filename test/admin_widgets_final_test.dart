import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/screens/admin/connections/error_card.dart';
import 'package:sso_admin/screens/admin/device_security_widgets.dart';
import 'package:sso_admin/screens/admin/governance_models.dart';
import 'package:sso_admin/screens/admin/org_members_card.dart';
import 'package:sso_admin/screens/admin/user_device_security_panel.dart';
import 'package:sso_admin/screens/admin/commerce/commerce_subscription_dialogs.dart';
import 'package:sso_admin/screens/admin/tenant_export_download.dart';
import 'package:sso_admin/screens/admin/user_form_dialog.dart';
import 'package:sso_admin/screens/admin/user_support_cards.dart';
import 'package:sso_admin/services/browser_auth_response.dart';
import 'package:sso_admin/services/browser_download_stub.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';

void main() {
  group('UserFormDialog', () {
    testWidgets('creates a user with parsed attributes', (tester) async {
      var created = <String>[];
      final client = SSOAdminClient(
        'https://sso.example.test',
        httpClient: MockClient((request) async {
          if (request.method == 'POST' &&
              request.url.path == '/api/v1/admin/users') {
            created.add(request.body);
            return http.Response(
              jsonEncode({
                'user': {'id': 'user-1'},
              }),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: UserFormDialog(client: client)),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'ID'),
        'user-1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Provider'),
        'local',
      );
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Attributes (one key=value per line)',
        ),
        'department=R&D\n  role = engineer \nbroken-line',
      );
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(created.single, contains('"id":"user-1"'));
      expect(created.single, contains('"department":"R&D"'));
      expect(created.single, contains('"role":"engineer"'));
      // Malformed lines are skipped.
      expect(created.single, isNot(contains('broken-line')));
    });

    testWidgets('requires an ID for new users', (tester) async {
      var requests = 0;
      final client = SSOAdminClient(
        'https://sso.example.test',
        httpClient: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: UserFormDialog(client: client)),
        ),
      );

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsOneWidget);
      expect(requests, 0);
    });
  });

  group('OrgMembersCard', () {
    testWidgets('lists members and notifies removal', (tester) async {
      final memberUser = TextEditingController();
      addTearDown(memberUser.dispose);
      String? removed;
      var saved = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrgMembersCard(
              members: [
                {'user_id': 'user-1', 'role': 'admin'},
              ],
              mutating: false,
              memberUserController: memberUser,
              memberRole: 'member',
              onRoleChanged: (_) {},
              onSaveMember: () => saved++,
              onRemoveMember: (id) => removed = id,
            ),
          ),
        ),
      );

      expect(find.text('user-1'), findsOneWidget);
      await tester.tap(find.text('Remove'));
      expect(removed, 'user-1');
      await tester.tap(find.text('Add or update member'));
      expect(saved, 1);
    });
  });

  group('UserSupportCards', () {
    testWidgets('renders sessions and consents', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SessionsCard(
                  sessions: [
                    {'id': 'session-1', 'ip': '203.0.113.9'},
                  ],
                ),
                ConsentsCard(
                  consents: [
                    {
                      'client_id': 'app-1',
                      'scopes': ['openid'],
                    },
                  ],
                  userId: 'user-1',
                  mutating: false,
                  onRevoke: (_) async {},
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('session-1'), findsOneWidget);
      expect(find.text('app-1'), findsOneWidget);
    });
  });

  group('GovernanceModels', () {
    test('parses the read and write catalogs', () {
      expect(governanceReadSpecs, isNotEmpty);
      expect(
        governanceReadSpecs.any(
          (spec) => spec.path == '/api/v1/admin/config/running',
        ),
        isTrue,
      );
      expect(
        governanceReadSpecs.every(
          (spec) =>
              spec.section.isNotEmpty &&
              spec.key.isNotEmpty &&
              spec.title.isNotEmpty &&
              spec.path.startsWith('/api/v1/'),
        ),
        isTrue,
      );
      expect(governanceWriteOperations, isNotEmpty);
      expect(
        governanceWriteOperations.every(
          (op) =>
              op.label.isNotEmpty &&
              ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'].contains(op.method) &&
              op.path.startsWith('/api/v1/'),
        ),
        isTrue,
      );
    });
  });

  group('ConnectionErrorCard', () {
    testWidgets('renders the error message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ConnectionErrorCard(error: 'boom')),
        ),
      );
      expect(find.text('boom'), findsOneWidget);
    });
  });

  group('DeviceSecurityWidgets', () {
    testWidgets('renders a device list with trust chips', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceListPanel(
              title: 'Devices',
              devices: [
                {
                  'id': 'device-1',
                  'device_name': 'Laptop',
                  'trust_score': 0.9,
                  'status': 'active',
                },
              ],
            ),
          ),
        ),
      );
      expect(find.text('Laptop'), findsOneWidget);
    });

    testWidgets('renders login history', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginHistoryPanel(
              records: [
                {'id': 'h-1', 'ip': '203.0.113.9', 'method': 'password'},
              ],
            ),
          ),
        ),
      );
      expect(find.text('203.0.113.9'), findsOneWidget);
    });
  });

  group('TenantExportDownload', () {
    test('downloads the export as an attachment', () {
      downloadTenantExport(
        SnaplinkAdminDownload(
          bytes: Uint8List.fromList(utf8.encode('{"tenant":"t-1"}')),
          contentType: 'application/json',
          filename: 'export.json',
        ),
        'tenant-a',
      );
      final captured = capturedDownloads.single;
      expect(captured['filename'], 'export.json');
      expect(captured['contentType'], 'application/json');
    });
  });

  group('UserDeviceSecurityPanel', () {
    testWidgets('renders the panel shell', (tester) async {
      final api = _panelApi();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserDeviceSecurityPanel(api: api, userId: 'user-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Laptop'), findsOneWidget);
    });
  });

  group('CommerceSubscriptionDialogs', () {
    testWidgets('create-subscription dialog submits a plan choice', (
      tester,
    ) async {
      Map<String, dynamic>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  result = await CommerceCreateSubscriptionDialog.show(
                    context,
                    [
                      {
                        'id': 'plan-1',
                        'name': 'Enterprise',
                        'status': 'active',
                      },
                    ],
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create subscription'));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
    });
  });

  group('BrowserAuthResponse', () {
    test('VM stub refuses form submission and document replacement', () {
      expect(
        BrowserAuthResponse.submitForm('https://sso.example/cb', {}),
        isFalse,
      );
      expect(BrowserAuthResponse.replaceDocument('<html></html>'), isFalse);
    });
  });
}

SnaplinkAdminApi _panelApi() => SnaplinkAdminApi(
  baseUrl: 'https://sso.example.test',
  accessToken: 'admin-token',
  httpClient: MockClient((request) async {
    if (request.url.path.contains('/devices')) {
      return http.Response(
        jsonEncode({
          'devices': [
            {'id': 'device-1', 'device_name': 'Laptop'},
          ],
        }),
        200,
      );
    }
    return http.Response('{}', 404);
  }),
);

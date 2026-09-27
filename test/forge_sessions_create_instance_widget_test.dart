import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_client_instance_resource_view.dart';
import 'package:sso_admin/api/forge_client_instance_session_view.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

Map<String, dynamic> _owner(ForgeDeviceOwner owner) => owner.toJson();

Map<String, dynamic> _authority() => {
  'owner_authenticated': false,
  'session_read_authorized': false,
  'prompt_write_authorized': false,
  'device_identity_verified': false,
  'reservation_created': false,
  'execution_authorized': false,
  'dispatch_performed': false,
  'audit_published': false,
};

Map<String, dynamic> _sessionView(ForgeDeviceOwner owner) => {
  'schema_version': forgeClientInstanceSessionViewSchema,
  'evaluation_mode': forgeClientInstanceSessionViewEvaluationMode,
  'owner_declaration': _owner(owner),
  'owner_declaration_unverified': true,
  'instances': [
    {
      'instance_id': 'client-web-001',
      'client_kind': 'web',
      'session_ids': ['existing-conversation'],
      'observed_at_ms': 200500,
      'status': 'active',
    },
  ],
  'read_only': true,
  'authority': _authority(),
};

Map<String, dynamic> _resourceView(ForgeDeviceOwner owner) => {
  'schema_version': forgeClientInstanceResourceViewSchema,
  'evaluation_mode': forgeClientInstanceResourceViewEvaluationMode,
  'owner_declaration': _owner(owner),
  'owner_declaration_unverified': true,
  'instances': [
    {
      'instance_id': 'client-web-001',
      'client_kind': 'web',
      'session_ids': ['existing-conversation'],
      'observed_at_ms': 200500,
      'status': 'active',
    },
  ],
  'devices': <Object>[],
  'device_attributes_unverified': true,
  'read_only': true,
  'authority': _authority(),
};

Future<void> _pumpRequests(WidgetTester tester) async {
  for (var count = 0; count < 8; count++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => BrowserNavigation.resetForTest());
  tearDown(() => BrowserNavigation.resetForTest());

  testWidgets(
    'selected instance keeps a newly created undeclared session private-read free',
    (tester) async {
      final owner = ForgeDeviceOwner(
        issuer: 'https://id.example',
        subject: 'create-user',
        tenantID: 'tenant-1',
      );
      final requests = <http.Request>[];
      final sessionView = ForgeClientInstanceSessionView.fromJson(
        _sessionView(owner),
      );
      final resourceView = ForgeClientInstanceResourceView.fromJson(
        _resourceView(owner),
      );
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations') {
          return _json({'conversations': <Object>[], 'has_more': false});
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/conversations') {
          expect(jsonDecode(request.body), {
            'scope': {'kind': 'global'},
            'title': 'Hidden work',
          });
          return _json({
            'id': 'created-outside-instance',
            'scope': {'kind': 'global'},
            'title': 'Hidden work',
            'created_at_ms': 40,
            'updated_at_ms': 40,
          }, status: 201);
        }
        throw StateError(
          'Unexpected private read or transport: ${request.method} ${request.url}',
        );
      });
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: 'forge-token',
            apiOrigin: 'https://forge.example',
            httpClient: client,
            initialClientInstanceID: 'client-web-001',
            clientInstanceSessionViewOwner: owner,
            clientInstanceSessionViewReader: (_) async => sessionView,
            clientInstanceResourceViewOwner: owner,
            clientInstanceResourceViewReader: (_) async => resourceView,
          ),
        ),
      );
      await _pumpRequests(tester);

      await tester.scrollUntilVisible(
        find.text('Create a conversation'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byType(TextField).first, 'Hidden work');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Create conversation'),
      );
      await _pumpRequests(tester);

      expect(
        requests.where(
          (request) =>
              request.method == 'POST' &&
              request.url.path == '/api/v1/conversations',
        ),
        hasLength(1),
      );
      expect(
        requests.where((request) => request.url.path.endsWith('/prompts')),
        isEmpty,
      );
      expect(
        requests.where((request) => request.url.path.endsWith('/runs')),
        isEmpty,
      );
      expect(find.text('Hidden work'), findsNothing);
      expect(
        find.text(
          'Created conversation "created-outside-instance", but the selected client instance has not declared it yet.',
        ),
        findsOneWidget,
      );
      expect(
        BrowserNavigation.currentUri.path,
        isNot(endsWith('/created-outside-instance')),
      );
    },
  );
}

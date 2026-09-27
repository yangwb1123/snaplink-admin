import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_client_instance_session_resource_convergence.dart';
import 'package:sso_admin/api/forge_client_instance_session_view.dart';
import 'package:sso_admin/api/forge_client_instance_resource_view.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/session.dart';

import 'support/memory_forge_credential_backend.dart';

const _owner = ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'user-1',
  tenantID: 'tenant-1',
);

ForgeClientInstanceSessionResourceConvergence _pair() =>
    ForgeClientInstanceSessionResourceConvergence.fromJson({
      'schema_version': forgeClientInstanceSessionResourceConvergenceSchema,
      'evaluation_mode':
          forgeClientInstanceSessionResourceConvergenceEvaluationMode,
      'session_view': {
        'schema_version': forgeClientInstanceSessionViewSchema,
        'evaluation_mode': forgeClientInstanceSessionViewEvaluationMode,
        'owner_declaration': _owner.toJson(),
        'owner_declaration_unverified': true,
        'instances': <Object>[],
        'read_only': true,
        'authority': const ForgeClientInstanceSessionViewAuthority.offline()
            .toJson(),
      },
      'resource_view': {
        'schema_version': forgeClientInstanceResourceViewSchema,
        'evaluation_mode': forgeClientInstanceResourceViewEvaluationMode,
        'owner_declaration': _owner.toJson(),
        'owner_declaration_unverified': true,
        'instances': <Object>[],
        'devices': <Object>[],
        'device_attributes_unverified': true,
        'read_only': true,
        'authority': const ForgeClientInstanceSessionViewAuthority.offline()
            .toJson(),
      },
      'converged': true,
      'read_only': true,
      'authority':
          const ForgeClientInstanceSessionResourceConvergenceAuthority.offline()
              .toJson(),
    });

void main() {
  setUp(() {
    BrowserNavigation.resetForTest();
    Session.clear();
  });

  tearDown(BrowserNavigation.resetForTest);

  testWidgets('default paired candidate stays request-free', (tester) async {
    final credentialStore = await _credentialStore('pair-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      expect(request.url.path, '/api/v1/conversations');
      return http.Response(
        '{"conversations":[],"has_more":false}',
        200,
        headers: const {'content-type': 'application/json'},
      );
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: client,
          clientInstanceSessionResourceConvergenceOwner: _owner,
        ),
      ),
    );
    await _pump(tester);

    expect(requests, hasLength(1));
    expect(
      requests.map((request) => request.url.path),
      everyElement(isNot('/api/v1/client-instances/session-view')),
    );
    expect(
      requests.map((request) => request.url.path),
      everyElement(isNot('/api/v1/client-instances/resource-view')),
    );
  });

  testWidgets('explicit pair reader reaches the shared Sessions surface', (
    tester,
  ) async {
    final credentialStore = await _credentialStore('pair-token');
    var calls = 0;
    final pair = _pair();
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/conversations');
      return http.Response(
        '{"conversations":[],"has_more":false}',
        200,
        headers: const {'content-type': 'application/json'},
      );
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: client,
          clientInstanceSessionResourceConvergenceOwner: _owner,
          clientInstanceSessionResourceConvergenceReader: (owner) async {
            expect(owner, _owner);
            calls++;
            return pair;
          },
        ),
      ),
    );
    await _pump(tester);

    expect(calls, 1);
    expect(
      find.byKey(const ValueKey('forge-client-instance-session-view-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('forge-client-instance-resource-view-panel')),
      findsOneWidget,
    );
  });
}

Future<void> _pump(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

Future<ForgeCredentialStore> _credentialStore(String token) async {
  final backend = MemoryForgeCredentialBackend();
  final store = ForgeCredentialStore(
    backend: backend,
    forcePersistentStorage: true,
  );
  expect(await store.store(accessToken: token), isTrue);
  return store;
}

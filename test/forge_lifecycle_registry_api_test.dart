import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';

import 'support/forge_lifecycle_registry_fixture.dart';

void main() {
  test(
    'performs one authenticated GET and binds the candidate origin',
    () async {
      final requests = <http.Request>[];
      final api = ForgeConversationsApi(
        baseUrl: 'https://candidate.example',
        accessToken: 'lifecycle-token',
        httpClient: MockClient((request) async {
          requests.add(request);
          return _json(forgeLifecycleRegistryTestEnvelope());
        }),
      );
      addTearDown(api.close);

      final registry = await api.readLifecycleRegistryCandidate(
        owner: forgeLifecycleRegistryTestOwner,
        candidateOrigin: 'https://candidate.example/',
      );

      expect(registry.owner, forgeLifecycleRegistryTestOwner);
      expect(registry.isDisplayOnly, isTrue);
      expect(requests, hasLength(1));
      expect(requests.single.method, 'GET');
      expect(
        requests.single.url.path,
        '/api/v1/device-enrollment-heartbeat/lifecycle-registry',
      );
      expect(requests.single.url.query, isEmpty);
      expect(requests.single.body, isEmpty);
      expect(
        requests.single.headers['authorization'],
        'Bearer lifecycle-token',
      );
      expect(requests.single.headers['accept'], 'application/json');
    },
  );

  test('rejects a candidate origin drift before issuing a request', () async {
    var requestCount = 0;
    final api = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'lifecycle-token',
      httpClient: MockClient((_) async {
        requestCount++;
        return _json(forgeLifecycleRegistryTestEnvelope());
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.readLifecycleRegistryCandidate(
        owner: forgeLifecycleRegistryTestOwner,
        candidateOrigin: 'https://other.example',
      ),
      throwsFormatException,
    );
    expect(requestCount, 0);
  });

  test('rejects foreign response owners without replaying the GET', () async {
    final foreignOwner = const ForgeDeviceOwner(
      issuer: 'https://id.example',
      subject: 'foreign-user',
      tenantID: 'tenant-1',
    );
    var requestCount = 0;
    final api = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'lifecycle-token',
      httpClient: MockClient((_) async {
        requestCount++;
        return _json(forgeLifecycleRegistryTestEnvelope(owner: foreignOwner));
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.readLifecycleRegistryCandidate(
        owner: forgeLifecycleRegistryTestOwner,
        candidateOrigin: 'https://candidate.example',
      ),
      throwsFormatException,
    );
    expect(requestCount, 1);
  });

  test(
    'rejects duplicate response keys at the authenticated transport boundary',
    () async {
      var requestCount = 0;
      final api = ForgeConversationsApi(
        baseUrl: 'https://candidate.example',
        accessToken: 'lifecycle-token',
        httpClient: MockClient((_) async {
          requestCount++;
          return http.Response(
            '{"schema_version":"forge.device-enrollment-heartbeat-lifecycle-file-set/v1",'
            '"schema_version":"forge.device-enrollment-heartbeat-lifecycle-file-set/v1",'
            '"owner":{},"states":[]}',
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(api.close);

      await expectLater(
        api.readLifecycleRegistryCandidate(
          owner: forgeLifecycleRegistryTestOwner,
          candidateOrigin: 'https://candidate.example',
        ),
        throwsA(isA<ForgeConversationsApiException>()),
      );
      expect(requestCount, 1);
    },
  );

  test('rejects a response that tries to grant execution authority', () async {
    final api = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'lifecycle-token',
      httpClient: MockClient(
        (_) async => _json(forgeLifecycleRegistryTestAuthorityMutation()),
      ),
    );
    addTearDown(api.close);

    await expectLater(
      api.readLifecycleRegistryCandidate(
        owner: forgeLifecycleRegistryTestOwner,
        candidateOrigin: 'https://candidate.example',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);

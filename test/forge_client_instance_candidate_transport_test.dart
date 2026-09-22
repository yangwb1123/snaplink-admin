import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_client_instance_resource_view.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';

void main() {
  test(
    'session-view candidate does not replay a 401 through token refresh',
    () async {
      final requests = <http.Request>[];
      var refreshCalls = 0;
      final api = ForgeConversationsApi(
        baseUrl: 'https://candidate.example',
        accessToken: 'expired-token',
        refreshAccessToken: (_) async {
          refreshCalls++;
          return 'rotated-token';
        },
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response('{}', 401);
        }),
      );
      addTearDown(api.close);

      await expectLater(
        api.readClientInstanceSessionViewCandidate(owner: _owner()),
        throwsA(
          isA<ForgeConversationsApiException>()
              .having((error) => error.statusCode, 'status', 401)
              .having((error) => error.isUnauthorized, 'unauthorized', isTrue),
        ),
      );
      expect(refreshCalls, 0);
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/api/v1/client-instances/session-view');
      expect(requests.single.headers['authorization'], 'Bearer expired-token');
    },
  );

  test(
    'resource-view candidate does not replay a 401 through token refresh',
    () async {
      final requests = <http.Request>[];
      var refreshCalls = 0;
      final api = ForgeConversationsApi(
        baseUrl: 'https://candidate.example',
        accessToken: 'expired-token',
        refreshAccessToken: (_) async {
          refreshCalls++;
          return 'rotated-token';
        },
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response('{}', 401);
        }),
      );
      addTearDown(api.close);

      await expectLater(
        api.readClientInstanceResourceViewCandidate(owner: _owner()),
        throwsA(
          isA<ForgeConversationsApiException>()
              .having((error) => error.statusCode, 'status', 401)
              .having((error) => error.isUnauthorized, 'unauthorized', isTrue),
        ),
      );
      expect(refreshCalls, 0);
      expect(requests, hasLength(1));
      expect(
        requests.single.url.path,
        '/api/v1/client-instances/resource-view',
      );
      expect(requests.single.headers['authorization'], 'Bearer expired-token');
    },
  );

  test('resource-view candidate rejects a non-display-only response', () async {
    final api = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'candidate-token',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/client-instances/resource-view');
        final payload = <String, Object?>{
          'schema_version': forgeClientInstanceResourceViewSchema,
          'evaluation_mode': forgeClientInstanceResourceViewEvaluationMode,
          'owner_declaration': _owner().toJson(),
          'owner_declaration_unverified': true,
          'instances': <Object>[],
          'devices': <Object>[],
          'device_attributes_unverified': true,
          'read_only': false,
          'authority': {
            'owner_authenticated': false,
            'session_read_authorized': false,
            'prompt_write_authorized': false,
            'device_identity_verified': false,
            'reservation_created': false,
            'execution_authorized': false,
            'dispatch_performed': false,
            'audit_published': false,
          },
        };
        return http.Response(jsonEncode(payload), 200);
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.readClientInstanceResourceViewCandidate(owner: _owner()),
      throwsA(isA<FormatException>()),
    );
  });
}

ForgeDeviceOwner _owner() => const ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'user-1',
  tenantID: 'tenant-1',
);

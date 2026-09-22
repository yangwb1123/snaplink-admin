import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

const _owner = ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'user-1',
  tenantID: 'tenant-1',
);

void main() {
  test('candidate resource and Run-status GETs never replay a 401', () async {
    final cases = <Future<void> Function(ForgeConversationsApi)>[
      (api) => api.readDeviceInventoryCandidate(owner: _owner),
      (api) => api.readDeviceInventoryCandidateV2(owner: _owner),
      (api) => api.readRunObservedCandidate(
        conversationID: 'conversation-1',
        runID: 'run-1',
      ),
    ];
    final paths = [
      '/api/v1/devices',
      '/api/v1/devices/observations/v2',
      '/api/v1/conversations/conversation-1/runs/run-1/observation',
    ];

    for (var index = 0; index < cases.length; index++) {
      var requests = 0;
      var refreshes = 0;
      late final ForgeConversationsApi api;
      api = ForgeConversationsApi(
        baseUrl: 'https://candidate.example',
        accessToken: 'old-bearer',
        refreshAccessToken: (token) async {
          refreshes++;
          return 'new-bearer';
        },
        httpClient: MockClient((request) async {
          requests++;
          expect(request.method, 'GET');
          expect(request.url.path, paths[index]);
          expect(request.headers['authorization'], 'Bearer old-bearer');
          return _json({
            'code': 'unauthorized',
            'message': 'expired',
          }, status: 401);
        }),
      );
      addTearDown(api.close);

      await expectLater(
        cases[index](api),
        throwsA(isA<ForgeConversationsApiException>()),
      );
      expect(requests, 1, reason: paths[index]);
      expect(refreshes, 0, reason: paths[index]);
    }
  });
}

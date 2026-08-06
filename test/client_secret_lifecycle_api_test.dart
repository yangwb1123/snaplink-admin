import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/sso_client.dart';

void main() {
  test(
    'lists expiring clients and sends an explicit rotation policy',
    () async {
      var requestNumber = 0;
      final client = SSOAdminClient(
        'https://sso.example.test',
        httpClient: MockClient((request) async {
          requestNumber++;
          if (requestNumber == 1) {
            return http.Response('{"access_token":"admin-token"}', 200);
          }
          if (requestNumber == 2) {
            expect(request.method, 'GET');
            expect(request.url.path, '/api/v1/admin/clients/expiring');
            expect(request.url.queryParameters['within_seconds'], '604800');
            return http.Response(
              '{"clients":[{"id":"due","client_secret_expires_at":42}]}',
              200,
            );
          }
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/admin/clients/due/rotate-secret');
          expect(jsonDecode(request.body), {
            'overlap_seconds': 3600,
            'lifetime_seconds': 7200,
          });
          return http.Response(
            '{"secret":"new","client_secret_expires_at":99}',
            200,
          );
        }),
      );
      await client.login('admin', 'password');

      final expiring = await client.listExpiringClients(
        within: const Duration(days: 7),
      );
      expect(expiring.single['id'], 'due');
      final rotation = await client.rotateClientSecretWithPolicy(
        'due',
        overlap: const Duration(hours: 1),
        lifetime: const Duration(hours: 2),
      );
      expect(rotation['secret'], 'new');
      expect(rotation['client_secret_expires_at'], 99);
    },
  );
}

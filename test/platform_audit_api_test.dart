import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';

void main() {
  group('SnaplinkAdminApiAudit', () {
    test('fetchPlatformAuditEvents 请求 /api/v1/audit/events 并解析事件', () async {
      Uri? requested;
      final api = SnaplinkAdminApi(
        baseUrl: 'http://sso.test',
        accessToken: 'token-1',
        httpClient: MockClient((request) async {
          requested = request.url;
          return http.Response(
            jsonEncode({
              'events': [
                {
                  'id': 'evt-1',
                  'type': 'login',
                  'outcome': 'success',
                  'timestamp': '2026-08-07T10:00:00Z',
                  'actor_id': 'admin',
                  'actor_ip': '10.0.0.5',
                  'client_id': 'console',
                  'metadata': {'target_user': 'u1'},
                },
              ],
              'count': 1,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final events = await api.fetchPlatformAuditEvents(limit: 50);
      expect(requested!.path, '/api/v1/audit/events');
      expect(requested!.queryParameters['limit'], '50');
      expect(events, hasLength(1));
      expect(events.first.type, 'login');
      expect(events.first.actorId, 'admin');
      expect(events.first.metadata['target_user'], 'u1');
      expect(events.first.timestamp!.year, 2026);
    });

    test('fetchPlatformAuditEvents 支持类型过滤', () async {
      Uri? requested;
      final api = SnaplinkAdminApi(
        baseUrl: 'http://sso.test',
        accessToken: 'token-1',
        httpClient: MockClient((request) async {
          requested = request.url;
          return http.Response(jsonEncode({'events': [], 'count': 0}), 200);
        }),
      );
      await api.fetchPlatformAuditEvents(type: 'token_revoked', limit: 10);
      expect(requested!.queryParameters['type'], 'token_revoked');
    });
  });
}

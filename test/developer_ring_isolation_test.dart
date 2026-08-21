@TestOn('vm')
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/developer/developer_api.dart';
import 'package:sso_admin/services/audit_log_service.dart';
import 'package:sso_admin/services/local_storage.dart';

/// AC-1 net-zero ring-isolation guard (spec REQ-2; design §1.2).
///
/// Driving the developer module's three client-lifecycle mutations through
/// `DeveloperApi` — register (POST /register), saveApp (PUT
/// /register/:client_id), deleteApp (DELETE /register/:client_id) — must
/// leave the debug-only audit ring (`sso_audit_log`) bit-identical: no new
/// key, no stored-value rewrite, no in-memory mutation, and no request to
/// any audit endpoint.
///
/// Identity pin (design V1): `AuditEntry` has no `operator ==`, so the
/// `entries` equality is element-identity — any transient `record()`
/// inserts a fresh instance that can never be identity-equal to the seed
/// instance, catching a write-then-restore that launders localStorage
/// back to its prior value (storage-level asserts are the second layer).
///
/// Compile-error in this file == a landed surface changed (design C1):
/// every symbol here is frozen (developer_api.dart:44-49,75-92,136-152,
/// 155-166; audit_log_service.dart:58-59,89-94,120-125; local_storage.dart:
/// 11,21).
void main() {
  test(
    'DCR mutations leave the pre-seeded audit ring untouched (AC-1)',
    () async {
      // Pre-seed the debug-only ring (spec AC-1.1): record() persists
      // synchronously via LocalStorage.setItem, so the key is present.
      AuditLogService().record(
        AuditEntry(
          timestamp: DateTime.now(),
          method: 'POST',
          path: '/api/v1/admin/forged',
          statusCode: 200,
          label: 'forged',
        ),
      );
      addTearDown(AuditLogService().clear);

      // Post-seed snapshots (spec AC-1.2) + seed sanity.
      final keysBefore = LocalStorage.keys().toSet();
      final valueBefore = LocalStorage.getItem('sso_audit_log');
      final countBefore = AuditLogService().count;
      final entriesBefore = AuditLogService().entries;
      expect(keysBefore, contains('sso_audit_log'), reason: 'seed sanity');
      expect(countBefore, 1, reason: 'seed sanity');

      // Drive all three mutations through one MockClient-backed DeveloperApi
      // (spec AC-1.3), recording every request URL.
      final paths = <Uri>[];
      final api = DeveloperApi(
        baseUri: Uri.parse('https://sso.example'),
        httpClient: MockClient((request) async {
          paths.add(request.url);
          if (request.method == 'POST' && request.url.path == '/register') {
            expect(request.headers['authorization'], 'Bearer bootstrap-token');
            expect(jsonDecode(request.body), {
              'client_name': 'Acme app',
              'redirect_uris': ['https://app.example.test/callback'],
              'scope': 'openid',
              'token_endpoint_auth_method': 'none',
              'token_strategy': 'jwt',
            });
            return http.Response(
              jsonEncode({
                'client_id': 'client-1',
                'registration_access_token': 'rat-1',
              }),
              201,
            );
          }
          if (request.method == 'PUT' &&
              request.url.path == '/register/client-1') {
            expect(request.headers['authorization'], 'Bearer rat-1');
            return http.Response('{}', 200);
          }
          if (request.method == 'DELETE' &&
              request.url.path == '/register/client-1') {
            expect(request.headers['authorization'], 'Bearer rat-1');
            return http.Response('', 204);
          }
          return http.Response('{"error":"unexpected request"}', 404);
        }),
      );
      await api.register(
        clientName: 'Acme app',
        redirectUris: ['https://app.example.test/callback'],
        scope: 'openid',
        tokenEndpointAuthMethod: 'none',
        tokenStrategy: 'jwt',
        initialAccessToken: 'bootstrap-token',
      );
      await api.saveApp(
        clientId: 'client-1',
        token: 'rat-1',
        body: {'client_name': 'Acme app'},
      );
      await api.deleteApp(clientId: 'client-1', token: 'rat-1');

      // Net-zero (spec AC-1.4, REQ-2).
      expect(
        LocalStorage.keys().toSet(),
        keysBefore,
        reason: 'the DCR flow must not introduce the ring key',
      );
      expect(
        LocalStorage.getItem('sso_audit_log'),
        valueBefore,
        reason: 'stored ring value byte-identical',
      );
      expect(
        AuditLogService().count,
        countBefore,
        reason: 'same in-memory entry count',
      );
      expect(
        AuditLogService().entries,
        entriesBefore,
        reason: 'same in-memory entry instances (catches write-then-restore)',
      );
      // Exactly three DCR requests (design V4): POST /register, PUT and
      // DELETE /register/client-1 share one path — never a set-equality over
      // three distinct paths.
      expect(paths.length, 3, reason: 'exactly the three DCR requests');
      expect(
        paths.every((p) => p.path.startsWith('/register')),
        isTrue,
        reason: 'exactly the three DCR requests',
      );
      expect(
        paths.where((p) => p.path.contains('/api/v1/audit')),
        isEmpty,
        reason: 'the DCR flow must not issue any audit request',
      );
    },
  );
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/audit_read_client.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';

SnaplinkAdminApi _api(List<Uri> requests) => SnaplinkAdminApi(
  baseUrl: 'https://sso.example.test',
  accessToken: 'admin-token',
  httpClient: MockClient((request) async {
    requests.add(request.url);
    return http.Response(jsonEncode({'events': <Object>[], 'count': 0}), 200);
  }),
);

void main() {
  test(
    'default list() wire is exactly {limit: 100} — no tenant, no trace',
    () async {
      final requests = <Uri>[];
      final client = AuditReadClient(_api(requests));

      final rows = await client.list();

      expect(rows, isEmpty);
      expect(requests, hasLength(1));
      final uri = requests.single;
      expect(uri.path, AuditReadClient.eventsPath);
      expect(uri.queryParameters, {'limit': '100'});
    },
  );

  test(
    'constructor tenantId/traceId ride the wire; per-call override shadows',
    () async {
      final requests = <Uri>[];
      final client = AuditReadClient(
        _api(requests),
        tenantId: 'acme',
        traceId: 'tr-1',
      );

      await client.list();
      expect(requests.last.queryParameters, {
        'limit': '100',
        'tenant_id': 'acme',
        'trace_id': 'tr-1',
      });

      // Per-call override shadows the constructor values.
      await client.list(tenantId: 'other', traceId: 'tr-2');
      expect(requests.last.queryParameters, {
        'limit': '100',
        'tenant_id': 'other',
        'trace_id': 'tr-2',
      });
    },
  );

  test('whitespace-only tenant/trace values are omitted', () async {
    final requests = <Uri>[];
    final client = AuditReadClient(_api(requests), tenantId: '   ');

    await client.list(traceId: ' \t ');

    expect(requests.single.queryParameters, {'limit': '100'});
  });

  test('facets() hits facetsPath with the same AuditQuery semantics', () async {
    final requests = <Uri>[];
    final client = AuditReadClient(_api(requests));

    final facets = await client.facets();

    expect(facets['events'], isEmpty);
    expect(requests.single.path, AuditReadClient.facetsPath);
    expect(requests.single.queryParameters, {'limit': '100'});
  });

  test('event() encodes the id and sends no query parameters', () async {
    final requests = <Uri>[];
    final client = AuditReadClient(_api(requests));

    await client.event('a/b');

    expect(requests, hasLength(1));
    // MockClient pattern assertion: request.url.path returns the encoded id.
    expect(requests.single.path, '${AuditReadClient.eventsPath}/a%2Fb');
    expect(requests.single.queryParameters, isEmpty);
  });

  test('client-forwarding pin: cursor/eventTypes/outcome forward verbatim via '
      'AuditQuery (singular event_type wire key, no mapping)', () async {
    final requests = <Uri>[];
    final client = AuditReadClient(_api(requests));

    await client.list(cursor: 'c-1');
    expect(requests.last.queryParameters, {'limit': '100', 'cursor': 'c-1'});

    await client.list(eventTypes: 'admin_client_created');
    expect(requests.last.queryParameters, {
      'limit': '100',
      'event_type': 'admin_client_created',
    });

    await client.list(outcome: 'failure');
    expect(requests.last.queryParameters, {
      'limit': '100',
      'outcome': 'failure',
    });

    await client.facets(cursor: 'c-1', eventTypes: 'x', outcome: 'failure');
    expect(requests.last.queryParameters, {
      'limit': '100',
      'cursor': 'c-1',
      'event_type': 'x',
      'outcome': 'failure',
    });
  });

  test(
    'source pin: query maps are AuditQuery-only (no hand-built literal)',
    () {
      final source = File('lib/api/audit_read_client.dart').readAsStringSync();
      expect(RegExp(r'query:\s*\{').hasMatch(source), isFalse);
      expect(source, contains('AuditQuery'));
    },
  );
}

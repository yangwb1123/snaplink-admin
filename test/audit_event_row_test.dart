import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/audit_event_row.dart';

void main() {
  group('auditEventRowsFromResponse', () {
    test('maps a real-shape event to the allowlisted row fields', () {
      final rows = auditEventRowsFromResponse({
        'events': [
          {
            'id': 'e-1',
            'type': 'admin_client_created',
            'outcome': 'success',
            'timestamp': '2026-08-05T12:00:00Z',
            'actor_id': 'admin-1',
            'client_id': 'console',
            'tenant_id': 'acme',
          },
        ],
        'count': 1,
      });

      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.id, 'e-1');
      expect(row.type, 'admin_client_created');
      expect(row.outcome, 'success');
      expect(row.timestamp, DateTime.utc(2026, 8, 5, 12));
      expect(row.actorId, 'admin-1');
      expect(row.clientId, 'console');
      expect(row.tenantId, 'acme');
    });

    test('maps Audit Governance event envelopes without exposing payload', () {
      final rows = auditEventRowsFromResponse({
        'items': [
          {
            'event_id': 'ag-1',
            'event_type': 'aero.vault.audit-fact',
            'outcome': 'success',
            'occurred_at': '2026-08-22T09:30:00Z',
            'actor': {'id': 'principal-digest', 'type': 'principal'},
            'source_system': 'aero-vault.source-1',
            'tenant_id': 'acme',
            'payload': {'access_token': 'must-not-surface'},
          },
        ],
        'next_cursor': 'opaque',
        'count': 1,
      });

      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.id, 'ag-1');
      expect(row.type, 'aero.vault.audit-fact');
      expect(row.outcome, 'success');
      expect(row.timestamp, DateTime.utc(2026, 8, 22, 9, 30));
      expect(row.actorId, 'principal-digest');
      expect(row.clientId, 'aero-vault.source-1');
      expect(row.tenantId, 'acme');
      expect(row.type, isNot(contains('must-not-surface')));
    });

    test('{} and {"events": []} both produce zero rows', () {
      expect(auditEventRowsFromResponse(const {}), isEmpty);
      expect(
        auditEventRowsFromResponse(const {'events': <Object>[], 'count': 0}),
        isEmpty,
      );
    });

    test('a non-empty bare map is a single record', () {
      final rows = auditEventRowsFromResponse(const {'id': 'bare-1'});
      expect(rows, hasLength(1));
      expect(rows.single.id, 'bare-1');
      expect(rows.single.type, 'bare-1');
      expect(rows.single.outcome, '');
    });

    test('count-preserving: N input elements produce exactly N rows', () {
      final rows = auditEventRowsFromResponse(const {
        'events': [
          {'id': 'ok', 'type': 't'},
          42,
          null,
          'garbage',
          {'id': 'x'},
        ],
      });

      expect(rows, hasLength(5));
      expect(rows[0].id, 'ok');
      // Fallback rows: constant-built, never fabricated success/failure.
      for (final row in rows.skip(1)) {
        expect(row.type, isNotEmpty);
        expect(row.outcome, '');
      }
      expect(rows[4].id, 'x');
    });

    test('non-allowlisted bait fields never surface', () {
      final rows = auditEventRowsFromResponse({
        'events': [
          {
            'id': 'e-1',
            'type': 'admin_client_created',
            'outcome': 'success',
            'timestamp': '2026-08-05T12:00:00Z',
            'actor_id': 'admin-1',
            'client_id': 'console',
            'tenant_id': 'acme',
            'request_id': 'req-bait',
            'trace_id': 'trace-bait',
            'span_id': 'span-bait',
            'parent_span_id': 'parent-bait',
            'actor_ip': '203.0.113.9',
            'user_agent': 'ua-bait',
            'provider': 'provider-bait',
            'session_id': 'session-bait',
            'token_id': 'token-bait',
            'token_strategy': 'strategy-bait',
            'reason': 'reason-bait',
            'metadata': {'client_secret': 'meta-bait'},
            'prev_hash': 'prev-bait',
            'hash': 'hash-bait',
            'server_version': 'version-bait',
          },
        ],
      });

      final row = rows.single;
      expect(row.id, 'e-1');
      expect(row.type, 'admin_client_created');
      expect(row.outcome, 'success');
    });

    test('legacy ring vocabulary is a defensive fallback only', () {
      final rows = auditEventRowsFromResponse({
        'entries': [
          {
            'method': 'POST',
            'path': '/api/v1/admin/clients',
            'statusCode': 200,
            'label': 'clients POST',
          },
        ],
      });

      final row = rows.single;
      expect(row.type, 'clients POST');
      expect(row.outcome, '');
    });

    test('URI query scrub: sensitive query params are redacted', () {
      final rows = auditEventRowsFromResponse(const {
        'id':
            'https://sso.example.test/api/v1/clients?client_secret=SECRET'
            '&page=2',
      });

      final row = rows.single;
      expect(row.type, contains('client_secret'));
      expect(row.type, isNot(contains('SECRET')));
      expect(row.type, contains('%3Credacted%3E'));
      expect(row.type, contains('page=2'));
    });

    test('URI query scrub: token params are redacted', () {
      final rows = auditEventRowsFromResponse(const {
        'label': 'https://sso.example.test/oauth/token?access_token=TOK1',
      });

      expect(rows.single.type, isNot(contains('TOK1')));
      expect(rows.single.type, contains('access_token'));
    });

    test('URI query scrub: OAuth/authorization query keys are redacted, '
        'audit context survives', () {
      final rows = auditEventRowsFromResponse(const {
        'events': [
          {
            'type':
                'https://sso.example.test/oauth/authorize'
                '?code=C0DESECRET&state=ST8SECRET&jwt=J0TSECRET'
                '&key=K3YSECRET&sig=S1GSECRET&assertion=ASRTSECRET'
                '&ticket=T1CKSECRET&session=S3SSSECRET'
                '&limit=100&tenant_id=acme&outcome=failure',
          },
        ],
      });

      final t = rows.single.type;
      // Values never survive, at any layer of the EVENT column or export.
      for (final value in const [
        'C0DESECRET',
        'ST8SECRET',
        'J0TSECRET',
        'K3YSECRET',
        'S1GSECRET',
        'ASRTSECRET',
        'T1CKSECRET',
        'S3SSSECRET',
      ]) {
        expect(t, isNot(contains(value)));
      }
      // Keys are retained so the reader sees which credential-bearing
      // parameter was present; each value is truncated to the redacted
      // marker.
      for (final key in const [
        'code',
        'state',
        'jwt',
        'key',
        'sig',
        'assertion',
        'ticket',
        'session',
      ]) {
        expect(t, contains('$key='), reason: 'key $key must be retained');
      }
      expect(t, contains('%3Credacted%3E'));
      // Legitimate audit context passes through untouched.
      expect(t, contains('limit=100'));
      expect(t, contains('tenant_id=acme'));
      expect(t, contains('outcome=failure'));
    });

    test('URI query scrub: no over-redaction of legitimate business query '
        'keys', () {
      final rows = auditEventRowsFromResponse(const {
        'events': [
          {
            // Substring-decoy keys: fragment-style matching (or a global
            // SensitiveData extension) would wrongly redact these — `sig`
            // sits inside `design`, `key` inside `monkey`, `code` inside
            // `decode`, `state` inside `statement`. The scrub is exact-key
            // on the normalized query key, so the full URI (and its audit
            // context) survives.
            'type':
                'https://sso.example.test/ops'
                '?design=v2&monkey=zoo&decode=1&statement=paid'
                '&limit=100&tenant_id=acme&page=2&outcome=failure',
          },
        ],
      });

      final t = rows.single.type;
      expect(t, contains('design=v2'));
      expect(t, contains('monkey=zoo'));
      expect(t, contains('decode=1'));
      expect(t, contains('statement=paid'));
      expect(t, contains('limit=100'));
      expect(t, contains('tenant_id=acme'));
      expect(t, contains('page=2'));
      expect(t, contains('outcome=failure'));
      expect(t, isNot(contains('%3Credacted%3E')));
    });

    test('URI query scrub: session_id is redacted like session', () {
      final rows = auditEventRowsFromResponse(const {
        'events': [
          {
            'type':
                'https://sso.example.test/continue'
                '?session_id=S3SSID&session_id2=keepme',
          },
        ],
      });

      final t = rows.single.type;
      expect(t, isNot(contains('S3SSID')));
      expect(t, contains('session_id='));
      expect(t, contains('session_id2=keepme'));
    });

    test('non-URI strings and URIs without query pass through unchanged', () {
      final rows = auditEventRowsFromResponse(const {
        'events': [
          {'type': 'admin_client_created'},
          {'type': 'https://sso.example.test/plain'},
        ],
      });

      expect(rows[0].type, 'admin_client_created');
      expect(rows[1].type, 'https://sso.example.test/plain');
    });

    test('invalid timestamp parses to null', () {
      final rows = auditEventRowsFromResponse(const {
        'events': [
          {'type': 't', 'timestamp': 'not-a-date'},
        ],
      });

      expect(rows.single.timestamp, isNull);
    });

    test(
      'wrong-typed envelope keys produce zero rows, never a phantom row (F1)',
      () {
        // The adversarial review's degenerate-payload probe matrix: a
        // degraded sink returning a present-but-not-List envelope key must
        // read as "server had nothing", not as one fabricated 'audit event'
        // record that would ride the CSV export.
        for (final payload in <Map<String, dynamic>>[
          const {'events': null, 'count': 0},
          const {'events': 42},
          const {'events': 'oops'},
          const {'events': <String, dynamic>{}},
        ]) {
          expect(
            auditEventRowsFromResponse(payload),
            isEmpty,
            reason: 'payload: $payload',
          );
        }
        // The wrong-typed envelope also wins over bare-map record fields:
        // `{'events': null, 'id': 'x'}` is still zero rows (F3 precedence:
        // the envelope key owns the payload shape).
        expect(
          auditEventRowsFromResponse(const {'events': null, 'id': 'x'}),
          isEmpty,
        );
        // And `{}` / `{'events': []}` stay zero rows (existing pin).
        expect(auditEventRowsFromResponse(const {}), isEmpty);
        expect(
          auditEventRowsFromResponse(const {'events': <Object>[], 'count': 0}),
          isEmpty,
        );
      },
    );

    test('never throws on garbage input', () {
      expect(
        () => auditEventRowsFromResponse(const {
          'events': [
            {'x': 1},
            'z',
          ],
        }),
        returnsNormally,
      );
      // Wrong-typed envelope: zero rows (F1), not a fabricated row.
      expect(
        auditEventRowsFromResponse(const {'events': 'not-a-list'}),
        isEmpty,
      );
    });
  });
}

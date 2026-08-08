import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/audit_query.dart';

void main() {
  group('AuditQuery.toQueryParameters', () {
    test(
      'AC-1.1 default construction is exactly {limit: 100}, no tenant/trace',
      () {
        expect(
          AuditQuery(limit: 100).toQueryParameters(),
          equals({'limit': '100'}),
        );
      },
    );

    test('AC-1.2 tenant_id and trace_id serialize when present', () {
      expect(
        AuditQuery(
          tenantId: 'tenant-a',
          traceId: 'tr-1',
          limit: 100,
        ).toQueryParameters(),
        equals({'limit': '100', 'tenant_id': 'tenant-a', 'trace_id': 'tr-1'}),
      );
    });

    test('AC-1.3 whitespace-only tenantId is omitted', () {
      expect(
        AuditQuery(
          tenantId: '  ',
          traceId: 'tr-1',
          limit: 100,
        ).toQueryParameters(),
        equals({'limit': '100', 'trace_id': 'tr-1'}),
      );
    });

    test(
      'AC-1.6 cursor and event_type serialize when present, omit when absent',
      () {
        expect(
          AuditQuery(
            cursor: 'abc',
            eventTypes: 'sign-in,sign-out',
          ).toQueryParameters(),
          equals({'cursor': 'abc', 'event_type': 'sign-in,sign-out'}),
        );
        expect(AuditQuery().toQueryParameters(), isEmpty);
        expect(AuditQuery(outcome: '  ').toQueryParameters(), isEmpty);
      },
    );

    test('values are trimmed at serialization', () {
      expect(
        AuditQuery(tenantId: ' acme ', outcome: 'failure ').toQueryParameters(),
        equals({'tenant_id': 'acme', 'outcome': 'failure'}),
      );
    });
  });

  group('AuditQuery.fromJson', () {
    test('AC-1.4 helper-text example round-trips', () {
      const example = {'limit': 100, 'tenant_id': 'acme', 'outcome': 'failure'};
      expect(
        AuditQuery.fromJson(example).toQueryParameters(),
        equals({'limit': '100', 'tenant_id': 'acme', 'outcome': 'failure'}),
      );
    });

    test(
      'AC-1.5 unknown keys throw a typed parse error listing the key set',
      () {
        expect(
          () => AuditQuery.fromJson(const {'limit': 100, 'unknown_key': 'x'}),
          throwsA(
            isA<AuditQueryParseException>().having(
              (error) => error.message,
              'message',
              allOf(
                contains('unsupported key "unknown_key"'),
                contains('tenant_id'),
                contains('trace_id'),
                contains('event_type'),
              ),
            ),
          ),
        );
      },
    );

    test('limit as a numeric string is accepted; non-numeric throws', () {
      expect(
        AuditQuery.fromJson(const {'limit': '100'}).toQueryParameters(),
        equals({'limit': '100'}),
      );
      expect(
        () => AuditQuery.fromJson(const {'limit': 'abc'}),
        throwsA(
          isA<AuditQueryParseException>().having(
            (error) => error.message,
            'message',
            contains('limit must be an integer'),
          ),
        ),
      );
      expect(
        () => AuditQuery.fromJson(const {'limit': 1.5}),
        throwsA(isA<AuditQueryParseException>()),
      );
    });

    test('wrong-typed values throw (F3)', () {
      expect(
        () => AuditQuery.fromJson(const {'outcome': true}),
        throwsA(
          isA<AuditQueryParseException>().having(
            (error) => error.message,
            'message',
            contains('must be a string or integer'),
          ),
        ),
      );
      expect(
        () => AuditQuery.fromJson(const {'tenant_id': <String>[]}),
        throwsA(isA<AuditQueryParseException>()),
      );
    });

    test('F6: null values are treated as absent, never stringified', () {
      expect(
        AuditQuery.fromJson(const {
          'limit': 100,
          'tenant_id': null,
          'trace_id': null,
        }).toQueryParameters(),
        equals({'limit': '100'}),
      );
    });

    test(
      'int values for string keys coerce like the previous wire behavior',
      () {
        expect(
          AuditQuery.fromJson(const {'tenant_id': 42}).toQueryParameters(),
          equals({'tenant_id': '42'}),
        );
      },
    );
  });

  test('supportedKeys is exactly the REQ-1 key set', () {
    expect(
      AuditQuery.supportedKeys,
      equals([
        'limit',
        'tenant_id',
        'trace_id',
        'cursor',
        'event_type',
        'outcome',
      ]),
    );
  });
}

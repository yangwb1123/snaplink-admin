/// Repo-wide audit contract guard (AC-3) — the corrected four scans.
///
/// Revised per `docs/proposals/b6-1c-audit-contract-guard-review.md` §4:
///  * scan 1: per-line path-token extraction inside triple-quoted literals
///    (the `routes` blob at `snaplink_admin_types.dart`), shared `{id}`
///    normalizer (incl. `${Uri.encodeComponent(<ident>)}`), bare
///    `/api/v1/audit` grouping anchor;
///  * scan 2: unified case-insensitive whole-file `bff` semantics (==
///    `grep -rni "bff" lib/`);
///  * scan 3: runtime catalog trio, sharing the scan-1 normalizer;
///  * scan 4: lib-wide whitespace-tolerant `MapEntry(key, '$value')`
///    absence + positive pins (builder wiring, default field text,
///    parse-error surface, `'null'` literal ban in the builder).
///
/// The trip matrix for the planted regressions lives in
/// `test/audit_contract_guard_mutation_test.dart`; the behavioral wire
/// pins (default map, facets twin, parse-error-no-request, no-other-path)
/// live in `test/admin_governance_security_test.dart`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';

import 'audit_contract_guard_scans.dart';

void main() {
  group('AC-3.1 audit-path literal scan', () {
    test('green against the current tree', () {
      final violations = scanLibDirectory(
        packageLibDir(),
      ).where((violation) => violation.scan == 'audit-path-literals');
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('routes blob per-line tokens normalize into the trio', () {
      // The `routes` triple-quoted blob is one giant literal; per-line
      // token extraction must yield the trio (not one unnormalizable blob).
      const blob = '''
GET /api/v1/admin/events/stream
GET /api/v1/audit/events
GET /api/v1/audit/facets
GET /api/v1/audit/events/{id}
''';
      expect(scanAuditPathLiterals(blob, 'probe.dart'), isEmpty);
    });

    test('encodeComponent member normalizes; dropping it trips', () {
      final good =
          r"final detail = await api.get("
          r"'/api/v1/audit/events/${Uri.encodeComponent(id)}');";
      expect(scanAuditPathLiterals(good, 'probe.dart'), isEmpty);

      final dropped =
          r"final detail = await api.get("
          r"'/api/v1/audit/events/${id}');";
      final violations = scanAuditPathLiterals(dropped, 'probe.dart');
      expect(violations, isNotEmpty);
    });

    test(
      'bare /api/v1/audit grouping anchor is allowed, trailing slash trips',
      () {
        expect(
          scanAuditPathLiterals(
            "endpoint.path.startsWith('/api/v1/audit')",
            'probe.dart',
          ),
          isEmpty,
        );
        expect(
          scanAuditPathLiterals(
            "endpoint.path.startsWith('/api/v1/audit/')",
            'probe.dart',
          ),
          isNotEmpty,
        );
      },
    );

    test('double-quoted literals are scanned too', () {
      // A method-prefixed literal is not an exact path token and trips;
      // an exact double-quoted trio path passes.
      expect(
        scanAuditPathLiterals('"GET /api/v1/audit/events"', 'probe.dart'),
        isNotEmpty,
      );
      expect(
        scanAuditPathLiterals('"/api/v1/audit/events"', 'probe.dart'),
        isEmpty,
      );
      expect(
        scanAuditPathLiterals(
          '"GET /api/v1/audit/events/{id}/export"',
          'probe.dart',
        ),
        isNotEmpty,
      );
    });
  });

  group('AC-3.2 BFF literal scan', () {
    test('green against the current tree (unified semantics)', () {
      final violations = scanLibDirectory(
        packageLibDir(),
      ).where((violation) => violation.scan == 'bff-literals');
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('case variants, identifiers, and comments all trip identically', () {
      for (final probe in <String>[
        r"final path = '/api/v1/BFF/audit/events';",
        r"final path = '/bff/audit/events';",
        'final bffClient = api;',
        '// bff path is proposed only',
      ]) {
        expect(scanBffLiterals(probe, 'probe.dart'), isNotEmpty, reason: probe);
      }
    });

    test('lowercase literal trips; plain non-bff text passes', () {
      expect(
        scanBffLiterals(r"final path = '/api/v1/bff/audit';", 'probe.dart'),
        isNotEmpty,
      );
      expect(
        scanBffLiterals(r"final path = '/api/v1/audit/events';", 'probe.dart'),
        isEmpty,
      );
    });
  });

  group('AC-3.3 catalog trio scan', () {
    test('green against the current tree', () {
      expect(scanCatalogTrio(SnaplinkAdminOperationCatalog.endpoints), isEmpty);
    });

    test('a fourth audit path or non-GET method trips', () {
      final mutated = [
        ...SnaplinkAdminOperationCatalog.endpoints,
        const SnaplinkAdminEndpoint(
          method: 'GET',
          path: '/api/v1/audit/events/{id}/export',
          feature: 'documented',
        ),
      ];
      expect(scanCatalogTrio(mutated), isNotEmpty);
      final withPost = [
        for (final endpoint in SnaplinkAdminOperationCatalog.endpoints)
          if (endpoint.path == '/api/v1/audit/events' &&
              endpoint.method == 'GET')
            const SnaplinkAdminEndpoint(
              method: 'POST',
              path: '/api/v1/audit/events',
              feature: 'documented',
            )
          else
            endpoint,
      ];
      expect(scanCatalogTrio(withPost), isNotEmpty);
    });
  });

  group('scan 5 — B6-1a second-consumer land-check', () {
    test('green against the current tree', () {
      final violations = scanLibDirectory(
        packageLibDir(),
      ).where((violation) => violation.scan == 'second-consumer');
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('trio-literal ownership pin is green against the current tree', () {
      final violations = scanLibDirectory(
        packageLibDir(),
      ).where((violation) => violation.scan == 'trio-literal-owner');
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('a hand-built query map on the audit endpoints trips', () {
      const consumer = r'''
class AuditLogTab {
  Future<void> refresh() async {
    await api.get('/api/v1/audit/events', query: {'limit': '100'});
  }
}
''';
      expect(scanSecondConsumer(consumer, 'audit_log_tab.dart'), isNotEmpty);
    });

    test(
      'AuditQuery wire + read-client reference is scan-green; {id} detail '
      'readers are not flagged',
      () {
        // The sanctioned consumer shape: parameters via
        // AuditQuery.toQueryParameters() AND the endpoint via the read
        // client's constants (both halves of the hardened green
        // condition).
        expect(
          scanSecondConsumer(
            "import 'package:sso_admin/api/audit_read_client.dart';\n"
                "import 'package:sso_admin/api/audit_query.dart';\n"
                'final parameters = AuditQuery(limit: 100).toQueryParameters();\n'
                "await api.get(AuditReadClient.eventsPath, query: parameters);",
            'audit_log_tab.dart',
          ),
          isEmpty,
        );
        // Split {id}-detail literal: no `query:` argument, so no flag even
        // though the fragment normalizes to the collection token.
        expect(
          scanSecondConsumer(
            r"final detail = await api.get('/api/v1/audit/events' "
                r"+ '/' + Uri.encodeComponent(id));",
            'admin_live_events_tab.dart',
          ),
          isEmpty,
        );
      },
    );

    test('a raw trio literal outside the read client trips the ownership '
        'pin (E3)', () {
      final owner = File(
        '${packageLibDir()}${Platform.pathSeparator}api'
        '${Platform.pathSeparator}audit_read_client.dart',
      ).readAsStringSync();
      final violations = scanTrioLiteralOwnership({
        'api/audit_read_client.dart': owner,
        'screens/admin/future_consumer.dart':
            "final rows = await api.get('/api/v1/audit/events');",
      });
      expect(
        violations.any((v) => v.scan == 'trio-literal-owner'),
        isTrue,
        reason: violations.join('\n'),
      );
    });

    test('ownership pin is non-vacuous: a dropped trio literal in the '
        'read client trips', () {
      final owner = File(
        '${packageLibDir()}${Platform.pathSeparator}api'
        '${Platform.pathSeparator}audit_read_client.dart',
      ).readAsStringSync();
      final degraded = owner.replaceFirst(
        "static const eventsPath = '/api/v1/audit/events';",
        'static const eventsPath = "placeholder";',
      );
      expect(degraded, isNot(owner));
      final violations = scanTrioLiteralOwnership({
        'api/audit_read_client.dart': degraded,
      });
      expect(
        violations.any((v) => v.scan == 'trio-literal-owner'),
        isTrue,
        reason: violations.join('\n'),
      );
    });

    group('E1–E6 evasion matrix (adversarial review) — all fail closed', () {
      // Synthetic future-consumer files exactly as the adversarial review
      // constructed them. E1/E2/E5/E6 go through the read-client constants
      // (identifier indirection); E3 carries the raw literal (ownership
      // pin); E4 splits the path across adjacent literals.
      final owner = File(
        '${packageLibDir()}${Platform.pathSeparator}api'
        '${Platform.pathSeparator}audit_read_client.dart',
      ).readAsStringSync();
      final evasions = <String, String>{
        'E1': "await api.get(AuditReadClient.eventsPath, "
            "query: {'limit': '100'});",
        'E2': "import 'package:sso_admin/api/audit_query.dart' "
            "show AuditQuery;\n"
            "await api.get(AuditReadClient.eventsPath, "
            "query: {'limit': '100'});",
        'E3': "await api.get('/api/v1/audit/events');",
        'E4': "await api.get('/api/v1/audit' '/events', "
            "query: {'limit': '100'});",
        'E5': "await api.get(AuditReadClient.facetsPath, "
            "query: {'limit': '100'});",
        'E6': "await api.get(AuditReadClient.eventsPath, "
            "query: {...AuditQuery(limit: 100).toQueryParameters(), "
            "'evil': 'x'});",
      };
      for (final entry in evasions.entries) {
        test('${entry.key} fails closed', () {
          final scanViolations = scanSecondConsumer(
            entry.value,
            'screens/admin/future_consumer.dart',
          );
          final pinViolations = scanTrioLiteralOwnership({
            'api/audit_read_client.dart': owner,
            'screens/admin/future_consumer.dart': entry.value,
          });
          final all = [...scanViolations, ...pinViolations];
          expect(
            all,
            isNotEmpty,
            reason: '${entry.key} stayed scan-green:\n${entry.value}',
          );
        });
      }
    });
  });

  group('AC-3.4 raw-stringification scan', () {
    test('green against the current tree', () {
      final violations = scanLibDirectory(
        packageLibDir(),
      ).where((violation) => violation.scan == 'raw-stringification');
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('whitespace-tolerated MapEntry skins trip in both quote styles', () {
      for (final probe in <String>[
        r"final parameters = query.map((key, value) => "
            r"MapEntry(key, '$value'));",
        r'final parameters = query.map((key, value) => '
            r'MapEntry( key ,  "$value" ));',
        r"final parameters = query.map((key, value) =>"
            r"\n    MapEntry(\n      key,\n      '$value',\n    ));",
      ]) {
        expect(
          scanRawStringification(probe, 'screens/admin/governance_tab.dart'),
          isNotEmpty,
          reason: probe,
        );
      }
    });

    test('Map.from/.cast/.toString skins fail only via the positive pins', () {
      // A rewired builder in governance_tab.dart with no raw `$value` entry
      // passes the absence check — the positive pins must catch it.
      final rewired =
          'final parameters = Map<String, String>.from(query);\n'
          '// no AuditQuery import, no fromJson, no toQueryParameters here\n';
      final violations = scanRawStringification(
        rewired,
        'screens/admin/governance_tab.dart',
      );
      expect(
        violations.any((v) => v.detail.contains('positive pin missing')),
        isTrue,
        reason: violations.join('\n'),
      );
    });

    test(
      'null literal ban inside the builder trips the tenant_id=null skin',
      () {
        expect(
          scanRawStringification(
            "if (tenantId == null) parameters['tenant_id'] = 'null';",
            'api/audit_query.dart',
          ),
          isNotEmpty,
        );
      },
    );
  });
}

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
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/api/snaplink_admin_types.dart';

import 'audit_contract_guard_scans.dart';

void main() {
  group('AC-3.1 audit-path literal scan', () {
    test('green against the current tree', () {
      final violations = scanLibDirectory(packageLibDir()).where(
        (violation) => violation.scan == 'audit-path-literals',
      );
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
      final good = r"final detail = await api.get("
          r"'/api/v1/audit/events/${Uri.encodeComponent(id)}');";
      expect(scanAuditPathLiterals(good, 'probe.dart'), isEmpty);

      final dropped = r"final detail = await api.get("
          r"'/api/v1/audit/events/${id}');";
      final violations = scanAuditPathLiterals(dropped, 'probe.dart');
      expect(violations, isNotEmpty);
    });

    test('bare /api/v1/audit grouping anchor is allowed, trailing slash trips',
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
    });

    test('double-quoted literals are scanned too', () {
      expect(
        scanAuditPathLiterals('"GET /api/v1/audit/events"', 'probe.dart'),
        isEmpty,
      );
      expect(
        scanAuditPathLiterals('"/api/v1/audit/events/{id}/export"',
            'probe.dart'),
        isNotEmpty,
      );
    });
  });

  group('AC-3.2 BFF literal scan', () {
    test('green against the current tree (unified semantics)', () {
      final violations = scanLibDirectory(packageLibDir()).where(
        (violation) => violation.scan == 'bff-literals',
      );
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

  group('AC-3.4 raw-stringification scan', () {
    test('green against the current tree', () {
      final violations = scanLibDirectory(packageLibDir()).where(
        (violation) => violation.scan == 'raw-stringification',
      );
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
      final rewired = 'final parameters = Map<String, String>.from(query);\n'
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

    test('null literal ban inside the builder trips the tenant_id=null skin',
        () {
      expect(
        scanRawStringification(
          "if (tenantId == null) parameters['tenant_id'] = 'null';",
          'api/audit_query.dart',
        ),
        isNotEmpty,
      );
    });
  });
}

/// Repo-wide audit contract guard (AC-3) — the corrected four scans,
/// the B6-1 portal/developer boundary scans (6/6b), and the B6-1b
/// ring-storage-seam scan (7).
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
///    parse-error surface, `'null'` literal ban in the builder);
///  * scan 6: portal negative boundary (`portal-audit-boundary`) — zero
///    case-insensitive `audit` occurrences in `lib/screens/portal/` (B6-1),
///    plus a temp-dir positive pin so the `scanLibDirectory` wiring cannot
///    regress vacuously (F2);
///  * scan 6b: developer negative boundary (`developer-audit-boundary`)
///    — parity with scan 6 for `lib/screens/developer/` (B6-1);
///  * scan 7: ring-storage-seam source guard (`ring-storage-seam`) —
///    key-scoped pins on `services/audit_log_service.dart` plus the
///    lib-wide non-service literal branch (B6-1b).
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

    test('AuditQuery wire + read-client reference is scan-green; {id} detail '
        'readers are not flagged', () {
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
    });

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
        'E1':
            "await api.get(AuditReadClient.eventsPath, "
            "query: {'limit': '100'});",
        'E2':
            "import 'package:sso_admin/api/audit_query.dart' "
            "show AuditQuery;\n"
            "await api.get(AuditReadClient.eventsPath, "
            "query: {'limit': '100'});",
        'E3': "await api.get('/api/v1/audit/events');",
        'E4':
            "await api.get('/api/v1/audit' '/events', "
            "query: {'limit': '100'});",
        'E5':
            "await api.get(AuditReadClient.facetsPath, "
            "query: {'limit': '100'});",
        'E6':
            "await api.get(AuditReadClient.eventsPath, "
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

  group('scan 6 — portal-audit-boundary (B6-1 negative boundary)', () {
    test('zero "audit" occurrences across the portal module and API', () {
      final violations = scanLibDirectory(
        packageLibDir(),
      ).where((violation) => violation.scan == 'portal-audit-boundary');
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('F2 wiring pin — synthetic probe tree trips every per-file scan '
        'via scanLibDirectory', () {
      // The positive pin (F2 amendment, extended at re-review): a synthetic
      // probe tree inside a throwaway temp dir must trip EVERY per-file
      // scan through the `scanLibDirectory` loop wiring. Scan 6's probe is
      // a `screens/portal/_probe.dart` containing `audit`; scans 1/2/4/5
      // and the trio-owner pin get one probe each. If any per-file call in
      // the scans.dart loop is forgotten (or a prefix/id check breaks),
      // that scan's green-against-tree group would pass vacuously — this
      // test cannot: the missing scan's id simply produces no violations.
      // (The `_scanWith` dispatch re-implements the loop, so the mutation
      // skins pin only the dispatch — scans 1/2/4/5 share this residual
      // with scan 6 and are covered here too.) Temp-dir only; no repo file
      // is touched; the tree is removed via addTearDown.
      final tempDir = Directory.systemTemp.createTempSync('b6_1_guard_pin_');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });
      void writeProbe(String relativePath, String body) {
        final file = File(
          '${tempDir.path}${Platform.pathSeparator}'
          '${relativePath.replaceAll('/', Platform.pathSeparator)}',
        );
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(body);
      }

      // Dirty state — one probe per scan id:
      writeProbe(
        'screens/portal/_probe.dart',
        "final _probe = 'audit'; // synthetic negative-boundary probe\n",
      );
      writeProbe(
        'api/portal_api.dart',
        "final _probe = 'audit'; // contract-named API probe\n",
      );
      writeProbe(
        'screens/developer/_probe.dart',
        "final _probe = 'AUDIT'; // synthetic negative-boundary probe\n",
      );
      writeProbe(
        'screens/portal/_probe_scan1.dart',
        "final p = '/api/v1/audit/events/export';\n",
      );
      writeProbe('screens/portal/_probe_scan2.dart', '// bff\n');
      writeProbe(
        'screens/portal/_probe_scan4.dart',
        "final m = MapEntry(key, '\$value');\n",
      );
      writeProbe(
        'screens/portal/_probe_scan5.dart',
        "await api.get('/api/v1/audit/events', "
            "query: {'limit': '100'});\n",
      );
      // A complete trio owner in the throwaway tree, so the ownership pin
      // trips on the offender probe above, not on missing-owner noise.
      writeProbe(
        'api/audit_read_client.dart',
        "const a = '/api/v1/audit/events';\n"
            "const b = '/api/v1/audit/facets';\n"
            "const c = '/api/v1/audit/events/{id}';\n",
      );
      const allPerFileScans = [
        'portal-audit-boundary',
        'developer-audit-boundary',
        'audit-path-literals',
        'bff-literals',
        'raw-stringification',
        'second-consumer',
        'trio-literal-owner',
      ];
      final dirty = scanLibDirectory(tempDir.path);
      for (final scan in allPerFileScans) {
        expect(
          dirty.where((v) => v.scan == scan),
          isNotEmpty,
          reason:
              'dirty probe tree produced no $scan violations — the '
              'scanLibDirectory wiring for this scan is missing or broken: '
              '${dirty.join('\n')}',
        );
      }
      // Control: neutralize every probe; all ids must stay green, so the
      // pin cannot be satisfied by paths/layout alone (over-flagging).
      writeProbe('screens/portal/_probe.dart', "final _probe = 'activity';\n");
      writeProbe('api/portal_api.dart', "final _probe = 'activity';\n");
      writeProbe(
        'screens/developer/_probe.dart',
        "final _probe = 'activity';\n",
      );
      writeProbe(
        'screens/portal/_probe_scan1.dart',
        "final p = '/me/security/activity';\n",
      );
      writeProbe('screens/portal/_probe_scan2.dart', '// activity\n');
      writeProbe(
        'screens/portal/_probe_scan4.dart',
        'final m = MapEntry(key, value);\n',
      );
      writeProbe(
        'screens/portal/_probe_scan5.dart',
        "await api.get('/me/security/activity', "
            "query: {'limit': '100'});\n",
      );
      final clean = scanLibDirectory(tempDir.path);
      for (final scan in allPerFileScans) {
        expect(
          clean.where((v) => v.scan == scan),
          isEmpty,
          reason:
              'clean probe tree still trips $scan — over-flagging: '
              '${clean.join('\n')}',
        );
      }
    });
  });

  group('scan 6b — developer-audit-boundary (B6-1 negative boundary)', () {
    test('zero "audit" occurrences across the live developer module', () {
      final violations = scanLibDirectory(
        packageLibDir(),
      ).where((violation) => violation.scan == 'developer-audit-boundary');
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('probe 1 — AuditLogService import trips the developer boundary', () {
      final violations = scanDeveloperAuditBoundary(
        "import 'package:sso_admin/services/audit_log_service.dart';\n",
        'screens/developer/developer_api.dart',
      );
      expect(violations, isNotEmpty, reason: violations.join('\n'));
      expect(
        violations.every((v) => v.scan == 'developer-audit-boundary'),
        isTrue,
        reason: violations.join('\n'),
      );
    });

    test('probe 2 — trio literal trips regardless of the scan-1 allowlist', () {
      final violations = scanDeveloperAuditBoundary(
        "final p = '/api/v1/audit/events';\n",
        'screens/developer/developer_api.dart',
      );
      expect(violations, isNotEmpty, reason: violations.join('\n'));
      expect(
        violations.every((v) => v.scan == 'developer-audit-boundary'),
        isTrue,
        reason: violations.join('\n'),
      );
    });

    test(
      'probe 3 — bff token trips scan 2 (module inside the guarded tree)',
      () {
        final violations = scanBffLiterals(
          '// bff\n',
          'screens/developer/developer_api.dart',
        );
        expect(violations, isNotEmpty, reason: violations.join('\n'));
        expect(
          violations.every((v) => v.scan == 'bff-literals'),
          isTrue,
          reason: violations.join('\n'),
        );
      },
    );

    test('probe 4 — camelCase letter-adjacent identifier trips; a narrowed '
        'letter-boundary pattern cannot (mutation canary)', () {
      // The negative-boundary net is the whole-substring, case-insensitive
      // `audit` over raw source: a camelCase identifier with the token
      // mid-word (`myAuditLogService`) is inside the contract. A plausible
      // "smart fix" narrowing of `_auditAnyPattern` to a letter boundary —
      // `(?<![A-Za-z])audit` or `audit(?![A-Za-z])` — silently drops exactly
      // this class, and no committed probe carried a letter-adjacent
      // occurrence. This probe is that class: it trips the real scan, and
      // the two narrowed variants are empirically proven below to match
      // nothing here — so if `_scanNegativeBoundary` is ever narrowed to
      // either, THIS assertion goes red and the mutation cannot land green.
      const probe = "final myAuditLogService = _service();\n";
      final violations = scanDeveloperAuditBoundary(
        probe,
        'screens/developer/developer_api.dart',
      );
      expect(violations, isNotEmpty, reason: violations.join('\n'));
      expect(
        violations.every((v) => v.scan == 'developer-audit-boundary'),
        isTrue,
        reason: violations.join('\n'),
      );
      // Empirical proof the narrowing fails: the scan's detection is exactly
      // `_auditAnyPattern.allMatches(source)`, so the regex-level result IS
      // the scan-level result. Both candidate narrowed patterns produce zero
      // matches on the same probe text — under either mutation the probe
      // reds (the assertion above fails), proving the gap is now closed.
      for (final narrowed in <String>[
        r'(?<![A-Za-z])audit',
        r'audit(?![A-Za-z])',
      ]) {
        expect(
          RegExp(narrowed, caseSensitive: false).allMatches(probe),
          isEmpty,
          reason: 'narrowed pattern $narrowed must miss the probe',
        );
      }
    });

    test('portal detail string stays byte-identical through the shared '
        'helper (V1 pin)', () {
      const probe =
          '// portal negative-boundary probe\n'
          "final _probe = 'audit';\n";
      final violations = scanPortalAuditBoundary(
        probe,
        'screens/portal/security_activity_tab.dart',
      );
      expect(violations, hasLength(1));
      expect(
        violations.single.detail,
        'case-insensitive "audit" at line 2; the portal module is the B6-1 '
        'negative boundary \u2014 audit reads belong to '
        'SnaplinkAdminApi via AuditReadClient',
      );
    });
  });

  group('AC-3.6 ring-storage-seam scan (B6-1b)', () {
    test('green against the current tree', () {
      final violations = scanLibDirectory(
        packageLibDir(),
      ).where((violation) => violation.scan == 'ring-storage-seam');
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('a guard dropped from the service source trips', () {
      final source = File(
        '${packageLibDir()}${Platform.pathSeparator}services'
        '${Platform.pathSeparator}audit_log_service.dart',
      ).readAsStringSync();
      final degraded = source.replaceFirst(
        '    if (!kDebugMode) return; // first statements, before the try\n',
        '',
      );
      expect(degraded, isNot(source));
      final violations = scanRingStorageSeam(
        degraded,
        'services/audit_log_service.dart',
      );
      expect(
        violations.where((v) => v.scan == 'ring-storage-seam'),
        isNotEmpty,
        reason: violations.join('\n'),
      );
    });

    test('key literal outside the service file trips; bare LocalStorage. '
        'usage stays green (key-scoped)', () {
      final violations = scanRingStorageSeam(
        "LocalStorage.setItem('sso_audit_log', json);",
        'screens/admin/audit_log_tab.dart',
      );
      expect(
        violations.where((v) => v.scan == 'ring-storage-seam'),
        isNotEmpty,
        reason: violations.join('\n'),
      );
      // Key-scoped: the four legitimate LocalStorage consumers never name
      // the key, so the scan must not flag them (C5).
      expect(
        scanRingStorageSeam(
          'LocalStorage.setItem(settingsKey, json);',
          'app_settings.dart',
        ),
        isEmpty,
      );
    });

    test('F4 anti-vacuity probe — dropped scanLibDirectory registration '
        'cannot go undetected', () {
      // scanLibDirectory must run scan 7 over every file: a degraded
      // temp `services/audit_log_service.dart` (one guard removed) must
      // produce a ring-storage-seam violation through the real loop.
      // The live-tree green test and the drill rows (which exercise
      // `_scanWith`, a separate registration) cannot catch a dropped
      // registration — this probe can.
      final tempDir = Directory.systemTemp.createTempSync('b6_1b_seam_pin_');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });
      final source = File(
        '${packageLibDir()}${Platform.pathSeparator}services'
        '${Platform.pathSeparator}audit_log_service.dart',
      ).readAsStringSync();
      final degraded = source.replaceFirst(
        '    if (!kDebugMode) return; // first statements, before the try\n',
        '',
      );
      expect(degraded, isNot(source));
      final file = File(
        '${tempDir.path}${Platform.pathSeparator}services'
        '${Platform.pathSeparator}audit_log_service.dart',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(degraded);
      final violations = scanLibDirectory(tempDir.path);
      expect(
        violations.where((v) => v.scan == 'ring-storage-seam'),
        isNotEmpty,
        reason:
            'degraded temp service file produced no ring-storage-seam '
            'violations — the scanLibDirectory registration is missing or '
            'broken: ${violations.join('\n')}',
      );
      // Control: the unmutated live source in the same layout stays green.
      file.writeAsStringSync(source);
      final clean = scanLibDirectory(tempDir.path);
      expect(
        clean.where((v) => v.scan == 'ring-storage-seam'),
        isEmpty,
        reason: clean.join('\n'),
      );
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

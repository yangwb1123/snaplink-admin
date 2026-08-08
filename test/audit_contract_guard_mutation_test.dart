/// Mutation drill for the corrected audit contract guard.
///
/// Every target regression from the validation task is planted here
/// against *in-memory copies* of the current `lib/` sources (no file is
/// modified), and the same scan functions the CI guard test runs are
/// asserted to trip on each. The unmutated baseline must stay green —
/// that is the "green against the current tree" half of the contract.
///
/// Regressions that are wire-semantic rather than literal-level (default
/// `{'limit':'100'}` drift, parse-error-no-request) are caught by the
/// behavioral harness group in `test/admin_governance_security_test.dart`;
/// this file documents that they deliberately leave the four scans green
/// and records the enforcement point for each.
///
/// The real-tree variant of the drill (mutating the actual files, running
/// `flutter test`, reverting) is executed as a one-off evidence step and
/// reported in `docs/proposals/b6-1c-guard-mutation-drill.md`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/snaplink_admin_catalog.dart';
import 'package:sso_admin/api/snaplink_admin_types.dart';

import 'audit_contract_guard_scans.dart';

/// Reads a live `lib/` file for mutation.
String _libSource(String relativePath) => File(
  '${packageLibDir()}/${relativePath.replaceAll('/', Platform.pathSeparator)}',
).readAsStringSync();

/// Runs scans 1/2/4/5/6/6b/7 + the ownership pin over a mutated tree
/// assembled from [overrides] (relative path → mutated source) layered
/// over the live `lib/` tree.
List<AuditGuardViolation> _scanWith(
  Map<String, String> overrides, {
  Set<String> scans = const {
    'audit-path-literals',
    'bff-literals',
    'raw-stringification',
    'portal-audit-boundary',
    'developer-audit-boundary',
    'ring-storage-seam',
  },
}) {
  final violations = <AuditGuardViolation>[];
  final sources = <String, String>{};
  final root = Directory(packageLibDir());
  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final relative = entity.path.substring(root.path.length + 1);
    final source = overrides[relative] ?? entity.readAsStringSync();
    sources[relative] = source;
    if (scans.contains('audit-path-literals')) {
      violations.addAll(scanAuditPathLiterals(source, relative));
    }
    if (scans.contains('bff-literals')) {
      violations.addAll(scanBffLiterals(source, relative));
    }
    if (scans.contains('raw-stringification')) {
      violations.addAll(scanRawStringification(source, relative));
    }
    if (scans.contains('second-consumer')) {
      violations.addAll(scanSecondConsumer(source, relative));
    }
    if (scans.contains('portal-audit-boundary')) {
      violations.addAll(scanPortalAuditBoundary(source, relative));
    }
    if (scans.contains('developer-audit-boundary')) {
      violations.addAll(scanDeveloperAuditBoundary(source, relative));
    }
    if (scans.contains('ring-storage-seam')) {
      violations.addAll(scanRingStorageSeam(source, relative));
    }
  }
  if (scans.contains('trio-literal-owner')) {
    violations.addAll(scanTrioLiteralOwnership(sources));
  }
  return violations;
}

void main() {
  group('guard baseline — green against the current tree', () {
    test(
      'all scans pass on the live lib/ tree (incl. scan 5 + ownership pin)',
      () {
        final violations = scanLibDirectory(packageLibDir());
        expect(violations, isEmpty, reason: violations.join('\n'));
        expect(
          scanCatalogTrio(SnaplinkAdminOperationCatalog.endpoints),
          isEmpty,
        );
      },
    );
  });

  group('planted regressions trip the corrected scans', () {
    test(r"F6 skin 1 — literal tenant_id=null via MapEntry(key, '$value')", () {
      final source = _libSource('screens/admin/governance_tab.dart');
      final mutated = source.replaceFirst(
        'final parameters = auditQuery.toQueryParameters();',
        r"final parameters = query.map((key, value) => MapEntry(key, '$value'));",
      );
      expect(mutated, isNot(source));
      final violations = _scanWith({
        'screens/admin/governance_tab.dart': mutated,
      });
      expect(
        violations.where((v) => v.scan == 'raw-stringification'),
        isNotEmpty,
        reason: violations.join('\n'),
      );
    });

    test('F6 skin 2 — Map.from interception', () {
      final source = _libSource('screens/admin/governance_tab.dart');
      final mutated = source.replaceFirst(
        'final parameters = auditQuery.toQueryParameters();',
        'final parameters = Map<String, String>.from(query);',
      );
      final violations = _scanWith({
        'screens/admin/governance_tab.dart': mutated,
      });
      expect(
        violations.where((v) => v.scan == 'raw-stringification'),
        isNotEmpty,
        reason: violations.join('\n'),
      );
    });

    test('F6 skin 3 — .cast interception', () {
      final source = _libSource('screens/admin/governance_tab.dart');
      final mutated = source.replaceFirst(
        'final parameters = auditQuery.toQueryParameters();',
        'final parameters = query.cast<String, String>();',
      );
      final violations = _scanWith({
        'screens/admin/governance_tab.dart': mutated,
      });
      expect(
        violations.where((v) => v.scan == 'raw-stringification'),
        isNotEmpty,
        reason: violations.join('\n'),
      );
    });

    test('F6 skin 4 — .toString interception', () {
      final source = _libSource('screens/admin/governance_tab.dart');
      final mutated = source.replaceFirst(
        'final parameters = auditQuery.toQueryParameters();',
        'final parameters = query.map((key, value) => '
            'MapEntry(key, value.toString()));',
      );
      final violations = _scanWith({
        'screens/admin/governance_tab.dart': mutated,
      });
      expect(
        violations.where((v) => v.scan == 'raw-stringification'),
        isNotEmpty,
        reason: violations.join('\n'),
      );
    });

    test('F6 skin 5 — literal null coercion inside the builder', () {
      final source = _libSource('api/audit_query.dart');
      final mutated = source.replaceFirst(
        "addIfPresent('tenant_id', tenantId);",
        "if (tenantId == null) parameters['tenant_id'] = 'null';",
      );
      expect(mutated, isNot(source));
      final violations = _scanWith({'api/audit_query.dart': mutated});
      expect(
        violations.where((v) => v.scan == 'raw-stringification'),
        isNotEmpty,
        reason: violations.join('\n'),
      );
    });

    test('{id} member — path segment added after the trio member', () {
      final source = _libSource('api/audit_read_client.dart');
      final mutated = source.replaceFirst(
        "static const eventDetailPath = '/api/v1/audit/events/{id}';",
        "static const eventDetailPath = "
            "'/api/v1/audit/events/{id}/details';",
      );
      final violations = _scanWith({'api/audit_read_client.dart': mutated});
      expect(
        violations.where((v) => v.scan == 'audit-path-literals'),
        isNotEmpty,
        reason: violations.join('\n'),
      );
    });

    test('catalog-trio drift — fourth audit path in the routes listing', () {
      final source = _libSource('api/snaplink_admin_types.dart');
      final mutated = source.replaceFirst(
        'GET /api/v1/audit/events/{id}',
        'GET /api/v1/audit/events/{id}\nGET /api/v1/audit/events/{id}/export',
      );
      expect(mutated, isNot(source));
      // Literal level: scan 1's per-line token extraction over the blob.
      final violations = _scanWith({'api/snaplink_admin_types.dart': mutated});
      expect(
        violations.where((v) => v.scan == 'audit-path-literals'),
        isNotEmpty,
        reason: violations.join('\n'),
      );
      // Runtime level: scan 3 against a catalog that mirrors the drift.
      final driftedCatalog = [
        ...SnaplinkAdminOperationCatalog.endpoints,
        const SnaplinkAdminEndpoint(
          method: 'GET',
          path: '/api/v1/audit/events/{id}/export',
          feature: 'documented',
        ),
      ];
      expect(scanCatalogTrio(driftedCatalog), isNotEmpty);
    });

    test('BFF case-variant literal trips the unified scan 2', () {
      final source = _libSource('screens/admin/governance_tab.dart');
      final mutated = source.replaceFirst(
        "import 'package:sso_admin/api/audit_query.dart';",
        r"import 'package:sso_admin/api/audit_query.dart';"
            r"final _bffProbe = '/api/v1/BFF/audit/events';",
      );
      final violations = _scanWith({
        'screens/admin/governance_tab.dart': mutated,
      });
      expect(
        violations.where((v) => v.scan == 'bff-literals'),
        isNotEmpty,
        reason: violations.join('\n'),
      );
    });

    test('second consumer (B6-1a map literal) trips scan 5', () {
      const consumer = r'''
class AuditLogTab {
  Future<void> refresh() async {
    await api.get('/api/v1/audit/events', query: {'limit': '$_limit'});
  }
}
''';
      expect(scanSecondConsumer(consumer, 'audit_log_tab.dart'), isNotEmpty);
    });

    test('second consumer via read-client constant + raw map (E1) trips '
        'scan 5', () {
      const consumer = r'''
class AuditLogTab {
  Future<void> refresh() async {
    await api.get(AuditReadClient.eventsPath, query: {'limit': '100'});
  }
}
''';
      final violations = scanSecondConsumer(
        consumer,
        'screens/admin/future_consumer.dart',
      );
      expect(
        violations.where((v) => v.scan == 'second-consumer'),
        isNotEmpty,
        reason: violations.join('\n'),
      );
    });

    test('unused AuditQuery import does not satisfy scan 5 (E2)', () {
      const consumer = r'''
import 'package:sso_admin/api/audit_query.dart' show AuditQuery;
class AuditLogTab {
  Future<void> refresh() async {
    await api.get(AuditReadClient.eventsPath, query: {'limit': '100'});
  }
}
''';
      final violations = scanSecondConsumer(
        consumer,
        'screens/admin/future_consumer.dart',
      );
      expect(
        violations.where((v) => v.scan == 'second-consumer'),
        isNotEmpty,
        reason: violations.join('\n'),
      );
    });

    test('AuditQuery spread skin trips scan 5 (E6)', () {
      const consumer = r'''
class AuditLogTab {
  Future<void> refresh() async {
    await api.get(AuditReadClient.eventsPath, query: {
      ...AuditQuery(limit: 100).toQueryParameters(),
      'evil': 'x',
    });
  }
}
''';
      final violations = scanSecondConsumer(
        consumer,
        'screens/admin/future_consumer.dart',
      );
      expect(
        violations.where((v) => v.scan == 'second-consumer'),
        isNotEmpty,
        reason: violations.join('\n'),
      );
    });

    test('trio literal re-planted outside the read client trips the '
        'ownership pin', () {
      final source = _libSource('screens/admin/governance_tab.dart');
      final mutated = source.replaceFirst(
        'static const _auditPath = AuditReadClient.eventsPath;',
        "static const _auditPath = '/api/v1/audit/events';",
      );
      expect(mutated, isNot(source));
      final violations = _scanWith(
        {'screens/admin/governance_tab.dart': mutated},
        scans: const {'trio-literal-owner'},
      );
      expect(
        violations.where((v) => v.scan == 'trio-literal-owner'),
        isNotEmpty,
        reason: violations.join('\n'),
      );
    });

    test('trio literal dropped from the read client trips the ownership '
        'pin (non-vacuous)', () {
      final source = _libSource('api/audit_read_client.dart');
      final mutated = source.replaceFirst(
        "static const eventsPath = '/api/v1/audit/events';",
        'static const eventsPath = "placeholder";',
      );
      expect(mutated, isNot(source));
      final violations = _scanWith(
        {'api/audit_read_client.dart': mutated},
        scans: const {'trio-literal-owner'},
      );
      expect(
        violations.where((v) => v.scan == 'trio-literal-owner'),
        isNotEmpty,
        reason: violations.join('\n'),
      );
    });

    group('B6-1 scan 6 — portal negative boundary fails closed', () {
      // The three skins against `screens/portal/security_activity_tab.dart`
      // (in-memory overrides via `_libSource` + `_scanWith`; no file is
      // touched). Each probe asserts `mutated != source` (so the anchor is
      // still live) and that the `portal-audit-boundary` scan trips through
      // the `_scanWith` dispatch.
      test('skin A — AuditReadClient import + usage in the portal tab', () {
        final source = _libSource('screens/portal/security_activity_tab.dart');
        final mutated = source.replaceFirst(
          "import 'package:sso_admin/i18n/app_strings.dart';",
          "import 'package:sso_admin/i18n/app_strings.dart';\n"
              "import 'package:sso_admin/api/audit_read_client.dart';\n"
              'final _probe = AuditReadClient(null).list();',
        );
        expect(mutated, isNot(source));
        final violations = _scanWith({
          'screens/portal/security_activity_tab.dart': mutated,
        });
        expect(
          violations.where((v) => v.scan == 'portal-audit-boundary'),
          isNotEmpty,
          reason: violations.join('\n'),
        );
      });

      test(
        'skin B — securityActivity argument replaced by an audit literal',
        () {
          final source = _libSource(
            'screens/portal/security_activity_tab.dart',
          );
          final mutated = source.replaceFirst(
            'PortalSecurityPaths.securityActivity',
            "'/api/v1/audit/events'",
          );
          expect(mutated, isNot(source));
          final violations = _scanWith({
            'screens/portal/security_activity_tab.dart': mutated,
          });
          expect(
            violations.where((v) => v.scan == 'portal-audit-boundary'),
            isNotEmpty,
            reason: violations.join('\n'),
          );
        },
      );

      test('skin C — doc comment containing audit appended', () {
        final source = _libSource('screens/portal/security_activity_tab.dart');
        final mutated = '$source\n/// audit probe comment\n';
        expect(mutated, isNot(source));
        final violations = _scanWith({
          'screens/portal/security_activity_tab.dart': mutated,
        });
        expect(
          violations.where((v) => v.scan == 'portal-audit-boundary'),
          isNotEmpty,
          reason: violations.join('\n'),
        );
      });
    });

    group('B6-1 scan 6 — developer negative boundary fails closed', () {
      // The three skins against `screens/developer/developer_api.dart`
      // (in-memory overrides via `_libSource` + `_scanWith`; no file is
      // touched). Each probe asserts `mutated != source` (so the anchor is
      // still live) and that the `developer-audit-boundary` scan trips
      // through the `_scanWith` dispatch.
      test('skin A — AuditReadClient import + usage in developer_api', () {
        final source = _libSource('screens/developer/developer_api.dart');
        final mutated = source.replaceFirst(
          "import 'package:http/http.dart' as http;",
          "import 'package:http/http.dart' as http;\n"
              "import 'package:sso_admin/api/audit_read_client.dart';\n"
              'final _probe = AuditReadClient(null).list();',
        );
        expect(mutated, isNot(source));
        final violations = _scanWith({
          'screens/developer/developer_api.dart': mutated,
        });
        expect(
          violations.where((v) => v.scan == 'developer-audit-boundary'),
          isNotEmpty,
          reason: violations.join('\n'),
        );
      });

      test('skin B — DCR register POST repointed at the audit bare prefix', () {
        final source = _libSource('screens/developer/developer_api.dart');
        final mutated = source.replaceFirst("'/register'", "'/api/v1/audit'");
        expect(mutated, isNot(source));
        final violations = _scanWith({
          'screens/developer/developer_api.dart': mutated,
        });
        expect(
          violations.where((v) => v.scan == 'developer-audit-boundary'),
          isNotEmpty,
          reason: violations.join('\n'),
        );
      });

      test('skin C — doc comment containing audit appended', () {
        final source = _libSource('screens/developer/developer_api.dart');
        final mutated = '$source\n/// audit probe comment\n';
        expect(mutated, isNot(source));
        final violations = _scanWith({
          'screens/developer/developer_api.dart': mutated,
        });
        expect(
          violations.where((v) => v.scan == 'developer-audit-boundary'),
          isNotEmpty,
          reason: violations.join('\n'),
        );
      });
    });
  });

  group('B6-1b scan 7 — ring-storage-seam fails closed (rows a–i)', () {
    // Anchors are the §1.1-verbatim spellings, trailing guard comments
    // included (F3): if the implementation drops a trailing comment, the
    // anchor-rot guard (`expect(mutated, isNot(source))`) fails the row
    // loudly and both are updated together.
    String serviceSource() => _libSource('services/audit_log_service.dart');
    Iterable<AuditGuardViolation> seamViolations(
      Map<String, String> overrides,
    ) => _scanWith(
      overrides,
      scans: const {'ring-storage-seam'},
    ).where((v) => v.scan == 'ring-storage-seam');

    test('row (a) — _save guard pair deleted trips', () {
      final source = serviceSource();
      final mutated = source.replaceFirst(
        'if (!kDebugMode) return; // first statements, before the try\n'
            '    if (!_storageEnabled) return;',
        '',
      );
      expect(mutated, isNot(source));
      final violations = seamViolations({
        'services/audit_log_service.dart': mutated,
      });
      expect(violations, isNotEmpty, reason: violations.join('\n'));
    });

    test('row (b) — assert(kDebugMode) substitution trips', () {
      final source = serviceSource();
      final mutated = source.replaceFirst(
        'if (!kDebugMode) return; // first statements, before the try\n'
            '    if (!_storageEnabled) return;',
        'assert(kDebugMode);\n    if (!_storageEnabled) return;',
      );
      expect(mutated, isNot(source));
      final violations = seamViolations({
        'services/audit_log_service.dart': mutated,
      });
      expect(violations, isNotEmpty, reason: violations.join('\n'));
    });

    test('row (c) — setItem hoisted into record() trips', () {
      final source = serviceSource();
      final mutated = source.replaceFirst(
        '    _save();\n  }',
        '    LocalStorage.setItem(_storageKey, '
            'jsonEncode(_entries.map((e) => e.toJson()).toList()));\n  }',
      );
      expect(mutated, isNot(source));
      final violations = seamViolations({
        'services/audit_log_service.dart': mutated,
      });
      expect(violations, isNotEmpty, reason: violations.join('\n'));
    });

    test('row (d) — bool.fromEnvironment second axis trips', () {
      final source = serviceSource();
      final mutated = source.replaceFirst(
        'static bool _storageEnabled = kDebugMode;',
        "static bool _storageEnabled = kDebugMode || "
            "bool.fromEnvironment('ringStorage');",
      );
      expect(mutated, isNot(source));
      final violations = seamViolations({
        'services/audit_log_service.dart': mutated,
      });
      expect(violations, isNotEmpty, reason: violations.join('\n'));
    });

    test('row (e) — storage setter guard deleted trips', () {
      final source = serviceSource();
      final mutated = source.replaceFirst(
        '  static set debugStorageEnabled(bool value) {\n'
            '    if (!kDebugMode) return;',
        '  static set debugStorageEnabled(bool value) {',
      );
      expect(mutated, isNot(source));
      final violations = seamViolations({
        'services/audit_log_service.dart': mutated,
      });
      expect(violations, isNotEmpty, reason: violations.join('\n'));
    });

    test('row (f) — non-foldable initializer trips', () {
      final source = serviceSource();
      final mutated = source.replaceFirst(
        'static bool _storageEnabled = kDebugMode;',
        'static bool _storageEnabled = true;',
      );
      expect(mutated, isNot(source));
      final violations = seamViolations({
        'services/audit_log_service.dart': mutated,
      });
      expect(violations, isNotEmpty, reason: violations.join('\n'));
    });

    test(
      'row (g) — key literal injected into lib/api trips (non-writer pin)',
      () {
        final source = _libSource('api/snaplink_admin_api.dart');
        final mutated = source.replaceFirst(
          'AuditLogService().record(',
          'AuditLogService().record( /* sso_audit_log */ ',
        );
        expect(mutated, isNot(source));
        final violations = seamViolations({
          'api/snaplink_admin_api.dart': mutated,
        });
        expect(violations, isNotEmpty, reason: violations.join('\n'));
      },
    );

    test('row (h) — String.fromCharCodes key reconstruction trips', () {
      final source = serviceSource();
      final mutated = source.replaceFirst(
        "static const String _storageKey = 'sso_audit_log';",
        'static const String _storageKey = '
            'String.fromCharCodes([115,115,111,95,97,117,100,105,116,95,108,111,103]);',
      );
      expect(mutated, isNot(source));
      final violations = seamViolations({
        'services/audit_log_service.dart': mutated,
      });
      expect(violations, isNotEmpty, reason: violations.join('\n'));
    });

    test('row (i) — F16 payload echo reintroduced trips', () {
      final source = serviceSource();
      final mutated = source.replaceFirst(
        r"debugPrint('audit_log storage error: ${e.runtimeType}');",
        r"debugPrint('audit_log storage error: $e');",
      );
      expect(mutated, isNot(source));
      final violations = seamViolations({
        'services/audit_log_service.dart': mutated,
      });
      expect(violations, isNotEmpty, reason: violations.join('\n'));
    });
  });

  group('wire-semantic regressions — scan-caught (pins) and harness-caught', () {
    test(
      'default {"limit": 100} drift trips scan 4 (default-text pin) and the AC-2 harness',
      () {
        // The needle is derived from the live file so the drill works whether
        // the tree currently carries the design default (100) or a planted
        // drift.
        final source = _libSource('screens/admin/governance_tab.dart');
        final match = RegExp(r"""\{"limit": \d+\}""").firstMatch(source);
        expect(match, isNotNull, reason: 'default limit text present');
        final current = match!.group(0)!;
        final drifted = current.replaceFirst(RegExp(r'\d+'), '999');
        final mutated = source.replaceFirst(current, drifted);
        expect(mutated, isNot(source));
        final violations = _scanWith({
          'screens/admin/governance_tab.dart': mutated,
        });
        expect(
          violations.where((v) => v.scan == 'raw-stringification'),
          isNotEmpty,
          reason: violations.join('\n'),
        );
        // Enforcement point 2: AC-2 group in admin_governance_security_test.dart
        // (recorded queryParameters must equal {'limit': '100'} exactly).
      },
    );

    test(
      'parse-error-no-request (weakened fromJson) trips scan 4 (parse-surface pin) and the AC-2 harness',
      () {
        final source = _libSource('api/audit_query.dart');
        // Structurally remove the unknown-key throw statement, anchored on its
        // message (in-memory only; the drill text never needs to compile).
        final msgIdx = source.indexOf('Audit query: unsupported key');
        expect(msgIdx, greaterThanOrEqualTo(0));
        final throwIdx = source.lastIndexOf(
          'throw AuditQueryParseException(',
          msgIdx,
        );
        expect(throwIdx, greaterThanOrEqualTo(0));
        final end = source.indexOf(');', msgIdx);
        expect(end, greaterThan(msgIdx));
        final mutated = source.replaceRange(throwIdx, end + 2, 'continue;');
        expect(mutated, isNot(source));
        final violations = _scanWith({'api/audit_query.dart': mutated});
        expect(
          violations.where((v) => v.scan == 'raw-stringification'),
          isNotEmpty,
          reason: violations.join('\n'),
        );
        // Enforcement point 2: AC-2 parse-error test (banner + zero requests).
      },
    );
  });

  group('documented residual escape routes (accepted, with backstops)', () {
    test('{id} encodeComponent drop evades scan 1 via constant indirection; '
        'detail-read harness backstop', () {
      // Post-ownership-pin the detail path is assembled from the read
      // client's constant, so dropping Uri.encodeComponent leaves no
      // inline audit token for the literal scans to see. Accepted as
      // active circumvention; backstop: audit_read_client_test pins the
      // encoded wire (`eventsPath/a%2Fb`) and
      // admin_live_events_detail_read_test pins `ev%201%2F2`.
      final source = _libSource('api/audit_read_client.dart');
      final mutated = source.replaceFirst(
        r"'$eventsPath/${Uri.encodeComponent(id)}'",
        r"'$eventsPath/$id'",
      );
      expect(mutated, isNot(source));
      final violations = _scanWith({'api/audit_read_client.dart': mutated});
      expect(
        violations.where((v) => v.scan == 'audit-path-literals'),
        isEmpty,
        reason: violations.join('\n'),
      );
    });

    test(
      'bare /api/v1/audit call evades scan 1; harness no-other-path backstop',
      () {
        final source = _libSource('screens/admin/governance_tab.dart');
        final mutated = source.replaceFirst(
          'widget.api.get(_auditPath, query: parameters);',
          "widget.api.get('/api/v1/audit', query: parameters);",
        );
        expect(mutated, isNot(source));
        final violations = _scanWith({
          'screens/admin/governance_tab.dart': mutated,
        });
        expect(
          violations.where((v) => v.scan == 'audit-path-literals'),
          isEmpty,
          reason: violations.join('\n'),
        );
        // Backstop: AC-2 "no request to any other path" assertion.
      },
    );

    test(
      'adjacent-literal split "/api/v1/audit" + "/events" evades scan 1',
      () {
        final source = _libSource('api/audit_read_client.dart');
        final mutated = source.replaceFirst(
          "static const eventDetailPath = '/api/v1/audit/events/{id}';",
          r"static const eventDetailPath = '/api/v1/audit' "
              r"'/events/{id}';",
        );
        expect(mutated, isNot(source));
        final violations = _scanWith({'api/audit_read_client.dart': mutated});
        expect(
          violations.where((v) => v.scan == 'audit-path-literals'),
          isEmpty,
          reason: violations.join('\n'),
        );
        // Note: the mirror split "/api/v1/audit/" + "events" DOES trip
        // (trailing slash is neither bare nor a trio member).
      },
    );

    test('segment assembly via a prefix variable evades scan 1', () {
      final source = _libSource('api/audit_read_client.dart');
      final mutated = source.replaceFirst(
        "static const eventsPath = '/api/v1/audit/events';",
        "static const _auditPrefix = '/api/v1/audit';\n"
            "  static const eventsPath = '\$_auditPrefix/events';",
      );
      final violations = _scanWith({'api/audit_read_client.dart': mutated});
      expect(
        violations.where((v) => v.scan == 'audit-path-literals'),
        isEmpty,
        reason: violations.join('\n'),
      );
      // The mirror form '$base/api/v1/audit/events' trips loudly (safe
      // direction) because the literal still contains the full token.
    });

    test('case-variant path literal evades scan 1 (behavioral backstop)', () {
      final source = _libSource('screens/admin/governance_tab.dart');
      final mutated = source.replaceFirst(
        'widget.api.get(_auditPath, query: parameters);',
        "widget.api.get('/API/V1/audit/events', query: parameters);",
      );
      final violations = _scanWith({
        'screens/admin/governance_tab.dart': mutated,
      });
      expect(
        violations.where((v) => v.scan == 'audit-path-literals'),
        isEmpty,
        reason: violations.join('\n'),
      );
      // Backstop: AC-2 no-other-path assertion uses exact trio membership.
    });

    test('bff via concatenation evades scan 2', () {
      final source = _libSource('screens/admin/governance_tab.dart');
      final mutated = source.replaceFirst(
        "import 'package:sso_admin/api/audit_query.dart';",
        r"import 'package:sso_admin/api/audit_query.dart';"
            r"final _probe = '/api/v1/' 'b' 'ff/audit';",
      );
      final violations = _scanWith({
        'screens/admin/governance_tab.dart': mutated,
      });
      expect(
        violations.where((v) => v.scan == 'bff-literals'),
        isEmpty,
        reason: violations.join('\n'),
      );
      // Residual: the concatenated spelling defeats both the guard and the
      // step-7 grep; accepted as active circumvention.
    });

    test('B6-1b residual — adjacent-literal key split at the call site '
        'evades scan 7; artifact gate is the backstop', () {
      // The genuine evasion: the pinned `_storageKey` const stays intact
      // (keyHits stays 1, unused decoy — DCE'd), while the real I/O uses
      // `'sso_' 'audit_log'` (no single literal carries the pin). Scan 7
      // stays green at source level; the concatenated constant still
      // lands the full string in the release bundle, so
      // `make release-artifact-check` (the key literal + its
      // base64/base64Url masks == 0 in build/web/) is the backstop.
      // Deliberate reintroduction is a manual-review matter, not a gate
      // one (seam design §1.4 residual).
      final source = _libSource('services/audit_log_service.dart');
      final mutated = source.replaceFirst(
        'LocalStorage.setItem(_storageKey, jsonStr);',
        r"LocalStorage.setItem('sso_' 'audit_log', jsonStr);",
      );
      expect(mutated, isNot(source));
      final violations = _scanWith(
        {'services/audit_log_service.dart': mutated},
        scans: const {'ring-storage-seam'},
      );
      expect(
        violations.where((v) => v.scan == 'ring-storage-seam'),
        isEmpty,
        reason: violations.join('\n'),
      );
      // Backstop note: artifact needle `sso_audit_log` + masks == 0 in
      // build/web/ (Makefile release-artifact-check).
    });

    test('B6-1b boundary — IO swap between the gated functions trips the '
        'ordering pin (corrected F1 pins close the seam-design F6 class)', () {
      // Seam design §1.4 records F6 as a documented boundary: "swapping
      // the IO calls between the two gated functions is scan-6-green and
      // release-safe". That note predates the F1 correction — the
      // per-function ordering pin (4 guards before setItem, 6 before
      // getItem) trips the genuine swap: `_save` reads (getItem after 4
      // guards) and `_load` writes (setItem after 6 guards), so both
      // orderings are violated. The class is therefore scan-7-caught,
      // stronger than the design records; the flag-on write-path
      // behavior tests (R4.1-R4.4) remain the semantic backstop.
      final source = _libSource('services/audit_log_service.dart');
      final mutated = source
          .replaceFirst(
            'final jsonStr = jsonEncode(_entries.map((e) => e.toJson()).toList());\n'
                '      LocalStorage.setItem(_storageKey, jsonStr);',
            'final jsonStr = LocalStorage.getItem(_storageKey);',
          )
          .replaceFirst(
            'final jsonStr = LocalStorage.getItem(_storageKey);\n'
                '      if (jsonStr != null && jsonStr.isNotEmpty) {',
            'final jsonStr = jsonEncode(_entries.map((e) => e.toJson()).toList());\n'
                '      LocalStorage.setItem(_storageKey, jsonStr);\n'
                '      if (jsonStr != null && jsonStr.isNotEmpty) {',
          );
      expect(mutated, isNot(source));
      expect(mutated.contains('LocalStorage.setItem'), isTrue);
      expect(mutated.contains('LocalStorage.getItem'), isTrue);
      final violations = _scanWith(
        {'services/audit_log_service.dart': mutated},
        scans: const {'ring-storage-seam'},
      );
      expect(
        violations.where((v) => v.scan == 'ring-storage-seam'),
        isNotEmpty,
        reason: violations.join('\n'),
      );
    });
  });
}

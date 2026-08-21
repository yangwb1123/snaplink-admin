@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// B6-2 attribution census (task-1 design, REQ-1): the developer edge
/// (`lib/screens/developer`) is the DCR-only no-auth path — it must never
/// fabricate a login emission string, never construct the console login
/// route, and never put a client-id key into a login payload.
///
/// Three directory-driven clauses (REQ-4 #5 mirror; design AC-1..AC-3):
///  * Clause A — zero emission strings, module-wide (the string is
///    server-owned; `edge_generation_portal_negative_test.dart` pins it
///    over all of `lib/`, this pins the developer module);
///  * Clause B — zero login-route path construction, module-wide
///    (substring needle equal to the standing portal census grep
///    `auth/`+`login`, so a `../`-relative construction is caught too;
///    the portal sibling pins the same needle over `lib/screens/portal`);
///  * Clause C — zero login-payload client-id keys, implemented as an
///    exact quoted-literal site pin equal to the 5 verified DCR-wire
///    lines (register_panel 107/117, dcr_credentials 185, manage_panel
///    55, dcr_models 67) plus a liveness test so the pin cannot be
///    eviscerated.
///
/// Factoring (audit_contract_guard_test.dart:57-97 precedent): the three
/// clause predicates below are the single implementation — the green runs
/// reach them through [offendersFor], the synthetic probes call them
/// directly with canonical-literal payloads (never via the needle
/// constants, so a mutated needle cannot pass vacuously), and the
/// F2-style wiring pin drives them through [offendersFor] on a throwaway
/// tree. A "fails on any" clause is therefore executable and cannot drift
/// from the green path.
///
/// Hygiene: every needle and probe payload is literal-split (adjacent
/// literals), so this file carries no contiguous banned token anywhere —
/// test names, comments, failure reasons, and probe payloads included
/// (the `developer_audit_visibility_guard_test.dart` convention; the
/// live `test/` literal census stays green).
///
/// Grep forms for CI / joint gate (must stay exit 1; adjacent shell quotes
/// concatenate, so each command below is copy-pasteable as-is):
///   grep -rn "auth\.login\.""success" lib/screens/developer/
///   grep -rn "auth/""login" lib/screens/developer/
///   grep -rn "'client_"''"id'" lib/screens/developer/
void main() {
  const moduleDir = 'lib/screens/developer';
  const emissionNeedle =
      'auth.login.'
      'success';
  const loginPathNeedle =
      'auth/'
      'login';
  const clientIdNeedle =
      "'client_"
      "id'";

  bool clauseAEmissionString(String source) => source.contains(emissionNeedle);

  bool clauseBLoginPath(String source) => source.contains(loginPathNeedle);

  bool clauseCClientIdKey(String source) => source.contains(clientIdNeedle);

  /// Files under [dir] whose content trips [predicate]. Shared by the
  /// green runs (real module) and the wiring pin (throwaway tree).
  List<String> offendersFor(String dir, bool Function(String) predicate) {
    final offenders = <String>[];
    for (final entity in Directory(dir).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (predicate(File(entity.path).readAsStringSync())) {
        offenders.add(entity.path);
      }
    }
    return offenders;
  }

  group('directory-driven green runs over $moduleDir', () {
    test('scan coverage — the module holds exactly 13 .dart files', () {
      final files = [
        for (final entity in Directory(moduleDir).listSync(recursive: true))
          if (entity is File && entity.path.endsWith('.dart')) entity.path,
      ];
      expect(
        files.length,
        13,
        reason:
            'coverage pin — a module-level rename, an emptied '
            'directory, or an unlisted new file fails here, never '
            'silently (found ${files.length})',
      );
    });

    test('Clause A — zero emission strings (REQ-4 #5 mirror)', () {
      expect(
        offendersFor(moduleDir, clauseAEmissionString),
        isEmpty,
        reason:
            'the developer edge must never fabricate the '
            'auth.login.'
            'success emission string — it is generated '
            'server-side only (AC-1)',
      );
    });

    test('Clause B — zero login-route construction', () {
      expect(
        offendersFor(moduleDir, clauseBLoginPath),
        isEmpty,
        reason:
            'the developer edge builds no auth/'
            'login route — '
            'DCR-only wire via /register (AC-2)',
      );
    });

    test('Clause C — the 5 DCR-wire key sites, exactly '
        '(quoted-literal site pin)', () {
      const pinned = <String, List<int>>{
        'lib/screens/developer/register_panel.dart': [107, 125],
        'lib/screens/developer/dcr_credentials.dart': [183],
        'lib/screens/developer/manage_panel.dart': [57],
        'lib/screens/developer/dcr_models.dart': [67],
      };
      final actual = <String, List<int>>{};
      for (final entity in Directory(moduleDir).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = File(entity.path).readAsStringSync().split('\n');
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains(clientIdNeedle)) {
            actual.putIfAbsent(entity.path, () => []).add(i + 1);
          }
        }
      }
      expect(
        actual,
        pinned,
        reason:
            "the quoted 'client_"
            "id' literal must appear at "
            'exactly the 5 verified DCR-wire sites — a new login-payload '
            'key, a relocation, or a deletion fails here (AC-3)',
      );
      // Liveness: the pin cannot be eviscerated — every pinned line must
      // still carry the literal on disk, and the site count must stay 5.
      var totalSites = 0;
      for (final entry in pinned.entries) {
        totalSites += entry.value.length;
        final lines = File(entry.key).readAsStringSync().split('\n');
        for (final ln in entry.value) {
          expect(
            lines[ln - 1].contains(clientIdNeedle),
            isTrue,
            reason: '${entry.key}:$ln lost the pinned literal',
          );
        }
      }
      expect(
        totalSites,
        5,
        reason:
            'site pin must hold exactly 5 lines — an eviscerated '
            'pin passes nothing',
      );
    });
  });

  group('synthetic probes — each clause fails on any offender '
      '(shared implementation, canonical-literal payloads)', () {
    test('Clause A probe — a fabricated emission string trips', () {
      expect(
        clauseAEmissionString(
          'auth.login.'
          'success',
        ),
        isTrue,
      );
      expect(
        clauseAEmissionString(
          'auth.login.'
          'ok',
        ),
        isFalse,
      );
    });

    test('Clause B probe — a ../-relative route construction trips', () {
      expect(
        clauseBLoginPath(
          '../'
          'auth/'
          'login',
        ),
        isTrue,
      );
      expect(clauseBLoginPath('/me/security/activity'), isFalse);
    });

    test('Clause C probe — a quoted key in a payload trips', () {
      final payload =
          "result['client_"
          "id']";
      expect(clauseCClientIdKey(payload), isTrue);
      expect(clauseCClientIdKey('result[clientId]'), isFalse);
      expect(clauseCClientIdKey('result.clientId'), isFalse);
    });
  });

  test('wiring pin — the directory walk wires all three clauses '
      '(F2 style)', () {
    final tempDir = Directory.systemTemp.createTempSync('b6_2_census_pin_');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    void writeProbe(String name, String body) {
      File(
        '${tempDir.path}${Platform.pathSeparator}$name',
      ).writeAsStringSync(body);
    }

    final clauses = <String, bool Function(String)>{
      'Clause A (emission)': clauseAEmissionString,
      'Clause B (login route)': clauseBLoginPath,
      'Clause C (quoted key)': clauseCClientIdKey,
    };
    // Dirty tree — one canonical-literal probe file per clause, built
    // from the same split pieces the green runs use.
    writeProbe(
      '_probe_a.dart',
      "final s = '"
          'auth.login.'
          'success'
          "';\n",
    );
    writeProbe(
      '_probe_b.dart',
      "final p = '../"
          'auth/'
          'login'
          "';\n",
    );
    writeProbe(
      '_probe_c.dart',
      "final k = "
          "'client_"
          "id'"
          ";\n",
    );
    for (final entry in clauses.entries) {
      expect(
        offendersFor(tempDir.path, entry.value),
        isNotEmpty,
        reason:
            'dirty probe tree produced no ${entry.key} offenders — '
            'the directory-walk wiring for this clause is missing or '
            'broken',
      );
    }
    // Control: neutralize every probe; all clauses must stay clean, so the
    // pin cannot be satisfied by paths/layout alone (over-flagging).
    writeProbe('_probe_a.dart', "final s = 'ok';\n");
    writeProbe('_probe_b.dart', "final p = '/me/security/activity';\n");
    writeProbe('_probe_c.dart', 'final k = 1;\n');
    for (final entry in clauses.entries) {
      expect(
        offendersFor(tempDir.path, entry.value),
        isEmpty,
        reason:
            'clean probe tree still trips ${entry.key} — '
            'over-flagging',
      );
    }
  });
}

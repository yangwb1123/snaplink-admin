/// Shared implementation of the repo-wide audit contract guard (AC-3).
///
/// Lives under `test/` (not `lib/`) deliberately: the scans inspect `lib/`
/// sources, and the guard itself must not introduce literals that the scans
/// would flag (e.g. a `bff` token, or an audit path literal).
///
/// The scans implement the corrected audit contract guard (review §4 of
/// `docs/proposals/b6-1c-audit-contract-guard-review.md`, plus the B6-1
/// portal boundary):
///   1. audit-path literal scan — per-line path-token extraction inside
///      triple-quoted literals (the `routes` blob at
///      `snaplink_admin_types.dart`), `${Uri.encodeComponent(<ident>)}` →
///      `{id}` normalization, bare `/api/v1/audit` prefix anchor;
///   2. BFF scan — unified, case-insensitive, whole-file semantics equal to
///      `grep -rni "bff" lib/`;
///   3. catalog trio scan — runtime-derived from
///      [SnaplinkAdminOperationCatalog], sharing the scan-1 normalizer;
///   4. raw-stringification scan — lib-wide, whitespace-tolerant absence of
///      `MapEntry(key, '$value')`, plus positive pins on the `AuditQuery`
///      wiring (import + `fromJson` + `toQueryParameters` in
///      `governance_tab.dart`), the default `'{"limit": 100}'` field text,
///      the parse-error surface in `audit_query.dart`, and a ban on
///      `'null'` string literals inside `audit_query.dart` (the F6
///      literal-`tenant_id=null` regression);
///   5. second-consumer land-check (B6-1a) — files querying the audit trio
///      must construct parameters via `AuditQuery.toQueryParameters()` and
///      reference `AuditReadClient` (no hand-built maps, no spread skins);
///   6. portal negative-boundary scan (B6-1) — zero case-insensitive
///      `audit` occurrences (identifiers, comments, literals) anywhere in
///      `lib/screens/portal/`; the audit timeline read belongs to
///      `SnaplinkAdminApi` via `AuditReadClient`, never the portal client;
///   6b. developer negative-boundary scan (B6-1) — zero case-insensitive
///      `audit` occurrences anywhere in `lib/screens/developer/`; DCR
///      reads/writes belong to DeveloperApi's /register surface, audit
///      reads belong to SnaplinkAdminApi via AuditReadClient;
///   7. ring-storage-seam source guard (B6-1b) — key-scoped pins on
///      `services/audit_log_service.dart` (kDebugMode == 6, direct guards
///      == 4, storage initializer, guard-before-IO ordering, adjacency and
///      function-head pairs, `LocalStorage.` == 2, key literal == 1, bans)
///      plus a lib-wide non-service branch: any `sso_audit_log` literal
///      outside the service file trips (lib/api and lib/screens can never
///      own the key).
library;

import 'dart:io';

import 'package:sso_admin/api/snaplink_admin_types.dart';
part 'audit_contract_guard_scans_catalog.dart';
part 'audit_contract_guard_scans_boundaries.dart';
part 'audit_contract_guard_scans_stringification.dart';

/// One guard violation: which scan found it, in which file, and why.
class AuditGuardViolation {
  /// Scan id: `audit-path-literals`, `bff-literals`, `catalog-trio`,
  /// `raw-stringification`, `second-consumer`, `trio-literal-owner`,
  /// `portal-audit-boundary`, `developer-audit-boundary`, or
  /// `ring-storage-seam`.
  final String scan;

  /// File label (relative to the scanned `lib/` root) or catalog name.
  final String file;

  final String detail;

  const AuditGuardViolation({
    required this.scan,
    required this.file,
    required this.detail,
  });

  @override
  String toString() => '[$scan] $file: $detail';
}

/// The documented audit trio (E11 baseline; `snaplink_admin_types.dart`
/// `routes` listing).
const auditTrio = <String>{
  '/api/v1/audit/events',
  '/api/v1/audit/facets',
  '/api/v1/audit/events/{id}',
};

/// Bare prefix token allowed as the admin-operations grouping anchor
/// (`endpoint.path.startsWith('/api/v1/audit')` at
/// `admin_operations_tab.dart`); it is not a callable path. Anchoring the
/// bare token instead of the exact expression makes the allowlist
/// formatting-insensitive.
const auditBarePrefix = '/api/v1/audit';

/// Shared `{id}` normalizer — used by scan 1 (literals) and scan 3
/// (catalog) so the two cannot drift from each other.
///
/// Only two normalizations exist, both grounded in the codebase idiom:
///  * `:id` / `{id}` → `{id}`;
///  * `${Uri.encodeComponent(<ident>)}` → `{id}` (`admin_live_events_tab.dart`).
/// Anything else interpolated is a genuinely new segment and must trip.
String normalizeAuditPathToken(String token) {
  final encodedId = RegExp(
    r'^/api/v1/audit/events/\$\{Uri\.encodeComponent\([A-Za-z_][A-Za-z0-9_]*\)\}$',
  );
  if (encodedId.hasMatch(token)) return '/api/v1/audit/events/{id}';
  return token.replaceAll(':id', '{id}');
}

/// Runs scans 1, 2, 4, 5, 6 (portal boundary), 6b (developer boundary),
/// and 7 (ring-storage-seam) plus the trio-literal ownership pin over
/// every `.dart` file under [libDirPath]. Scan 3 is runtime-derived and
/// must be invoked with the catalog endpoints separately (see
/// [scanCatalogTrio]).
List<AuditGuardViolation> scanLibDirectory(String libDirPath) {
  final root = Directory(libDirPath);
  if (!root.existsSync()) {
    throw ArgumentError('lib directory not found: $libDirPath');
  }
  final violations = <AuditGuardViolation>[];
  final sources = <String, String>{};
  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final relative = entity.path.substring(root.path.length + 1);
    final source = entity.readAsStringSync();
    sources[relative] = source;
    violations.addAll(scanAuditPathLiterals(source, relative));
    violations.addAll(scanBffLiterals(source, relative));
    violations.addAll(scanRawStringification(source, relative));
    violations.addAll(scanSecondConsumer(source, relative));
    violations.addAll(scanPortalAuditBoundary(source, relative));
    violations.addAll(scanDeveloperAuditBoundary(source, relative));
    violations.addAll(scanRingStorageSeam(source, relative));
  }
  violations.addAll(scanTrioLiteralOwnership(sources));
  return violations;
}

/// Resolves the package `lib/` directory for `flutter test` runs (cwd is
/// the package root).
String packageLibDir() =>
    '${Directory.current.path}${Platform.pathSeparator}lib';

/// Scan 1 — audit-path literal allowlist.
///
/// String literals (both quote styles, single- and multi-line) are
/// tokenized with comments skipped. Triple-quoted literals are processed
/// per line (`/api/v1/audit[^\s'"]*` tokens per line) so the `routes` blob
/// at `snaplink_admin_types.dart` yields its individual path tokens instead
/// of one giant match; scan 3 still owns the runtime catalog. Single-line
/// literals are checked whole (a literal is either an exact path or a
/// deliberate inventory change).
List<AuditGuardViolation> scanAuditPathLiterals(
  String source,
  String fileLabel,
) {
  final violations = <AuditGuardViolation>[];
  final seen = <String>{};
  for (final literal in _stringLiterals(source)) {
    if (literal.triple) {
      for (final line in literal.content.split('\n')) {
        for (final match in _auditTokenPattern.allMatches(line)) {
          _checkAuditToken(match.group(0)!, fileLabel, violations, seen);
        }
      }
      continue;
    }
    if (literal.content.contains('api/v1/audit')) {
      _checkAuditToken(literal.content, fileLabel, violations, seen);
    }
  }
  return violations;
}

final _auditTokenPattern = RegExp(r"""/api/v1/audit[^\s'"]*""");

void _checkAuditToken(
  String token,
  String fileLabel,
  List<AuditGuardViolation> violations,
  Set<String> seen,
) {
  final normalized = normalizeAuditPathToken(token);
  if (auditTrio.contains(normalized) || normalized == auditBarePrefix) {
    return;
  }
  if (seen.add('$fileLabel:$token')) {
    violations.add(
      AuditGuardViolation(
        scan: 'audit-path-literals',
        file: fileLabel,
        detail:
            'unexpected audit path token "$token" (normalizes to '
            '"$normalized"); allowlist is $auditTrio or the bare '
            '$auditBarePrefix grouping anchor',
      ),
    );
  }
}

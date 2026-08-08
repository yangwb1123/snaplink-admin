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

/// Scan 2 — BFF literal scan, unified semantics.
///
/// Case-insensitive `bff` substring over the whole file text — the exact
/// Dart-native equivalent of the migration `grep -rni "bff" lib/` step, so
/// the two mechanisms cannot disagree (a case-variant literal, an
/// identifier, or a comment all trip identically).
List<AuditGuardViolation> scanBffLiterals(String source, String fileLabel) {
  final violations = <AuditGuardViolation>[];
  final lower = source.toLowerCase();
  var index = 0;
  while (true) {
    final hit = lower.indexOf('bff', index);
    if (hit < 0) break;
    final start = hit > 16 ? hit - 16 : 0;
    final end = hit + 16 < source.length ? hit + 16 : source.length;
    violations.add(
      AuditGuardViolation(
        scan: 'bff-literals',
        file: fileLabel,
        detail:
            'bff token near "...${source.substring(start, end).replaceAll('\n', ' ')}..."',
      ),
    );
    index = hit + 3;
  }
  return violations;
}

/// Scan 3 — catalog trio drift guard.
///
/// [SnaplinkAdminOperationCatalog.endpoints] derives from the `routes`
/// listing at runtime, so this check is structurally drift-free; it pins
/// that the audit-prefixed members are exactly the trio with method GET.
List<AuditGuardViolation> scanCatalogTrio(
  List<SnaplinkAdminEndpoint> endpoints,
) {
  final actual = <String>{
    for (final endpoint in endpoints)
      if (endpoint.path.startsWith('/api/v1/audit'))
        '${endpoint.method} ${normalizeAuditPathToken(endpoint.path)}',
  };
  const expected = <String>{
    'GET /api/v1/audit/events',
    'GET /api/v1/audit/facets',
    'GET /api/v1/audit/events/{id}',
  };
  if (setEquals(actual, expected)) return const [];
  return [
    AuditGuardViolation(
      scan: 'catalog-trio',
      file: 'SnaplinkAdminOperationCatalog.endpoints',
      detail:
          'audit-prefixed endpoints $actual differ from the pinned trio '
          '$expected',
    ),
  ];
}

/// Scan 5 — B6-1a second-consumer land-check (hardened per the
/// adversarial review E1–E6 evasion matrix).
///
/// Examined files: those whose literals normalize to one of the two
/// *queryable* audit endpoints (`/api/v1/audit/events`, `/api/v1/audit/facets`),
/// those carrying an adjacent-literal audit split (E4), and those
/// referencing the read client (`AuditReadClient`/`audit_read_client`,
/// E1/E5 identifier indirection) — in each case only when the file also
/// passes a `query:` argument. Green requires constructing the parameters
/// through [AuditQuery]'s wire surface (`.toQueryParameters()`, not a
/// bare import — E2) **and** referencing the read client (import-pin
/// style); the `{...AuditQuery(...)}` spread skin is banned outright
/// (E6 — the limit-only wire contract allows no hand-added keys). The
/// `query:`-presence discriminator keeps a split `{id}`-detail literal
/// (which never passes `query:`) from false-positiving on the detail
/// reader.
List<AuditGuardViolation> scanSecondConsumer(String source, String fileLabel) {
  final queryable = <String>{};
  for (final literal in _stringLiterals(source)) {
    if (literal.triple) {
      for (final line in literal.content.split('\n')) {
        for (final match in _auditTokenPattern.allMatches(line)) {
          final normalized = normalizeAuditPathToken(match.group(0)!);
          if (normalized == '/api/v1/audit/events' ||
              normalized == '/api/v1/audit/facets') {
            queryable.add(normalized);
          }
        }
      }
      continue;
    }
    if (literal.content.contains('api/v1/audit')) {
      final normalized = normalizeAuditPathToken(literal.content);
      if (normalized == '/api/v1/audit/events' ||
          normalized == '/api/v1/audit/facets') {
        queryable.add(normalized);
      }
    }
  }
  final referencesClient =
      source.contains('AuditReadClient') ||
      source.contains('audit_read_client');
  final adjacentSplit = _adjacentAuditSplit.hasMatch(source);
  final examined = queryable.isNotEmpty || adjacentSplit || referencesClient;
  if (!examined || !source.contains('query:')) return const [];

  final violations = <AuditGuardViolation>[];
  final what = queryable.isEmpty
      ? 'the audit trio (via AuditReadClient / audit_read_client reference)'
      : queryable.join(', ');
  if (!source.contains('.toQueryParameters(')) {
    violations.add(
      AuditGuardViolation(
        scan: 'second-consumer',
        file: fileLabel,
        detail:
            'queries $what but never constructs '
            'parameters through AuditQuery.toQueryParameters() — B6-1a '
            'must reuse AuditQuery (pure Dart, zero cost) or extend this '
            'scan at landing time',
      ),
    );
  }
  if (!referencesClient) {
    violations.add(
      AuditGuardViolation(
        scan: 'second-consumer',
        file: fileLabel,
        detail:
            'queries the audit trio but never references '
            'AuditReadClient / audit_read_client (import-pin) — the read '
            'client is the only sanctioned route to the sink read API',
      ),
    );
  }
  if (_auditQuerySpread.hasMatch(source)) {
    violations.add(
      AuditGuardViolation(
        scan: 'second-consumer',
        file: fileLabel,
        detail:
            'spreads AuditQuery parameters into a hand-extended map '
            '({...AuditQuery(...)}) — the limit-only wire contract allows '
            'no extra keys around the AuditQuery result',
      ),
    );
  }
  return violations;
}

/// Adjacent-literal concatenation carrying an audit fragment
/// (`'/api/v1/audit' '/events'` or `'/api/v1/audit' + '/events'`) — the
/// E4 split form. The literal tokenizer sees the fragments separately, so
/// the split is invisible to the queryable-literal trigger; this raw-source
/// pattern closes it. Nothing in the current tree concatenates string
/// literals around an audit token (verified by census).
final _adjacentAuditSplit = RegExp(
  r'''['"][^'"]*api/v1/audit[^'"]*['"]\s*(\+\s*)?['"]''',
);

/// Spread skin `...AuditQuery(` inside a map literal (E6): AuditQuery
/// parameters may only flow as the whole `query:` value, never spread into
/// a hand-extended map — the limit-only wire contract allows no extra
/// keys around the AuditQuery result.
final _auditQuerySpread = RegExp(r'\.\.\.\s*AuditQuery');

/// Positive pin for trio-literal ownership (scan-5 hardening, E3).
///
/// `api/audit_read_client.dart` is the only lib file containing the trio
/// literals: the census counts single-line literals only (triple-quoted
/// blobs — the `routes` listing at `snaplink_admin_types.dart` — and
/// `///` doc comments are documentation, not callable code), and every
/// occurrence outside the owner trips. The owner must contain all three
/// members, so the pin cannot pass vacuously if a literal is deleted.
List<AuditGuardViolation> scanTrioLiteralOwnership(
  Map<String, String> sources, {
  String libRootLabel = 'lib',
}) {
  const owner = 'api/audit_read_client.dart';
  final ownerHits = <String>{};
  final offenders = <String>[];
  for (final entry in sources.entries) {
    final hits = _trioLiteralsInSource(entry.value);
    if (entry.key == owner) {
      ownerHits.addAll(hits);
    } else if (hits.isNotEmpty) {
      offenders.add(entry.key);
    }
  }
  final violations = <AuditGuardViolation>[];
  for (final file in offenders) {
    violations.add(
      AuditGuardViolation(
        scan: 'trio-literal-owner',
        file: file,
        detail:
            'contains audit trio literals outside the owner $owner — the '
            'trio literals must live only in the read client (import-pin '
            'style); reference ${owner.split('/').last} constants instead',
      ),
    );
  }
  for (final member in auditTrio) {
    if (!ownerHits.contains(member)) {
      violations.add(
        AuditGuardViolation(
          scan: 'trio-literal-owner',
          file: owner,
          detail:
              'missing trio literal $member — the read client must own '
              'all three trio members (non-vacuous pin)',
        ),
      );
    }
  }
  return violations;
}

/// Trio literals present as single-line string literals in [source].
/// Triple-quoted literals (doc/route listings) and comments are excluded:
/// they are documentation, not callable code.
Set<String> _trioLiteralsInSource(String source) {
  final hits = <String>{};
  for (final literal in _stringLiterals(source)) {
    if (literal.triple) continue;
    if (!literal.content.contains('api/v1/audit')) continue;
    final normalized = normalizeAuditPathToken(literal.content);
    if (auditTrio.contains(normalized)) hits.add(normalized);
  }
  return hits;
}

/// Shared B6-1 negative-boundary scan (portal + developer parity).
///
/// [modulePrefix] gates the scan (the early return keeps every other
/// label byte-for-byte unaffected — the existing scans 1/2/4/5 run
/// exactly as before); [scanId] is the pin id; [moduleLabel] and
/// [boundaryReason] render the violation detail. This is the reason the
/// temp-dir positive pin (F2) writes its synthetic probes under the
/// module root inside a throwaway tree: only that label is scanned.
final _auditAnyPattern = RegExp(r'audit', caseSensitive: false);

List<AuditGuardViolation> _scanNegativeBoundary(
  String source,
  String fileLabel, {
  required String modulePrefix,
  required String scanId,
  required String moduleLabel,
  required String boundaryReason,
}) {
  if (!fileLabel.startsWith(modulePrefix)) return const [];
  final violations = <AuditGuardViolation>[];
  for (final match in _auditAnyPattern.allMatches(source)) {
    final line = 1 + '\n'.allMatches(source.substring(0, match.start)).length;
    violations.add(
      AuditGuardViolation(
        scan: scanId,
        file: fileLabel,
        detail:
            'case-insensitive "audit" at line $line; the $moduleLabel '
            'is the B6-1 negative boundary — $boundaryReason',
      ),
    );
  }
  return violations;
}

/// Scan 6 — B6-1 portal negative boundary.
///
/// The portal module (`lib/screens/portal/`) keeps zero case-insensitive
/// `audit` occurrences (identifiers, comments, literals, doc comments).
/// The audit timeline read belongs to SnaplinkAdminApi via
/// AuditReadClient; the portal self-service client never acquires an
/// audit surface (record: audit-contract-batch-snaplink-console.md:10).
List<AuditGuardViolation> scanPortalAuditBoundary(
  String source,
  String fileLabel,
) => _scanNegativeBoundary(
  source,
  fileLabel,
  modulePrefix: 'screens/portal/',
  scanId: 'portal-audit-boundary',
  moduleLabel: 'portal module',
  boundaryReason: 'audit reads belong to SnaplinkAdminApi via AuditReadClient',
);

/// Scan 6b — B6-1 developer negative boundary (parity with scan 6).
///
/// The developer module (`lib/screens/developer/`) keeps zero
/// case-insensitive `audit` occurrences (identifiers, imports, comments,
/// literals, doc comments). DCR reads/writes belong to DeveloperApi's
/// /register surface; audit reads belong to SnaplinkAdminApi via
/// AuditReadClient — the developer self-service client never acquires an
/// audit surface.
List<AuditGuardViolation> scanDeveloperAuditBoundary(
  String source,
  String fileLabel,
) => _scanNegativeBoundary(
  source,
  fileLabel,
  modulePrefix: 'screens/developer/',
  scanId: 'developer-audit-boundary',
  moduleLabel: 'developer module',
  boundaryReason:
      "DCR reads/writes belong to DeveloperApi's /register "
      'surface; audit reads belong to SnaplinkAdminApi via AuditReadClient',
);

/// Scan 7 — ring-storage-seam source guard (b6-1a §1.2a / F13 / S14-S16).
///
/// Key-scoped: `LocalStorage` is legitimately used by other lib/ services
/// (app_settings, cross_tab_sync, list_state_manager,
/// trusted_device_token) — the pin is the `sso_audit_log` key literal,
/// never call-scope. Absence is lib-wide; positive pins are per-file on
/// `services/audit_log_service.dart`.
List<AuditGuardViolation> scanRingStorageSeam(String source, String fileLabel) {
  final violations = <AuditGuardViolation>[];
  final isService = fileLabel == 'services/audit_log_service.dart';
  final keyHits = 'sso_audit_log'.allMatches(source).length;
  if (!isService && keyHits > 0) {
    violations.add(
      AuditGuardViolation(
        scan: 'ring-storage-seam',
        file: fileLabel,
        detail:
            'sso_audit_log literal outside the service file '
            '(must live only in audit_log_service.dart) — F13 S16',
      ),
    );
  }
  if (!isService) return violations;
  if (keyHits != 1) {
    violations.add(
      AuditGuardViolation(
        scan: 'ring-storage-seam',
        file: fileLabel,
        detail: 'sso_audit_log literal count == $keyHits, pinned 1',
      ),
    );
  }
  final kDebugLines = RegExp(r'kDebugMode').allMatches(source).length;
  if (kDebugLines != 6) {
    violations.add(
      AuditGuardViolation(
        scan: 'ring-storage-seam',
        file: fileLabel,
        detail:
            'kDebugMode lines == $kDebugLines, pinned 6 '
            '(2 initializers + 4 direct guards)',
      ),
    );
  }
  final guardLines = RegExp(
    r'if \(!kDebugMode\) return;',
  ).allMatches(source).length;
  if (guardLines != 4) {
    violations.add(
      AuditGuardViolation(
        scan: 'ring-storage-seam',
        file: fileLabel,
        detail:
            'direct guards == $guardLines, pinned 4 '
            '(copy setter + storage setter + _save + _load)',
      ),
    );
  }
  if (!source.contains('static bool _storageEnabled = kDebugMode;')) {
    violations.add(
      AuditGuardViolation(
        scan: 'ring-storage-seam',
        file: fileLabel,
        detail: 'foldable storage initializer missing',
      ),
    );
  }
  if (RegExp(r'_storageEnabled = value').allMatches(source).length != 1) {
    violations.add(
      AuditGuardViolation(
        scan: 'ring-storage-seam',
        file: fileLabel,
        detail:
            '_storageEnabled = value must appear exactly once '
            '(const-gated setter)',
      ),
    );
  }
  final ioTokens = RegExp(r'LocalStorage\.').allMatches(source).length;
  if (ioTokens != 2) {
    violations.add(
      AuditGuardViolation(
        scan: 'ring-storage-seam',
        file: fileLabel,
        detail:
            'LocalStorage. tokens == $ioTokens, pinned 2 '
            '(one setItem in _save, one getItem in _load)',
      ),
    );
  }
  // Corrected R2.4 (spec R2.4 as literally stated fails on the landed
  // layout): per-function ordering — _save's setItem must sit after
  // exactly 4 guard lines, _load's getItem after exactly 6 (the two
  // setter guards + _save's pair + _load's pair). These counts own the
  // drops, below-IO moves, and cross-function reorders; the hoist class
  // is owned by the function-head pair pin below (F2).
  final guards = <Match>[
    ...RegExp(r'if \(!kDebugMode\) return;').allMatches(source),
    ...RegExp(r'if \(!_storageEnabled\) return;').allMatches(source),
  ]..sort((a, b) => a.start.compareTo(b.start));
  final setItem = source.indexOf('LocalStorage.setItem');
  final getItem = source.indexOf('LocalStorage.getItem');
  int before(int idx) => guards.where((m) => m.start < idx).length;
  if (before(setItem) != 4 || before(getItem) != 6) {
    violations.add(
      AuditGuardViolation(
        scan: 'ring-storage-seam',
        file: fileLabel,
        detail:
            'guard-before-IO ordering broken: ${before(setItem)} guards '
            'before setItem (pinned 4), ${before(getItem)} before getItem '
            '(pinned 6) — S14 direct-first-statement guards',
      ),
    );
  }
  // Pair adjacency: each function's direct guard is immediately followed
  // by the _storageEnabled guard (2 pairs; the setter guards are followed
  // by assignments, so they cannot be counted here).
  final lines = source.split('\n');
  var pairs = 0;
  for (var i = 0; i + 1 < lines.length; i++) {
    if (lines[i].contains('if (!kDebugMode) return;') &&
        lines[i + 1].contains('if (!_storageEnabled) return;')) {
      pairs++;
    }
  }
  if (pairs != 2) {
    violations.add(
      AuditGuardViolation(
        scan: 'ring-storage-seam',
        file: fileLabel,
        detail: 'direct-guard pairs == $pairs, pinned 2 (one per function)',
      ),
    );
  }
  // Function-head pair pin (closes FD-7 — F2): each of _save/_load must
  // open with the direct guard followed by the storage guard, anchored to
  // the function signature. The ordering pins above count guards before
  // the IO tokens globally, so a pair hoisted into the constructor,
  // record(), clear(), a setter, or above the class keeps every count
  // green; this pin is what makes the FD-7 claim true. Comments/blanks
  // between the signature and the guard are allowed (the guards remain
  // the first *statements*); a statement line there breaks the pattern.
  final fnPairPattern = RegExp(
    r'void (_save|_load)\(\) \{\n'
    r'(?:    (?://|///)[^\n]*\n|[ \t]*\n)*'
    r'    if \(!kDebugMode\) return;[^\n]*\n'
    r'    if \(!_storageEnabled\) return;',
  );
  final fnPairs = fnPairPattern.allMatches(source).length;
  if (fnPairs != 2) {
    violations.add(
      AuditGuardViolation(
        scan: 'ring-storage-seam',
        file: fileLabel,
        detail:
            'function-head guard pairs == $fnPairs, pinned 2 — each of '
            '_save/_load must open with the direct guard + storage guard '
            '(FD-7 hoist class)',
      ),
    );
  }
  // Bans (F13/F16/S15): zero in-tree today, must stay zero.
  for (final needle in const [
    'assert(kDebugMode',
    'bool.fromEnvironment',
    'String.fromCharCodes',
    'base64Decode', // open finding 1 — mirror of the python-gate ban
    'base64Url', // same; also covers base64UrlDecode
  ]) {
    if (source.contains(needle)) {
      violations.add(
        AuditGuardViolation(
          scan: 'ring-storage-seam',
          file: fileLabel,
          detail: 'banned $needle present (F13 last-resort/second-axis)',
        ),
      );
    }
  }
  if (RegExp(r'debugPrint\([^)]*\$e').hasMatch(source)) {
    violations.add(
      AuditGuardViolation(
        scan: 'ring-storage-seam',
        file: fileLabel,
        detail: 'debugPrint interpolates \$e — F16 payload echo',
      ),
    );
  }
  return violations;
}

/// Scan 4 — raw-stringification source guard (absence + positive pins).
///
/// Absence (lib-wide): the `MapEntry(key, '$value')` form — the F6
/// literal-`tenant_id=null` bug — must not reappear anywhere, in either
/// quote style, tolerant of whitespace/line breaks between tokens.
///
/// Positive pins (so the scan cannot pass vacuously if the wiring is
/// deleted or rewired via `Map.from`/`.cast`/`.toString()` skins):
///  * `governance_tab.dart` must import and use `AuditQuery.fromJson` /
///    `toQueryParameters`, and keep the default `'{"limit": 100}'` field
///    text (the source of the C1 default wire);
///  * `audit_query.dart` must keep the parse-error surface (the F2/F4
///    typed-rejection messages) and must never contain a `'null'` string
///    literal (C5 — null values are omitted, never stringified).
List<AuditGuardViolation> scanRawStringification(
  String source,
  String fileLabel,
) {
  final violations = <AuditGuardViolation>[];

  final rawEntry = RegExp(
    r"""MapEntry\s*\(\s*key\s*,\s*["']\$value["']\s*\)""",
  );
  if (rawEntry.hasMatch(source)) {
    violations.add(
      AuditGuardViolation(
        scan: 'raw-stringification',
        file: fileLabel,
        detail:
            "raw `MapEntry(key, '\$value')` stringification reintroduced "
            '(F6: JSON null becomes the literal wire string tenant_id=null '
            'for platform tokens)',
      ),
    );
  }

  if (fileLabel == 'screens/admin/governance_tab.dart') {
    const pins = <(String, String)>[
      ("package:sso_admin/api/audit_query.dart'", 'AuditQuery import'),
      ('AuditQuery.fromJson(', 'AuditQuery.fromJson usage'),
      ('.toQueryParameters()', 'AuditQuery.toQueryParameters usage'),
      ('{"limit": 100}', 'default limit-100 field text (C1 wire)'),
    ];
    for (final (needle, label) in pins) {
      if (!source.contains(needle)) {
        violations.add(
          AuditGuardViolation(
            scan: 'raw-stringification',
            file: fileLabel,
            detail: 'positive pin missing: $label ($needle)',
          ),
        );
      }
    }
  }

  if (fileLabel == 'api/audit_query.dart') {
    const parsePins = <(String, String)>[
      ('AuditQueryParseException', 'typed parse exception type'),
      ('Audit query: unsupported key', 'unknown-key rejection (F2)'),
      ('Audit query: limit must be an integer', 'limit rejection (F4)'),
    ];
    for (final (needle, label) in parsePins) {
      if (!source.contains(needle)) {
        violations.add(
          AuditGuardViolation(
            scan: 'raw-stringification',
            file: fileLabel,
            detail: 'positive pin missing: $label ($needle)',
          ),
        );
      }
    }
    final nullLiteral = RegExp(r"""["']null["']""");
    if (nullLiteral.hasMatch(source)) {
      violations.add(
        AuditGuardViolation(
          scan: 'raw-stringification',
          file: fileLabel,
          detail:
              "'null' string literal present — an absent field may be "
              'serialized as the literal wire string null (C5/F6)',
        ),
      );
    }
  }

  return violations;
}

/// A string literal found in source: content plus quoting style. Raw
/// (`r'...'`) and interpolated (`'...${...}...'`) literals are captured
/// with their verbatim content.
class _StringLiteral {
  final String content;
  final bool triple;
  final bool raw;

  const _StringLiteral(this.content, {this.triple = false, this.raw = false});
}

/// Minimal Dart string-literal tokenizer: both quote styles, single-line
/// and triple-quoted (per-line processing happens in the caller), raw
/// prefixes, escapes, and `//`/`/* */` comment skipping. Not a full parser
/// — adjacent-literal concatenation is intentionally split into separate
/// literals (each is checked independently; see the mutation drill).
List<_StringLiteral> _stringLiterals(String source) {
  final literals = <_StringLiteral>[];
  var i = 0;
  while (i < source.length) {
    final ch = source[i];
    if (ch == '/' && i + 1 < source.length) {
      if (source[i + 1] == '/') {
        final end = source.indexOf('\n', i);
        i = end < 0 ? source.length : end + 1;
        continue;
      }
      if (source[i + 1] == '*') {
        final end = source.indexOf('*/', i + 2);
        i = end < 0 ? source.length : end + 2;
        continue;
      }
    }
    final raw = i > 0 && (source[i - 1] == 'r' || source[i - 1] == 'R');
    if (ch == "'" || ch == '"') {
      final triple =
          i + 2 < source.length && source[i + 1] == ch && source[i + 2] == ch;
      if (triple) {
        final close = ch == "'" ? "'''" : '"""';
        final end = source.indexOf(close, i + 3);
        if (end < 0) break;
        literals.add(
          _StringLiteral(source.substring(i + 3, end), triple: true, raw: raw),
        );
        i = end + 3;
        continue;
      }
      var j = i + 1;
      final buffer = StringBuffer();
      while (j < source.length) {
        final c = source[j];
        if (c == '\\' && !raw && j + 1 < source.length) {
          buffer.write(c);
          buffer.write(source[j + 1]);
          j += 2;
          continue;
        }
        if (c == ch) break;
        buffer.write(c);
        j++;
      }
      literals.add(_StringLiteral(buffer.toString(), raw: raw));
      i = j < source.length ? j + 1 : j;
      continue;
    }
    i++;
  }
  return literals;
}

/// Deep-equality helper for unordered sets (mirrors `package:collection`'s
/// `setEquals` without the dependency).
bool setEquals<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);

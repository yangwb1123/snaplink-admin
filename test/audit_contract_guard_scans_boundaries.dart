part of 'audit_contract_guard_scans.dart';

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
  String? exactFile,
  required String scanId,
  required String moduleLabel,
  required String boundaryReason,
}) {
  if (!fileLabel.startsWith(modulePrefix) &&
      (exactFile == null || fileLabel != exactFile)) {
    return const [];
  }
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
/// The portal module and its self-service transport keep zero case-insensitive
/// audit occurrences. The audit timeline read belongs to SnaplinkAdminApi via
/// AuditReadClient; the portal client never acquires an audit surface.
List<AuditGuardViolation> scanPortalAuditBoundary(
  String source,
  String fileLabel,
) => _scanNegativeBoundary(
  source,
  fileLabel,
  modulePrefix: 'screens/portal/',
  exactFile: 'api/portal_api.dart',
  scanId: 'portal-audit-boundary',
  moduleLabel: 'portal module',
  boundaryReason:
      'audit reads belong to SnaplinkAdminApi via AuditReadClient',
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

part of 'audit_contract_guard_scans.dart';


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

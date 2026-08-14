part of 'audit_contract_guard_scans.dart';

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

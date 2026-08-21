@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AC-2 static guard (spec REQ-1): the oidc_login module must keep zero
/// references to the debug-only audit ring — no imports, no construction,
/// no reads, no writes, no string literals.
///
/// Census pattern per `test/oidc_login_handle_success_census_test.dart`
/// (`@TestOn('vm')`, `dart:io` scans of `lib/screens/oidc_login`).
/// The needles are literal-split so this guard file can never trip its own
/// scan (and survives a future widening of the scan root to `test/`).
/// The reason string and the grep-form line below are split the same way
/// (adjacent literals / adjacent shell quotes) — the file contains no
/// contiguous banned needle anywhere.
///
/// Grep form for CI / joint gate (must exit 1); adjacent quotes concatenate
/// in POSIX shell, so the command below is copy-pasteable as-is:
///   grep -rn "AuditLog""Service\|audit_log_""service\|sso_audit_""log" \
///     lib/screens/oidc_login/
void main() {
  const moduleDir = 'lib/screens/oidc_login';
  const banned = [
    'AuditLog'
        'Service',
    'audit_log_'
        'service',
    'sso_audit_'
        'log',
  ];

  test('zero audit-ring references in the module (REQ-1 floor, AC-2)', () {
    final offenders = <String, List<String>>{};
    for (final entity in Directory(moduleDir).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = File(entity.path).readAsStringSync();
      final hits = [
        for (final needle in banned)
          if (source.contains(needle)) needle,
      ];
      if (hits.isNotEmpty) offenders[entity.path] = hits;
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'lib/screens/oidc_login must keep zero '
          'AuditLog'
          'Service / audit_log_'
          'service / sso_audit_'
          'log references '
          '(localStorage ring is debug-only; the login edge is evidenced '
          'exclusively through the server-fed timeline)',
    );
  });
}

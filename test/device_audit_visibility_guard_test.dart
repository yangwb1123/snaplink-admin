@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// B6-1 REQ-1 static guard (spec AC-1/AC-2): the device module must keep
/// zero references to the debug-only audit ring — no imports, no
/// construction, no reads, no writes, no string literals.
///
/// Verbatim mirror of `test/oidc_login_audit_visibility_guard_test.dart`
/// (same three literal-split needles, `@TestOn('vm')` recursive `dart:io`
/// scan) with the scan root changed to `lib/screens/device/`.
/// The needles are literal-split so this guard file can never trip its own
/// scan (and survives a future widening of the scan root to `test/`).
///
/// Grep form for CI / joint gate (must exit 1) — needles split here too,
/// so the file stays self-scan-safe under any scan-root widening:
///   grep -rn "AuditLog""Service\|audit_log_""service\|sso_audit_""log" \
///     lib/screens/device/
void main() {
  const moduleDir = 'lib/screens/device';
  const banned = [
    'AuditLog'
        'Service',
    'audit_log_'
        'service',
    'sso_audit_'
        'log',
  ];

  test(
    'zero audit-ring references in the device module (REQ-1 floor, AC-2)',
    () {
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
            'lib/screens/device must keep zero '
            'AuditLog'
            'Service'
            ' / '
            'audit_log_'
            'service'
            ' / '
            'sso_audit_'
            'log'
            ' '
            'references (localStorage ring is debug-only; device decisions '
            'are evidenced exclusively through the server-fed timeline)',
      );
    },
  );
}

@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// REQ-1 / AC-2 negative-boundary guard (B6-2, hardened per the security
/// review): the portal module is not an edge generator (design §3.2, D3)
/// and the `auth.login.success` emission string is server-owned repo-wide.
///
/// Two scopes, exactly mirroring the standing repo greps
/// (`grep -rn "auth/login" lib/screens/portal/` and
/// `grep -rn "auth\.login\.success" lib/`):
///
///  * `auth/login` — `lib/screens/portal/` only, **35 files pinned**. The
///    route is legitimately emitted outside the module by the console/OIDC
///    clients (`lib/api/sso_client.dart:96`, `lib/api/oidc_login_api.dart:51`,
///    `lib/screens/oidc_login/*`), so a lib/-wide raw scan would false-hit;
///    the module-scoped pin keeps the scan non-vacuous (a module-level
///    rename, an emptied directory, or an unlisted new file goes red).
///  * `auth.login.success` — **all of `lib/`** (recursive walk, the
///    `i18n_coverage_test.dart` precedent): the emission string must never
///    be fabricated anywhere in production code. Widening the walk closes
///    the constant-outside-the-module and router/api-wrapper bypass
///    vectors for the emission string and makes AC-4.1's manual grep an
///    independent backstop instead of the only guard.
///
/// Matching is **normalized before comparison** (the security-review
/// hardening): quote seams (`'auth.' 'login'`), `' + '` concatenation, and
/// `$` interpolation markers are stripped, so the split-literal evasion the
/// census itself documents (`oidc_login_handle_success_census_test.dart`
/// self-host trick) cannot hide a portal login surface from this guard.
/// The substring set is identical to the standing greps, so the guard can
/// never disagree with them; both stay exit 1. The scan roots are
/// production directories only, so test scaffolding cannot self-hit.
void main() {
  const portalDir = 'lib/screens/portal';
  const portalFileCount = 35;

  /// Strips quote seams, concatenation operators, whitespace, and
  /// interpolation markers so a split literal that assembles to a needle
  /// becomes contiguous:
  ///  * `'auth.' 'login'` / `"auth." "login"` — adjacent-literal seams
  ///  * `'/auth/' + 'login'` — concatenation operator
  ///  * `'/auth/$segment'`, `'auth.${x}.login.success'` — interpolation
  ///    markers (marker + identifier/expression removed)
  String normalizeForMatch(String source) {
    final buffer = StringBuffer();
    for (var i = 0; i < source.length; i++) {
      final ch = source[i];
      if (ch == '\'' || ch == '"' || ch == '+' || ch == ' ' || ch == '\t') {
        continue;
      }
      if (ch == r'$') {
        if (i + 1 < source.length && source[i + 1] == '{') {
          final end = source.indexOf('}', i + 2);
          i = end == -1 ? source.length : end;
        } else {
          i++;
          while (i < source.length &&
              RegExp(r'[A-Za-z0-9_]').hasMatch(source[i])) {
            i++;
          }
          i--;
        }
        continue;
      }
      buffer.write(ch);
    }
    return buffer.toString();
  }

  /// Files under [dir] whose normalized content contains [needle]. When
  /// [recursive], the walk descends into subdirectories (all of `lib/`);
  /// otherwise only the directory's own `.dart` files are scanned and the
  /// scanned count is asserted against [pinnedCount].
  List<String> offendersFor(
    String dir,
    String needle, {
    bool recursive = false,
    int? pinnedCount,
  }) {
    final offenders = <String>[];
    var scanned = 0;
    for (final entity in Directory(dir).listSync(recursive: recursive)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      scanned++;
      if (normalizeForMatch(
        File(entity.path).readAsStringSync(),
      ).contains(needle)) {
        offenders.add(entity.path);
      }
    }
    if (pinnedCount != null) {
      expect(
        scanned,
        pinnedCount,
        reason:
            'the guard must cover the full $pinnedCount-file portal '
            'module — a module-level rename, an emptied directory, or an '
            'unlisted new file fails here, never silently '
            '(found $scanned)',
      );
    }
    return offenders;
  }

  test('lib/screens/portal has zero auth/login references (REQ-1)', () {
    expect(
      offendersFor(portalDir, 'auth/login', pinnedCount: portalFileCount),
      isEmpty,
      reason:
          'the portal module must stay a non-emitter: PortalApi.login '
          'is a GET /me probe, never an auth/login emitter — the paste and '
          'resume paths cannot create spurious or duplicate sink events',
    );
  });

  test('lib/-wide: zero auth.login.success emission strings anywhere in lib/ '
      '(REQ-1 / AC-4.1)', () {
    expect(
      offendersFor('lib', 'auth.login.success', recursive: true),
      isEmpty,
      reason:
          'the emission string is generated server-side only; it '
          'must never be fabricated anywhere in lib/ — the widened walk '
          'closes the constant-outside-the-module and router/api-wrapper '
          'bypass vectors (the manual AC-4.1 grep is an independent '
          'backstop)',
    );
  });
}

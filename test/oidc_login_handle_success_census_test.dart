@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// REQ-1 + REQ-4 structural census guard (design §4.3, D12/D13).
///
/// Pins the single `_handleSuccess` declaration, the six call sites, the
/// syntactic adjacency rule (`if (outcome.ok) {` → `_handleSuccess(outcome);`
/// as the next non-empty line — no `&&` compounds, no allowlist), the
/// account-flow isolation, and the zero-emission-string invariant. Written
/// against the verified census and MUST pass at HEAD with zero `lib/` edits.
void main() {
  const moduleDir = 'lib/screens/oidc_login';
  const authorizationFlow = '$moduleDir/oidc_authorization_flow.dart';
  const challengeFlow = '$moduleDir/oidc_challenge_flow.dart';
  const providerFlow = '$moduleDir/oidc_provider_flow.dart';
  const accountFlow = '$moduleDir/oidc_account_flow.dart';
  const flowFiles = [authorizationFlow, challengeFlow, providerFlow];

  List<String> linesOf(String path) =>
      File(path).readAsStringSync().split('\n');

  group('_handleSuccess census (REQ-1/REQ-4)', () {
    test('single declaration at oidc_authorization_flow.dart:8', () {
      final declarations = <String, List<int>>{};
      for (final file in [...flowFiles, accountFlow]) {
        final lines = linesOf(file);
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('void _handleSuccess(')) {
            declarations.putIfAbsent(file, () => []).add(i + 1);
          }
        }
      }
      expect(declarations, {authorizationFlow: [8]});
    });

    test('exactly six call sites at the pinned lines, none elsewhere', () {
      final pinned = <String, List<int>>{
        authorizationFlow: [242, 313, 379],
        challengeFlow: [150, 244],
        providerFlow: [60],
      };
      final actual = <String, List<int>>{};
      for (final file in pinned.keys) {
        final lines = linesOf(file);
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('_handleSuccess(outcome);')) {
            actual.putIfAbsent(file, () => []).add(i + 1);
          }
        }
      }
      expect(actual, pinned);
    });

    test(
      'adjacency rule: every `if (outcome.ok) {` is immediately followed by '
      '_handleSuccess(outcome); — exactly six pairs (D12)',
      () {
        // Exact syntactic form, no `&&` (leading indentation allowed): the
        // compound probe condition (oidc_provider_flow.dart:279) and the
        // `_codeSent = outcome.ok` assignment are excluded structurally.
        final pattern = RegExp(r'^[ \t]*if \(outcome\.ok\) \{');
        var pairs = 0;
        for (final file in flowFiles) {
          final lines = linesOf(file);
          for (var i = 0; i < lines.length; i++) {
            if (!pattern.hasMatch(lines[i])) continue;
            var next = i + 1;
            while (next < lines.length && lines[next].trim().isEmpty) {
              next++;
            }
            expect(
              lines[next].trim(),
              '_handleSuccess(outcome);',
              reason: '$file:${i + 1} must be immediately followed by '
                  '_handleSuccess(outcome);',
            );
            pairs++;
          }
        }
        expect(pairs, 6);
      },
    );

    test('oidc_account_flow.dart has zero _handleSuccess references', () {
      final lines = linesOf(accountFlow);
      final hits = [
        for (var i = 0; i < lines.length; i++)
          if (lines[i].contains('_handleSuccess')) i + 1,
      ];
      expect(hits, isEmpty);
    });

    test('no auth.login.success emission string in the module (REQ-4 #5)', () {
      final offenders = <String>[];
      for (final entity in Directory(moduleDir).listSync()) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (File(entity.path).readAsStringSync().contains('auth.login.success')) {
          offenders.add(entity.path);
        }
      }
      expect(offenders, isEmpty);
    });
  });

  group('client_id literal census (single-source rule, §6.4 gate c)', () {
    // Split so the exact quoted literal never appears in this file's source
    // (the census scans test/*.dart and must not self-hit).
    const literal = "'sso-admin-" "console'";
    const ssoClientPath = 'lib/api/sso_client.dart';
    const constantDecl = 'static const String firstPartyClientId';
    // Pinned literal sites while the sibling constant is absent (HEAD state).
    const pinnedSites = <String, List<int>>{
      'test/sso_client_test.dart': [18],
      'test/oidc_account_flow_test.dart': [35, 75, 115, 160],
      'test/oidc_login_screen_client_id_test.dart': [76, 136, 158],
    };

    test(
      'expectation derives from the constant existence (design §4.2/§5/§6.4; '
      'REQ-4 item 6)',
      () {
        final constantExists =
            File(ssoClientPath).readAsStringSync().contains(constantDecl);
        final actual = <String, List<int>>{};
        for (final entity in Directory('test').listSync()) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final lines = File(entity.path).readAsStringSync().split('\n');
          for (var i = 0; i < lines.length; i++) {
            if (lines[i].contains(literal)) {
              actual.putIfAbsent(entity.path, () => []).add(i + 1);
            }
          }
        }
        if (constantExists) {
          // Single-source rule active: once SSOAdminClient.firstPartyClientId
          // exists, no test may carry the value as a fresh literal — every
          // reference goes through the constant. The sibling co-change list
          // constantizes the anchor's REQ-2 file in the same commit (M2); a
          // forgotten co-site fails here immediately (red, not silent).
          expect(actual, isEmpty,
              reason: 'firstPartyClientId exists in $ssoClientPath — the '
                  'sso-admin-console literal must not appear in test/; '
                  'every reference goes through the constant');
        } else {
          // Pre-sibling: the literal census equals exactly the pinned sites.
          expect(actual, pinnedSites,
              reason: 'constant absent — literal census is pinned; the '
                  'sibling M2 commit constantizes these sites in the same '
                  'commit (anchor design §4.2)');
        }
      },
    );
  });
}

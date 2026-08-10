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
      'literal census derives from constant existence + standing 43-test '
      'count gate (design §4.2/§4.4/§5/§6.4; REQ-2/REQ-4 item 6)',
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
        // ---- lib/ single-source clause (REQ-2, design §2.2a) ----
        // Recursive lib/ scan with the same split-literal convention: in
        // constant mode exactly the declaration site may carry the value;
        // in absent mode the two historical production sites are pinned.
        // The matcher is deliberately broader than the test/ side: the
        // contiguous quoted literal OR the bare value prefix — the bare
        // form covers split halves, adjacent concatenation, and
        // interpolation, all zero-hit in lib/ today besides the
        // declaration site, so it has no false positives. The 'console'
        // half-token is deliberately NOT scanned: it is a legitimate
        // token in lib/ debug strings (probed: reddens on legit code).
        // lib/-only: even the bare prefix appears in test/ only inside
        // this file's own source (self-hit — see §8).
        bool libCarriesValue(String line) =>
            line.contains(literal) || line.contains('sso-admin-');
        final libOffenders = <String, List<int>>{};
        for (final entity in Directory('lib').listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final lines = File(entity.path).readAsStringSync().split('\n');
          for (var i = 0; i < lines.length; i++) {
            if (libCarriesValue(lines[i])) {
              libOffenders.putIfAbsent(entity.path, () => []).add(i + 1);
            }
          }
        }
        // Self-presence pin: the walk and its collector must physically
        // live in THIS file (deleting the walk reddens; relocating it to a
        // helper or hiding it in a comment does too — anchored statement
        // forms, not bare contains).
        final censusLines = File(
                'test/oidc_login_handle_success_census_test.dart')
            .readAsStringSync()
            .split('\n');
        expect(
            censusLines.indexWhere((l) =>
                RegExp(r"^\s*for \(final entity in Directory\('lib'\)")
                    .hasMatch(l)),
            isNot(-1),
            reason: 'lib clause walk must be a statement of this file');
        expect(
            censusLines.indexWhere((l) => RegExp(
                    r'^\s*final libOffenders = <String, List<int>>\{\};')
                .hasMatch(l)),
            isNot(-1),
            reason: 'libOffenders collector must be declared in this file');
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
          // Constant mode lib/ clause: exactly the declaration site, and
          // that site's line carries the declaration itself (site +
          // declaration-line-content invariant, not an absolute line pin).
          expect(libOffenders.length, 1,
              reason: 'exactly one lib/ site may carry the literal in '
                  'constant mode — found $libOffenders');
          expect(libOffenders.keys.single, ssoClientPath,
              reason: 'the single lib/ site must be the declaration file '
                  '$ssoClientPath — found $libOffenders');
          final declLine = libOffenders[ssoClientPath]!.single;
          expect(
            File(ssoClientPath)
                .readAsStringSync()
                .split('\n')[declLine - 1]
                .contains(constantDecl),
            isTrue,
            reason: 'the single lib/ hit must be the declaration line '
                '($ssoClientPath:$declLine) — found $libOffenders',
          );
        } else {
          // Pre-sibling: the literal census equals exactly the pinned sites.
          expect(actual, pinnedSites,
              reason: 'constant absent — literal census is pinned; the '
                  'sibling M2 commit constantizes these sites in the same '
                  'commit (anchor design §4.2)');
          // Absent mode lib/ clause: the two pre-constantization
          // production sites (anchor spec §1.4 census coordinates),
          // preserved for two-state traceability. Compile-broken at HEAD.
          expect(libOffenders, {
            'lib/api/sso_client.dart': [86],
            'lib/app_router.dart': [35],
          },
              reason: 'constant absent — lib/ literal census is pinned');
        }

        // ---- 43-test self-count regression gate (design §4.4) ----
        // The acceptance command's 43 tests are 10 (this file: 6 census +
        // literal-census + 4 topology) + 3 (client_id) + 17 (sso) + 3
        // (sso_client_login_exactly_once) + 10 (entry_ux). A guard test
        // deleted by a later refactor silently regresses the command (the
        // runner still exits 0); this pin makes it red inside
        // the command itself. It lives in THIS test (not the topology
        // group) so a regression that deletes the whole topology group
        // still fails on the count.
        final declRe = RegExp(r'^\s*(test|testWidgets)\(', multiLine: true);
        final censusCount = declRe
            .allMatches(File('test/oidc_login_handle_success_census_test.dart')
                .readAsStringSync())
            .length;
        final clientIdCount = declRe
            .allMatches(File('test/oidc_login_screen_client_id_test.dart')
                .readAsStringSync())
            .length;
        final ssoCount = declRe
            .allMatches(File('test/sso_client_test.dart').readAsStringSync())
            .length;
        final ssoLoginCount = declRe
            .allMatches(File('test/sso_client_login_exactly_once_test.dart')
                .readAsStringSync())
            .length;
        expect(censusCount, 10,
            reason: 'census file must hold 10 tests (6 census/literal-census '
                '+ 4 topology) — found $censusCount');
        expect(clientIdCount, 3,
            reason: 'client_id widget file must hold 3 testWidgets — found '
                '$clientIdCount');
        expect(ssoCount, 17,
            reason: 'sso_client_test must hold 17 tests — found $ssoCount');
        expect(ssoLoginCount, 3,
            reason: 'exactly-once harness file must hold 3 tests — found '
                '$ssoLoginCount');
        final entryUxCount = declRe
            .allMatches(File('test/entry_ux_test.dart').readAsStringSync())
            .length;
        expect(entryUxCount, 10,
            reason: 'entry_ux_test must hold 10 tests (redirect-leg group '
                'included) — found $entryUxCount');
        expect(
            censusCount + clientIdCount + ssoCount + ssoLoginCount +
                entryUxCount,
            43,
            reason: 'joint 43-test acceptance count (10+3+17+3+10)');

        // ---- silencing ban (mutation-audit §2 A/B) ----
        // The gate's counts are text-based, so an exclusion token on any
        // non-guard joint-gate file would silently shrink the 43-run
        // (@TestOn('browser') → "No tests ran", exit 0; skip: → skipped
        // without red). Tokens are written split so the ban cannot
        // self-hit its own guard file; @TestOn('vm') is allowed (matches
        // the default VM runner — the census file's own line-1 annotation
        // is the precedent).
        final silenceRe = RegExp(
            "skip\\s*:|skipTag|@Skip|@Tags|tags\\s*:|@TestOn\\s*\\((?!\\s*['\"]vm['\"])");
        for (final f in [
          'test/sso_client_login_exactly_once_test.dart',
          'test/oidc_login_screen_client_id_test.dart',
          'test/sso_client_test.dart',
          'test/entry_ux_test.dart',
        ]) {
          expect(silenceRe.hasMatch(File(f).readAsStringSync()), isFalse,
              reason: 'silencing tokens banned in $f (joint-gate file)');
        }
      },
    );
  });

  group('single-emission topology (REQ-5, revision-3 pins)', () {
    // D17 brace-balanced slicer (design §3 D17): every 2-space-indented
    // `Future<...>|void name(...)` method whose signature line ends in `{`
    // or `async {`. Returns (file, name, startLine, endLine, body) with
    // 1-based line numbers; body = [startLine, endLine] inclusive.
    // Single-line getters and multi-line signatures are skipped — the
    // pinned set-size (Gap A) turns any silent dropout red.
    List<(String, String, int, int, List<String>)> sliceMethods(String path) {
      final lines = linesOf(path);
      final sig = RegExp(
          r'^[ \t]+(Future<void>|Future<bool>|void|Future<[^>]*>) \w+\(');
      final result = <(String, String, int, int, List<String>)>[];
      var i = 0;
      while (i < lines.length) {
        final line = lines[i];
        if (sig.hasMatch(line) &&
            (line.trimRight().endsWith('{') ||
                line.trimRight().endsWith('async {'))) {
          final name = line.trim().split('(').first.split(' ').last;
          var depth = 0;
          var j = i;
          for (; j < lines.length; j++) {
            depth += '${lines[j]}'
                    .split('')
                    .where((c) => c == '{')
                    .length -
                '${lines[j]}'.split('').where((c) => c == '}').length;
            if (depth == 0 && j > i) break;
          }
          if (j < lines.length) {
            result
                .add((path, name, i + 1, j + 1, lines.sublist(i, j + 1)));
            i = j + 1;
            continue;
          }
        }
        i++;
      }
      return result;
    }

    List<(String, String, int, int, List<String>)> allSlices() {
      final out = <(String, String, int, int, List<String>)>[];
      for (final f in flowFiles) {
        out.addAll(sliceMethods(f));
      }
      return out;
    }

    test(
      'Gap A: identified set == 6; pinned call-site lines inside exactly one '
      'sliced body; per-method uniqueness; G2 delivery tails terminate',
      () {
        final all = allSlices();
        final ids = [
          for (final m in all)
            if (m.$5.any((l) => l.contains('_handleSuccess(outcome);'))) m,
        ];
        expect(ids.length, 6,
            reason: 'identified set must be exactly 6 (Gap A) — a dispatch '
                'method that drops out of the scan (multi-line signature, '
                'slicer miss) or a seventh path fails here, never silently: '
                '${ids.length} found');
        const pinned = <String, List<int>>{
          authorizationFlow: [242, 313, 379],
          challengeFlow: [150, 244],
          providerFlow: [60],
        };
        pinned.forEach((file, lineNumbers) {
          final lines = linesOf(file);
          for (final ln in lineNumbers) {
            expect(lines[ln - 1].trim(), '_handleSuccess(outcome);',
                reason: 'Gap A content pin: $file:$ln must carry the '
                    '_handleSuccess(outcome); call-site form');
            final containing = [
              for (final m in ids)
                if (m.$1 == file && m.$3 <= ln && ln <= m.$4) m,
            ];
            expect(containing.length, 1,
                reason: 'Gap A containment: $file:$ln must lie inside '
                    'exactly one sliced body — ${containing.length} found');
          }
        });
        for (final m in ids) {
          expect(
              m.$5.where((l) => l.contains('_handleSuccess(outcome);')).length,
              1,
              reason: '${m.$1}:${m.$3} must contain exactly one '
                  '_handleSuccess(outcome); call site (exact-form '
                  'criterion)');
          expect(m.$5.where((l) => l.contains('_handleSuccess(')).length, 1,
              reason: '${m.$1}:${m.$3} must contain exactly one '
                  '_handleSuccess( reference — per-method uniqueness');
        }
        // G2 (security-review pin): every delivery tail inside _handleSuccess
        // is followed by return; (function-final statement exempt).
        final hs =
            all.firstWhere((m) => m.$1 == authorizationFlow && m.$3 == 8);
        final region = hs.$5.sublist(1, hs.$5.length - 1);
        final stmtRe =
            RegExp(r'^\s*(_update\(|_authorizationDeliveryBlocked\()');
        final starts = <int>[];
        for (var i = 0; i < region.length; i++) {
          if (stmtRe.hasMatch(region[i])) starts.add(i);
        }
        expect(starts.length, 8,
            reason: 'G2 presence anchor: exactly 8 delivery tails inside '
                '_handleSuccess (4 _authorizationDeliveryBlocked(); + 4 '
                '_error-assigning _update(...)) — ${starts.length} found');
        for (final s in starts) {
          var depth = 0;
          var t = s;
          while (t < region.length) {
            depth += region[t].split('').where((c) => c == '(').length -
                region[t].split('').where((c) => c == ')').length;
            if (depth == 0 && region[t].contains(';')) break;
            t++;
          }
          expect(t < region.length, isTrue,
              reason: 'G2: tail at authorization_flow:${hs.$3 + s + 1} has '
                  'no terminating ;');
          final functionFinal = t == region.length - 1 ||
              region.sublist(t + 1).every((l) => l.trim().isEmpty);
          if (functionFinal) continue; // function-final statement exempt
          var nxt = t + 1;
          while (nxt < region.length && region[nxt].trim().isEmpty) nxt++;
          expect(
              nxt < region.length && region[nxt].trim() == 'return;',
              isTrue,
              reason: 'G2: delivery tail at '
                  'authorization_flow:${hs.$3 + s + 1} must be followed by '
                  'return; (next: '
                  '${nxt < region.length ? region[nxt].trim() : 'EOF'})');
        }
      },
    );

    test(
      'Gap B: _submitLogin dispatch exclusivity with anchor-presence expects '
      '(index != -1)',
      () {
        final all = allSlices();
        final submit = all.firstWhere(
            (m) => m.$1 == authorizationFlow && m.$2 == '_submitLogin',
            orElse: () => throw StateError('_submitLogin slice not found'));
        final body = submit.$5;
        for (final anchor in [
          '_signInWithFederated(_provider);',
          'await _submitPasskeyLogin();',
        ]) {
          final idx = body.indexWhere((l) => l.contains(anchor));
          expect(idx, isNot(-1),
              reason: 'Gap B: anchor `$anchor` must exist in _submitLogin '
                  '(${submit.$3}-${submit.$4}) — a refactor that inlines the '
                  'dispatch removes it; the adjacency check must not pass '
                  'vacuously');
          var next = idx + 1;
          while (next < body.length && body[next].trim().isEmpty) next++;
          expect(next < body.length, isTrue,
              reason: 'Gap B: `$anchor` has no following line');
          expect(body[next].trim(), 'return;',
              reason: 'Gap B: next non-empty line after `$anchor` '
                  '(authorization_flow:${submit.$3 + idx}) must be return; '
                  '(no fall-through to the primary login POST)');
        }
      },
    );

    test(
      'one wire mutation per dispatch method (== 1) + choke point '
      'request-free (G1)',
      () {
        final all = allSlices();
        final ids = [
          for (final m in all)
            if (m.$5.any((l) => l.contains('_handleSuccess(outcome);'))) m,
        ];
        for (final m in ids) {
          final wires = m.$5
              .where((l) =>
                  l.contains('_api.login(') || l.contains('_api.mfaComplete('))
              .length;
          expect(wires, 1,
              reason: '${m.$1}:${m.$3} must contain exactly one wire '
                  'mutation (== 1, not <= 1) — a second POST per method '
                  'fails here');
        }
        final hs =
            all.firstWhere((m) => m.$1 == authorizationFlow && m.$3 == 8);
        expect(hs.$5.isNotEmpty, isTrue,
            reason: 'G1 presence anchor: _handleSuccess slice must exist');
        expect(hs.$5.any((l) => l.contains('void _handleSuccess(')), isTrue,
            reason: 'G1 presence anchor: slice must contain the declaration');
        expect(hs.$5.where((l) => l.contains('_api.')).length, 0,
            reason: 'G1: _handleSuccess must stay request-free — a wire '
                'added inside the choke point creates the double-request '
                'vector AC-2 targets');
      },
    );

    test(
      'Gap C: renewal call site pinned at provider_flow:36 inside '
      '_checkFederatedReturn (module-wide scan) + onSubmit form-pins',
      () {
        final declRe = RegExp(
            r'^[ \t]+(Future<void>|Future<bool>|void|Future<[^>]*>) '
            r'_submitSilentRenewal\(');
        final refs = <String, List<int>>{};
        for (final entity in Directory(moduleDir).listSync()) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final lines = linesOf(entity.path);
          for (var i = 0; i < lines.length; i++) {
            if (!lines[i].contains('_submitSilentRenewal(')) continue;
            if (declRe.hasMatch(lines[i])) continue; // declaration excluded
            refs.putIfAbsent(entity.path, () => []).add(i + 1);
          }
        }
        expect(refs.length, 1,
            reason: 'Gap C: exactly one _submitSilentRenewal( reference '
                'outside its declaration (module-wide over $moduleDir)');
        expect(refs.containsKey(providerFlow), isTrue,
            reason: 'Gap C: the reference must be in oidc_provider_flow.dart');
        expect(refs[providerFlow]![0], 36,
            reason: 'Gap C positional pin: the reference must be at '
                'provider_flow:36 (a relocation into an interactive handler '
                'keeps the count at 1 but fails here)');
        final cfr =
            allSlices().firstWhere((m) => m.$1 == providerFlow && m.$2 == '_checkFederatedReturn');
        expect(cfr.$3 <= 36 && 36 <= cfr.$4, isTrue,
            reason: 'Gap C: provider_flow:36 must lie inside the '
                '_checkFederatedReturn slice (${cfr.$3}-${cfr.$4})');
        final viewLines = linesOf('$moduleDir/oidc_login_view_flow.dart');
        expect(
            viewLines
                .where((l) => l.contains('onSubmit: _submitLogin,'))
                .length,
            1,
            reason: 'onSubmit: _submitLogin, exactly once (view_flow:268)');
        expect(
            viewLines.where((l) => l.contains('onSubmit: _submitMfa,')).length,
            1,
            reason: 'onSubmit: _submitMfa, exactly once (view_flow:302)');
        for (final entity in Directory(moduleDir).listSync()) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final lines = linesOf(entity.path);
          for (var i = 0; i < lines.length; i++) {
            if (lines[i].contains('onSubmit:') &&
                lines[i].contains('_submitSilentRenewal')) {
              fail('onSubmit must never reference _submitSilentRenewal '
                  '(${entity.path}:${i + 1})');
            }
          }
        }
      },
    );
  });
}
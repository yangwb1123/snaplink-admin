# B6-2 — Audit: negative-control drill + 11 failure modes vs. the 43/43 joint gate

> Task: *"Confirm each listed red signal would genuinely fail the 43/43 joint gate (not just a flaky or unrelated failure), and enumerate missing mutations the drill should include — `skip:`/`skipTag:` silencing, @Tags/platform exclusion, grep pattern/flag drift, count-gate relaxation, census scan-target swap, deletion of the negative-control pins."*
> Audit target: `docs/proposals/b6-2-lib-screens-device-firstparty-exactly-once-design.md` §5 (failure modes) + §6 step 2 (drill).

## 0. Method and environment (honest account)

- Every red signal was checked three ways: (1) static — is the assertion present in a file inside the joint command, and does the mutation flip it? (2) mechanical — is the flip deterministic (no timers, no shared mutable state across tests)? (3) empirical — the mutation was applied to the real tree, `flutter test` run, mutation reverted.
- **The tree changed under the audit**: a concurrent session landed REQ-1 (`test/sso_client_login_exactly_once_test.dart`) and REQ-2 (census extension) mid-audit, including a transient compile-broken census edit (duplicated `else` block) that was fixed in-session. All post-landing claims below were re-verified against the landed state. Joint gate at audit close: **43/43 green**; harness file literal-free; no audit residue (all plants/skips/relaxations reverted; probe file deleted).
- Empirical probes used (throwaway, deleted): P1 probe-GET-401 behavior, P2 script-exhaustion propagation, P3 credential-less POST bucket, P4 double-dispatch; plus real-tree mutations: lib/ plant (single/double quote), test/ plant (single/double/split), `skip: true`, `@TestOn('browser')`, harness-test deletion, pin relaxation chains, scan-target swap.

## 1. Verdict per failure mode — does the red signal genuinely fail the joint gate?

Legend: ✅ genuine + deterministic · ⚠️ genuine but the listed mechanism is wrong or narrower than claimed · ❌ not caught (silent) · (accepted) documented non-signal.

| # | Failure mode | Listed red signal | Verdict | Evidence |
|---|---|---|---|---|
| 1 | `login()` double-dispatches | `loginPosts == 2` | ✅ | **P4 empirical**: with the design's shared 1-entry script, the second dispatch increments the count then `script.removeAt(0)` throws `RangeError`, which propagates **out of `login()`** (`_post` has no catch — verified in `lib/api/sso_client.dart`). Test 1 reds deterministically. Correction to the design's comment: the count asserts do **not** "fire first" — the RangeError surfaces at the `await` inside `login()`, before the asserts. Same cause, same red. |
| 2 | Silent renewal re-POSTs `/auth/login` in `_handle` 401 path | `loginPosts == 2` after expiring read | ⚠️ | Realistic renewal **is** caught: this client holds no refresh token (`_token` is the only credential state; the 401 branch clears it), so any renewal must re-send the `credential` map → counted → red (RangeError at the re-POST or count assert). **Blind spot (P3 empirical)**: a credential-*less* POST to `/auth/login` (refresh-token shape) lands in `probePosts` — and test 3 **never asserts `probePosts`**. Such a POST returns `{}` 200, `loginPosts` stays 1, `unauthorizedCalls` stays 1 → gate green. Fix: add `expect(h.probePosts, 0)` to test 3. |
| 3 | Probe/read paths switched to login POSTs | `loginPosts > 1` | ✅ | A credential-bearing POST on `probeAdminAccess()`/`listClients()` both counts (`loginPosts == 2`) and exhausts the script → RangeError at the bare `await` in test 3 → red. Deterministic. |
| 4 | Fresh literal planted in `lib/` | `libOffenders.length != 1` / wrong site | ⚠️ | **Empirical (post-landing)**: single-quoted plant in `lib/zz_audit_plant.dart` → red, `found {lib/zz_audit_plant.dart: [1], lib/api/sso_client.dart: [82]}`. **But the census only sees single-quoted contiguous literals**: double-quoted plant → **green** (empirical); source-split `'sso-admin-' 'console'` → green; escape form → green. The design's claim "a fresh literal, contiguous or split, reddens the census" is false (§2 H). |
| 5 | Fresh literal in any `test/*.dart` | `actual` non-empty | ⚠️ | **Empirical**: single-quoted plant → red (`Actual: {'test/zz_audit_plant_test.dart': [1]}`); double-quoted → **green**; split → **green**. Same quote-form blind spot as #4. (Existing behavior, not introduced by this design.) |
| 6 | Deletion of any of the 3 harness tests | `ssoLoginCount != 3` / total `!= 33` | ✅ | **Empirical**: delete test 2 → red, `exactly-once harness file must hold 3 tests — found 2`. Both the per-file pin and the total pin red independently. |
| 7 | Deletion from the three pinned files | `10/3/17` mismatch | ✅ / ❌ (partial) | Per-file pins hold (same mechanism as #6, empirically green against the landed gate). **Hole**: `entry_ux_test.dart`'s 10 tests are **not counted anywhere** — deleting the redirect-leg group (`:174-220`) leaves every pin green and the joint run at 41/42 with exit 0. 10 of the 43 claimed tests rest on the human reading only. |
| 8 | Line-number drift of the declaration | **No red** (by design) | (accepted) | Correct as documented. Landed code pins site + declaration-line-content (`libOffenders.keys.single == ssoClientPath` + the line contains `constantDecl`), not absolute line 82 — a comment inserted above the declaration stays green. |
| 9 | Extra dispatch exhausts the script | `RangeError` | ✅ | **P2 empirical**: `removeAt(0)` on the empty list throws synchronously inside the async mock handler; the failed future propagates through `login()` (no try/catch in `_post`) → test red. Deterministic — no flakiness (no timers, per-test fresh harness). |
| 10 | Gate self-description drift | none (mitigated) | (accepted) | Nuance: the numeric `== 33` pin does machine-enforce the **computation** side (code drift reddens); only comment drift is silent — consistent with the doc. |
| 11 | Test-3 order-dependency broken | probe 401s → "**silent**" | ⚠️ | **The listed mechanism is wrong.** **P1 empirical**: an authenticated GET that 401s makes `_handle` clear session + fire `onUnauthorized` **and throw `SSOError(401)`**; `probeAdminAccess()` has no catch. In the reordered test the bare `await h.client.probeAdminAccess()` **throws** → test red. Even if the throw were swallowed, `unauthorizedCalls` would be 2 → `expect(..., 1)` reds. The mutation is genuinely caught — by two mechanisms, neither of which is "silent". The doc's red signal needs rewriting (and the probe-position comment is load-bearing for a different reason: the probe must not 401). |

**Summary**: 9 of 11 listed signals genuinely redden the joint gate deterministically and inside the joint command (#1-7, #9, #11); #8/#10 are documented non-signals; #2 and #11 are genuine but the listed mechanism is wrong or narrower than claimed; #4/#5 have quote-form blind spots; #7 misses `entry_ux`.

## 2. Missing mutations the drill must include

All confirmed against the **landed** guards unless noted.

### A. `skip:` / `skipTag:` silencing — **silent today** (empirical)
`skip: true` on one harness test → count gate **10/10 green** (`ssoLoginCount` counts declarations via `^\s*(test|testWidgets)\(` — a skipped test still matches), harness run `+2 ~1: All tests passed!`, exit 0. The joint gate would report 42+1 skipped with every machine pin green; "43/43" holds only if a human reads the `~1`. `skip: 'reason'` (truthy string) is the same vector; `skipTag:` needs a `dart_test.yaml` tag config (none exists today — see B). **Drill row**: plant `skip: true` on each harness test → record green (the hole), revert.

### B. Platform/tag exclusion from the default run — **silent today** (empirical)
`@TestOn('browser')` on a pinned file → default `flutter test` runs **zero** tests from it ("No tests ran. No tests were found.", exit 0 — demonstrated on `sso_client_test.dart`); the count gate reads file text, not run results → green. The repo already uses `@TestOn('browser')` on 6 files, so this is a live, idiomatic vector. `@Tags([...])` alone does not exclude (no `dart_test.yaml`, no `--exclude-tags` today), but a future tag config re-opens the same hole. **Drill row**: `@TestOn('browser')` on the harness file → gate green, file silent. **Machine close**: a static ban in the census gate on `skip:`, `skipTag`, `@Skip`, `@TestOn`, `@Tags` inside the harness file (the census already scans file text; the harness is currently free of all five tokens).

### C. grep pattern/flag drift (R3 manual gate) — **outside the joint command by construction**
The "exactly one hit" criterion is command-shape-dependent, and no test enforces it:
- quoted `grep -rn "'sso-admin-console'"` → 1 hit (correct form);
- bare `grep -rn "sso-admin-console"` → **2 hits** — it self-hits the census file's own split-literal line (`oidc_login_handle_success_census_test.dart:160`). "Improving" the grep to the bare form causes a **false alarm**, not a miss;
- `grep -rni` → 1 hit today (no case variants exist);
- regex metacharacters: the value is metachar-free (`-` is literal in BRE), so no silent broadening today; a future value containing `.`/`*` would broaden silently.
**Drill row**: run all three grep shapes against a planted case-variant / double-quoted literal and record which shapes trip (none machine-enforced; the drill's value is documenting the dependence).

### D. Count-gate relaxation — **`>=`/`>` forms are live vectors** (empirical)
- `==33` → `>=33` alone: **no-op** while the four per-file `==` pins hold (each fixes its file's count; the total follows). 
- `>30` alone: still red on single deletions (per-file pins fire).
- **Dangerous form (empirical)**: relax the per-file pin *and* the total — `ssoLoginCount >= 2` + total `> 30` → deleting one harness test → **10/10 green**. This is exactly the "relaxation + deletion" chain the drill must keep red.
- **Master key (mechanical)**: `censusCount == 10` → `>= 9` + total `> 30` → delete the literal-census test (the holder of the lib clause, test scan, and all four count pins) → the entire guard vanishes silently.
**Drill rows**: each relaxation alone (expected red via the surviving pins) and both chains (expected green — the documented hole).

### E. Census scan-target swap — **trips red on its own, silently with expectation co-mutation** (empirical)
- Plain `Directory('lib')` → `Directory('test')` → red: `exactly one lib/ site may carry the literal in constant mode — found {}` (the `length == 1` expectation self-detects). **The red message is misleading** ("no lib literals" reads like a pass condition for an absent plant); the drill should record it and explain the true cause. Same for `recursive: true` → `false` (`sso_client.dart` lives under `lib/api/`).
- **Silent variant**: swap **plus** `expect(libOffenders.length, 0)`/`isEmpty` and drop the site + declaration-line expects → green, and a lib plant goes unnoticed.
- **Scan-predicate tamper (mechanical)**: filter the scan to lines already containing `constantDecl` before recording → `libOffenders` = `{sso_client.dart: [82]}` → all three constant-mode expects pass while a plant in any other lib file is invisible.
**Drill rows**: plain swap (expected red, message-documented), swap+expectation (expected green — the hole), predicate tamper (expected green).

### F. Deletion of the negative-control pins themselves — **single pins are cross-covered; the block is the hole** (mechanical)
- Delete `expect(ssoLoginCount, 3)` alone → harness-test deletion still red via `== 33` total.
- Delete the total pin alone → still red via `ssoLoginCount == 3`.
- Delete the literal-census test itself → red via `censusCount == 10` **and** the total.
- **Hole**: delete the whole count-gate block *and* the lib-clause expects *inside* the still-10-test file → nothing else asserts them → green. Combined with D/E variants this is the master key (§2 D).
**Drill rows**: each single-pin deletion (expected red), the full-block deletion (expected green — the hole), and the D/E/F combination.

### G. `entry_ux_test.dart` deletion (incl. redirect-leg group `:174-220`) — **silent today**
No count pin covers the file; the joint run drops to 41/42 with exit 0. **Drill row**: delete the redirect-leg group → record green (the hole). **Machine close**: extend the existing count gate with `entryUxCount == 10` and total `43` (same `declRe`, no new test, census file stays at 10 tests).

### H. Literal-form evasions — **silent today** (empirical)
Double-quoted (`"sso-admin-console"`), source-split (`'sso-admin-' 'console'`, `'sso-admin-' + 'console'`), escape (`'\u0073so-admin-console'`), and case-variant forms all miss the `contains("'sso-admin-console'")` scan in both the test/ and lib/ clauses — the design's "contiguous or split" claim is empirically false (b6-1c's scan-1 precedent handles both quote styles; this census does not). **Drill rows**: each form in test/ and in lib/ → record green. If the single-source rule is meant to cover these, the needle must be assembled dynamically (the census file itself contains the bare value — a bare-value scan self-hits, see §2 C).

### I. Expected-green probe rows (b6-1c precedent)
The landed guard should carry permanent probe rows for the *accepted* invariants so they cannot silently change: FM8 line-shift above the declaration → stays green; a credential-less probe POST → `probePosts` parity row (after the §1 #2 fix); the R3 grep shapes (§2 C) as documented rows.

## 3. Verdict and priority fixes

- **The 11 failure modes' red signals are, for 9 of 11, genuine, deterministic, and inside the joint command** — no flaky or unrelated reds found. Two listed signals are mis-described (#11: reorder reds via the probe's thrown `SSOError(401)`, not "silently"; #2's renewal must re-send credentials — true for this client, but the credential-less bucket is unasserted).
- **Highest-value closes** (all test-only, one commit):
  1. `expect(h.probePosts, 0)` in harness test 3 (closes §1 #2 blind spot).
  2. Static silencing-ban in the census gate: harness file must not contain `skip:`, `skipTag`, `@Skip`, `@TestOn`, `@Tags` (closes §2 A/B).
  3. `entryUxCount == 10` + total `43` in the count gate (closes §2 G; makes the 43/43 claim machine-enforced).
  4. Add §2 D/E/F drill chains (relaxation+deletion, swap+expectation, pin-block deletion) to the documented drill — the landed gate's own `==` pins already make the plain forms red, so the drill's job is to keep the *combined* forms visible.
- **Accepted residuals to document explicitly** (mirror b6-1c's R-row convention): quote-form/split/escape literal evasions (§2 H), grep-shape dependence (§2 C), and the "misleading red" on scan-target swaps (§2 E).

## 4. Evidence log

| Mutation | Tree state | Result |
|---|---|---|
| joint gate (5 files) | landed | **43/43 green** |
| lib plant `'sso-admin-console'` | landed | red — `found {lib/zz_audit_plant.dart: [1], lib/api/sso_client.dart: [82]}` |
| lib plant `"sso-admin-console"` | landed | **green** (evasion) |
| test plant `'sso-admin-console'` | pre-landing strict mode | red — `Actual: {'test/zz_audit_plant_test.dart': [1]}` |
| test plant `"sso-admin-console"` | pre-landing | **green** (evasion) |
| test plant `'sso-admin-' 'console'` | pre-landing | **green** (evasion) |
| `skip: true` on harness test 1 | landed | count gate green; harness `+2 ~1: All tests passed!` exit 0 |
| `@TestOn('browser')` on `sso_client_test.dart` | pre-landing | "No tests ran. No tests were found." exit 0; count gate reads 17 decls |
| harness test 2 deleted | landed | red — `must hold 3 tests — found 2` |
| `ssoLoginCount >= 2` + total `> 30` + harness test deleted | landed | **green** (master-key form confirmed) |
| lib scan swapped to `Directory('test')` | landed | red — `found {}` (misleading message) |
| P1 probe GET 401 | probe file | `SSOError(401)` thrown, `onUnauthorized` fired once |
| P2 empty-script login | probe file | `RangeError` propagates out of `login()` |
| P3 credential-less POST | probe file | lands in `probePosts`, `loginPosts` stays 1 |
| P4 double dispatch, 1-entry script | probe file | `RangeError` + `loginPosts == 2` |

All mutations reverted; probe files deleted; tree left in the concurrent session's landed state (joint gate 43/43 at close).

## 5. Adversarial re-probe of the proposed closes (pre-landing, this pass)

All clauses from §3's priority-fix list were implemented in-tree, then re-probed for **false positives on legitimate code** and **residual evasions**. Joint gate at close: **43/43 green**; `dart analyze` clean for both touched files (4 pre-existing infos only); all mutations reverted.

### 5.1 Split-halves / bare-prefix lib matcher (M4 close)

| Probe | Mutation | Result | Note |
|---|---|---|---|
| EV-1 | `const String zz = 'sso-admin-' 'console';` in lib/ | **RED** | adjacent-literal concat, the M4 form |
| EV-2 | `final String zz = 'sso-admin-${c}';` in lib/ | **RED** | interpolation — closed by the bare prefix |
| EV-5 | `const String zz = "sso-admin-console";` in lib/ | **RED** | double-quoted — closes audit §1 #4's quote-form gap for lib/ |
| FP-A | `debugPrint('console');` in lib/ | **GREEN** | **false positive found & fixed**: the first matcher draft included the `'console'` half-token → red on legit code; token removed |
| FP-B | `const String consoleLabel = 'console';` in lib/ | **GREEN** | same, retest |
| EV-3/EV-4 | `String.fromCharCodes([…])`; `'\u0073so-admin-console'` in lib/ | **GREEN** | textually invisible — disclosed residual (§8) |
| self-hit | census file's own split-literal source (`"'sso-admin-" "console'"`) | n/a | lib/-only scan cannot see test/; additionally the census source contains neither half-token (verified by construction) |

Design note: the bare prefix `sso-admin-` subsumes the contiguous literal, both halves, concatenation, interpolation, and double-quoting — one matcher term, zero legit hits in lib/ today besides the declaration site (verified: `grep -rn "sso-admin-" lib/` → 1). `'console'` is **never** a valid scan token: it is a legitimate string in `lib/` debug code and in `test/` fixtures (`audit_event_row_test.dart:15`), and a test/-wide bare scan would self-hit the census file's own source.

### 5.2 Self-presence pin (M5 close)

| Probe | Mutation | Result | Note |
|---|---|---|---|
| SP-1 | full M5: walk + all constant-mode expects deleted | **RED** | pin fires |
| SP-2 | walk line replaced by `// for (final entity in Directory('lib')…` comment | **RED** | anchored statement regex rejects comment forms |
| SP-3 | `Directory( 'lib')` whitespace-padded | **RED** | FP class documented: whitespace-sensitive by design; `dart format` cannot produce the padded form |
| SP-4 | walk relocated to a helper call | **RED** | relocation forbidden — the clause must stay self-contained in the guard file |
| residual | exact statement text embedded in a block comment | **GREEN** (by construction) | deliberate sabotage class — repo-wide neuterability disclosure (§8) |

### 5.3 Silencing ban (audit §2 A/B close)

| Probe | Mutation | Result | Note |
|---|---|---|---|
| SB-1 | `skip: true,` on harness test 1 | **RED** | |
| SB-2 | `skip : true,` (space before colon) | **RED** | `skip\s*:` regex closes the whitespace variant |
| SB-3 | `@TestOn('browser')` on `sso_client_test.dart` | **RED** | the demonstrated "No tests ran, exit 0" vector is now banned on all four non-guard joint-gate files |
| SB-5 | `@Skip('probe')` on an `entry_ux` test | **RED** | |
| SB-4 | `@TestOn('vm')` on the harness (legit) | **GREEN** | whitelist: no false positive (also `@TestOn( 'vm' )` padded — green) |
| scope | census file itself silenced | GREEN (accepted) | the guard file is the trust boundary — FM15, §8 |

### 5.4 Harness unscripted-POST throw + `probePosts == 0` (M2b/M3b close)

| Probe | Mutation (production) | Result | Note |
|---|---|---|---|
| M2b | credential-less `/auth/login` POST added inside `login()` | **RED** | `StateError` at the `await`; `probePosts` also asserted 0 |
| M3b | `/auth/refresh` grant POST added inside `login()` | **RED** | cross-path renewal closed |
| M3b-c | `/auth/refresh` POST added inside the 401-expiry branch (`_handle`) | **RED** | branch-inserted renewal closed (first attempt silently no-op'd on indentation — 8 vs 6 spaces — re-probed correctly) |
| residual | renewal on a second internal `http.Client` / second client instance / deployed IdP | GREEN (by construction) | outside the mock's visibility — §8 M3b disclosure; the `[PROPOSED]` deployed-IdP drill remains the only complete proof |

### 5.5 entryUx pin + relaxation chains

| Probe | Mutation | Result | Note |
|---|---|---|---|
| EU-1 | `entry_ux_test.dart` redirect-leg group deleted (10→8 decls) | **RED** | `entryUxCount == 10` + total 43 — the 43/43 claim is now machine-enforced |
| REL-1 | total `==43` → `>40` **and** one harness test deleted | **RED** | per-file `==` pins dominate; the chain is not a master key |
| master key | delete the literal-census test + relax `censusCount`/total | GREEN (mechanical, structure unchanged from audit §2 D) | repo-wide accepted risk — §8 |

### 5.6 Closing state

Clauses as landed: harness = D9 filter + `probePosts == 0` in tests 1/3 + throw-on-any-unscripted-POST; census = bare-prefix lib matcher (no `'console'` token), anchored self-presence pin, silencing ban on the four non-guard files with `@TestOn('vm')` whitelist, `entryUxCount == 10` + total `== 43`. Census file stays at **10 tests**; harness at **3**; joint gate **43/43 green**; `lib/` untouched; `git diff` clean on all probe surfaces.

# Story S23 - An acknowledged FOUNDATIONAL security waiver stops the auth-keyword WARN until NEW mentions appear (R24) : report card

**Current grade: A**  (as of 2026-10-02, iteration 2)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-10-01        | A-    | first card for S23; T23.1 (23c12aa) doc-stats.ps1 waiver logic and T23.2 (471780a) Test-Case READ |
| 2    | 2026-10-02        | A     | T23.3 (99f46f0) scoped the waiver parse to the header and added body + DONE sub-cases; T23.4 (ae297ff) scoped the `Security review:` lookup to the same header; both prior [dev]/[mechanical] gaps closed |

## Assessment (this iteration)
Read (line numbers re-verified against the files as they are NOW): docs/STORIES.md:944-997 (S23 block),
docs/TASKS.md T23.1-T23.4 (headers at ~2078 plus the dependency notes at docs/TASKS.md:210-219),
doc-stats.ps1:297-351 (header split, Security review lookup, waiver logic), test-kit.ps1:4328-4425 (the S23 Test-Case
"S23: an acknowledged security waiver silences the auth-keyword WARN until NEW mentions appear (AC1-AC6)"), plus a grep of
doc-stats.ps1 for `waiver|authKw|Security review`. Not run by me: build and tests (assessor has no shell); T23.3/T23.4
commits judged from the files at HEAD, not from `git show`.

- Correctness: good. The header is carved once at doc-stats.ps1:297-298 (text before the first `## `) and reused by both
  the `Security review:` lookup (doc-stats.ps1:300, T23.4) and the waiver lookup (doc-stats.ps1:325, T23.3). `$authKw` is
  unchanged (doc-stats.ps1:318). M is a match count over the design doc with the header confirmation line removed
  (doc-stats.ps1:326: `$designRaw.Remove($wl.Index, $wl.Length)` - the index is valid because `$designHeader` is a prefix of
  `$designRaw`) plus STORIES.md (doc-stats.ps1:328). Validation is a shape regex plus `TryParseExact` with InvariantCulture
  (doc-stats.ps1:334-337), so an impossible date is rejected. The four branches (doc-stats.ps1:342-350) map to Behaviors 4-7:
  no line + M>0 -> WARN with the line to add; malformed -> WARN regardless of M; valid and M<=N -> `$securityWaiverFact`
  only; M>N -> WARN with `<M-N> new ...` and the refreshed line. Logic lives only in the NOT-REQUIRED branch
  (doc-stats.ps1:303), so REQUIRED (doc-stats.ps1:363) and DONE (doc-stats.ps1:351) ignore the line with no extra code.
- Acceptance: all in test-kit.ps1. AC1 test-kit.ps1:4354-4359 (WARN, `auth-keyword hits: 3`, line to add). AC2
  test-kit.ps1:4361-4366 (silent; fact string; `now 3` proves the line's own `auth` is excluded). AC3 test-kit.ps1:4368-4373
  (anchored on `still holds here\. - 2 new`, so a sign-flipped delta fails). AC4 test-kit.ps1:4375-4382 (bad date, missing N;
  `malformed`, WARN kept, not honoured). T23.3(a) test-kit.ps1:4384-4395 (a BODY line with the prefix is not honoured, not
  `malformed`, and is counted: expected M = 4). AC5 test-kit.ps1:4397-4402 (REQUIRED keeps its finding). T23.3(b)
  test-kit.ps1:4404-4409 (DONE + waiver line: no waiver reading, no DONE finding) - this closes the "DONE not exercised"
  gap from iteration 1. AC6 test-kit.ps1:4411-4423 (fact line untagged; dad-run-summary's findings count equals the direct
  `[tag]` count). Residual: AC2's "line added exactly as AC1's WARN printed it" is covered by a fixed-date literal
  (test-kit.ps1:4347), not by harvesting AC1's output - equivalent in shape; AC7 and the T23.2 mutation check cannot be
  verified by me without a shell.
- Design: in scope. Only doc-stats.ps1 and test-kit.ps1 changed. The T23.4 header-scoping of `Security review:` is
  human-approved per docs/TASKS.md:217-219 and is consistent with the story's "header line" wording. Behavior 8 (agents never
  write the confirmation line) still holds as far as I can tell; the human has not yet added the line to docs/DESIGN.md.
- Quality: improved. The header variable is computed once and shared; comments state the why (doc-stats.ps1:299,
  doc-stats.ps1:319-324); PS 5.1-safe (`$dt` pre-initialised at doc-stats.ps1:336, no ternary). One remaining cosmetic
  wart: malformed with M = 0 still emits `$base` (doc-stats.ps1:345), whose text claims the docs "mention auth/login/..." -
  spec-conformant ("regardless of M") but the message may then be untrue. Low severity.
- Hygiene: ASCII; fixture writer `Set-WaiverDesign` (test-kit.ps1:4336-4343) is local to the case; sandbox removed in
  `finally` (test-kit.ps1:4424). The old `$ds` re-join duplication is gone (AC6 now only joins for dad-run-summary at
  test-kit.ps1:4418, which is a different script). No manifest or dependency changes.
- Verification mode: no AC touches real machine state - doc-stats and dad-run-summary only read docs, and every fixture is
  a New-Sandbox temp dir. All ACs are code-review verified against the Test-Case; no live run observed by me.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [human] Add the `Security waiver confirmed: <date> (human; auth-keyword hits: <N>)` line to the docs/DESIGN.md header via
   /design (unlock), copying the exact line doc-stats prints in its WARN on the kit, counted AFTER S22/S23 text is in
   docs/STORIES.md (docs/STORIES.md:996-997). Until then the kit's own audit keeps raising the WARN this story retires. Also
   confirm the T23.2 mutation check (force the M<=N branch to WARN -> AC2 fails) was actually performed.
2. [dev] Optional, low value: when the waiver line is malformed and M = 0, word the WARN so it does not claim auth mentions
   exist (doc-stats.ps1:345), and add a sub-case next to AC4 (test-kit.ps1:4375-4382).
3. [mechanical] Optional: make AC2 round-trip literal by building `$valid` from AC1's harvested line (test-kit.ps1:4347 vs
   test-kit.ps1:4359); test-only, no behaviour change.

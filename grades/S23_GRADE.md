# Story S23 - An acknowledged FOUNDATIONAL security waiver stops the auth-keyword WARN until NEW mentions appear (R24) : report card

**Current grade: A-**  (as of 2026-10-01, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-10-01        | A-    | first card for S23; T23.1 (23c12aa) doc-stats.ps1 waiver logic and T23.2 (471780a) Test-Case READ |

## Assessment (this iteration)
Read (line numbers verified against the files as they are NOW): docs/STORIES.md:944-997 (S23), docs/TASKS.md:2059-2097
(T23.1, T23.2), doc-stats.ps1:219-220 (initialiser), doc-stats.ps1:296-358 (security header block incl. the new waiver
logic), doc-stats.ps1:747-757 (STATE FACTS print), dad-run-summary.ps1:140-148 (findings count, unchanged),
test-kit.ps1:4272-4304 (pre-existing admissibility case, untouched) and test-kit.ps1:4306-4383 (the new case), plus a grep
of docs/DESIGN.md for `Security (review|waiver)`. Not run by me: build/tests and `git show` (assessor has no shell;
commits judged from the files at HEAD).

- Correctness: good. `$authKw` is reused unchanged (doc-stats.ps1:314). M is a MATCH COUNT, not a presence test, over the
  design doc with every `Security waiver confirmed:` line blanked first (doc-stats.ps1:320-321) plus STORIES.md
  (doc-stats.ps1:322) - exactly Behavior 2, including the self-exclusion that prevents M = N+1 forever. Validation is
  shape regex + `TryParseExact` with InvariantCulture (doc-stats.ps1:328-333), so `2026-13-45` is rejected. The four
  branches (doc-stats.ps1:336-344) map 1:1 to Behaviors 4-7: no line + M>0 -> WARN with the line to add; malformed ->
  WARN regardless of M; valid and M<=N -> no `$f` entry, fact string set; valid and M>N -> WARN with `<M-N> new ...` and
  the re-confirm line. `$base` (doc-stats.ps1:324) is the pre-existing text, so the old Test-Case still matches. The
  logic sits only in the NOT-REQUIRED branch (doc-stats.ps1:299), so REQUIRED/DONE ignore the line with no extra code
  (Behavior 3). The fact prints untagged in STATE FACTS (doc-stats.ps1:757) right after the design Status line, as DECIDED
  in docs/STORIES.md:992-997; dad-run-summary.ps1:147 is untouched.
- Acceptance: AC1 test-kit.ps1:4332-4337 (WARN, `auth-keyword hits: 3`, the exact line to add; 3 = 2 design + 1 STORIES
  so the sum is proven). AC2 test-kit.ps1:4339-4344 (`now 3` proves the confirmation line's own `auth` is excluded). The
  second half of AC2 ("the line added exactly as AC1's WARN printed it -> still silent") is only covered indirectly: the
  test uses a fixed-date literal, not the string harvested from AC1's output - equivalent in shape, but not literally that
  round-trip. AC3 test-kit.ps1:4346-4351, anchored on `still holds here\. - 2 new` so a sign-flipped delta fails. AC4
  test-kit.ps1:4353-4360 (bad date and missing N, each checked for `malformed`, WARN kept, not honoured). AC5
  test-kit.ps1:4362-4367 (REQUIRED kept, no `not re-raised`, no `malformed`); DONE is not exercised. AC6
  test-kit.ps1:4369-4381 calls both scripts directly and asserts the fact line is untagged and run-summary's count equals
  the direct `[tag]` count. AC7 and T23.2's mutation check (M<=N branch forced to WARN -> AC2 fails) are not verifiable by
  me without a shell.
- Design: in scope. Only doc-stats.ps1 and test-kit.ps1 changed per the tasks; docs/DESIGN.md carries no
  `Security waiver confirmed:` line (grep hits only docs/DESIGN.md:4, :241, :244, :1577), i.e. agents did not write it
  (Behavior 8). Consequence: on the kit itself the WARN still fires until the human adds the line via /design.
- Quality: compact, commented with the why (doc-stats.ps1:315-318), PS 5.1-safe (`[ref]$dt` pre-initialised at
  doc-stats.ps1:330, no ternary). Two edge gaps: (a) the `$wl` match (doc-stats.ps1:319) is `(?im)^...` over the WHOLE
  design doc, not the header, and takes the FIRST hit - a body line that happens to start with `Security waiver confirmed:`
  (e.g. a documented example of the format) would be parsed, and a placeholder like `<YYYY-MM-DD>` would trip `malformed`;
  the blanking at doc-stats.ps1:320 also removes every such line from M. (b) malformed + M = 0 still emits `$base`, whose
  text claims the docs "mention auth/login/..." - spec-conformant (T23.1 says "regardless of M") but the message is then
  untrue.
- Hygiene: ASCII; fixture writer mirrors the neighbouring case's shape (test-kit.ps1:4314-4322 vs test-kit.ps1:4282-4289);
  sandbox removed in `finally` (test-kit.ps1:4382); STORIES.md fixture removed between sub-cases when `$null`
  (test-kit.ps1:4320). Minor duplication: the case defines `$ds` (test-kit.ps1:4313) then re-joins the same path inline at
  test-kit.ps1:4371.
- Verification mode: no AC touches real machine state - doc-stats and dad-run-summary only read docs, and all fixtures are
  New-Sandbox temp dirs. Every AC above is code-review verified against the Test-Case; no live run observed by me.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [human] Add the confirmation line to docs/DESIGN.md via /design (unlock), copying the exact line doc-stats now prints in
   its WARN on the kit (M must be counted AFTER S22/S23 text is in docs/STORIES.md, per docs/STORIES.md:996-997). Until
   then the kit's own audit keeps raising the WARN this story was written to retire. Also confirm the T23.2 mutation check
   was actually performed.
2. [dev] Restrict the confirmation-line parse to the header (e.g. text before the first `## ` heading) at
   doc-stats.ps1:319-320, so a documented example of the format in the body is neither parsed nor blanked from M; add a
   sub-case to test-kit.ps1:4306-4383 with a body example line. Optionally add a DONE + confirmation-line sub-case next
   to AC5 (test-kit.ps1:4362-4367), since Behavior 3 names both REQUIRED and DONE.
3. [mechanical] Reuse `$ds` at test-kit.ps1:4371 instead of re-joining `doc-stats.ps1`; no behaviour change.

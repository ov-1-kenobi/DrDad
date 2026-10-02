# Story S22 - doc-stats flags a contract that is REFERENCED but never PINNED (R24) : report card

**Current grade: A**  (as of 2026-10-02, iteration 3)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-10-01        | A-    | first card for S22; T22.1 (da3cecf) doc-stats.ps1 check and T22.2 (23e1015) Test-Case READ |
| 2    | 2026-10-01        | A-    | cites rewritten as full relative paths; doc-stats.ps1 cites after line 250 shifted +1 by hygiene's comment edit; mechanical item applied; AC5 confirmed by a live doc-stats run |
| 3    | 2026-10-02        | A     | T22.3 (07617ee) landed: reference regex suffix now `[A-Za-z0-9]+`, closing iter-2 suggestion 1; two new assertions added |

## Assessment (this iteration)
Read now (line numbers re-verified against the current files, 2026-10-02): docs/STORIES.md:904-934 (S22 Behavior/AC),
docs/TASKS.md:2029-2076 (T22.1-T22.3), doc-stats.ps1:240-279 (the whole referenced-but-not-pinned block),
test-kit.ps1:4204-4280 (Test-Case "S22: doc-stats flags contract ids REFERENCED but never PINNED (AC1-AC4)"). Not run by me:
build/tests (no shell), so the green suite is taken from the T22.3 close, not observed.

- Correctness: good. Reference regex at doc-stats.ps1:264 is `\bC[0-9]+[a-z]?(?:-[A-Za-z0-9]+)?\b`, run through the
  case-sensitive `[regex]::Matches`, so the hyphen suffix accepts the same alphabet as the heading regex
  (`$contractHeadingRx`, reused at doc-stats.ps1:256). `### C7-API:` + reference `C7-API` resolves exactly
  (doc-stats.ps1:267). Resolve rule: exact id or `^C[0-9]+` parent (doc-stats.ps1:266-267), so C4a -> C4 and C3-b -> C3.
  Gate is only the `## Contracts` section (doc-stats.ps1:254), DRAFT and LOCKED alike; grade cards are not scanned (stated
  doc-stats.ps1:252, and the sources list at :258 is only DESIGN/STORIES/TASKS); first location per file per id
  (`$seenHere`, doc-stats.ps1:262,268); 8-entry cap with ` ...` (doc-stats.ps1:275-276); finding text at :277.
- Acceptance:
  - AC1 (finding names each id with file:line, first line per file only; fires in DRAFT and LOCKED; pinning clears it):
    test-kit.ps1:4222-4237, exact string at :4227 (`C5 (DESIGN.md:8, STORIES.md:4, TASKS.md:5)`; DESIGN.md:9 is deliberately absent).
  - AC2 (sub-id resolves via parent): test-kit.ps1:4239-4244 (C4a, C3-b).
  - AC3 (C2PA, C#, C++ and lowercase c<n> are not ids): test-kit.ps1:4256-4260, lowercase ids built at runtime (:4257).
  - AC4 (no `## Contracts` section -> silent): test-kit.ps1:4262-4267.
  - Cap: test-kit.ps1:4269-4278 (10 counted, exactly 8 entries shown, ` ...` present).
  - T22.3 assertions: (a) test-kit.ps1:4248-4251 pinned uppercase-suffix id not flagged; (b) :4252-4254 an unpinned one IS
    named (guards against the regex simply going silent). The id is built by concatenation (:4247) so the suite text carries
    no dangling id. AC5 (kit repo silent) confirmed live in iter 2; AC6 and the mutation checks need a shell, unverified by me.
- Design: in scope. Heading regex, `-Contract <id>` and DESIGN.md untouched by T22.3. One check, no second heading regex
  (the heading regex is reused, doc-stats.ps1:256). Same section gate as the empty-Contracts finding (doc-stats.ps1:241-243).
- Quality: compact, why-comments at doc-stats.ps1:245-253, PS 5.1-safe, no dead code. Residual behaviour: a prose word like
  `C1-Based` is read as sub-id `C1-Based`, which resolves only via parent `C1` - harmless when C1 is pinned, a (correct)
  WARN when it is not. This is now documented at doc-stats.ps1:250-252, though the wrap is ragged (`likewise a capitalised`
  alone on :251, a very long :252).
- Hygiene: only doc-stats.ps1 and test-kit.ps1 touched; ASCII; fixtures live in a temp sandbox removed in `finally`
  (test-kit.ps1:4279).
- Verification mode: no AC touches real machine state (reads docs only; fixtures are temp sandboxes). Code-review plus
  fixture-test evidence; AC5 was live-run read-only on the kit repo in iter 2.

## Suggestions (prioritized; tag each so the team knows who acts)
1. ~~[dev] Make heading and reference suffix formats agree.~~ APPLIED by T22.3 (doc-stats.ps1:264, test-kit.ps1:4246-4254).
2. [human] Confirm the T22.2/T22.3 "revert the change and the assertion fails" mutation checks were actually performed
   (I cannot run them); low risk since assertion (b) and the cap case would expose a silent regex.
3. ~~[mechanical] Note that a capitalised word after a hyphen parses as a sub-id.~~ APPLIED (doc-stats.ps1:250-252);
   optional leftover: re-wrap that comment (:251 is a one-line fragment, :252 is overlong).

# Story S26 - upgrade-project refuses to run against a kit checkout (R15) : report card

**Current grade: A**  (as of 2026-10-01, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-10-01        | A     | first card for S26; T26.1 (565eb49) upgrade-project.ps1 guard and T26.2 (8cd72b2) Test-Cases READ |

## Assessment (this iteration)
Read (line numbers verified against the files as they are NOW): docs/STORIES.md:1064-1099 (S26), docs/TASKS.md:2197-2225
(T26.1, T26.2), upgrade-project.ps1:1-110 (header, param, the new guard, and the steps it precedes), test-kit.ps1:4770-4871
(end of the repoint case, the S26 helpers and the three S26 cases), plus a grep of test-kit.ps1 for `-ProjectDir $kit`.
Not run by me: build/tests and `git show` (assessor has no shell; commits judged from the files at HEAD).

- Correctness: good. The guard (upgrade-project.ps1:32-38) sits directly after `$proj = (Resolve-Path ...)`
  (upgrade-project.ps1:24) and BEFORE the CLAUDE.md check (upgrade-project.ps1:40), the stamp/legacy-marker migration
  (upgrade-project.ps1:49-57), `docs\` creation (upgrade-project.ps1:61), the .mcp.json repoint (upgrade-project.ps1:80-94)
  and git (upgrade-project.ps1:107+) - so "changes NOTHING" holds by construction, as the Dev notes ask. Only
  `$kit`/`$templates` path strings are computed before it (no I/O). It keys on `$proj`, never `$kit`, requires all three
  markers with the right types (Leaf, Leaf, Container), prints one Write-Host line and `exit 2`. The comment
  (upgrade-project.ps1:26-31) records the why and the exit-code map; header line added at upgrade-project.ps1:12.
- Acceptance: AC1 -> "S26 AC1: upgrade-project refuses a kit checkout - exit 2, one message line, every file
  byte-identical" (test-kit.ps1:4801-4830): exit 2 (:4812), exactly one non-blank line (:4814), exact message with `-ceq`
  (:4815), SHA256 + folder snapshot equal (:4816), and explicit absence of .dad-kit-version, .git, docs\, .gitignore
  (:4817-4820). The fixture's stale .mcp.json path (test-kit.ps1:4787) means a missing guard WOULD rewrite it, so the
  snapshot check has teeth. AC2 -> test-kit.ps1:4832-4858 (Push-Location to another cwd, same asserts, and the cwd stays
  empty at :4850) plus the all-three-markers check (:4853-4856). AC3 -> test-kit.ps1:4860-4871 (exit 0, no message, stamp
  written) on top of the untouched existing upgrade-project cases. AC4 -> the only `-ProjectDir $kit` hits in the suite are
  doc-stats/tidy at test-kit.ps1:3705-3710, none for upgrade-project; the fixture is also asserted under %TEMP%
  (test-kit.ps1:4805). AC5 and T26.2's mutation check (remove the guard -> AC1 fails) are not verifiable by me.
- Design: in scope - only upgrade-project.ps1 and test-kit.ps1 touched, per docs/STORIES.md:1084-1085. One small addition
  beyond the task text: trailing-separator trimming for the message only (upgrade-project.ps1:34-35), with drive roots
  kept; it is tested (test-kit.ps1:4822-4828) and only affects display, so acceptable. No pinned contract touched.
- Quality: readable, PS 5.1-safe, `-LiteralPath` throughout. The test used `-ceq` on the full line instead of the
  task's suggested `.Contains()` - stricter and fine since `$p` and the resolved path share a form. Helpers
  `New-S26KitSandbox` / `Get-S26Snapshot` (test-kit.ps1:4777-4798) remove duplication across cases.
- Hygiene: ASCII; sandboxes removed in `finally` (test-kit.ps1:4829, :4857, :4870); fixture .mcp.json written UTF-8 no BOM
  (test-kit.ps1:4790). The S26 AC checkboxes are still `[ ]` (docs/STORIES.md:1088-1095) although the header says DONE;
  other stories in the file tick theirs.
- Verification mode: AC4 is the one AC about real machine state (the real kit repo). It is code-review verified
  2026-10-01, not live-run - by grep of test-kit.ps1 (no upgrade-project call with `$kit` as target) and the %TEMP%
  assertion at test-kit.ps1:4805. AC1-AC3 run only on New-Sandbox temp dirs; I did not see a run, so they are
  code-review verified against the Test-Cases.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [human] Decide the QUESTION at docs/STORIES.md:1098-1099: the step-3 CRLF rewrite of CLAUDE.md affects NORMAL projects
   too and is out of scope here - file it as its own story so it is not lost.
2. [dev] Tighten the partial-marker check: assert `$code3 -eq 0` (not just `-ne 2`) at test-kit.ps1:4855, and add the two
   other single-missing-marker variants (no VERSION, no install.ps1) - today only the missing `global\commands\` case is
   proven, so dropping either Leaf test from upgrade-project.ps1:32 would go uncaught.
3. [mechanical] Tick S26's AC checkboxes at docs/STORIES.md:1088-1095 to match the DONE status (via the STORIES owner).

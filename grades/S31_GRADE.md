# Story S31 - Every git-dependent test-kit case really runs, and the failures hiding behind the broken guard are fixed : report card

**Current grade: B+**  (as of 2026-10-09, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-10-09        | B+    | initial grade at story close (T31.1-T31.9 done; 278 passed, 0 failed, 0 skipped) |

## Assessment (this iteration)
- Correctness: the root cause is fixed. `$haveGit` is hoisted to test-kit.ps1:28, ahead of every case, so the guards no longer read `$null`. Of the 17 formerly vacuous cases, the ones I checked now carry `Skip-Case "git is not installed"` (e.g. test-kit.ps1:330, 2267, 2302, 2650, 2707, 2765). Two product fixes are in: the method pattern in recover-lost.ps1:68 (the parameter list is `[^;{}]*`, so it no longer spans newlines and swallows later methods), and the hand-tick `$tickPattern` at doc-stats.ps1:773, which now matches `[x]` before the task id or `Status: DONE` after it.
- Acceptance:
  - AC1 covered. `Find-EarlyGuardViolations` (test-kit.ps1:97-145) is AST-based and handles `-not` and `!`. The case "no Test-Case guard reads a variable before it is first assigned (S31)" (test-kit.ps1:147) includes three seeded mutations: assignment below the guard, the `!` form, and a clean control.
  - AC2 covered. "S31 AC2: with no git on PATH the formerly vacuous cases report SKIP, not PASS" (test-kit.ps1:159) runs the real Test-Case and Skip-Case in a child with a git-free PATH. It asserts `pass=0 fail=0 skip=1`. It also checks the old `return` shape still gives `pass=1`, which is the mutation check.
  - AC3 covered per the story. I did not read the VERDICTS line itself: grep returned only a truncated match at docs/STORIES.md:1278, so I could not confirm its text. T31.5, T31.6 and T31.8 are fixture fixes and T31.7 is a product fix, per `git log` subjects.
  - AC4 covered. "S31 AC4: recover-lost reports a deleted method with an EMPTY body as GONE" (test-kit.ps1:2761) uses `{ }` methods with no `;` anywhere and asserts exit 1 and that Case3 appears in a GONE block.
  - AC5 is from the orchestrator's report (278 passed / 0 failed / 0 skipped); I did not re-run it.
- Design: no DESIGN prose was touched, which matches the story's "Not changed" line. The work belongs to R28 (docs/DESIGN.md:208) and R29 (docs/DESIGN.md:227). No scope creep seen.
- Quality: the detector is good and its comments explain why. Two blemishes:
  - Many guards still use a bare `return` and are still silent on a git-less machine: test-kit.ps1:6373, 6562, 6594, 6629, 6651, 6748, 6793, 6833, 6871, 6899, 6970, 7011, 7873, 7908 and 7957. They are not early-guard bugs, since `$haveGit` now exists. They do count as PASS without git, which is the exact failure class S21 Behavior 4 forbids.
  - test-kit.ps1:2840 uses an inline `Get-Command git` with a comment saying `$haveGit` "is assigned far below this case". That is now false, because it is assigned at line 28. The comment is stale and the line is redundant.
- Hygiene: CHANGELOG 0.59.2 is present. The `$unitPatterns` regex at recover-lost.ps1:68 is long but commented. No dependency or manifest issues seen. Git was available, so skip-on-no-git was not exercised live in the full suite; the AC2 child-process case covers it.
- Verification mode: no AC touches real machine state. All fixtures run under `New-Sandbox` and the AC2 child only narrows `$env:Path` in its own process, restoring it in `finally` (test-kit.ps1:181-185). Verified live-sandboxed.

## Suggestions (prioritized)
1. [dev] Convert the remaining `if (-not $haveGit) { return }` guards (list above, test-kit.ps1:6373 to 7957) to `Skip-Case "git is not installed"` so a git-less machine counts SKIP rather than PASS. The AC2 count check (`-ge 17`) would then need to rise or become a "no bare return guard" assertion.
2. [mechanical] Fix or remove the stale comment and redundant inline `Get-Command git` at test-kit.ps1:2840; use `$haveGit`.
3. [human] Decide whether to extend `Find-EarlyGuardViolations` beyond the exact `if (-not $x) { return }` shape. It currently ignores guards using `-eq $false`, `Skip-Case` bodies and nested conditions.

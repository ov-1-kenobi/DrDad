# Story S32 - The remaining git-dependent test-kit guards report SKIP, never a silent PASS, when git is missing : report card

**Current grade: A-**  (as of 2026-10-10, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-10-10        | A-    | initial grade at story close (T32.1, T32.2 done; 279 passed, 0 failed, 0 skipped per orchestrator, not re-run) |

## Assessment (this iteration)
- Correctness: the story closes S31 suggestion 1 (grades/S31_GRADE.md:26). The 15 former bare returns (the S31 list at grades/S31_GRADE.md:20) are now `Skip-Case`. Examples: test-kit.ps1:6582, 6614, 6649, 6671, 6768, 6813, 6853, 6891, 6919, 6990, 7031, 7893, 7928, 7977. I counted 38 lines reading `Skip-Case "git is not installed"` in test-kit.ps1 (350 through 7977). The 17 earlier conversions plus 15 here, plus the 6 inline `Get-Command git` forms, account for the 38.
- Acceptance:
  - AC1 met. A grep for `haveGit\)\s*\{\s*return` in test-kit.ps1 matches only string literals: the seeded mutations at test-kit.ps1:170, 172 and the old-shape stand-in at test-kit.ps1:213. No real guard remains.
  - AC2 met. `Find-EarlyGuardViolations` gained a `-cmatch "^have[A-Z]"` branch (test-kit.ps1:137-142). The case "no Test-Case uses a bare return on a prerequisite flag (S32)" (test-kit.ps1:165-178) runs the check on the real file and four mutations: (a) `-not` form and (b) `!` form must each report exactly one finding, (c) a `Skip-Case` guard and (d) a non-flag variable must report none. The existing S31 case and its mutations are untouched (test-kit.ps1:153-163).
  - AC3 met. The case "S31 AC2: with no git on PATH the formerly vacuous cases report SKIP, not PASS" (test-kit.ps1:179) now asserts `$n -ge 38` (test-kit.ps1:184), which equals the real count. The threshold is tight, so a regression that drops a guard is caught. The child-process stand-in still asserts `pass=0 fail=0 skip=1` (test-kit.ps1:211), and the old `return` shape still gives `pass=1` (test-kit.ps1:214).
  - AC4 is from the orchestrator's report (279 passed, 0 failed, 0 skipped; 278 plus one new case). I did not re-run it.
- Design: only test-kit.ps1 changed, as the story's Data line requires. No DESIGN prose was touched, and it follows S21 Behavior 4. No case removed, no assertion weakened.
- Quality: the detector is a small addition to the existing AST walk, and its comment (test-kit.ps1:137-139) states what it deliberately skips. Residual gaps are listed below.
- Hygiene: no manifest or dependency impact.
- Verification mode: no AC touches real machine state. The AC3 child only narrows `$env:Path` in its own process and restores it in `finally` (test-kit.ps1:201-205). Verified live-sandboxed, as in S31.

Remaining bare-return or non-SKIP prerequisite guards I found:
- test-kit.ps1:1966-1967: `$haveCopilot` compound guard, `if (-not ((Test-Path $hookFile) -or $haveCopilot)) { return }`. It is a deliberate exclusion, because the detector only matches a single negated variable. On a box with neither the hook file nor copilot, this case counts as PASS.
- test-kit.ps1:6485 and 6519 use `Skip-Case "git not available"`, a different message from the standard string. They are correct SKIPs, but the `-ge 38` counter does not count them, and the wording is inconsistent.
- test-kit.ps1:6294 and 6736 use the positive `if ($haveGit) { ... }` form. I did not read their bodies, so I cannot say whether a git-less run silently skips assertions inside them.
- Optional-tool guards (python, dotnet, ollama, `$LASTEXITCODE`) are not covered, by design (test-kit.ps1:138-139). I did not enumerate them.

## Suggestions (prioritized)
1. [dev] Replace the `$haveCopilot` compound guard at test-kit.ps1:1967 with a `Skip-Case` (for example "copilot harness not installed"), and extend the detector (test-kit.ps1:127-132) to cover compound `-not (... -or $have*)` guards, with a mutation case.
2. [dev] Check the positive-form `if ($haveGit) {` blocks at test-kit.ps1:6294 and 6736. If any assertion is skipped silently when git is missing, add an `else { Skip-Case ... }`.
3. [mechanical] Normalise `Skip-Case "git not available"` at test-kit.ps1:6485 and 6519 to `"git is not installed"`, then raise the test-kit.ps1:184 threshold to 40.
4. [human] Decide whether the python, dotnet and ollama optional-tool bare returns should also become SKIP, which would extend S21 Behavior 4 beyond git, or stay silent PASS by design.

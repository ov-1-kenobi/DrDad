# Story S15 - doc-stats' root-junk check must not flag the kit's own scripts (R24) : report card

**Current grade: A-**  (as of 2026-09-30, iteration 2)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-09-30        | B+    | first card for S15; T15.1 (cccaa27) and T15.2 (21da04c, scope completed in a second round) READ |
| 2    | 2026-09-30        | A-    | human narrowed the exemption to the kit root ($PSScriptRoot); hygiene changed doc-stats.ps1 and split/inverted the test-kit S15 cases; re-read both |

## Assessment (this iteration)
Read: doc-stats.ps1:28-70 (Get-ProjectJunk, -Junk switch), tidy.ps1 lines 5, 38, 42 (consumes `doc-stats -Junk`), test-kit.ps1:3316-3323 (junk-class case), 3357-3427 (S15 case, three blocks). Not run: build and suite (assessor is read-only), so "0 failed" is not re-proven here.

- Correctness: good. doc-stats.ps1:39 computes `$isKitRoot` by comparing the scanned root with `$PSScriptRoot`, both trimmed of trailing slashes, case-insensitive (-ieq). Only when true does line 41 drop `^dad-.+\.(ps1|cmd)$` from `$stray`. Non-script dad-* names (dad-notes.md, dad-summary.txt) stay flagged even at the kit root because the extension is anchored. A user project's own dad-run-summary script is now flagged, which matches the human's decision.
- Acceptance:
  - AC1 covered. test-kit.ps1:3403-3416 plants dad-run-summary.ps1/.cmd in a NON-kit sandbox and asserts the ad-hoc finding fires (3412), tidy's dry run names them (3414) and deletes nothing (3415). The kit-root half of AC1 is covered by 3425-3426 (tidy on the kit does not name dad-run-summary).
  - AC2 covered. Non-kit root: 3373-3378 assert ps1/.cmd AND dad-notes.md/dad-summary.txt are all stray; 3316-3323 assert the stray finding names dad-run-summary and dad-notes.md in a non-kit root. Kit-root emulation: 3382-3397 copy doc-stats.ps1 into a sandbox so `$PSScriptRoot` equals the scanned dir, then assert scripts (including a future dad-other-notes) are exempt while IMPLEMENTATION_SUMMARY.md, dad-notes.md and dad-summary.txt stay flagged. 3399-3400 also pin the upper-case plus trailing-slash spelling.
  - AC3 covered by code. 3419-3426 run -Findings, -Junk and tidy against the real `$kit`: no ad-hoc finding, no dad-* script in StrayFiles, no dad-run-summary in tidy. This is a read-only live scan.
- Design: now matches S15 Behavior more literally than iteration 1 ("only the kit's files"). The earlier project-wide false-negative window is closed. The exemption keys on location, not on kit markers such as models.json, which is simple and good enough. The test technique (copy the script so it is its own kit root) exercises the real code path without a hook in production code.
- Quality: small, well commented (doc-stats.ps1:36-38 states the rule and the reason). One scan point serves -Findings (434), -Junk (67) and tidy (38), so no second edit. Test blocks now define `$ds` where needed (3406, 3419), which retires the old fragility about reusing a variable across blocks. Minor: the `.ToUpper() + "\"` case at 3399 is meaningful on Windows only, which is fine for this Windows-only kit.
- Hygiene: test text ASCII; no manifests or dependencies touched; hypothetical names in this card are written without script extensions by design. CLAUDE.md "Test-Case for any bug fix" satisfied.
- Verification mode: no AC touches real machine state. Fixtures use New-Sandbox temp dirs; AC3 reads the real kit root read-only (code-review plus a read-only live scan inside the test). Nothing was live-run by this assessor.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [human] RESOLVED: scope decision made (kit root only) and implemented at doc-stats.ps1:36-42. No further action.
2. SUPERSEDED: the "pin project-wide scope" test idea no longer applies; the tests now pin the opposite (non-kit flags, kit root exempts).
3. DONE: `$ds` is re-defined per block (test-kit.ps1:3406, 3419).
4. [dev] Safety check for tidy on a kit clone not at `$PSScriptRoot`: tidy.ps1:38 invokes the `doc-stats.ps1` found beside tidy, so a clone scanned by its own scripts is fine (PSScriptRoot equals root). The risk is a path-spelling mismatch (junction, subst drive, 8.3 short name, or -ProjectDir resolved through a symlink): `Resolve-Path` at doc-stats.ps1:67 and `$PSScriptRoot` could differ, the exemption silently drops, and `tidy` (non-dry-run) could then list kit scripts as deletable. Consider normalising both sides (e.g. resolve `$PSScriptRoot` through Resolve-Path too) and/or have tidy refuse to delete files whose root holds this script. Low probability, high cost if hit.
5. [dev] Another gap: running a kit-clone's doc-stats against a DIFFERENT kit checkout (for example an installed copy in %USERPROFILE%, or a worktree) flags that checkout's scripts as stray in -Junk and -Findings. Acceptable by the decision, but worth one sentence in doc-stats' header comment or docs so users are not surprised; optionally add a test for it (the non-kit case at 3373 already behaves this way, so only a comment is needed).

# Story S5 - Rename the distribution package DAD-kit -> DrDad (cosmetic only) : report card

**Current grade: A-**  (as of 2026-09-20, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-09-20        | A-    | initial grading of T5.1 rollup             |

## Assessment (this iteration)
- **Correctness vs intent:** Matches the Goal exactly. `package-kit.ps1:30` `$name = "DrDad-v$version"`
  (was `DAD-kit-v$version`); the two header-comment usage examples at `package-kit.ps1:6-7` now read
  `-> ..\DrDad-v<version>.zip` / `-> D:\transfer\DrDad-v<version>.zip`. `package-kit.cmd:3-4`'s mirrored
  header comments were also updated (this was outside T5.1's literal Touches list but is the same class of
  edit, correctly done as a QA follow-up).
- **Acceptance coverage:**
  - AC1 (folder/zip named `DrDad-v<version>`): met - `package-kit.ps1:30,77,83` all derive the output name
    from the single `$name` variable, so both `-Folder` and zip mode inherit the rename.
  - AC2 (placeholder inside packaged `.mcp.json` etc. still says `DAD-kit`, untouched): met and
    double-checked - `package-kit.ps1:58-64`'s own move-safety self-check still asserts `$t -match 'DAD-kit'`
    against `.mcp.json` / `templates\_common\.mcp.json` / `templates\unity\.mcp.json`, and per the QA note
    this was run for real against a scratch `-OutDir`, confirming the generated output still contains the
    literal placeholder untouched. `test-kit.ps1:596-606` ("dev-path placeholder preserved in ALL
    configs") and `test-kit.ps1:622` (packaged `.mcp.json` still matches `DAD-kit`) independently re-check
    the same invariant, so this is now covered from two directions.
  - AC3 (test-kit.ps1 assertion updated, gate passes): met - `test-kit.ps1:614` now reads
    `$out = Join-Path $sb "DrDad-v$v"`. QA reports 139 passed / 2 pre-existing unrelated failures
    (voice.py, corpus shell-door), i.e. no regression introduced by this change.
  - AC4 (README naming note updated, still explains why `DAD-kit` persists internally): met -
    `README.md:104-105` now reads "asset is named `DrDad-v<x>.zip`. You will still see `DAD-kit` inside, in
    the dev-path placeholder (`C:\Projects\Claude\MCP\DAD-kit`) that `install.ps1` rewrites... that's by
    design." `docs/PUBLISHING.md:88-89` carries the identical explanation and was also updated (again,
    outside T5.1's literal Touches list, but the right catch - PUBLISHING.md's release commands at lines
    32/36/64/67 all reference `DrDad-v<x>` paths now, so the publishing walkthrough stays internally
    consistent with the renamed artifact).
- **Design adherence:** Scope boundary explicitly respected. Confirmed `install.ps1`'s `$old` placeholder
  and the `.bashrc` markers were NOT touched (not in this diff at all - the only files changed were
  `package-kit.ps1`, `package-kit.cmd`, `test-kit.ps1`, `README.md`, `docs/PUBLISHING.md`), and
  `test-kit.ps1:596-606` / `package-kit.ps1:58-64` still both hard-assert the placeholder is `DAD-kit`, so
  a future accidental full-rename would be caught by the existing gate. No scope creep found.
- **Quality:** Small, surgical diff; each changed line is a straightforward literal-string substitution
  with matching prose updates in README/PUBLISHING. One overlooked inconsistency: `package-kit.ps1:43`
  still prints `Write-Host "Packaging DAD-kit $version"` at runtime - so a user actually running the script
  sees the console banner say "Packaging DAD-kit 0.49.1" immediately before it writes out
  `DrDad-v0.49.1.zip`. This line is not covered by any of the story's declared "Do" bullets or by any AC
  (the ACs only check the produced folder/zip name and the placeholder, not console output), so it slipped
  through untouched. It's cosmetic-on-cosmetic (doesn't affect any AC or the placeholder-safety invariant)
  but is a visible leftover of the old name inside the very fix that was supposed to remove visible
  instances of the old name from the packaging path.
- **Hygiene:** No CHANGELOG.md entry for this rename (VERSION is still `0.49.1`, same as the prior
  cms3-example entry at `CHANGELOG.md:5`, and no rename entry exists anywhere in the file). Not a project
  requirement enforced by `close-unit.ps1` (grep for "CHANGELOG" against it turned up nothing), so this is
  a style/completeness gap rather than a defect - flagged as `[human]` since whether every closed story
  gets a changelog line is a project-convention call, not something to assume.
- **Verification-mode note (per T4.3/R35):** Per the task framing, this was verified live-sandboxed - QA
  actually ran `package-kit.ps1` against a scratch/temp `-OutDir`, confirming both the renamed output name
  and the untouched placeholder inside it. Agreeing with the QA framing supplied: writing new files to a
  directory the agent/human chose is not the same risk class as mutating PATH/env vars/installed models
  (R35's actual target), so a full "verification mode: code-review-only, human declined" note is not
  required here - this is correctly closer to S1's AC1 (live-sandboxed, isolated target) than to S1's AC2
  (code-review-only because it would mutate real installed state). No corrective action needed on this
  point.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [mechanical] `package-kit.ps1:43` - change `Write-Host "Packaging DAD-kit $version"` to
   `Write-Host "Packaging DrDad $version"` so the console banner matches the renamed output it is about to
   produce. Trivial, ASCII-preserving, no behavior change - safe for hygiene-agent.
2. [human] Decide whether closed stories/tasks like this one should get a `CHANGELOG.md` entry as a matter
   of course (the file's own header says "All notable changes to DrDad") - S5 currently has none, and
   nothing in `close-unit.ps1` enforces one, so this is a project-convention decision, not a code defect.
3. [dev] None required - the story's core Behavior/Data-interfaces/Acceptance are all implemented and
   verified as described; no further dev-agent pass is needed for S5 itself. (Listed for completeness of
   the tag set, not because there is real outstanding work.)

# Verification - DrDad kit 0.60.0 process fixes (Tier 1)

Date: 2026-11-09. Branch: `drdad-fixes-2026-11` (not pushed, not merged).

This file records, for each Tier 1 issue, a reproduction that shows the OLD behavior and the same
reproduction showing the FIXED behavior.

## How the reproductions were run

- OLD kit: the installed copy `D:\Tools\DrDad-v0.59.4`. Its scripts are byte-identical to `main`
  (checked by hash for close-unit, new-project, upgrade-project, install-hooks, api-surface, ratchet,
  tidy, doc-stats and dad-doctor).
- FIXED kit: this repo at the head of `drdad-fixes-2026-11`, with `local-tools` rebuilt.
- Each reproduction creates a throwaway project under `%TEMP%\drdad-repro-2026-11\old\...` or
  `...\new\...` with the kit's own `new-project`, gives it two stories of two tasks each (S1: T1.1,
  T1.2; S2: T2.1, T2.2), a build command that always passes, and a test command that fails while a
  file named `fail.flag` exists. Nothing outside those temp folders and this repo was written.
- The script is `examples\verification-2026-11\repro.ps1`. To rerun one case:

  ```
  powershell -NoProfile -ExecutionPolicy Bypass -File examples\verification-2026-11\repro.ps1 -Kit D:\Tools\DrDad-v0.59.4 -Issue 2 -Root %TEMP%\drdad-repro\old
  powershell -NoProfile -ExecutionPolicy Bypass -File examples\verification-2026-11\repro.ps1 -Kit <this repo>           -Issue 2 -Root %TEMP%\drdad-repro\new
  ```

  Issue ids: 1, 1u (needs `-OldKit <old kit path>`), 2, 2c, 3, 4, 10, 12, 14, 15, 16, 18.
- Each fix also has an automated case in `test-kit.ps1` (names start with `0.60.0 #<issue>`), so the
  kit's own gate keeps checking it. Full suite on the branch: 300 passed, 0 failed, 0 skipped (it was 284 passed, 0 failed
  on `main` before any change).
- The Galactic Data Network project (GDN) was read only. Two read-only checks of the fixed kit were
  run against it and are noted under issues 2 and 4.

## Summary

| Issue | Old behavior reproduced | Fixed behavior shown | Commit |
|---|---|---|---|
| 1 machine-specific paths | yes | yes | `ddeb376` |
| 2 Status marker writer | yes | yes | `6565b0f` |
| 3 ratchet / -AcceptShrink | yes | yes | `7eef38b` |
| 4 STATUS.md freshness | yes | yes | `782acb4` |
| 10 API-SURFACE.md | yes | yes | `b635882` |
| 12 source-scan tests per task | yes | yes | `daf7c49` |
| 14 commit robustness | yes | yes | `12c3180` |
| 15 scaffold gate log | yes | yes | `cc76ad8` |
| 18 tidy _tmp/ | yes | yes | `5e3f0ae` |
| 16 elevated shell (warning part) | yes | yes | `ab4f9c9` |

---

## Issue 1 - machine-specific paths in `.mcp.json` and the pre-commit hook

Evidence in GDN: the committed `.mcp.json` holds `D:\Tools\DrDad\local-tools\...\local-tools.exe` and
`D:\projects\GalacticDataNetwork\gdn1\docs`; `.git/hooks/pre-commit` names `D:\Tools\DrDad\scan-secrets.ps1`.

Reproduction: scaffold a project, print the server command, the docs dir and the hook lines that
locate the kit; make one commit through the hook; run `doc-stats` to prove the docs folder is found.

Old (0.59.4):
```
command             = D:\Tools\DrDad-v0.59.4\local-tools\bin\Release\net8.0\local-tools.exe
LOCALTOOLS_DOCS_DIR = C:\Users\ov_1_\AppData\Local\Temp\drdad-repro-2026-11\old\i1\docs
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Tools\DrDad-v0.59.4\scan-secrets.ps1" -Staged -Quiet
```

Fixed:
```
command             = ${DAD_HOME}\local-tools\bin\Release\net8.0\local-tools.exe
LOCALTOOLS_DOCS_DIR = docs
kit="$DAD_HOME"
if [ -z "$kit" ] || [ ! -f "$kit/scan-secrets.ps1" ]; then kit="$fallback"; fi
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$kit/scan-secrets.ps1" -Staged -Quiet
commit exit 0; HEAD: <sha> docs: note
doc-stats: stories 0/2, tasks 0/4, next task T1.1   [exit 0]
```
`dad doctor` in that project reports `.mcp.json portable (${DAD_HOME} -> D:\Tools\DrDad\...)`, the docs
dir resolved, and the hook as "secret scan + story-status guard (kit found through DAD_HOME)". The
server itself resolves the relative docs dir: `LOCALTOOLS_DOCS_DIR=docs local-tools.exe --corpus` run
from the project root lists the project's `docs` folder.

Upgrade path (case 1u): a project scaffolded by 0.59.4, then `upgrade-project` from the fixed kit.
```
before: command = D:\Tools\DrDad-v0.59.4\local-tools\...   LOCALTOOLS_DOCS_DIR = C:\...\new\i1u\docs
        hook: ... -File "D:\Tools\DrDad-v0.59.4\scan-secrets.ps1" -Staged -Quiet
upgrade: hooks: pre-commit named the kit by a fixed path - rewriting it to follow DAD_HOME
after:  command = ${DAD_HOME}\local-tools\bin\Release\net8.0\local-tools.exe   LOCALTOOLS_DOCS_DIR = docs
        hook: kit="$DAD_HOME" ...      .dad-kit-version = 0.60.0
```

Not verified live: that Claude Code itself expands `${DAD_HOME}` when it starts the MCP server. This
is documented Claude Code behavior for `.mcp.json`, but I could not start an approved project server
from this session to watch it. Check once with `/mcp` in a new or upgraded project.

Tests: `0.60.0 #1: new-project writes a PORTABLE .mcp.json ...`, `0.60.0 #1 upgrade path: ...`.

## Issue 2 - close-unit must be the only writer of a story's Status marker

Evidence in GDN: gate log lines 997-1004 (2026-11-05). `story S55 not closed: tests failed`; then a
T55.8 close that passed its checks, stamped S55 DONE on disk, and failed at `git commit`; then a
hand-made commit 44435b6 "T55.8: ...; S55 DONE" that banked the stamp; then `story S55 not closed:
tests failed` again.

Reproduction (case 2): close T1.1; make the suite fail; close T1.2 (the last task of S1, so a story
close) - refused. Hand-edit S1's heading to `<!-- Status: DONE closed:close-unit -->`. Then (a) run
close-unit for T2.1, a task of another story; (b) commit by hand.

Old (0.59.4):
```
[close-unit] TESTS FAILED (exit 1) - story S1 is NOT closed. Nothing changed.
(a) close-unit T2.1 -> committed: 43adcec T2.1: unit 2.1        close-unit OK [exit 0]
    is 'S1 DONE' in HEAD? True
```
The forged marker was committed under T2.1, one step after the story close had failed its tests.

Fixed:
```
[close-unit] TESTS FAILED (exit 1) - story S1 is NOT closed. Nothing changed.
(a) [close-unit] A STORY IS MARKED DONE BY HAND - 'T2.1' is NOT closed. Nothing was ticked or committed.
    [status-guard] REFUSED: a story was marked DONE by hand: S1 (docs/STORIES.md)      [exit 1]
    is 'S1 DONE' in HEAD? False
(b) git commit -am "T1.2: unit 1.2; S1 DONE"
    pre-commit: story status guard refused - commit aborted.                          [git commit exit 1]
    is 'S1 DONE' in HEAD? False
```

Reproduction (case 2c, the exact S55 sequence): close T1.1; make every commit fail (a pre-commit hook
that exits 1); close T1.2.

Old (0.59.4):
```
FAIL git commit exited 1
close-unit INCOMPLETE [exit 1]
on disk, STORIES S1 line: ### Story S1: One   <!-- Status: DONE closed:close-unit -->
on disk, TASKS T1.2 line: ### [x] T1.2 - unit 1.2   (Story S1)
```
The close failed, but the tick and the DONE stamp stayed on disk for the next `git add -A`.

Fixed:
```
FAIL git commit exited 1
FAIL bookkeeping ROLLED BACK: the TASKS.md tick and any STORIES.md DONE marker were restored, because the commit did not land - 'T1.2' is NOT closed
close-unit INCOMPLETE [exit 1]
on disk, STORIES S1 line: ### Story S1: One   <!-- Status: TODO -->
on disk, TASKS T1.2 line: ### [ ] T1.2 - unit 1.2   (Story S1)
```

Read-only check on GDN: `dad-status-guard -WorkingTree` against GDN's current working tree exits 0
(no false alarm on a real 109-story file).

Tests: four cases named `0.60.0 #2: ...` (hand marker refused twice plus the human override; a real
story close still lands through the hook; roll-back when the commit fails; headings-only parsing).

## Issue 3 - a ratchet block must stop the close; -AcceptShrink needs a recorded human reason

Evidence in GDN: the gate log has 13 `ratchet` block lines; five of them are followed 10 to 45
seconds later by `close-unit-refusal allow "clean close: <id>"` for the same unit (S19, T23.4, T25.1,
T40.6, T30.10 - for example lines 70-71, `tests: 145->139` then `clean close: T23.4`). The log records
no reason for any of them, and no commit in GDN's history carries a `Shrink-accepted:` line.

Reproduction: close T1.1 (baseline: 10 tests); delete 6 tests; close T2.1; re-run with a bare
`-AcceptShrink`; re-run with `-AcceptShrink -Reason "..."`.

Old (0.59.4):
```
close T2.1                      -> VERIFICATION SURFACE SHRANK ... [exit 1]
close T2.1 -AcceptShrink        -> committed: 583e6cb T2.1: unit 2.1
                                   WARN shrink accepted with no -Reason - nothing recorded about WHY
                                   close-unit OK [exit 0]          T2.1 is [x]
gate log: ratchet block "tests: 10->4", then close-unit-refusal allow "clean close: T2.1"
```

Fixed:
```
close T2.1                      -> VERIFICATION SURFACE SHRANK ... [exit 1]
close T2.1 -AcceptShrink        -> [close-unit] -AcceptShrink NEEDS A REASON - 'T2.1' is NOT closed. [exit 1]
                                   T2.1 is still [ ]
close T2.1 -AcceptShrink -Reason "Kristen approved 2026-11-09: cases 5-10 duplicated the contract test"
                                -> committed; close-unit OK [exit 0]; T2.1 is [x]
gate log: close-unit-refusal block "T2.1 not closed: -AcceptShrink given without a recorded -Reason ..."
          ratchet block "tests: 10->4"
          close-unit-refusal allow "clean close: T2.1 - shrink accepted: Kristen approved 2026-11-09: ..."
commit body: Shrink-accepted: Kristen approved 2026-11-09: cases 5-10 duplicated the contract test (human)
```

Limit: a script cannot prove a human wrote the reason. What changed is that an acceptance now always
leaves a sentence in the commit and in the gate log that someone can be asked about.

Tests: `0.60.0 #3: ...`; the existing `S30 AC6` and `T9.3 (b)` cases were updated, because they
pinned the old "bare -AcceptShrink closes" behavior.

## Issue 4 - STATUS.md freshness

Evidence in GDN: `docs/STATUS.md` says "As of: 2026-10-30 ... Stories: 35/54, Tasks: 307/362, NEXT:
T30.17"; the documents on 2026-11-09 say 42/109 stories and 512/895 tasks.

Reproduction: close T1.1 and T2.1, then print the Snapshot section of `docs/STATUS.md`; then set the
snapshot back to `Tasks: 0/4` by hand and run `doc-stats -Findings`.

Old (0.59.4):
```
## Snapshot
- As of: <YYYY-MM-DD>  (session model: <model>)
- DESIGN: <DRAFT | LOCKED>   Stories: <done>/<total>   Tasks: <done>/<total>
STATUS.md in the last commit? False
doc-stats -Findings: (no finding mentions STATUS.md)
```

Fixed:
```
ok   docs\STATUS.md Snapshot regenerated (counts + next task)
## Snapshot
- As of: 2026-11-09  (counts generated by doc-stats.ps1 - do not hand-edit this section)
- DESIGN: DRAFT   Stories: 0/2   Tasks: 2/4
- NEXT: T1.2 (Story S1)
- Narrative sections below last refreshed (/audit status): never; units closed since: 2
STATUS.md in the last commit? True
doc-stats -Findings: [status] docs/STATUS.md is STALE: its Snapshot says 'Stories: 0/2, Tasks: 0/4' but the documents say 'Stories: 0/2, Tasks: 2/4'. ...
```

Read-only check on GDN: the fixed `doc-stats -Findings` run against GDN prints
`[status] docs/STATUS.md is STALE: its Snapshot says 'Stories: 35/54, Tasks: 307/362' but the documents
say 'Stories: 42/109, Tasks: 512/895'.` `doc-stats` takes about 4 seconds on GDN's 6 MB of docs, which
is the cost this adds to each close there.

Test: `0.60.0 #4: ...`.

## Issue 10 - API-SURFACE.md: no test assemblies, not in docs/, not committed

Evidence in GDN: `docs/API-SURFACE.md` is 1.3 MB and tracked by git; the "This solution" part runs to
line 15,507 because it includes the `Gdn.IntegrationTests` assembly; it changes in most task commits.

Reproduction: add a small .NET solution to the throwaway project - `src\App` (class `Greeter`) and
`tests\App.IntegrationTests` (class `GreeterTestHelper`) - then close T1.1 so the build runs.

Old (0.59.4):
```
ok   API surface regenerated (docs\API-SURFACE.md)
docs\API-SURFACE.md exists; mentions GreeterTestHelper (test assembly)? True; mentions Greeter? True
files in the T1.1 commit: docs/API-SURFACE.md, docs/TASKS.md, grades/gates-log.jsonl
tracked by git: docs/API-SURFACE.md
```

Fixed:
```
ok   API surface regenerated (.claude\API-SURFACE.md - not committed; query: dad api-surface -Lookup <Name>)
docs\API-SURFACE.md does not exist
.claude\API-SURFACE.md exists; mentions GreeterTestHelper (test assembly)? False; mentions Greeter? True
files in the T1.1 commit: docs/RECIPES.md, docs/STATUS.md, docs/TASKS.md, grades/gates-log.jsonl
tracked by git: (nothing)
dad api-surface -Lookup Greeter -> class Greeter / Greeter() / string Hello(string name)   [exit 0]
```

Upgrade path: covered by the automated case - a generated, tracked `docs\API-SURFACE.md` is moved to
`.claude\` and untracked by `upgrade-project` and by the next build-close; a hand-written file of the
same name is left alone.

Tests: `0.60.0 #10: ...` (builds a two-project fixture; full run only) and `0.60.0 #10 upgrade path: ...`.

## Issue 12 - run the source-scan tests in every task close

Evidence in GDN: commits 49b03b9 ("three failures found by the S92 story-close suite ... people-word
source scan") and 3c611bf ("LinuxDaemonStaticGuardTests.ApiV0_allowSet_is_KuboPaths_cs_only was failing
on main"): static scan tests broken by one task and found by a later story close.

Reproduction: the project's CLAUDE.md gets a line `- Fast test: \`tools\fake-scan.cmd\`` (standing in
for the source-scan subset) and that command currently fails. Close T1.1, an ordinary task close.

Old (0.59.4): the line is ignored; no test of any kind runs on a task close.
```
== close-unit T1.1 ==   ok build verified   ok task T1.1 -> [x]   committed   close-unit OK [exit 0]
```

Fixed:
```
[close-unit] fast tests (every task close): tools\fake-scan.cmd
[close-unit] FAST TESTS FAILED (exit 1) - 'T1.1' is NOT closed. Nothing was ticked or committed.  [exit 1]
T1.1 line: ### [ ] T1.1 - unit 1.1   (Story S1)
(after fixing the scan failure)
ok   fast tests verified (1 test(s) ran)   ok task T1.1 -> [x]   close-unit OK [exit 0]
```

What a project has to do: add the `Fast test:` line (for .NET, tag the scan tests with
`[Trait("Category", "SourceScan")]` and use `dotnet test --filter "Category=SourceScan"`). The kit
cannot know which tests are source scans, so without that line a task close is unchanged.

Test: `0.60.0 #12: ...`.

## Issue 14 - close-unit commit robustness

Evidence in GDN: 36 commits with a doubled prefix (`T68.5: T68.5: IUser32 wrapper ...`); three pairs of
identical subjects where the second commit holds only `grades/gates-log.jsonl` (and the regenerated
API surface), for example T80.3 at dc557ef and aabe6c7; stories S73 and S92 marked DONE with no grade
card and no `S73:` / `S92:` commit while task closes continued.

Reproduction: (i) close T1.1 with `-Title "T1.1: unit 1.1"`; (ii) run the same close again; (iii)
close T1.2 (S1 rolls up), then go straight to T2.1 without a story-level close of S1.

Old (0.59.4):
```
(i)   committed: f9f82a2 T1.1: T1.1: unit 1.1
(ii)  committed: 46c9b0d T1.1: T1.1: unit 1.1        (a second commit; it holds only log lines and RECIPES rows)
(iii) T1.2 -> story S1 -> DONE;  T2.1 -> close-unit OK [exit 0]   (S1 has no story commit, no grade)
```

Fixed:
```
(i)   subject: T1.1: unit 1.1
(ii)  ok 'T1.1' already has its commit and nothing new is staged - no duplicate commit made
      commits before: 3, after: 3
(iii) T1.2 -> story S1 -> DONE
        ok story S1 now owes its story-level close: grade + hygiene, then 'dad close-unit -Id S1 ... -RequireGrade'
      T2.1 -> [close-unit] STORY S1 IS DONE BUT NOT CLOSED - 'T2.1' is NOT closed.   [exit 1]
      close-unit -Id S1 -Title "S1 polish" -> committed: <sha> S1: S1 polish   [exit 0]
        commits whose subject starts with 'S1:': 1
      T2.1 -> close-unit OK [exit 0]
```

Tests: two cases named `0.60.0 #14: ...`; the existing `close-unit: tick, roll-up timing, ...` case was
updated for the story-level close.

## Issue 15 - /scaffold creates the gate log

Evidence in GDN: the project was scaffolded on 2026-09-22; the first line of `grades/gates-log.jsonl`
("log created; no prior history found") is dated 2026-10-03.

Reproduction: scaffold a project and look for `grades\gates-log.jsonl` and for it in the first commit.

Old (0.59.4):
```
grades\gates-log.jsonl exists: False
tracked in the scaffold commit: False
```

Fixed:
```
grades\gates-log.jsonl exists: True
tracked in the scaffold commit: True
{"v":1,...,"gate":"gates-log","decision":"allow",...,"reason":"log created; no prior history found - this log begins here",...}
{"v":1,...,"gate":"gates-log","decision":"allow",...,"reason":"project scaffolded (general, kit 0.60.0)",...}
```

Test: `0.60.0 #15: ...` (also covers `upgrade-project` adding the log to an older project).

## Issue 18 - tidy _tmp/ at story close

Evidence in GDN: `_tmp/` holds 175 entries dated 2026-10-04 to 2026-11-09 (test logs up to 526 KB,
`.bak` / `.orig` copies, one-off `.js` scripts).

Reproduction: put two scratch files dated 5 hours ago and one written now into `_tmp\`; close T1.1 (a
task close), then T1.2 (which closes story S1).

Old (0.59.4):
```
after the TASK close,  _tmp: in-flight.txt, old-log.txt, old.orig
after the STORY close, _tmp: in-flight.txt, old-log.txt, old.orig
```

Fixed:
```
after the TASK close,  _tmp: in-flight.txt, old-log.txt, old.orig
ok   _tmp\ swept at story close: 2 scratch file(s) older than 1h removed, 1 recent kept
after the STORY close, _tmp: in-flight.txt
```

Test: `0.60.0 #18: ...` (also: a dry run removes nothing; files git tracks under `_tmp\` are not swept).

## Issue 16 (warning part) - warn when the agent shell is elevated

Evidence in GDN: `docs/STATUS.md` says "agent shell is elevated; gdn bootstrap refuses elevation" as
the reason the human smoke gates cannot be run by the agent. The session that did this work was also
elevated, so the reproduction is a real one, not a simulated flag.

Reproduction: in an elevated shell, close T1.1 and run `dad doctor`.

Old (0.59.4):
```
(close-unit printed nothing about elevation)    close-unit exit: 0
(dad doctor printed nothing about elevation)
```

Fixed:
```
WARN this shell is ELEVATED (Administrator). Every command the agent runs has admin rights, and tools that refuse elevation will fail. Unless you chose this, close the editor/terminal and start it NON-elevated. (dad doctor reports it too.)
close-unit exit: 0
[WARN] shell      ELEVATED (Administrator) - agent commands run with admin rights; tools that refuse elevation will fail
```

Test: `0.60.0 #16 (warning part): ...` (the non-elevated case is covered through `DAD_ASSUME_ELEVATED=0`).

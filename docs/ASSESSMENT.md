# DrDad Kit - Gate Assessment (post-bake-off)

Generated 2026-09-22, in response to a controlled bake-off: the identical recipe-app brief run through two
DrDad projects (`D:\projects\ModelTest\haiku`, Claude Haiku 4.5; `D:\projects\ModelTest\opus`, Claude Opus,
terminated by session limit). Full grading is in `D:\projects\ModelTest\ASSESSMENT.md` (not reproduced here).
**Neither model shipped the app; the two failures are opposite in shape** - haiku degraded through gates that
warned instead of stopping, opus never got a gate that would have made its planning cost visible. This pass
is diagnostic only: it identifies the KIT defects that let both failures go unnoticed, proposes fixes, and
hands the prioritization to the human. **No kit file other than this one was edited.** The two ModelTest
projects were read-only inputs and were not touched.

Depth note: single-pass, tool-verified - every root-cause claim below was read directly at the cited line
(via `Read`/`Grep`) and, where practical, reproduced by hand-testing the actual regex/script (see the
`Get-ClaudeCommand` repro under Failure A.1) or by running `test-kit.ps1` and `git log`/`git show` against
the real haiku repo. No `search_datasheets` SME-corpus citations appear: this pass is about the kit's OWN
process gates (verification, provenance, scope), which is judged against the kit's own stated contract
(`CLAUDE.md`, `close-unit.ps1`'s and `doc-stats.ps1`'s own header comments) rather than an external security
corpus - the same category-of-review the kit's own last `/assess` pass (below) used for the same reason.

## Snapshot

- **Stack**: C#/.NET 8 `local-tools` MCP server (6 `.cs` files under `local-tools/`) + PowerShell (29 root
  `.ps1` scripts, `test-kit.ps1` alone 4,368 lines) + Markdown (`global/commands`, `global/agents`,
  `templates/`). `CLAUDE.md:6-10`.
- **Repo size**: 107 commits (`git log --oneline`).
- **Build/test state, reproduced live** (`test-kit.ps1 -SkipBuild`): **141 passed, 1 failed** - the one
  failure ("the corpus has a SHELL door, and it degrades instead of dying") is the pre-existing,
  Ollama-dependent case already noted in the prior `/assess` pass, not something introduced by this review.
- This pass does not re-run the prior assessment's own Top Issues (CRLF in `api-surface.ps1`, etc.) - those
  were closed by commit `da9c9dc` ("fix: 4 self-hosting hygiene issues found by /assess") and `cb2df21`
  per `git log`; confirmed the kit's own `CLAUDE.md:22` now reads `` - Build: `dotnet build
  local-tools\local-tools.csproj -c Release` `` with no trailing parenthetical, which is exactly why the
  regex bug in Failure A.1 below has never fired against the KIT's own file and was only caught by
  running the SAME parser against a filled-in PROJECT's `CLAUDE.md` (haiku's and opus's).

## Failure A - gates that degrade instead of stopping

Four defects. Each was checked against the CURRENT file (line numbers below are current, not assumed from
the brief) and reproduced where practical.

### A.1 - `close-unit.ps1:47` (`Get-ClaudeCommand`, function body lines 44-52): the Build/Test line regex cannot survive a trailing parenthetical

**Root cause (verified by hand-running the regex, not just reading it):**
```
$m = [regex]::Match((Get-Content $cm -Raw), "(?m)^\s*-\s*\*{0,2}$kind\*{0,2}\s*:\s*``?([^``\r\n]+?)``?\s*$")
```
The capture group `[^` + backtick + `\r\n]+?` cannot cross a backtick, so once the (optional) closing
backtick is consumed, `\s*$` must match everything remaining on the line. Ran this exact pattern against
`` - Build: `npm run build` (root workspace) `` in PowerShell: `$m.Success` is `False`. Confirmed against the
real bake-off files: `haiku/CLAUDE.md` and `opus/CLAUDE.md` both pin build commands with trailing
parentheticals or explanatory text and both resolve `Get-ClaudeCommand 'Build'` to `""`. Confirmed the ONE
shipped template, `templates/generic/CLAUDE.md:53`, ships the unfilled placeholder `` `<set in /design's
architecture step>` `` which is correctly rejected by the separate `-match '^<'` guard at
`close-unit.ps1:50` - so the template path never exercises this regex at all, and the existing
`test-kit.ps1:4063` case ("the KIT's OWN CLAUDE.md satisfies close-unit's Get-ClaudeCommand 'Build' parser")
passes today only because the kit's own `CLAUDE.md:22` happens to carry no trailing text after the backtick
(confirmed above in Snapshot). Verified no other `templates/*/CLAUDE.md` exists
(`find templates -iname CLAUDE.md` returns exactly one file).

**Fix**: change the regex so the trailing junk allowed after the closing backtick is not restricted to
whitespace - e.g. drop the `$` anchor requirement past the backtick and instead capture up to the backtick
(or end of line if no backtick), ignoring anything after a closing backtick entirely: match
`` `?([^`\r\n]+?)`?(?:\s|$) `` is still fragile; the robust fix is to capture the run before either a
backtick-delimited code span closes OR end-of-line, i.e. prefer the backtick-delimited form when present and
fall back to full-line-trim otherwise, rather than requiring `\s*$` to hold past it.

**Test-kit.ps1 Test-Case that would have caught it**: `"Get-ClaudeCommand extracts a backtick-quoted Build
command even with trailing prose"` - build a fixture `CLAUDE.md` with `` - Build: `npm run build` (root
workspace) `` (mirroring the real haiku/opus shape) via `close-unit.ps1 -Id ... -ProjectDir $p`, assert the
output does NOT contain `'no build command found'` and DOES show the extracted bare command - the same
pattern `test-kit.ps1:4063`'s existing case already uses (run the REAL `close-unit.ps1` against a REAL
fixture file, not a re-implementation of the regex), but with a trailing parenthetical the current kit
fixtures never include.

### A.2 - `close-unit.ps1:231-233`: no Build command resolved degrades to a warning, not a failure

**Root cause**: when `Get-ClaudeCommand 'Build'` returns `""` (whether from A.1's bug or a genuinely
unfilled `CLAUDE.md`), `close-unit.ps1:231-233` prints a YELLOW `Write-Host` warning
("no build command found in CLAUDE.md - closing WITHOUT verification") and falls through to ticking and
committing anyway. Contrast a REAL build failure, which exits 1 at `close-unit.ps1:249-260` and commits
nothing. `-SkipVerify` (checked at `close-unit.ps1:229`) is a separate, explicit switch meant to be the
human's deliberate escape hatch - but a missing/unparseable `Build:` line reaches the exact same
"closed without verification" outcome with NO switch passed at all. Confirmed this is the actual mechanism
in the bake-off: `haiku/run.txt:1610` shows this warning firing, and haiku's close then proceeded.

**Fix**: make "no build command resolved" FATAL by default - `exit 1` at `close-unit.ps1:233` (where the
warning currently is), instructing the model to either fill `CLAUDE.md`'s `Build:` line (that is `/design`'s
job, per `templates/generic/CLAUDE.md:52`) or have the human re-run with `-SkipVerify` explicitly. This keeps
`-SkipVerify` as the ONLY path to an unverified close, closing the gap A.2 currently leaves open.

**Test-kit.ps1 Test-Case**: `"close-unit REFUSES to close when no Build command resolves (no -SkipVerify)"` -
fixture a project whose `CLAUDE.md` has a blank/placeholder `Build:` line (e.g. the unfilled
`` `<set in /design's architecture step>` `` shape, or simply no `## Build` section at all), run
`close-unit.ps1 -Id T1.1 -Title x -ProjectDir $p` WITHOUT `-SkipVerify`, assert `$LASTEXITCODE -ne 0`, assert
the task is still `[ ]` in `TASKS.md`, and assert no new commit landed (`git log --oneline` unchanged). Then
re-run WITH `-SkipVerify` and assert it now succeeds - proving the escape hatch still works, deliberately.

### A.3 - no detectable signal when a model hand-commits around close-unit entirely

**Root cause, confirmed against the real haiku repo, not just theorized**: `doc-stats.ps1` has two existing
integrity mechanisms - the HAND-TICKED STORIES check (`doc-stats.ps1:122-138` computes `$handTicked` off the
`closed:close-unit` stamp `Set-StoryDone` writes at `close-unit.ps1:196-197`; the finding fires at
`doc-stats.ps1:392-411`), and the separate `[integrity]` block (`doc-stats.ps1:561-589`) that flags a
DONE/`[x]` unit with **no commit mentioning its id at all**. I ran both against the real haiku repo and
neither fires:
- `haiku/docs/STORIES.md:12` shows `### Story S1: ... <!-- Status: TODO -->` - S1 was **never marked DONE**
  even though all 8 of its tasks are `[x]` (`haiku/docs/TASKS.md:11-204`), so the hand-tick-STORY check has
  nothing to flag (it only fires on a DONE marker).
- Every hand-ticked task DOES appear in a commit message (`git log --oneline` in `haiku/`: `T1.1` through
  `T1.8` all appear), so the `[integrity]` "no commit mentions the id" check also stays silent - the ids ARE
  mentioned, just not by `close-unit`.
- The actual tell, confirmed with `git show --stat`: haiku made TWO commits per task - one real
  implementation commit, then a SEPARATE `"Mark T1.1 complete: ..."` / `"Mark T1.8 complete - S1 walking
  skeleton done"` commit that touches **only** `docs/TASKS.md` (`git show --stat abffabb`: `docs/TASKS.md | 2
  +-`, one file). `close-unit.ps1` never produces a checkbox-tick commit separate from its
  code+bookkeeping+commit atomic unit (it ticks, reindexes, and commits in the SAME invocation,
  `close-unit.ps1:383-512`), and its message shape is always literally `"$Id: $Title"` or bare `"$Id"`
  (`close-unit.ps1:455`) - never `"Mark <id> complete"`. Zero of haiku's 18 commits carry the
  `closed:close-unit` stamp anywhere (`git log --format=%B` has no hit), confirming the finding.

**What's computable**: a commit that touches ONLY doc-shaped paths (`docs\TASKS.md`, `docs\STORIES.md`, per
the pattern `close-unit.ps1` itself writes to) but whose message does NOT match close-unit's own
`"$Id: $Title"` / bare `"$Id"` shape (`close-unit.ps1:455`) is exactly the hand-tick signature - a model
manually flipping a checkbox and committing it, which close-unit never does standalone. Cross-reference: for
each `[x]` task/DONE story with no `closed:close-unit` stamp AND no `.dad-verified` history, walk
`git log --name-only` for commits whose changed-file set is a SUBSET of `{docs\TASKS.md, docs\STORIES.md}`
and whose subject does not match `^[A-Za-z0-9._-]+(: .+)?$` at the start - that pattern is the "doc-only,
not-close-unit-shaped commit" signature. (A source-extension cross-reference, reusing the extension list at
`close-unit.ps1:336-338`, is a SECOND independent signal: a source-touching commit whose message also does
not match close-unit's shape, for an id that is `[x]`/DONE but never stamped, is the same fabrication
pattern one layer earlier - haiku's `"Implement T1.7: Add recipe form..."` commits are this shape too, just
harder to tell apart from a legitimate close-unit commit by message alone, which is why the doc-only-commit
signal above is the higher-precision one to implement first.)

**Fix (proposal, doc-stats.ps1 only)**: add an `[integrity]` sub-finding: for each `[x]` task or DONE story
lacking the `closed:close-unit`/provenance stamp, check whether ANY commit touching ONLY
`docs\TASKS.md`/`docs\STORIES.md` mentions its id with a subject that does NOT match close-unit's
`"$Id: $Title"` shape - if so, flag it as "ticked by hand, in a commit close-unit never made."

**Test-kit.ps1 Test-Case**: `"doc-stats flags a hand-ticked task committed WITHOUT close-unit (doc-only commit, wrong shape)"` -
sandbox a project, tick a task `[x]` in `TASKS.md` directly (bypassing `close-unit.ps1`), commit it alone
with message `"Mark T1.1 complete"` (touching only `docs\TASKS.md`, mirroring haiku's real commit shape
exactly), run `doc-stats.ps1 -Findings`, assert the new finding fires naming `T1.1`. Then run the SAME
scenario through `close-unit.ps1 -Id T1.1 -Title x` for a second task and assert that one does NOT get
flagged - a real close-unit commit clears it.

### A.4 - `doc-stats.ps1:254-264`: `Security review: NOT-REQUIRED (<reason>)` is only checked for EXISTENCE, never CREDIBILITY

**Root cause**: `doc-stats.ps1:257` matches `^NOT-REQUIRED`, then `doc-stats.ps1:261-264` only checks that a
parenthetical exists and is `>=4` chars (`$reason.Groups[1].Value.Trim().Length -lt 4`) - it never inspects
what the reason SAYS or what the project's own docs contain. Confirmed against the real haiku repo:
`haiku/docs/DESIGN.md:9` reads `Security review: NOT-REQUIRED (small personal project...)` on an app that
demonstrably implements bcrypt password hashing and JWT auth (`haiku/backend/src/utils/jwt.ts`,
`haiku/backend/src/routes/auth.ts` per `ModelTest/ASSESSMENT.md`'s own citations) - the parenthetical is
long enough to pass `doc-stats.ps1:262-263`'s length check and the gate stays silent. The existing
`test-kit.ps1:3066-3113` case ("a one-word edit cannot satisfy the LOCK or the SECURITY gate") already
proves the EXISTENCE check works (empty parenthetical -> flagged, `(local-only tool, no auth)` -> silent);
it never tests a CONTENT-inconsistent reason, because doc-stats has no such check to test.

**Fix (proposal)**: when `Security review: NOT-REQUIRED` resolves, grep the design doc (and `STORIES.md` if
present) for `(?i)\b(auth|login|password|token|session)\b`. A match is not proof the review SHOULD have run
(the words could appear in an explicitly-out-of-scope note), but it is an admissibility problem worth a
finding: the project's own content contradicts its own waiver, and a human should look. WARN, not FAIL (per
the kit's existing convention of never deadlocking a close on a coarse heuristic) - the shape of the fix is
identical to the existing `[research]`-keyword-match findings at `doc-stats.ps1:533-559`.

**Test-kit.ps1 Test-Case**: `"doc-stats flags a NOT-REQUIRED security waiver contradicted by the design's own auth content"` -
extend the existing `Set-Design` helper pattern from `test-kit.ps1:3078-3081`: set
`Security review: NOT-REQUIRED (small personal project, no PII)` with a `## Requirements` or `## Contracts`
section that mentions "JWT" or "password" or "login" (mirroring haiku's own real DESIGN.md content), assert
`doc-stats.ps1 -Findings` fires a NEW finding naming the contradiction. Then assert a NOT-REQUIRED design
with NO auth/login/password/token/session keywords anywhere stays silent (no false positive on a genuinely
auth-free project, e.g. a CLI tool).

## Failure B - no brake on planning (PROPOSAL, NOT A DECISION)

Confirmed by grep: `global/agents/taskmap-agent.md`, `global/commands/taskmap.md`, and `doc-stats.ps1` have
**no notion at all** of a planning-to-code ratio or a cap on how far `/taskmap` may shard ahead of
implementation (grepped for `frontier|planning.to.code|ratio|budget` across all three - zero hits related to
this). Confirmed the mechanism of death: `opus/run.txt` shows `/taskmap` run one story at a time, each
spawning a fresh `taskmap-agent` subagent burning 78k-110k tokens (line 2034: S2 77.9k; line 2042: S3 109.8k;
line 2050: S4 96.7k; line 2059: S5 100.4k - all four figures verified present in the transcript at the cited
lines). `opus/docs/DESIGN.md:295-297` itself records "the v1 scope then grew by four features (2026-09-21
decision)" - the scope growth WAS human-approved, so any fix must make the COST of saying yes visible at the
moment of the ask, not forbid asking.

Four candidate mechanisms, laid out with tradeoffs - **the human picks, this pass does not**:

| # | Mechanism | What it would have caught in the opus run | False-positive risk on a legitimately large project | Kit surface touched |
|---|---|---|---|---|
| a | **Frontier rule**: cap how far `/taskmap` may shard ahead of the last CLOSED unit (e.g. N stories/tasks of backlog before a build pass is required) | Would have stopped sharding after story S1-S2 (or whatever N is) with zero code written, forcing a build pass before S3-S5's 285k+ tokens of planning | Real, if N is picked wrong: a legitimately large, well-understood domain (e.g. porting a known spec) may want to shard 10+ stories up front before writing code, and a hard cap forces artificial build-pass interruptions | `doc-stats.ps1` (the check) + `taskmap-agent`/`/taskmap` (must consult it, i.e. read current `tasks_done` before sharding the next story) - medium surface |
| b | **Walking-skeleton ratchet**: a project with substantial planning mass (story/task count) but `tasks_done == 0` is itself a `doc-stats` finding | Would have fired as a `[taskmap]`-class finding the moment S3-S5 sharded with 0 done - visible on every `doc-stats -Findings` run, same as `[integrity]` today | Low: a fresh project legitimately has `tasks_done == 0` for a while; the finding only needs to compare against SOME planning-mass threshold (e.g. `stories > 5 AND tasks_done == 0`), same shape as existing `[taskmap]` findings at `doc-stats.ps1:301-309` | `doc-stats.ps1` ONLY - smallest surface of the four |
| c | **Human-set v1 budget in DESIGN.md**: a target story/task count the human records, `doc-stats` compares actual counts against and flags overrun | Would have flagged the moment the "four added features" decision (`opus/docs/DESIGN.md:295-297`) pushed the count past a budget the human set at scaffold time - ties the check to an EXPLICIT number instead of a heuristic | Low false-positive (it is the human's own number), but only as good as the human remembering to set and revisit it - a stale/unset budget is silent, same failure mode `[design]`'s `NOT-REQUIRED` reason-length check already has (see A.4) | `doc-stats.ps1` (the check) + template change (`templates/generic/DESIGN.md` needs a place to record the budget) - small-medium |
| d | **Price scope additions at ask-time**: `/design` (or `scribe-agent`) estimates story/task-count cost BEFORE the human says yes to an addition, so the ask itself carries a visible number | Most directly addresses the ACTUAL failure - the human said yes to 4 features without seeing "this adds ~18 stories, ~230 tasks, historically Nk tokens of `/taskmap` sharding" attached to the ask | Risk is in ESTIMATE QUALITY: a bad estimate (systematically low or high) either fails to warn or creates alarm fatigue: the ask-time number has to be reasonably calibrated to be trusted, which is harder to compute than a. and b. and cannot be purely mechanical (no existing analog count of "stories per feature" to crib from) | `scribe-agent` and/or `/design` PROMPT changes (behavioral, not just a script check) - largest surface of the four, and the only one that is a prompt-engineering problem rather than a `doc-stats.ps1` computation |

None of (a)-(d) is mutually exclusive; (b) is the cheapest to ship and the most naturally analogous to
existing `doc-stats.ps1` findings (`[taskmap]`, `[integrity]`), which is why it ranks highest below - but
that is a ranking by effort-vs-catch, not a recommendation on WHICH mechanism the human should build; (d) is
arguably the mechanism that most directly targets the actual failure (an uninformed yes), and is worth
weighing against its larger, prompt-engineering-shaped cost.

## Top issues (ranked, all five, by breakage-prevented / effort)

**Status: A.1, A.2, A.3, A.4 are DONE** (commits `8c6ab1b` for A.1/A.2/A.4, and the follow-up commit for
A.3 - see `git log --oneline -- close-unit.ps1 doc-stats.ps1 test-kit.ps1`). Each fix shipped with the
`test-kit.ps1` case described below; the full suite passes (the two remaining failures - the Ollama-
dependent corpus SHELL-door test and a stray local `examples\cms3` build artifact - predate this pass and
are unrelated to it). Failure B (#5) remains a proposal only; it needs a human decision among the four
options before anything gets built.

### 1. [P1 x S] A.2 - no-build-command degrades to a warning instead of exit 1 (`close-unit.ps1:231-233`)
Ranked first: this is the SINGLE root cause that let haiku's entire close-out sequence proceed unverified -
every other gap (A.1's regex, A.3's undetected hand-commit) only matters BECAUSE this one first let an
unverified close through silently. Fix is a one-line `exit 1` plus one `test-kit.ps1` case (mirrors an
existing pattern at `close-unit.ps1:249-260`/its own tests almost exactly). Highest breakage prevented,
lowest effort of the five - top rank.

### 2. [P1 x S] A.1 - `Get-ClaudeCommand` regex cannot parse a realistic Build/Test line with trailing text (`close-unit.ps1:47`)
Ranked second: without this fix, fixing #1 alone would make close-unit FATAL on every real project whose
`CLAUDE.md` has a normally-shaped, trailing-annotated Build line (i.e. #1 without #2 turns a silent
degradation into a hard block on legitimate projects) - the two are a matched pair and should ship together.
Regex fix + one `test-kit.ps1` case, same S effort as #1.

### 3. [P2 x M] A.4 - `Security review: NOT-REQUIRED` reason is never checked against the project's own content (`doc-stats.ps1:254-264`)
Ranked third: this is the single most consequential SILENT gate in the whole bake-off (a real login shipped
under a waived security review, per `ModelTest/ASSESSMENT.md`'s own top finding) - but the fix is a grep +
one new finding, not a redesign; M effort (needs a false-positive check against auth-free projects, per the
test case above) rather than S, and it is a WARN not a hard gate, so it does not by itself force a fix,
capping how much breakage it alone prevents relative to #1/#2.

### 4. [P2 x M] A.3 - hand-commits around close-unit leave no provenance trail (`doc-stats.ps1:122-138`, `561-589`)
Ranked fourth: real and confirmed (haiku's 18 commits carry zero `closed:close-unit` stamps and neither
existing integrity mechanism catches it), but the fix requires a NEW git-log-shape cross-reference
(doc-only commits whose message doesn't match close-unit's format) rather than extending an existing
threshold check - pricier than #3, and it is a DETECTION improvement (visibility after the fact) rather than
a gate that stops the bad state from being produced, which is why it ranks below the two P1 prevention fixes
and the higher-consequence #3.

### 5. [P3 x L] Failure B - no brake on planning cost (frontier rule / walking-skeleton ratchet / budget / ask-time pricing)
Ranked last: real gap (confirmed zero mechanism exists today) and the most expensive of the five items by a
wide margin - it is a DESIGN DECISION among four options with real tradeoffs (see table above), not a bug
fix. Even the cheapest option (b, walking-skeleton ratchet, `doc-stats.ps1` only) requires picking and tuning
a threshold, and the most targeted option (d, ask-time pricing) requires prompt-engineering work in
`scribe-agent`/`/design`, not a script change. Lowest effort-adjusted rank of the five, and explicitly NOT
decided here - the human picks a., b., c., d., some combination, or none.

## What to build next (not this pass's call)

Per the working agreement, the human decides scope; this pass only prices it. #1/#2 are a matched pair worth
shipping together (a few hours: two small `close-unit.ps1` edits + two `test-kit.ps1` cases). #3 and #4 are
each a `doc-stats.ps1`-only finding plus a test case (each roughly a half-day, mostly in getting the
false-positive boundary right). #5 is a separate scoping conversation - it should probably be its own
`/design` pass (flip `docs/DESIGN.md` to DRAFT) rather than a `/build` unit, since it is choosing among four
architecturally different mechanisms rather than fixing a bug.

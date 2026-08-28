---
description: Orchestrate dev -> qa per task, grade + hygiene per story; close-out is scripted. Gated on DESIGN LOCKED.
argument-hint: [scope; empty = next ready task]
---
You are the **ORCHESTRATOR** (the main session). Subagents do NOT call each other - YOU relay.
Spawn agents with the **Task tool**, subagent_type = the agent's exact name (e.g. "dev-agent"). They are
NOT skills. Never enter plan mode - this loop IS the plan.

Read `CLAUDE.md` for doc paths, build command, test command, placeholder convention, human-verification.
**Gate 1 - actually grep, do not eyeball:** if `CLAUDE.md` still contains `<decided in`, `<set in`,
`<how to stub` or `# Project: <name>`, STOP and tell me to finish `/design`'s architecture step. Without a
real build/test command the dev and qa agents cannot verify anything and will invent their own reporting
files. This has happened - do not proceed past it.
**Gate 2 - DESIGN must be LOCKED.** Read the design doc's `Status:`. If it is **`DRAFT`, STOP** and tell me
to either lock it (`/design`, it will offer) or use `/proto` if I actually want greybox work. Do NOT quietly
continue "in PROTO mode" - a real run did that, then made 106 blind edits against an unfinished contract.
`/build` is the LOCKED-design loop; that is what R7 says and this command obeys it.

**Gate 2b - the SECURITY REVIEW must be settled.** Do NOT read the header and judge it yourself - run
`doc-stats.ps1 -Findings` (Gate 3 runs it anyway) and obey what it says. It settles the cases a
one-word edit can fake: `NOT-REQUIRED` with no stated reason, and `DONE` over an empty or uncited
`## Security decisions` section. It also reports a design LOCKED with an EMPTY `## Contracts` section -
treat that as Gate 2 failing, because a lock with nothing pinned is the unfinished state Gate 2 exists
to refuse. Then read the header:
`REQUIRED` -> **STOP**. `NOT-REQUIRED (<reason>)` or `DONE <date>` -> proceed. Retrofitting auth and input
handling after a dozen stories is how the insecure version ships, and a header saying REQUIRED means nobody
has decided yet - not that it is safe.
When you stop here, give me BOTH ways out, because one of them may not be available:
  1. run `/design` - it spawns security-agent, which needs the `local-tools` MCP server for `web_search`;
  2. or decide it without the agent, and set `Security review: NOT-REQUIRED (<reason>)` yourself.
Route 2 exists so this gate cannot deadlock. security-agent's tools are ALL MCP tools, so if the server is
not connected (`/mcp` to check, `dad-doctor.cmd` to diagnose) route 1 cannot complete - and without route 2
the only exit from REQUIRED would be a tool that does not run. **You may not take route 2 yourself**; state
it and wait for me.
If the header is ABSENT entirely (a project scaffolded before this existed), treat it as a WARNING, say
so, and continue - do not block work on an older project.

**Gate 3 - PROVE THE SHELL WORKS before writing a single line.** Run:
```
dad doc-stats
```
Use its numbers (done counts, next task) instead of counting by hand. If this command does not run - blocked,
denied, no such file - **STOP and tell me the shell is unavailable.** Do not proceed with edits. Everything
below this line depends on running the build, the tests and `close-unit`; a `/build` that cannot reach a
shell can only produce unverified code, and it will produce a great deal of it before anyone notices.

**If close-unit or qa-agent reports an ENVIRONMENT BLOCK (App Control / AppLocker / WDAC / policy /
access-denied on a .dll):** relay it to me verbatim and STOP. Do NOT send dev-agent back to 'fix' it - the
code is not the problem - and do NOT let any agent disable a service, add a Defender exclusion, or change
security policy. Lowering the machine's security is my decision, not the loop's.

Read `docs/STATUS.md` if present to orient. The docs are indexed - look things up with
`docs-find.ps1 "<question>"` (a shell command; `search_datasheets` is the same corpus) rather than
re-reading whole files. Nine graded runs called the MCP tool zero times and the shell constantly, so
prefer the shell door and stop guessing at contract text. ONE status file (`docs/STATUS.md`, librarian-written):
never create ad-hoc STATUS / BUILD_SUMMARY / NOTES files.

Scope: **$ARGUMENTS**  (empty = the next ready unit)

**UNIT** = a task from `docs/TASKS.md` when that exists (walk `## Build order`, take the next UNCHECKED
task whose dependencies are all `[x]`); otherwise a story from `docs/STORIES.md`. If no unchecked task has
its dependencies satisfied, STOP and report the blocked tasks.

## Per TASK
1. **Read the next ready task from `docs/TASKS.md` yourself.** It is already small and self-contained (the
   planner sharded it) - do NOT spawn requirements-agent for it and do NOT re-decompose it.
   *(No task map: spawn **requirements-agent** to select + flesh the next story from `docs/STORIES.md`.)*
2. **dev-agent** -> implement per CLAUDE.md conventions; collect its summary + any manual steps.
   *(If the unit has a VISIBLE SURFACE - a page, screen or component - spawn **ui-agent** instead. It is
   held to behaviour + accessibility gates and hands visual judgement back to me, because there is no exit
   code for taste. It will WAIT for my look; relay that and stop rather than closing the unit yourself.)*
2b. **UX review (visible surfaces ONLY).** After ui-agent builds the surface, spawn **ux-agent** to review
   it - reachability from the nav, hierarchy, affordances, form labels, empty/loading/error states,
   consistency. It does NOT edit; it returns a prioritized list (P1 broken, P2 confusing, P3 polish). Relay
   its **P1 and P2** items to **ui-agent**, which applies them directly; note P3 for me. This is a BUILD-TIME
   pass on purpose: **nothing is written into DESIGN / STORIES / TASKS** - the fix lands in the code and
   `close-unit -UxReviewed` records it in the commit, so the code plus its history are the documentation.
   ux-agent still hands the aesthetic call to me (no exit code for taste); it settles the mechanical half -
   a page nothing links to, a form with no labels, a view with no empty state. Skipping this pass is not
   silent: `doc-stats -Findings` reports `[ux]` when a project has visible surfaces but no commit records a
   review, exactly as it caught `ui-agent` never being routed.
   - If it reports a file got MANGLED: spawn **librarian-agent** in RECOVER mode, restore on my OK, retry
     with a smaller edit. Never let it hand-reconstruct a broken file.
   - **If `close-unit` reports the verification surface SHRANK, that is a recovery, not a retry.** A file
     that lost content is usually NOT "mangled" - it parses fine, it just has less in it, so nothing else
     will flag it. A run once rewrote a test file to add a fixture and 15 of 16 tests did not survive; the
     suite went green and every gate passed. Run:
     ```
     dad recover-lost
     ```
     It reports which NAMED UNITS (tests, methods, functions, headings) vanished, and separately which
     merely MOVED to another file - on the real incident 3 of 15 had moved, and restoring those would have
     duplicated them. `-Restore` puts the vanished ones back while KEEPING whatever the change ADDED; a
     whole-file revert throws away the good half (there it would have re-broken a fixture and two fixes
     that were correct). Then RECONCILE and build. Never re-close with `-AcceptShrink` to get past it
     unless I say the removal was deliberate.
   - If it returns **"needs contract"**: do NOT relay that to me until you have CHECKED it:
     ```
     dad doc-stats -Contract <Cn>
     ```
     **Exit 0 means the contract EXISTS and the claim is wrong** - it prints the heading and line number.
     Send dev-agent back with that location and tell it to `search_datasheets` for the contract instead of
     concluding it is absent. Only if this exits non-zero is it a real gap, and then STOP: pinning a
     contract belongs to `/design`, not this loop.
     A real run halted on "the contracts C6 and C7 are not present in DESIGN.md - a critical gap"; both
     were there, at lines 299 and 334, and it had also invented the contents of C5. A fabricated blocker
     costs a whole session, and whether a heading exists is a grep, not a judgement.
3. **qa-agent** -> write/run the tests. FAIL -> back to dev-agent with the details (max 3 rounds, then stop
   and summarize). PASS -> continue.
4. **Close it out by RUNNING the script** - do not perform these steps by hand:
   ```
   dad close-unit -Id <unit id> -Title "<short title>"
   ```
   It ticks the task, rolls the parent story up to DONE when all its tasks are `[x]`, reindexes, commits,
   and verifies. **Non-zero exit means the unit is NOT closed** - fix what it reports before the next unit.
   For a **visible-surface** unit that went through step 2b, add **`-UxReviewed`** (and optionally
   **`-UxNote "<what changed>"`**) so the commit records the pass and `doc-stats` stays quiet:
   ```
   dad close-unit -Id <unit id> -Title "<short title>" -UxReviewed -UxNote "nav + empty states"
   ```

## Per STORY (when close-unit reports `story <id> -> DONE`)
5. **grade-agent** -> grade the completed STORY. It writes `grades/<story id>_GRADE.md` and returns the
   grade + prioritized, tagged suggestions. **Gate (run these checks - a stub card is NOT a grade):** the
   file must exist, be **at least 800 bytes**, and contain **`## Grade history`**, **`## Assessment`** and
   **`## Suggestions`**. A one-line card saying "all criteria met" FAILS the gate - send it back to write a
   real assessment citing `file:line`.
6. **hygiene-agent** (give it the story id) -> applies the card's `[mechanical]` items plus its standard
   format/lint + project-file & dependency pass, then rebuilds.
7. If the grade is below B, or the card has critical `[dev]` suggestions: relay them to **dev-agent**, then
   re-grade (max 3 rounds). Then commit the story with the grade REQUIRED - the script fails if the card is
   missing or a stub, so you cannot close a story ungraded:
   ```
   dad close-unit -Id <story id> -Title "<story> polish" -RequireGrade
   ```
8. Present any manual steps + the human-verification checklist and WAIT for my confirmation.

## End of scope
Run CLAUDE.md's build command once more and report the result, then spawn **librarian-agent** (AUDIT) and
route approved fixes to their owners. `grades/` + `docs/STATUS.md` are the running record.

**Be decisive - act, don't narrate.** Spawn each subagent immediately and relay its result; never just
describe the plan, and never re-print this command instead of running it. Do NOT ask permission for
read-only steps or for the project's own build/test commands. The WAIT points above are only for my
choices and confirmations.

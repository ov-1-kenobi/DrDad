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

**Gate 3 - PROVE THE SHELL WORKS before writing a single line.** Run:
```
powershell -ExecutionPolicy Bypass -File "C:\Projects\Claude\MCP\DAD-kit\doc-stats.ps1"
```
Use its numbers (done counts, next task) instead of counting by hand. If this command does not run - blocked,
denied, no such file - **STOP and tell me the shell is unavailable.** Do not proceed with edits. Everything
below this line depends on running the build, the tests and `close-unit`; a `/build` that cannot reach a
shell can only produce unverified code, and it will produce a great deal of it before anyone notices.

Read `docs/STATUS.md` if present to orient. The docs are indexed: have subagents
`search_datasheets` rather than re-read whole files. ONE status file (`docs/STATUS.md`, librarian-written):
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
   - If it reports a file got MANGLED: spawn **librarian-agent** in RECOVER mode, restore on my OK, retry
     with a smaller edit. Never let it hand-reconstruct a broken file.
   - If it returns **"needs contract"**: do NOT relay that to me until you have CHECKED it:
     ```
     powershell -ExecutionPolicy Bypass -File "C:\Projects\Claude\MCP\DAD-kit\doc-stats.ps1" -Contract <Cn>
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
   powershell -ExecutionPolicy Bypass -File "C:\Projects\Claude\MCP\DAD-kit\close-unit.ps1" -Id <unit id> -Title "<short title>"
   ```
   It ticks the task, rolls the parent story up to DONE when all its tasks are `[x]`, reindexes, commits,
   and verifies. **Non-zero exit means the unit is NOT closed** - fix what it reports before the next unit.

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
   powershell -ExecutionPolicy Bypass -File "C:\Projects\Claude\MCP\DAD-kit\close-unit.ps1" -Id <story id> -Title "<story> polish" -RequireGrade
   ```
8. Present any manual steps + the human-verification checklist and WAIT for my confirmation.

## End of scope
Run CLAUDE.md's build command once more and report the result, then spawn **librarian-agent** (AUDIT) and
route approved fixes to their owners. `grades/` + `docs/STATUS.md` are the running record.

**Be decisive - act, don't narrate.** Spawn each subagent immediately and relay its result; never just
describe the plan, and never re-print this command instead of running it. Do NOT ask permission for
read-only steps or for the project's own build/test commands. The WAIT points above are only for my
choices and confirmations.

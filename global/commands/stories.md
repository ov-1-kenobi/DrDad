---
description: Manage STORIES.md - expand the DESIGN epics into stories, normalize/dedupe, or migrate stories out of an old design doc. Small in-place edits, one story at a time, no whole-file reprints.
argument-hint: [audit | migrate | expand <epic> | <story id> | empty = audit]
---
Manage the story backlog in **STORIES.md** - ONE story at a time, WITHOUT rewriting the whole file (a full
rewrite is what makes a local model loop and blow the output limit).

## ONE AGENT PER UNIT. Never one agent for the whole job.

Measured across four real runs - the scope of the spawn is what decides whether it survives:

| spawn | scope | tool calls |
|---|---|---|
| `taskmap-agent(S1.2-S1.5)` | 4 stories | **5** - fine |
| `taskmap-agent(S2.1-S2.8)` | 8 stories | **9** - fine |
| `taskmap-agent(S4.1-S4.7)` | 7 stories | **920** - killed by hand |
| `scribe-agent(all epics)` | everything | **947**, then **1023** - hours lost |

Small spawns finish in single digits. So delegation is fine; **one agent trying to manage the whole job is
not**. Spawn a SEPARATE agent for each unit, so every one starts with a clean context holding only what
that unit needs, and so you get control back between them.

**Nothing can interrupt a spawn once it starts.** Not the `PreToolUse` loop guard (it does not fire for a
subagent's calls - proven by 1023 identical calls with the matcher set to every tool), not the `tools:`
frontmatter (it looped on a tool it does not even list), and not you: while a Task runs, YOU ARE SUSPENDED
awaiting its result, so you cannot poll it, read a progress file, or cut it short. Asking the agent to
check in is a prose instruction given to the one component that has stopped following instructions - that
was tried on a real run and it spiralled for hours anyway.

So the only controls you actually have are: **make each spawn small**, and **verify the moment it returns**.

**Tell the human to start the watchdog before a long pass** - it is the only thing that shortens a spiral,
by making the silence loud:
```
dad watch
```
(in a second terminal; a spiral writes NOTHING, so no-writes is the signal.)

**RETRY LIMIT - this applies to YOU, not the agent.** If a spawn returns and the count has not risen, you
may re-spawn that ONE unit ONCE. If the second attempt also fails, STOP and report which unit failed and
what the gate said. Do not work down the list re-spawning: an orchestrator that retries forever is the same
loop one level up.
## The old failure, for context

Measured, three consecutive runs, all inside a subagent:

| where | what happened |
|---|---|
| `taskmap-agent` | 920 identical `dir ... 2>nul` calls; session killed by hand |
| `scribe-agent` | 947 tool calls, STORIES.md never written at all |
| `scribe-agent` | **1023 identical `Search **/STORIES.md` calls**; hours burned, killed by hand |

Eleven graded runs in the MAIN loop: zero loops.

The reason is not model quality, it is observability. **Inside a subagent, nothing governs the tool calls:**

- The `PreToolUse` hook (`dad-loopguard`) **does not fire** for a subagent's calls. The third run above was
  the ideal case for it - an identical, consecutive, non-shell call, with the matcher set to every tool -
  and it ran 1023 times without a single block. Confirmed empirically, not assumed.
- The `tools:` frontmatter **does not restrain it either**. `scribe-agent` does not list `Glob`, and that is
  the tool it looped on; a previous run had it invoking `Bash`, which it also does not list.
- The subagent's transcript cannot reliably be exported, so you cannot even review what it did.

So a subagent is an unguarded, unobservable region. Story expansion iterates over many epics, which is
exactly where a spiral has room to grow - so it stays in the main loop, where the loop guard and the Stop
guard both demonstrably work and where every call is in the transcript.

Writing them here has a second benefit: you can verify after EVERY story instead of after thirty.

STORIES.md IMPLEMENTS the DESIGN contract; it does NOT redefine requirements (that is `/design`). Anything
needing a new requirement -> back to `/design`. STORIES.md stays editable even while DESIGN is `LOCKED`.

Read `CLAUDE.md` for the doc paths. If `docs/STORIES.md` does not exist, the scribe-agent creates it from
`templates/_common/docs/STORIES.md` first.

**Read the design doc ONCE, directly, with Read.** It is one file of 10-20 KB. Do not search for it: the
1023-call loop above was `Search **/STORIES.md` repeated forever, looking for a file whose path CLAUDE.md
already states. If STORIES.md does not exist, create it from `templates/_common/docs/STORIES.md`.

Pick the mode from **$ARGUMENTS**:
- **empty / `audit`** -> list the stories, their problems, and a suggested fix order. Relay it, then WAIT
  for me to pick what to fix (or "go" to fix in order).
- **`migrate`** -> an older project has stories still inside DESIGN.md/TEDD.md: lift them into STORIES.md
  ONE at a time, tagging each to an epic, and remove each from the design doc as you go.
- **`expand <epic>`** (e.g. `expand E1`) -> write the stories that epic implies, ONE AT A TIME.
- **a story id** (e.g. `S3`) or **"go"** -> normalize/create that story with small Edit calls.

**The loop, ONE EPIC AT A TIME - do not batch:**
1. Run `dad doc-stats -Findings` and snapshot the BEFORE numbers -
   `storiesTotal/tasksTotal/storiesDone/tasksDone` - then spawn **scribe-agent** via the **Task tool**
   (subagent_type: "scribe-agent"), scoped to **exactly one epic**, and say so in the prompt ("expand ONLY
   epic E2; do not touch any other epic"). It writes those stories with small Edits and returns a short
   summary. For a tiny project you may simply write the stories yourself here instead - both are fine, and
   the main loop has the guards.
2. Run the gate:
   ```
   dad doc-stats -Findings
   ```
   The story count must have RISEN, and no `[scribe]` finding may appear. If you see
   `STORIES.md is NNKB but NOT ONE story id is parseable`, the heading shape is wrong - fix it NOW, at
   story one, rather than discovering it after thirty. Required shape:
   `### Story S<n>: <title>   <!-- Status: TODO -->`
2b. Diff step 2's AFTER numbers against step 1's BEFORE snapshot (`deltaStories = afterStories -
   beforeStories`), then say the C1c Trigger-1 pricing sentence and WAIT for the human's explicit answer
   before moving to step 3 - do not auto-continue the loop. Fill `{unit}`/`{id}` from whatever grouping the
   TARGET project's own `docs/DESIGN.md` actually uses for the thing just expanded: "Epic"/`E2` if that
   design doc has an `## Epics` section, otherwise "Requirement"/`R36` (this kit's own `docs/DESIGN.md` is
   the no-epics case - its S1-S6 are tagged by R# only). Never hardcode the literal word "epic" here:
   ```
   "{unit} {id} added ~{deltaStories} stor(y/ies) (now {afterStories} stories / {afterTasks} tasks total,
   {storiesDone}/{afterStories} stories and {tasksDone}/{afterTasks} tasks DONE). Build what's already
   scoped now, or keep scoping the next {unit}?"
   ```
   If the human says build, stop the expand loop and hand off to `/build`. If they say keep scoping,
   continue to step 3.
3. Next epic - a FRESH agent, not the same one. After the last one, reindex.

**If you find yourself running the same search twice, stop searching and Read the file.** Two identical
lookups mean the answer is not coming from that door.

Never paste the whole file into chat. STORIES only - design decisions belong in `/design`, task breakdown in
`/taskmap`.

## S1 IS A WALKING SKELETON, NOT A BUILD SKELETON

The FIRST story must prove the system end to end, however trivially: one request in, one response out,
through the real layers, with an integration test against a real store. NOT "create the solution with
warnings as errors" - that is build configuration, and it leaves every later story adding to a pile nobody
has assembled.

Measured: a project reached 183 passing unit tests across 12 building projects, with a TWENTY-LINE host and
zero integration tests, having never once served a request. Every part worked; the thing did not exist.

A walking skeleton makes every later story an extension of something that RUNS, and it makes close-unit's
test gate mean INTEGRATION from the very first close instead of mocks.
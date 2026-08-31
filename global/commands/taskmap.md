---
description: TASKMAP mode - shard STORIES.md into a dependency-ordered task map (docs/TASKS.md) for tight-context /build or /spec runs, then reindex.
argument-hint: [optional story id to scope to; empty = all of STORIES.md]
---
Run the **taskmap-agent** to turn the stories into an executable task map.

**Best run on `use-quality.cmd` (Next)** - decomposition + dependency reasoning is the heaviest thinking in
the pipeline, and this is a run-once step so the offload latency is fine. `oss` (gpt-oss-20b) or a high-effort
reasoner also work.

Read `CLAUDE.md` for the doc paths. Source = **STORIES.md**; the chosen stack/architecture is in DESIGN.md
(or TEDD.md). Best run once DESIGN is `LOCKED` and the stories are stable; it also works earlier - just
re-run after stories change (it preserves task done-state).
Scope: **$ARGUMENTS**  (empty = all of STORIES.md).

**Shard ONE STORY AT A TIME** - spawn the taskmap-agent per story instead of asking it to regenerate the
whole map in one pass. Whole-file regeneration is what makes a local model drift into inventing a different
project (we have seen it fabricate peer networking, a metrics endpoint, and merged PRs that never existed).

1. **ONE AGENT PER STORY.** Spawn **taskmap-agent** via the **Task tool** (subagent_type: "taskmap-agent" -
   an AGENT, not a skill), scoped to **exactly one story**, and say so in the prompt ("shard ONLY story S3").
   Then, before the next one:
   - run `dad doc-stats -Findings`: the task count must rise, and no `[taskmap]` finding may appear,
   - then spawn a FRESH agent for the next story. Reindex once at the end.

   **Read `docs/STORIES.md` and the design doc DIRECTLY with Read** before you start - they are one file
   each, 10-20 KB. Do not search for a path CLAUDE.md already gives you; a repeated
   `Search **/STORIES.md` was the 1023-call loop.

   Verify per story: every task cites a story id that exists in `docs/STORIES.md`, every task heading is
   `### [ ] T<n>.<n> - <title>   (Story S<id>)` (close-unit matches that shape by regex), and nothing
   appeared that is absent from DESIGN/STORIES.

2. If the stack isn't decided yet (DESIGN architecture still TBD), tell me to finish `/design` first.
3. Relay its summary: tasks per story, the build order, the first ready tasks, and any open questions.
4. **GATE - prove the map is MACHINE-READABLE before you report success.** Run:
   ```
   dad doc-stats -Findings
   ```
   The task count it prints must be non-zero and must match what the agent said it wrote. If you see
   `TASKS.md is NNKB but NOT ONE task id is parseable` or `Build order sequences N id(s) that are DEFINED
   NOWHERE`, the map is a dead document - **fix the headings to `### [ ] T<n>.<n> - <title>   (Story S<id>)`
   and re-run this gate** before telling me anything is done.
   Measured on a real CMS run: 41 KB of tasks, `doc-stats` counted **0**, `/build` could select no unit,
   and nobody noticed because "tasks 0/0" reads like a project that simply has no tasks yet.
5. Then tell me: review `docs/TASKS.md`, and run `/build` (or `/spec`) - they work the next unchecked task
   whose dependencies are done, so each dev step stays small and the RAG already holds the map.

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

**Be decisive - act, don't narrate.** Spawn the agent immediately; do not ask permission for read-only steps.
The only WAIT is if the architecture isn't set (step 2) or there are blocking open questions.

## S1 IS A WALKING SKELETON, NOT A BUILD SKELETON

The FIRST story must prove the system end to end, however trivially: one request in, one response out,
through the real layers, with an integration test against a real store. NOT "create the solution with
warnings as errors" - that is build configuration, and it leaves every later story adding to a pile nobody
has assembled.

Measured: a project reached 183 passing unit tests across 12 building projects, with a TWENTY-LINE host and
zero integration tests, having never once served a request. Every part worked; the thing did not exist.

A walking skeleton makes every later story an extension of something that RUNS, and it makes close-unit's
test gate mean INTEGRATION from the very first close instead of mocks.

## UI COMPLETENESS IS TASKS, NOT AN AFTERTHOUGHT

Measured: a real CMS run built five feature stories (rich text, uploads, modals) and shipped a `_Layout`
linking to NONE of its four controllers - a set of pages with no way to move between them. The feature
stories never mentioned navigation, so no task owned it, so it never got built. UI completeness is the
connective tissue a feature backlog skips.

So when a story has a **visible surface** (a page, screen, or component):
- **Tag each surface task `[ui]`** in its title line, e.g.
  `### [ ] T3.4 - Pages list view [ui]   (Story S3)`. `/build` routes `[ui]` tasks to `ui-agent` ->
  `ux-agent` (behaviour + accessibility + design review) instead of to a generic `dev-agent`; the grade and
  `doc-stats` watch for them. (Put `[ui]` before the `(Story ...)` tag; the id and story still parse.)
- **Write the acceptance in UX language, not just function** - "reachable from the shared nav; the primary
  action is prominent; a scannable list; EMPTY / LOADING / ERROR states; conforms to `docs/STYLE.md`", not
  merely "renders the pages." *Minimal to use, and readable* is the bar.
- **Emit the connective tasks the stories forgot** - at least a **navigation / shell** task (every
  controller/page reachable from one place, with an active-state indicator) and, wherever a view shows data,
  its **empty / loading / error** states. Each is its own `[ui]` task with its own acceptance - because if
  they are not tasks, they are not built.

Cite `docs/STYLE.md` (the visual contract: palette / type / tone / branding) in a surface task's acceptance
so the model builds toward a defined look instead of reinventing it each run. If `STYLE.md` is still
unfilled, say so - that is a `/design` gap to raise, not something to guess.
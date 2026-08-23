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

1. Spawn the **taskmap-agent** via the **Task tool** (subagent_type: "taskmap-agent" - it is an AGENT, not
   a skill; the Skill tool will fail), once per story in scope. It reads that story + the DESIGN
   architecture, appends bite-sized self-contained task blocks with dependencies to **`docs/TASKS.md`**,
   and **reindexes** so the map is searchable.
   **After each story, verify:** every new task cites a story id that exists in `docs/STORIES.md`, every
   task heading is `### [ ] <id> - <title>   (Story Sx)` (close-unit.ps1 matches that shape by regex), and
   nothing appeared that is absent from DESIGN/STORIES. Send it back if any check fails.
2. If it reports the stack isn't decided yet (DESIGN architecture still TBD), tell me to finish `/design` first.
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
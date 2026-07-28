---
description: BLUEPRINT mode - shard STORIES.md into a dependency-ordered task map (docs/TASKS.md) for tight-context /build or /spec runs, then reindex.
argument-hint: [optional story id to scope to; empty = all of STORIES.md]
---
Run the **planner-agent** to turn the stories into an executable task map.

**Best run on `use-quality.cmd` (Next)** - decomposition + dependency reasoning is the heaviest thinking in
the pipeline, and this is a run-once step so the offload latency is fine. Gemma 4 (`plan`) or a high-effort
reasoner also work.

Read `CLAUDE.md` for the doc paths. Source = **STORIES.md**; the chosen stack/architecture is in DESIGN.md
(or TEDD.md). Best run once DESIGN is `LOCKED` and the stories are stable; it also works earlier - just
re-run after stories change (it preserves task done-state).
Scope: **$ARGUMENTS**  (empty = all of STORIES.md).

1. Spawn the **planner-agent** via the **Task tool** (subagent_type: "planner-agent" - it is an AGENT, not
   a skill; the Skill tool will fail). Relay the scope. It reads STORIES.md + the DESIGN architecture, breaks each
   story into bite-sized, self-contained tasks with dependencies and a build order, writes **`docs/TASKS.md`**,
   and **reindexes** so the map is searchable.
2. If it reports the stack isn't decided yet (DESIGN architecture still TBD), tell me to finish `/forge` first.
3. Relay its summary: tasks per story, the build order, the first ready tasks, and any open questions.
4. Then tell me: review `docs/TASKS.md`, and run `/build` (or `/spec`) - they work the next unchecked task
   whose dependencies are done, so each dev step stays small and the RAG already holds the map.

**Be decisive - act, don't narrate.** Spawn the agent immediately; do not ask permission for read-only steps.
The only WAIT is if the architecture isn't set (step 2) or there are blocking open questions.

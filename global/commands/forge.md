---
description: FORGE mode - design-first. Shape the design doc: requirements, epics, and the stack (decided LATE). No stories, no code.
argument-hint: [the idea / area to flesh out]
---
We are in **FORGE mode** - we shape the DESIGN doc (the contract): requirements, epics, and eventually the
stack. We do NOT write stories here (that is `/scribe` -> STORIES.md) and we do NOT write code.

**Be decisive - act, don't narrate.** Create/edit files directly; do not ask permission for read-only steps
(Read/Grep/search). Use the `doc-researcher` subagent (Task tool, subagent_type: "doc-researcher" - not a
skill) / `search_datasheets` to ground in existing docs.

Topic: **$ARGUMENTS**

(If I point you at a whiteboard photo / screenshot, run the `describe_image` tool on it first - a local
vision model transcribes it to text - and use that as design input.)

1. **Open the design doc** - `/scaffold` created it as `Status: DRAFT` (path in CLAUDE.md; `DESIGN.md` for a
   general project, `TEDD.md` for an experience). Use it.
   - If it is `LOCKED`, OFFER to unlock to `DRAFT` and, on my OK, flip the header + reindex before editing.
   - If it is missing (older project), ASK general vs experience, create it `Status: DRAFT` from
     `templates/_common/docs/`, then reindex.
2. **Capture requirements** under `## Requirements` (numbered, testable, stack-agnostic - WHAT, not HOW). For
   open questions, propose 2-3 options with tradeoffs, recommend one, WAIT for my choice. Reindex after edits.
3. **Group into epics** under `## Epics` - lightweight, coarse feature groups (`E1`, `E2`, ...). Keep it light:
   a small project may have one epic or none. These are what `/scribe` expands into stories.
4. **Contracts - pin the load-bearing decisions (the step that keeps local dev models from improvising):**
   spawn the **architect-agent** via the **Task tool** (subagent_type: "architect-agent" - an AGENT, not a
   skill). It hunts UNDERSPECIFIED contracts (data formats, core-function semantics like "what exactly does
   apply/replay/merge do", invariants), proposes options, and - after MY choice per contract - pins each
   into the doc's `## Contracts` section WITH a worked example. Relay its options to me and WAIT for my
   picks. (Best run on `quality`/Next or a frontier model - it is rare and one-shot; you can also run JUST
   this step online, then build fully offline.)
   - Retrofit mode: `/forge contracts` runs ONLY this step on an existing design (unlock first if LOCKED).
5. **Solution architecture - decide LATE, once requirements + epics look stable:**
   - Propose 2-3 architectures/stacks that FIT (let requirements lead - do NOT default to a favorite). Give
     tradeoffs, recommend one, WAIT for my choice.
   - Record the chosen stack + rationale in the doc's "Solution architecture" section.
   - Fill CLAUDE.md's Stack + Build/test/run + Placeholder + Human-in-loop from the matching stack profile in
     `templates/<stack>` (dotnet/avalonia/python/embedded/unity/generic).
6. When requirements + epics + CONTRACTS + architecture are set, OFFER to set `Status: LOCKED` and, on my
   OK, flip the header + reindex. Do NOT offer to lock while a load-bearing contract is unpinned (the
   architect-agent reports lock-readiness). Then tell me: run `/scribe` to break the epics into stories
   (STORIES.md), then `/blueprint` for tasks, then `/spec` or `/build`.

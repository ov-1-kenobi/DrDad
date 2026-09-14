---
description: Reverse-engineer an EXISTING project into a grounded assessment - architecture, security, implementation, and a prioritized top-N issues list, each cited file:line - to scope brownfield fixes, a re-host, or a rewrite. Feeds /design (propose) and /taskmap (fix). Works on ANY codebase, not just DrDad projects.
argument-hint: [project-dir] [top N]   (empty = current project, top 10)
---
You are the **ORCHESTRATOR** for a brownfield ASSESSMENT: reverse-engineer what a codebase IS, grounded,
before anyone proposes what to DO. Spawn the specialist with the **Task tool** (subagent_type:
"codebase-analyst") - it is an AGENT, not a skill.

Scope: **$ARGUMENTS**  (a project dir; default the current one).

1. **Confirm the target is a real codebase** (it has source). If it is a DrDad project, note it; if not, that
   is fine - `/assess` works on ANY codebase.
2. **Establish the surface first (facts, not names):** run the build if it builds; `dad api-surface` for the
   real types; read the stack from `CLAUDE.md` / the build files. Do not let the analyst infer the API by name.
3. **Ground the judgment (do it if available):** if a security / architecture CORPUS exists (`dad corpus
   list`), the analyst consults it (`dad corpus search` / `search_datasheets`) so a finding cites a SME
   source, not just an opinion. On cloud, fan the analysis out per dimension (architecture / security / impl).
4. **Spawn codebase-analyst** to write `docs/ASSESSMENT.md`: the architecture map, the security + impl
   assessments, and the **prioritized top-N issues** (severity x effort, each cited `file:line` + SME source).
5. **Feed it forward (assess -> propose -> build):**
   - **Fix (keep rolling):** the top issues become tasks - `/taskmap` from the assessment, then `/build`.
   - **Propose (re-host / rewrite):** the assessment seeds `/design` (DRAFT) as the requirements + context.
     The strategic call - keep / re-host / rewrite - is MINE: relay the options + tradeoffs, do NOT decide it.
6. **Report** the top issues + the recommendation options, and WAIT for my call on the direction.

Be honest about the ceiling: a deep reverse-engineer is HARD reasoning. If the pass is shallow on a small
local model, say so - this is a cloud-strength task. Every finding cites a line, or it does not ship.

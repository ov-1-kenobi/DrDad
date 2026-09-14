---
description: Set a knowledge corpus's directive and run a refresh cycle - validate the CORPUS.md manifest, fill gaps WITH you, ingest the listed sources (cited, dated), re-index, and exercise it. Works a corpus under an environment, not a project.
argument-hint: <corpus-name> [-env <env>]   (empty = list corpora and pick one)
---
You are the **ORCHESTRATOR**. A CORPUS is a persistent, cited knowledge bank (see `dad corpus`); this command
sets its DIRECTIVE and refreshes it. Spawn the specialist with the **Task tool** (subagent_type:
"corpus-agent") - it is an AGENT, not a skill.

Scope: **$ARGUMENTS**  (a corpus name, optionally `-env <env>`; default env is `default`).

1. **Resolve + orient.** If no corpus name was given, run `dad corpus list -Env <env>` (and `dad env list`)
   and ask which corpus. If the named corpus does not exist, offer `dad corpus new <name> -Env <env>` and STOP.
2. **Validate FIRST - a script settles completeness, not your eyes:**
   ```
   dad corpus check <name> -Env <env>
   ```
   Relay its `[corpus]` findings - these are the real gaps (empty Goal, unfilled Scope, no sources, no index).
3. **Refine the directive WITH me.** Spawn **corpus-agent** to turn the gaps into concrete questions and
   PROPOSE `CORPUS.md` edits. The directive is MINE to own: relay its questions + proposed fills, and apply
   them only on my OK. Do not let it guess my intent or widen `## Scope` on its own.
4. **Run the cycle on my go** (it fetches from the web). corpus-agent ingests each source (cited + DATED in
   `SOURCES.md`), re-indexes (`dad corpus build`), and EXERCISES the bank (`dad corpus search`) so I can see
   it answers. Relay the evidence. A stale corpus is worse than none - if it flags stale sources, surface it.
5. **Report** what changed: filled sections, sources ingested, index freshness, and any contested "take" it
   handed back to me. Nothing here touches a PROJECT's docs - this is corpus work, by environment, by corpus.

Be decisive - spawn corpus-agent and relay; do not narrate a plan instead of running it. The WAIT points are
my directive approvals and my go on the ingest cycle.

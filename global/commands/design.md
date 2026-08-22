---
description: DESIGN mode - design-first. Shape the design doc: the STACK (decided FIRST), then requirements and epics. No stories, no code.
argument-hint: [the idea / area to flesh out]
---
We are in **DESIGN mode** - we shape the DESIGN doc (the contract): requirements, epics, and eventually the
stack. We do NOT write stories here (that is `/stories` -> STORIES.md) and we do NOT write code.

**Be decisive - act, don't narrate.** Create/edit files directly; do not ask permission for read-only steps
(Read/Grep/search). Use the `doc-researcher` subagent (Task tool, subagent_type: "doc-researcher" - not a
skill) / `search_datasheets` to ground in existing docs.

Topic: **$ARGUMENTS**

(If I point you at a whiteboard photo / screenshot, run the `describe_image` tool on it first - a local
vision model transcribes it to text - and use that as design input.)

0. **If the topic needs evidence you do not have, STOP and tell me to run `/research` first.** It is the
   only online mode; it builds `docs/sources/` with provenance and leaves `[Snnn]`-citable findings for you
   to design from. Cite them here rather than restating them. If `docs/SOURCES.md` has anything under
   `## Open questions` that this design depends on, say so before proceeding.
1. **Open the design doc** - `/scaffold` created it as `Status: DRAFT` (path in CLAUDE.md; `DESIGN.md` for a
   general project, `TEDD.md` for an experience). Use it.
   - If it is `LOCKED`, OFFER to unlock to `DRAFT` and, on my OK, flip the header + reindex before editing.
   - If it is missing (older project), ASK general vs experience, create it `Status: DRAFT` from
     `templates/_common/docs/`, then reindex.
2. **Solution architecture - decide the STACK NOW, before anything downstream depends on it:**
   The stack used to be chosen last, on the theory that late commitment keeps options open. In practice it
   blocked everything: CLAUDE.md has no Build/test command until a stack exists, so `/build` Gate 1 refuses
   to start and `close-unit` can verify nothing; the contracts below are stack-flavoured anyway (they name
   real library types); and the library docs cannot be ingested until you know the libraries - which is how
   a project shipped 16 compile errors from guessed API calls. Decide it here.
   - Propose 2-3 architectures/stacks that FIT (let requirements lead - do NOT default to a favorite). Give
     tradeoffs, recommend one, WAIT for my choice.
   - Record the chosen stack + rationale in the doc's "Solution architecture" section.
   - Fill CLAUDE.md's Stack + Build/test/run + Placeholder + Human-in-loop + any hygiene section by copying
     them from the matching **stack profile fragment** `templates/<stack>/PROFILE.md`
     (dotnet | web | avalonia | python | embedded | unity). Copy ONLY those sections - the profile is a fragment
     and deliberately contains nothing else; every other section is kit-owned and already in CLAUDE.md.
   - **Do not copy version numbers out of a profile.** The profiles tell you to detect the installed
     toolchain (e.g. `dotnet --list-sdks`) and record the chosen version here. Follow that. Also pin the
     toolchain for a clean machine where the ecosystem supports it (e.g. a `global.json` for .NET).
   - **INGEST THE LIBRARY DOCS NOW - do not defer this.** For every third-party library the architecture
     commits to, `web_search` its official API reference and `ingest_url` the pages you will actually need
     (the types/methods the stories touch), then reindex. List what you ingested under "Solution
     architecture". Rationale: a dev-agent that cannot find a signature INVENTS one - a single project shipped
     16 compile errors from guessed Magick.NET calls. Putting the real docs in the corpus at design time is
     the only reliable fix; "remember to look it up later" is not.
   - **GATE - verify CLAUDE.md actually got filled.** Grep it for `<decided in`, `<set in`, `<how to stub`,
     `# Project: <name>`. If ANY remain, the step is NOT done - fill them now. A CLAUDE.md still holding
     placeholders means dev-agent and qa-agent have **no build or test command**, so they improvise their
     own test reporting (that is where stray TEST_RESULTS.md / TEST_SUMMARY.md files come from) and `/build`
     cannot verify anything. Replace the project name too.
2b. **SECURITY REVIEW - ask me, once the stack is known.** The design doc carries a
   `Security review: REQUIRED | NOT-REQUIRED (<why>) | DONE <YYYY-MM-DD>` header. Tell me which you think
   it should be and WAIT:
   - **REQUIRED** (the default) for anything that handles auth, user data, uploads, payments, or is
     internet-facing. A CMS, an API, a web app.
   - **NOT-REQUIRED (<reason>)** for a throwaway POC, a local-only tool, a library with no I/O boundary.
     The reason goes in the header - "poc, no auth, never deployed" - so a later reader knows it was a
     decision and not an omission.
   If REQUIRED, spawn **security-agent** via the **Task tool** (subagent_type: "security-agent" - ONLINE).
   It pins CURRENT (under ~6 months old) framework and security guidance for THIS stack into
   `## Security decisions`, each line citing a dated source in `SOURCES.md`. Relay its findings; I approve;
   then set the header to `DONE <today>`. **You do not flip that header on your own.**
   **If the agent reports it could not search** (every tool it has is an MCP tool - `web_search`,
   `ingest_url`, `search_datasheets` - so an unconnected `local-tools` server leaves it with nothing), say
   so plainly and STOP. Do not relay a security review it produced from memory, and do not quietly leave
   the header REQUIRED with no route forward - `/build` refuses to start on REQUIRED, so that combination
   is a dead end. Give me the three real options: fix the server (`/mcp` to check, `dad-doctor.cmd` to
   diagnose), decide `NOT-REQUIRED (<reason>)` deliberately, or proceed with the framework's own docs if
   they are already in the corpus (`docs-find.ps1 "<question>"`) - and label those decisions as
   corpus-only, not current-as-of-today.
   Do this BEFORE contracts and stories: retrofitting auth and input handling after a dozen stories is how
   the insecure version ships. `/build` refuses to start while the header says REQUIRED.
   Then gate the citations:
   ```
   powershell -ExecutionPolicy Bypass -File "C:\Projects\Claude\MCP\DAD-kit\source-stats.ps1" -StaleDays 180
   ```
   180 days, not the default year: security guidance ages faster than anything else here.

3. **Capture requirements** under `## Requirements` (numbered, testable - WHAT, not HOW; the stack is now
   known, so name real types where it sharpens a requirement). For open questions, propose 2-3 options with
   tradeoffs, recommend one, WAIT for my choice. Reindex after edits.
4. **Group into epics** under `## Epics` - lightweight, coarse feature groups (`E1`, `E2`, ...). Keep it light:
   a small project may have one epic or none. These are what `/stories` expands into stories.
5. **Contracts - pin the load-bearing decisions (the step that keeps local dev models from improvising):**
   spawn the **architect-agent** via the **Task tool** (subagent_type: "architect-agent" - an AGENT, not a
   skill). It hunts UNDERSPECIFIED contracts (data formats, core-function semantics like "what exactly does
   apply/replay/merge do", invariants), proposes options, and - after MY choice per contract - pins each
   into the doc's `## Contracts` section WITH a worked example. Relay its options to me and WAIT for my
   picks. (Best run on `quality`/Next or a frontier model - it is rare and one-shot; you can also run JUST
   this step online, then build fully offline.)
   - Retrofit mode: `/design contracts` runs ONLY this step on an existing design (unlock first if LOCKED).
6. When requirements + epics + CONTRACTS + architecture are set, OFFER to set `Status: LOCKED` and, on my
   OK, flip the header + reindex. Do NOT offer to lock while a load-bearing contract is unpinned (the
   architect-agent reports lock-readiness). Then tell me: run `/stories` to break the epics into stories
   (STORIES.md), then `/taskmap` for tasks, then `/spec` or `/build`.

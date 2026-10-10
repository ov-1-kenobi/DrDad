# Technical Design Document - DrDad (Design Research Document, Agentic Development)

Status: LOCKED
Security review: NOT-REQUIRED (FOUNDATIONAL and permanent, not a per-release waiver - the kit handles NO security: it authenticates no one and stores, reads or brokers no credential; at most it passes a harness's or tool's own auth through untouched. See ## Out of scope "Handling security". A dev CLI that runs on the user's own machine in every mode; no user data stored, no exposed service; the kit stores and reads no credentials - a harness's login is its own, including R34's cloud/hybrid Anthropic key, and the Local path (R1; R37's BYOK to local Ollama) needs no account at all, so the kit itself never asks for one. Re-confirmed 2026-09-29 against doc-stats' auth-keyword WARN: the hits are LLM token counts - R38c/C4a, harness session ids - C3b/C4b, the harness's own login and dummy local-Ollama auth token, and the secret scanner's detection patterns; none is this kit authenticating anyone)
Security waiver confirmed: 2026-10-01 (human; auth-keyword hits: 145)
<!-- This describes the kit AS IT SHOULD WORK; implement/maintain it via /spec or /build.
     Flip to DRAFT (and use /design or /proto) only to change the design itself. -->

## Goal
A working implementation of the loop-engineering shape - a spec before code, a verifier that checks real
correctness, and context that persists across sessions - enforced by DETERMINISTIC gates the model cannot skip.
The thesis is "never accept an assertion a script can settle". It runs the real Claude Code agentic loop on
Windows, with a single C# MCP server for document RAG, per-project corpora, a design/proto/spec/build mode
system, and one-command model switching. **Cloud is the DEFAULT backend** (R34); **Local** (Ollama on the user's
own NVIDIA GPU, no network) is kept as a RESILIENCE mode for one real case - a disconnected afternoon where
output is still wanted, e.g. feeding datasheets to the local corpus RAG for a simple SoC/IC wiring plan, or a
small Unity3D prototype from a one-page game design document; **Hybrid** is the cloud loop plus the GPU as a
drudge co-processor. Every command, agent, and gate is identical across all three. Local-only was the naive
starting point and is not a pursuit. *(Reworded 2026-10-06, Story S28: this section used to say the loop runs
"fully offline" and that offline is "the DEFAULT and the thesis".)*

## Requirements
- [x] R1: (**Local mode**, the resilience backend - R34b; Cloud is the default, R34a, amended 2026-10-06.)
      Point Claude Code at local Ollama via `settings.json` `env` (`ANTHROPIC_BASE_URL=http://localhost:11434`,
      dummy `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_MODEL`) to skip the login screen, plus offline flags
      (telemetry/autoupdater off). apiKeyHelper is deliberately NOT set - having both caused a per-session
      Claude Code auth warning; the token alone suffices (apikey.cmd kept only as a fallback).
      Amended 2026-10-01 from S16 / T16.1 (Claude Code 2.1.285, measured 2026-09-30): an unknown `-cc` model
      id is a WARNING (`[claude-code:unrecognized_model]`), not a rejection - local runs succeed. Precedence:
      the USER `settings.json` `env.ANTHROPIC_MODEL` OVERRIDES a process-level `ANTHROPIC_MODEL` (and a project
      `.claude/settings.json` env beats the user one), so a kit probe that must reach a specific local model
      passes `--model <-cc name>` and never relies on the process env var. Detail and the probe rule: C4a.
- [x] R34: **Three backend modes, one loop - and the GPU is never idle.** Amended 2026-10-06 (Stories S28/S29,
      human decision): **Cloud is the DEFAULT**, and the modes are ordered Cloud, Local, Hybrid. They share every
      command, agent, and gate - only where the AGENT LOOP runs changes. The installer's mode rules (which flag
      selects which mode, what a no-flag run does, what a re-run keeps) are pinned in contract C6; C6 is
      DECIDED and IMPLEMENTED (Story S29, v0.59.0: `install-mode.ps1` resolves the mode, a no-flag install is
      Cloud on a machine with nothing to keep, and the end-to-end install test runs in a sandbox).
      (a) **Cloud** (`install.ps1 -Cloud`, and no flag per C6): the `ANTHROPIC_BASE_URL` redirect is DROPPED, so
          Claude Code uses its normal Anthropic auth; aliases resolve to each model's `cloud` id in `models.json`
          (dev/coder/oss/gemma -> Sonnet, fast -> Haiku, quality -> Opus). The ABSENCE of the base-URL is the
          mode tell - `use-model` and `dad-doctor` read it back; no marker file. **The GPU is NOT idle in cloud
          mode:** `local-tools` reaches Ollama independent of the agent loop, so semantic RAG and
          `describe_image` still run on it - and cloud install VERIFIES the embed/vision models are pulled, so a
          literal-scan degrade is LOUD, not silent.
      (b) **Local** (`install.ps1 -Local` per C6): R1 - Claude Code -> Ollama; the whole
          loop on the GPU, no network. A RESILIENCE mode, not the goal: it exists for a disconnected afternoon
          where output is still wanted (datasheets in, a simple SoC/IC wiring plan out; a small Unity3D
          prototype from a one-page design doc), and it is the weakest backend - a full `/design -> /build ->
          close` has not completed on a local model without human repair.
      (c) **Hybrid** (`install.ps1 -Hybrid`): the cloud agent loop of (a) PLUS the GPU offered to the cloud
          model as a drudge co-processor. `install` sets `LOCALTOOLS_HYBRID=1` in `settings.json` env (the
          single mode tell; cleared on a cloud/local re-install), which registers ONE extra MCP tool,
          `local_generate`: the cloud model delegates BOUNDED, low-stakes generation to the local model (an
          implementation guess it will review, synthetic test data, boilerplate). Its output is a DRAFT the
          cloud model verifies, prefixed `[LOCAL DRAFT - verify before use]`; never banked or shipped raw, and
          never used for reasoning that must be right or anything a test cannot check.
      Division of labor: **cloud = the brain; the local GPU = senses (embeddings, vision) and drudge-work.**
      The fence is DETERMINISTIC, not prose (the R-thesis): `local_generate` is a SEPARATE tool type
      (`HybridTools`) registered ONLY when `Rag.HybridEnabled` is true - `Program.cs` uses explicit
      `WithTools<T>()`, not assembly scanning - so in local/cloud mode the tool does not exist in the advertised
      list at all, and a model cannot be handed a job the mode exists to keep on the cloud brain.
      `dad-doctor` reports the mode, and in hybrid it sets the flag and PROBES the running server to confirm
      `local_generate` is actually exposed (not merely that the marker is set), warning if it leaks into a
      non-hybrid install. Draft model defaults to `models.json`'s default (`devstral`); override with
      `LOCALTOOLS_DRAFT_MODEL`.
- [x] R2: One C# MCP server (`local-tools`, stdio, `net8.0` + `RollForward=LatestMajor`) exposing
      `index_datasheets`, `search_datasheets`, `list_datasheets`, `ingest_url`, `web_search`,
      `describe_image` (local vision model via Ollama, default `gemma3:4b`, override `LOCALTOOLS_VISION_MODEL`),
      `detect_objects` (ONNX detector, `LOCALTOOLS_DETECT_MODEL`), `transcribe_audio` (Whisper via uv). Embeddings via
      Ollama `nomic-embed-text`; vectors in `<docs>\.index\chunks.json`; brute-force cosine; `.index` excluded from the corpus.
- [x] R3: Per-project corpora - each project's `.mcp.json` sets `LOCALTOOLS_DOCS_DIR` to its own `docs\`.
- [x] R4: Staleness handling - opt-in `LOCALTOOLS_AUTO_REINDEX=1` (re-index at search when docs changed) and a
      `--reindex <docsDir>` CLI mode (+ `reindex.cmd`) for one-offs/scheduling.
- [x] R5: Modes as global slash commands: `/design` (design-first, no code), `/proto` (build-as-you-go),
      `/spec` (implement a LOCKED doc), `/build` (orchestrate the agent team), `/assets` (Unity art list),
      `/scaffold` (stack-agnostic init), `/stories` (manage STORIES.md), `/taskmap` (shard STORIES.md into
      a task map), `/tidy` (code hygiene + project/dependency integrity), `/diagram` (Mermaid architecture
      view of DESIGN.md -> docs/ARCHITECTURE.md), `/audit` (cross-doc audit + routed fixes; `recover
      <file>` = git triage for a mangled file), `/document` (brownfield reverse-engineer into a DRAFT design,
      R26), `/research` (build the cited evidence corpus before design, ONLINE, R23), `/retro` (propose
      convention changes from grade trends, R27), `/assess` (grounded existing-codebase assessment ->
      `docs/ASSESSMENT.md`, `codebase-analyst`), `/corpus` (build/refresh one persistent cited knowledge
      corpus from its `CORPUS.md` directive, `corpus-agent`), `/grade` (backfill one unit's grade card,
      `grade-agent`).
- [x] R6: Agent team installed globally: `requirements-agent`, `architect-agent`, `taskmap-agent`, `dev-agent`,
      `grade-agent`, `qa-agent`, `doc-researcher`, `hygiene-agent`, `scribe-agent`, `librarian-agent` (read-only cross-doc
      auditor: schema/traceability/state-consistency/grade-card presence; findings tagged by owner and
      routed by the orchestrator; git RECOVER triage), `research-agent` (evidence corpus with provenance,
      ONLINE, R23), `ui-agent` (implements a visible surface, gated on behaviour/accessibility not looks,
      R25), `survey-agent` (read-only brownfield reverse-engineer, R26), `security-agent` (pins current
      framework/security guidance into the design doc, ONLINE, R31), `codebase-analyst` (grounded
      architecture/security/implementation assessment of an EXISTING codebase -> `docs/ASSESSMENT.md`,
      every finding cited `file:line`; via `/assess`), `corpus-agent` (builds/refreshes one persistent
      knowledge corpus from its `CORPUS.md` directive, cited sources only; via `/corpus`), `playtest-agent`
      (for an EXPERIENCE project, turns a just-built interactive unit into a concrete playtest protocol -
      cannot score fun, hands the verdict to the human), `ux-agent` (reviews a just-built visible surface
      for usability against `docs/STYLE.md`, returns prioritized fixes for `ui-agent` - does not edit, hands
      taste to the human). `scribe-agent` manages STORIES.md (expand
      epics into stories, normalize, migrate); `taskmap-agent` shards STORIES.md into `docs/TASKS.md` (a
      dependency-ordered map of bite-sized tasks, reindexed) for tight-context runs; `grade-agent` grades each story's implementation into a running
      report card (`grades/<id>_GRADE.md`) and emits tagged suggestions; `hygiene-agent` applies the
      `[mechanical]` ones (standards/lint + project-file & dependency integrity). `/build` order: per TASK
      dev -> qa -> `close-unit.ps1`; per STORY grade -> hygiene (see R18).
- [x] R7: **Layered docs + stack-agnostic scaffold + EARLY architecture.** `/scaffold <general|experience>`
      (`new-project.ps1`) lays down CLAUDE.md + .mcp.json + `docs/` AND creates the design doc - `DESIGN.md`
      (general) or `TEDD.md` (experience) - as `Status: DRAFT` (NO stack chosen). The design is split by
      lifecycle: **DESIGN.md/TEDD.md** (contract: requirements, epics, stack - owned by `/design`, the only
      lockable doc), **STORIES.md** (story backlog - `/stories`), **TASKS.md** (task map - `/taskmap`).
      `/design` decides the stack FIRST (crib from `templates/<stack>`: dotnet/avalonia/python/embedded/unity/
      generic). `/design` and `/proto` flip DESIGN `Status:` DRAFT<->LOCKED on confirmation; STORIES/TASKS stay
      editable while LOCKED; `/spec` and `/build` gate on DESIGN LOCKED.
      **Architecture is decided FIRST, not late** (reversed 2026-08-13). The original rule deferred the
      stack to keep options open; three graded runs showed it only deferred the blockers. CLAUDE.md has no
      Build/test command until a stack exists, so `/build` Gate 1 refuses and `close-unit` can verify
      nothing; the contracts are stack-flavoured anyway (they name real library types); and library API
      docs cannot be ingested before the libraries are known - which is how one project shipped 16 compile
      errors from guessed Magick.NET calls. `/scaffold` stays stack-agnostic (it is deterministic and
      model-free); `/design` step 2 picks the stack, fills CLAUDE.md from the profile fragment, and ingests
      the library docs BEFORE requirements, epics and contracts are written.
- [x] R23: **RESEARCH mode - build the evidence corpus first, with provenance** (`/research` +
      `research-agent`, ONLINE; everything downstream stays offline). Research runs BEFORE `/design`: a
      deliverable is deliberately NOT required yet, because the contracts layer is deliverable-agnostic -
      pin the DATA contracts from what you found and whatever gets built on top (site, report, form) comes
      later. The problem this has to solve is not finding things, it is PROVENANCE: a corpus without it is
      the same failure as code without a build, where six weeks later the design doc says "the market grew
      14%" and nobody can tell a statistics office from a content farm. So: captured sources live in
      `docs/sources/` named `S<nnn>-<slug>`, every one gets a row in `docs/SOURCES.md` (id, tier, fetched,
      title, url) plus a line saying which question it answers, and design-doc claims cite `[Snnn]`.
      **`source-stats.ps1` is the gate** - FAILs on a citation with no ledger row or a row whose file is
      missing; WARNs on untiered, uncited, unrecorded or stale sources. It verifies TRACEABILITY, NOT
      TRUTH: a perfectly-cited wrong number is still wrong. **Tiering is the human's call** (primary /
      secondary / unknown) - `research-agent` must always write `unknown`, because source quality is the
      one judgement nothing downstream can recover from if a model gets it wrong. One writer per doc holds:
      research-agent owns `docs/sources/` + `SOURCES.md` and never touches the design doc; `doc-researcher`
      stays OFFLINE and reads the corpus rather than building it. Sources are committed and indexed as
      PLAINTEXT, so capturing credentials or personal data is prohibited. The corpus supports **MULTIPLE
      ROOTS** - `LOCALTOOLS_DOCS_DIR` takes a `;`-separated list, the first root owns `.index\`, nested
      roots collapse so nothing is indexed twice, and a missing root degrades the corpus instead of
      breaking the server (`local-tools --corpus` shows what would be indexed, per root, with no Ollama
      needed). Unsettled questions stay under `## Open questions` in SOURCES.md - "we could not establish
      X" is a finding; guessing X is a defect.
- [x] R8: One-command installer (`install.ps1` / `install.cmd`) that detects its own location, builds the model
      `-cc` variants + the C# server, installs commands/agents/`settings.json` with paths auto-fixed
      (JSON parse/serialize, idempotent, move-safe), and tunes Ollama.
- [x] R9: Model switching (`use-model.ps1`/`.cmd`, `use-fast`/`use-quality.cmd`) editing `ANTHROPIC_MODEL`; aliases
      `oss`=gpt-oss-20b-cc, `dev`=devstral-cc (default), `fast`=qwen3-14b-cc, `quality`=qwen3-coder-next-cc.
- [x] R10: Ollama GPU tuning (flash attention, KV-cache quant, keep-alive) via `ollama-tuning.ps1`.
- [x] R11: Optional voice loop (`voice.py` + `voice.cmd`, Python managed by uv - a standalone utility, NOT an
      MCP server): push-to-talk mic -> faster-whisper STT (GPU) -> headless `claude -p --continue` (direct
      child-process stdio; no window handles/TUI scraping) -> Windows SAPI TTS. Run from the project folder.
- [x] R12: Per-project proven-commands log: `/scaffold` creates `docs/RECIPES.md` (indexed). All sessions +
      the shell-running agents (dev/qa/hygiene) CONSULT it via `search_datasheets` before unfamiliar shell
      ops and APPEND on new successes (Command / Does / When / Gotcha / Verified), then reindex - so future
      agents look up syntax that actually worked on this machine instead of re-guessing per model. No secrets.
- [x] R13: Git safety net: `/scaffold` runs `git init` + `.gitignore` + an initial commit (with `-c`
      user fallbacks; graceful skip if git absent). `/build` and `/spec` COMMIT after every unit that
      passes qa (each passing unit = a restore point). A mangled file is RESTORED from git (librarian
      RECOVER triage -> `git checkout`), never hand-reconstructed. `/build` gates on the grade card
      existing on disk and runs an /audit pass at end of scope.
- [x] R14: Status dashboard: `/scaffold` creates `docs/STATUS.md` (indexed) - done / next ready / dated
      blockers / notes for the next session. DERIVED working memory: the librarian-agent is its ONLY
      writer and REGENERATES it from TASKS/STORIES/grades (sources win on conflict) - on `/audit
      status`, at every AUDIT, and when `/build` stops on a blocker. Sessions read it first to orient.
      ONE status file: ad-hoc root STATUS/BUILD_SUMMARY/NOTES files are prohibited (CLAUDE.md + /build)
      and flagged by the librarian audit.
- [x] R24: **State findings are COMPUTED, not observed.** R14 made `docs/STATUS.md` derived; this extends
      the same rule to the audit itself. An `/audit` on a healthy project reported "DESIGN.md Status: LOCKED
      header missing" (line 5), "STORIES.md missing `<!-- Status -->` markers for S2-S6" (all 14 had them)
      and "TASKS.md has 0 tasks with `[x]`" (10 were ticked) - immediately after running `doc-stats`, which
      had printed the real numbers. Approving those "fixes" would have rewritten a correct header and
      re-ticked ticked tasks. So `doc-stats.ps1 -Findings` now GENERATES that whole category - design status,
      story Status markers and their vocabulary, roll-up disagreement in both directions, missing/stub grade
      cards, done units with no commit naming them, orphan test projects - and prints a `STATE FACTS` line
      the orchestrator passes to the librarian as ground truth it may not contradict. The librarian-agent is
      explicitly forbidden to author state findings; its remit is what no script can settle - scope
      contamination, traceability judgement, corpus health. Paired with `-Contract <Cn>`, which refutes a
      claimed-missing contract by grep (the same run called C2PA signing absent when it is that project's contract 10-b). The
      general rule, now applied three times: **never accept an assertion a script can settle** - not for
      counts (R14), not for a contract, not for document state.
- [x] R25: **UI units are gated on behaviour and accessibility, never on looks** (`ui-agent`,
      `templates/web/PROFILE.md`). There is no exit code for taste, so the parts that CAN be verified are
      the ones the agent is accountable for: the build with type errors fatal, tests that drive the thing
      like a user ("renders without crashing" passes on a blank page), an axe/pa11y run treated exactly
      like a failing unit test, and the 360px viewport. Visual judgement goes back to the human, once,
      with a specific thing to open and expect - the agent may never call a visual surface "done" on its
      own authority. Loading/empty/error states are acceptance, not polish. `/build` routes a unit with a
      visible surface here instead of dev-agent.
- [x] R26: **Brownfield adoption** (`/document` + `survey-agent`). The kit assumed greenfield; most work
      is not. `/document` reverse-engineers an EXISTING codebase into a DRAFT design doc plus a backlog of
      what REMAINS, one area per survey. The rule is DESCRIBE, NEVER INVENT: every claim cites `file:line`,
      anything taken from a name rather than logic is marked `(inferred)`, and "cannot determine X" is a
      finding rather than a gap to fill plausibly - a brownfield doc describing an idealised version of the
      code is worse than none, because every agent downstream implements against the fiction. Contracts are
      derived from `docs/API-SURFACE.md` (real signatures out of the compiled assemblies), which is why
      this works here at all. `survey-agent` is READ-ONLY and counts tests rather than assuming coverage
      from a csproj.
- [x] R27: **The retro loop** (`/retro` + `grade-trends.ps1`). Grade cards were per-unit islands: each
      said how ONE story went, and nothing asked what kept going wrong ACROSS units, so the same defect was
      found, written down, and found again three stories later. `grade-trends.ps1` computes the half a
      script can - grade direction (chronologically, by the dates in each card's history table, NOT by
      filename), units that needed rework, stub cards, and recurring themes; a theme in 40%+ of cards is a
      convention problem rather than bad luck. `/retro` then proposes at most THREE changes, each naming
      what it would have prevented, routed to CLAUDE.md (a convention), RECIPES.md (a proven command),
      `/design` (a missing contract) or - when no prose will stop a recurring defect - escalated as a
      request for a GATE in the kit. The human approves. Grades are read from where a card STATES them
      (`**Current grade: X**` / the history table), never by scanning prose for a capital letter: a first
      version matched "A worked example" and reported the wrong direction on a real project.
- [x] R28: **The verification surface may not SHRINK silently** (`ratchet.ps1`, enforced by `close-unit`).
      Every gate up to here asked "is X OK right now?" - and a gate of that shape is satisfied by DELETING
      X. Measured: a run set out to fix the IIIF tests, rewrote the test file to introduce a fixture, and
      15 of 16 tests did not survive the rewrite (including that project's contract-9 worked example, the level-2 conformance
      check and the byte-identical guarantee). The report read "8 passed, 3 failed" and EVERY gate went
      green - build passed, tests RAN (11 > 0), tests PASSED (8), tree clean - because none of them
      compared against what had been there before. The model was not cheating: it was asked to make the
      tests pass, deleting a red test does that, nothing forbade it, and the scoreboard applauded.
      `ratchet.ps1` records counts on each clean close and refuses the next close if any fell. It covers
      the five surfaces where the same trap was open: **tests** (delete a red test), **stories/tasks
      totals** (delete an undone unit and 6/14 becomes 6/9), **contracts/requirements** (nothing left to
      violate is not conformance), **sources** (deleting the ledger row silences source-stats), and
      **CLAUDE.md's `Build:` line** (without it close-unit prints "closing WITHOUT verification" and
      proceeds). Grade-card total BYTES too, so a real assessment cannot be replaced by a passing stub.
      A drop is not always wrong - an obsolete story removed on purpose is fine - so `-AcceptShrink`
      records the smaller number deliberately. What it must never be is silent. The ratchet FAILS OPEN on
      its own errors, for the same reason dad-guard does: a gate that fails closed on its own bugs stops
      real work and gets switched off. (The first version failed closed and broke three passing tests -
      which is exactly the evidence for the rule.)
- [x] R29: **Recovery works at the level of NAMED UNITS, not whole files** (`recover-lost.ps1`). R28
      detects a shrink; this is how you undo one. The generic shape to recognise: *a change removed far
      more than it added, the result still compiles, and nothing looks broken.* The worked example is the
      one that motivated both: a test file was rewritten to introduce a fixture and 12 of 16 tests
      vanished, while the suite went green.
      **A whole-file revert is the wrong answer** - the same change also added a working test fixture, a
      JSON-LD `@context` fix and a .NET 10 PipeWriter fix, and `git checkout` would have re-broken all
      three. So this diffs the NAMED UNITS (methods, tests, functions, types, markdown headings - by
      pattern, so it is language-agnostic) between the working tree and the ratchet's baseline commit, and
      restores only what disappeared.
      **"And sensible" is the load-bearing half.** A unit that still exists ELSEWHERE in the tree moved or
      was renamed - it is not lost, and restoring it would duplicate it. On the very first real case 3 of
      the 15 apparently-deleted tests had been relocated to another file, including that project's contract-9 worked example
      and the level-2 conformance check; a blind restore would have created duplicate `[Fact]` methods.
      Recovered content is written back COMMENTED, under a marker, with the diff command - it is a
      starting point for reconciliation, not a merge, because restored code routinely needs a using, a
      fixture or a helper that also changed. Nothing is ever restored without `-Restore`: deletion is
      sometimes correct, and a tool that silently undoes deliberate work is worse than the problem.
- [x] R30: **S1 is a WALKING skeleton, not a build skeleton.** Measured: a project reached 183 passing unit
      tests across 12 building projects with a TWENTY-LINE host and zero integration tests, having never
      once served a request. Every part worked; the thing did not exist. Its S1 was "create solution
      skeleton with warnings as errors" - build configuration - so every later story added to a pile nobody
      had assembled. The first story must now prove the system END TO END, however trivially: one request
      in, one response out, through the real layers, with an integration test against a real store. That
      makes every later story an extension of something that RUNS, and it makes `close-unit`'s test gate
      mean INTEGRATION from the first close instead of mocks. Written into the STORIES template, `/stories`,
      `scribe-agent` and `/taskmap`.
- [x] R31: **The security review is a gated header, settled before contracts and stories**
      (`security-agent`, `Security review:` in the design doc). Auth, input handling and secret management
      are the areas where a passing test suite tells you LEAST - tests go green over a subtly unsafe
      implementation - and retrofitting them after a dozen stories is how the insecure version ships. So
      the design doc carries `Security review: REQUIRED | NOT-REQUIRED (<why>) | DONE <date>` alongside
      `Status:`, computed by `doc-stats -Findings`, and **`/build` Gate 2b refuses to start while it says
      REQUIRED** (absent = WARN, so older projects are not blocked). `/design` decides it once the STACK is
      known (which is why R7 was reversed to choose the stack first) and ASKS: REQUIRED by default,
      NOT-REQUIRED with a stated reason for a POC or a local-only tool.
      **`security-agent` exists because recency is checkable and a model's memory is not.** It goes ONLINE
      for guidance under ~6 months old, records the publication date of every source, prefers the
      originating authority, and searches deprecation and advisories SEPARATELY from "how do I do X" - a
      pattern correct two years ago may now name a deprecated API or a library that has since had a CVE.
      It pins one cited line per decision into `## Security decisions`, writes no code, and may NOT flip
      the header itself - the human approves. `/design` gates the citations with
      `source-stats -StaleDays 180` rather than the default year. The most valuable thing it can return is
      "use the framework's built-in and do not build this yourself", which is the common case for auth.
- [x] R32: **A SUBAGENT IS AN UNGUARDED, UNOBSERVABLE REGION - iterative document generation stays in the
      main loop.** Three consecutive runs died inside a subagent and nowhere else: `taskmap-agent` made 920
      identical `dir ... 2>nul` calls; `scribe-agent` made 947 calls and never wrote STORIES.md; then
      `scribe-agent` made **1023 identical `Search **/STORIES.md` calls** and burned hours. Eleven graded
      runs in the main loop produced zero loops. The cause is not model quality, it is that NOTHING inside a
      subagent is governed:
      (a) the `PreToolUse` hook does not fire for a subagent's tool calls - the 1023-call run was the ideal
          case for the loop guard (identical, consecutive, non-shell, matcher set to EVERY tool) and not one
          call was blocked, which settles a question two releases had left open;
      (b) the `tools:` frontmatter does not restrain it either - it looped on `Glob`, which `scribe-agent`
          does not list, and an earlier run had it invoking `Bash`, which it also does not list;
      (c) the subagent transcript cannot reliably be exported, so the run cannot even be reviewed.
      The first fix for this was too blunt - it banned delegation from `/stories` and `/taskmap` outright.
      The data refutes that: bounded spawns SUCCEED. `taskmap-agent(S1.2-S1.5)` finished in **5** calls and
      `(S2.1-S2.8)` in **9**. What fails is ONE agent asked to manage the WHOLE job. So the rule is
      **one agent per unit** - one epic, one story - each with a clean context, with the orchestrator
      regaining control and running `doc-stats -Findings` between them, plus a RETRY LIMIT of one so an
      orchestrator that re-spawns forever cannot become the same loop one level up.
      Since nothing can interrupt a spawn, the remaining win is DETECTION, not prevention: `dad watch`
      (R33) makes the silence loud in minutes instead of hours, because a spiral writes nothing.
      The rule generalises: **a step that needs a gate cannot run where the gates do not reach - so keep
      each delegated step small enough that its failure is cheap, and verify the moment it returns.**
- [x] R15: Project upgrade path: `upgrade-project.ps1`/`.cmd` retrofits an EXISTING project to the current
      kit deterministically - adds missing `docs/STATUS.md`/`RECIPES.md`, git safety net if absent, and
      refreshes CLAUDE.md's kit-owned sections (Modes/Design docs/Proven recipes/Web/Working agreement)
      by header-prefix splice while preserving user sections (Stack/Build/test/Placeholder/Human-in-loop).
      Run after kit updates; a stale project CLAUDE.md makes local models improvise.
- [x] R21: **Model manifest + doctor** (closing the install / model-management gaps versus other local dev
      frameworks). `models.json` is the SINGLE SOURCE OF TRUTH - alias, `-cc` variant name, base tag, role,
      approx VRAM, autoPull, default, plus `numCtx` and the embed/vision/smallFast support models.
      `sync-models.ps1` GENERATES each Modelfile and builds the variants (`-Report` / `-All` / `-Only`),
      replacing six hand-written `.Modelfile` files and six copy-pasted install blocks; `use-model.ps1`,
      `install.ps1` and `uninstall.ps1 -Full` all read the manifest, so adding a model is one JSON entry.
      `dad-doctor.ps1` is a read-only readiness check (prereqs, GPU, Ollama server + every declared model,
      tuning env vars, the built server's live MCP tool list, the global install's settings/commands/agents,
      and with `-ProjectDir` a project's CLAUDE.md sections / .mcp.json wiring / index / git / hook) that
      prints the fix command for every non-OK line and exits non-zero only on FAILs. Named `dad-doctor`
      rather than `/doctor` because Claude Code already owns that command.
- [x] R19: **The kit tests itself.** `test-kit.ps1` (+ `.cmd`, + `.github/workflows/kit-ci.yml` on
      windows-latest) is THE validation gate, replacing the hand-run checklist in CLAUDE.md. Runs with no
      Ollama/GPU/network. Beyond build/JSON/PS-parse/ASCII it asserts the drift classes that actually bit
      us: uninstall lists vs real command/agent files (both directions), agent frontmatter `name` ==
      filename, every `*-agent` referenced by a command exists, every agent-spawning command names the
      **Task tool**, plus fixture tests for `new-project` (both kinds), `upgrade-project` (refresh +
      preserve + idempotent), and `close-unit` (tick, roll-up timing, idempotency, commit, loud failure).
      Convention: fix a bug here -> add a `Test-Case` for it.
- [x] R20: **Secret hygiene.** `scan-secrets.ps1` (patterns for AWS/GitHub/Slack/Google/Anthropic/OpenAI
      keys, Azure storage + client secrets, PEM keys, JWTs, and password/token literals, with
      placeholder suppression and an `DAD-ALLOW-SECRET` escape) reports **file:line + pattern + a SHA
      fingerprint and NEVER the value**. `install-hooks.ps1` wires it as each project's `pre-commit` hook
      (scaffold + upgrade do this automatically), because keeping a credential out of git history is the
      control that matters. `.gitignore` covers `.env*`, `*.pem/pfx/key`, `secrets/`,
      `appsettings.*.local.json`. A kit-owned `## Secrets` section in the project CLAUDE.md (propagates via
      `upgrade-project`) forbids credentials in `docs/` - everything there becomes PLAINTEXT in
      `.index/chunks.json` - requires referencing secrets BY NAME, points at platform-native auth (AWS SSO
      profiles/IAM roles, `az login` + DefaultAzureCredential/Managed Identity, Credential Manager/DPAPI),
      and tells the agent to STOP and report rather than echo anything that looks real.
- [x] R22: **A gate the model cannot skip** (`dad-guard.ps1`, wired by `install.ps1` as a Claude Code
      **Stop hook** in `settings.json`). Measured failure: a 7,115-line `/build` made 106 file edits and
      ZERO shell calls - no build, no test, no `close-unit`, no commit - then reasoned in prose about
      whether its own tests would pass, and left 47 dirty files. Every gate up to R21 was MODEL-INVOKED,
      and a gate the model chooses to invoke is prose with a filename. The harness runs a Stop hook at end
      of turn regardless of what the model decided, so the check lives there: uncommitted files with CODE
      extensions (docs/, grades/, .claude/, bin/obj excluded) and no `.claude/.dad-verified` stamp newer
      than the newest edit -> the stop is BLOCKED with the three ways out (run `close-unit`, run the real
      build/test, or `dad-guard.cmd -Ack`). `close-unit.ps1` writes the stamp on a clean close, so a
      properly closed unit clears it automatically. Deliberately a NAG WITH TEETH, not a wall: the harness
      sets `stop_hook_active` on the retry and the guard allows that pass, so it can never deadlock a
      session - what it guarantees is that the failure is LOUD instead of discovered in a transcript days
      later. FAILS OPEN on anything unexpected (not a DrDad project, no git, docs-only edits, its own
      errors); a guard that blocks on its own bugs is worse than the problem. Supporting gates from the
      same run: `/build` STOPS on a DRAFT design instead of silently degrading to PROTO (R7 always said it
      gates on LOCKED) and proves the shell works by running `doc-stats.ps1` before its first edit;
      `dad-doctor` checks the hook is wired, that `dotnet`/`git` are permitted, and flags a project whose
      `.claude/settings.local.json` has accreted one-off `Bash(...)` approvals (the fingerprint of a
      session that spent its time answering permission prompts and then stopped using the shell);
      `grade-agent` has a ~25-call search budget and may not repeat a query, after one invocation burned
      1015+ identical searches.
- [x] R18: **Loop cost discipline** (measured: 5-8 subagent spawns and 20-40+ min per task made the gates
      get skipped). Three cuts: (a) mechanical close-out is a SCRIPT - `close-unit.ps1` ticks the task, rolls
      the parent story up only when ALL its tasks are `[x]`, reindexes, commits, and VERIFIES, exiting
      non-zero if any step did not happen (deterministic beats a prose checklist); (b) when `docs/TASKS.md`
      exists the orchestrator reads the next ready task ITSELF - no requirements-agent spawn, since the
      planner already sharded it (requirements-agent now serves only the no-map and PROTO paths);
      (c) grade + hygiene run at the STORY boundary, not per task - cheaper AND more likely to actually
      happen, and `grades/` collapses from one card per task to one per story. Net: 2 spawns per task.
- [x] R17: **Sensor layer** (non-text input -> text, so it flows through the normal RAG/context path; the
      chat model stays resident while sensors are ephemeral and small):
      (a) multimodal corpus - images in `docs/` are captioned (`LOCALTOOLS_CAPTION_IMAGES`, default on) and
      audio transcribed (`LOCALTOOLS_TRANSCRIBE_AUDIO`, default off) at index time, with derived text cached
      in `.index/derived/` keyed by mtime+size so each file is processed once; failures are never cached and
      never abort the index;
      (b) `detect_objects` - ONNX Runtime (CPU) + SkiaSharp letterbox preprocessing + per-class NMS,
      model-agnostic via `LOCALTOOLS_DETECT_MODEL` (YOLOv8/v11 `[1,4+nc,anchors]` and YOLOv5 `[1,anchors,5+nc]`
      layouts), returning labels + confidence + source-pixel boxes; inert with a helpful message when unset;
      (c) `transcribe_audio` - Whisper via a `uv`-run `transcribe.py` helper (a subprocess utility, NOT an
      MCP server - the one-C#-server rule holds).
- [x] R16: Contract layer (the anti-improvisation altitude between epics and stories): `architect-agent`
      (via `/design` step 4, retrofit `/design contracts`) hunts UNDERSPECIFIED contracts ("two devs would
      implement it differently"), forces human-approved decisions, and pins each - Decision / Format /
      Invariants / WORKED EXAMPLE - into DESIGN's `## Contracts`. Gates: /design won't offer LOCK with
      unpinned load-bearing contracts; taskmap-agent refuses to shard tasks needing an unpinned contract;
      dev-agent STOPs instead of inventing formats/semantics; qa-agent turns each contract's worked example
      into the first unit test; grade-agent treats contract divergence as [dev]-critical; librarian audits
      contract coverage. Run this one step on the strongest model (Next/cloud); build offline after.
- [x] R35: **Self-verification is SANDBOXED against real machine state; irreversible actions wait for
      explicit consent.** A dogfood `/audit` + `/design` run on this kit's own S1 (`uninstall.ps1`) chose to
      verify an unticked acceptance box for real instead of trusting the hand-tick, and ran the script
      against a fake `~/.claude` via `-ClaudeDir` - which surfaced a real bug: the PATH/DAD_HOME/`~/.bashrc`
      cleanup was NOT scoped by `-ClaudeDir` at all, so every "sandboxed" run (including the existing
      `test-kit.ps1` suite) was silently mutating the REAL machine's environment. Separately, the same run
      declined to execute `-Full` live (`ollama rm` on real installed models, unsetting real env vars)
      without asking first, substituting a code-review-only verification. Two rules generalize from this,
      binding on `dev-agent`/`qa-agent`/`close-unit` and any command/agent that scripts
      install/uninstall/teardown/state-mutating behavior:
      (a) verifying an acceptance criterion that WOULD touch real installed state (registry/env vars/PATH,
      `~/.claude`, installed models, files outside the project) runs against an isolated, parameterized
      target - a temp dir, a `-ClaudeDir`-style override - never the live system, and that isolation is
      checked to actually cover every code path the real run touches, not just the happy-path ones a test
      exercises;
      (b) an action that is IRREVERSIBLE or reaches outside the project (deleting installed models,
      unsetting real env vars, removing real files, force-pushing, etc.) requires the human's EXPLICIT
      confirmation before it runs live - code-review-only verification is an acceptable substitute for the
      live run when the human declines, and the story/grade card records which one happened and why.
- [x] R36: **Planning cost is priced and ratcheted, not unlimited.** Measured (ModelTest bake-off,
      `docs/ASSESSMENT.md` Failure B): Opus spent its ENTIRE session budget growing scope from 0 to 28
      stories / 35 tasks sharded (5 of 28 stories reached `/taskmap`, each `taskmap-agent` spawn burning
      78k-110k tokens) before writing a single line of code - 1 commit (the scaffold), 0 `.cs` files, 0
      tasks done. The scope growth WAS human-approved (Opus's own `DESIGN.md` recorded "the v1 scope then
      grew by four features") - the failure is that the COST of saying yes was invisible at the moment of
      the ask. R30's walking-skeleton rule (the first STORY must run end-to-end) does not cover this: R30
      orders what S1 must contain; nothing caps how far `/stories`/`/taskmap` may shard AHEAD of S1 ever
      closing. R32's one-agent-per-unit rule does not cover it either - it stops a subagent from LOOPING
      inside one spawn, not the AGGREGATE cost of many legitimately-bounded spawns sharding a plan too big
      to have been approved at that size. Two mechanisms, run as one loop - SCOPE -> PRICE -> ASK ->
      WALK/WARN -> BUILD -> ANALYZE -> repeat:
      (a) **Ask-time scope pricing.** When `/design` or `/stories` grows scope (a new epic, or stories
      added beyond what the last `/stories` pass already priced), the acting agent states the delta in
      story/task-count terms BEFORE the human approves it, and asks explicitly: build now, or keep
      scoping? The human's yes is to a NUMBER, not a blank check.
      (b) **Walking-skeleton ratchet.** `doc-stats -Findings` computes planning mass against PROVEN
      footprint (stories/tasks actually DONE, both already tracked) and WARNs when the gap crosses a
      pinned threshold - the same generated-not-authored pattern as every other finding here, e.g. R24's
      `[integrity]`/`[taskmap]` findings.
      Exact thresholds, the pricing message shape, and worked examples (using this bake-off's real numbers)
      are pinned in `## Contracts` below by `architect-agent` - this requirement records the WHAT and the
      loop shape, not the formula.

- [x] R37: **A second HARNESS, not a fourth backend mode - the gates travel, the guard scripts do not fork.**
      R34's three modes vary WHERE THE MODEL RUNS. This varies WHICH AGENT HARNESS ENFORCES THE GATES, which
      is a different axis: R22's Stop guard and R32's loop guard are only worth anything if the harness the
      human actually drives will run them. Claude Code stays the DEFAULT and the reference harness (R1, R22);
      a second harness is OPT-IN and ADDITIVE - `install.ps1 -CopilotCli` leaves the Claude Code wiring
      untouched and additionally wires the SAME guard scripts into GitHub Copilot CLI, so one machine runs both.
      (a) **One guard, many harnesses.** `dad-guard.ps1` and `dad-loopguard.ps1` stay SINGLE-SOURCE: they keep
      all project detection, git diffing, repeat-counting and fail-open policy. Per-harness difference is
      confined to (i) a hooks file in that harness's own format and (ii) a thin ADAPTER where - and only
      where - the harness's block contract differs. Forking a guard per harness is forbidden: two copies of
      a gate drift, and the drifted one fails silently, which is the exact failure R22 exists to prevent.
      (b) **Copilot CLI is a PILOT, and the Local resilience mode must stay reachable under it.** Copilot CLI
      defaults to a GitHub account billed in AI Credits. It stays in scope as an UNVERIFIED pilot (measured once,
      against one version - C2f), not a supported target, and because it has a first-class BYOK escape -
      `COPILOT_PROVIDER_BASE_URL` pointed at Ollama's OpenAI-compatible endpoint, where GitHub authentication is
      documented as not required - verified against this kit's own local models with the hooks still firing, so
      the Local resilience mode (R34b) still works under it. A candidate harness with no such path is not
      rejected on the old offline thesis (retired 2026-10-06, S28); it is judged on whether its hooks can be
      MEASURED (R37c).
      (c) **Harness contracts are MEASURED, never assumed - because a mismatch fails SILENTLY.** A hook that is
      misnamed, wrongly cased, in the wrong location, or that signals a block in a shape the harness does not
      honor produces NO error: the gate simply never fires and the run looks clean. That is R22's original
      failure mode wearing a new hat. So a harness is only supported once its event names, config location,
      payload shape and block contract are measured against the real binary and pinned in `## Contracts`
      with the evidence and a dated version, and each load-bearing fact carries a `test-kit.ps1` case. Vendor
      documentation is a starting hypothesis here, not a source of truth.
      (d) **Subagent tool-call interception is a REQUIREMENT of a harness, not a bonus.** R32's one-agent-per-unit
      rule and the loop guard both depend on seeing a SUBAGENT's OWN tool calls, not merely that a subagent
      started and stopped. Lifecycle visibility without per-tool-call interception cannot carry these gates,
      so it disqualifies a harness rather than earning it partial support. **Admission test - what counts as
      proof:** before a harness may be wired, it must pass the MARKER TEST - a NAMED custom subagent (not the
      harness's built-in general-purpose agent, which on Copilot CLI emits no lifecycle events at all) issues a
      unique string no other session issues, and that string must be observed ARRIVING in the harness's
      pre-tool-use payload. Lifecycle events alone do not pass. The RESULT is pinned in `## Contracts` with the
      marker used, per R37(c) - C2d is the worked instance. "Someone reported that it works" is not proof; that
      second-hand degradation is exactly what R37(c) exists to stop.
      (e) **Teardown symmetry.** Whatever a harness target installs, `uninstall.ps1` removes, scoped so it is
      testable against a sandbox rather than the real machine. A hook left pointing at a deleted kit folder
      fires on every turn and fails - the same reason the Claude Code hook teardown already exists.

- [ ] R38: **A gate that cannot be shown to have FIRED is not a gate - gate activity leaves EVIDENCE.**
      R22, R28 and R32 each establish that a gate EXISTS; nothing in the kit proves one ever INTERCEPTED
      anything. That is this project's own thesis - never accept an assertion a script can settle - left
      unapplied one level up: the gates themselves are currently trusted by assertion. The failure is not
      hypothetical, it is R37(c)'s: a hook that is misnamed, wrongly cased or in the wrong location produces
      NO error, so the gate silently never fires and the run looks clean. Three mechanisms, each producing a
      COMPUTED artifact rather than console output a human reads once:
      (a) **Active proof, not file-existence.** A standalone command provokes a known violation against each
          real gate on a target project and confirms that gate actually intercepts it. Asserting "the hook
          file is present" tests the wrong thing; only a provoked violation distinguishes a wired gate from
          a dead one. (`dad gates-smoke`, shipped.)
      (b) **A durable, queryable record.** Every block a gate produces - the loop guard, `dad-guard`'s
          Stop hook, the ratchet's shrink refusal, a `close-unit` refusal - appends ONE structured,
          machine-readable line instead of printing to the console and vanishing, alongside the `allow`
          heartbeat lines C3b pins so that an empty block history is distinguishable from an unwired gate
          (WARN findings are not gate decisions and are not logged). Ephemeral
          output cannot be mined: R27's `/retro` parses PROSE today precisely because no data exists, and a
          model comparison counts gate interventions by a human watching and noting them by hand.
      (c) **Run cost is computed, not narrated.** The end of a `/build` scope or a full `/audit` emits a
          short summary - tokens, wall-clock, files touched, findings, and gate interventions drawn from
          (b). R24 made project STATE computed rather than observed; this extends the identical rule to what
          a RUN cost, which is today an after-the-fact human narration - and it is the real-numbers source
          R36's pricing loop needs in order to price scope against anything but an estimate.

- [ ] R39: **Copilot CLI PARITY - the DrDad loop, not only its two gates, runs under the second harness -
      MEASURED before it is promised.** R37 admitted Copilot CLI for exactly two things: the Stop guard and
      the loop guard. That is scope, not a defect, but it leaves the harness half-supported: under Copilot
      today the `local-tools` MCP server is not reachable (`copilot mcp list` shows only the built-in GitHub
      server, although Copilot's own help documents a workspace `.mcp.json` source), the kit's slash commands
      and `*-agent` subagents install to `%USERPROFILE%\.claude\` only, and the gate log (R38b) and its
      proofs are written and tested against the Claude Code hook payload alone. Parity means one project can
      be driven from either harness through the SAME docs, scripts and gates.
      (a) **Measure first, promise second (R37c applies unchanged).** No parity story may be written against a
          Copilot behaviour that is not pinned in `## Contracts` with the binary version and the evidence.
          The FIRST story is a measurement spike whose output is a new contract (C5): (i) why Copilot's
          workspace `.mcp.json` does not surface `local-tools` (schema, trust prompt, key names) and what
          configuration does, at user or workspace level; (ii) where Copilot loads custom agents and skills
          from, in what format, and whether the kit's `global\agents\*.md` and `global\commands\*.md` can be
          served to it without a second hand-maintained copy; (iii) whether the real PreToolUse and Stop
          payloads carry `cwd` and `session_id` (T9.5 measured Claude Code only) - the R38b writers skip
          logging on an empty `cwd`, so an unmeasured answer here means a log that looks clean and is dead.
      (b) **No fork (R37a extends).** Whatever parity ships is generated from, or points at, the Claude-side
          single source - agents, commands, guards, the gate log. A second hand-edited copy of an agent or a
          command drifts, and the drifted one fails silently.
      (c) **Explicit, additive and reversible.** It rides the existing `install.ps1 -CopilotCli` opt-in,
          leaves the Claude Code wiring untouched, and `uninstall.ps1` removes everything it adds, testable
          against a sandbox (R37e). A per-project MCP entry must not put a machine path into a committed
          file: the dev-path placeholder rule and its move-safety test still hold.
      (d) **An honest boundary.** Anything the measurement shows Copilot cannot do (for example, no
          equivalent of an orchestrating slash command) is recorded in `## Out of scope` with the evidence,
          not papered over. Partial parity that says so beats claimed parity that fails silently.
      (e) **Same pilot posture (R37b).** Nothing here may require a GitHub account beyond what R37b already
          accepts: the BYOK-to-Ollama path stays the route that needs none.

- [ ] R40: **Every install run REPORTS the harness versions against the latest release and ASKS before it
      moves them - a newer harness is a MEASURED-AGAINST-drift event, never a silent one.** Today
      `install.ps1` step 3 runs `npm install -g @anthropic-ai/claude-code` on EVERY run: it already pulls
      whatever is latest, without reporting what changed and without asking. That is how a Claude Code newer
      than the one this kit's contracts were measured against reaches a machine unannounced - and the kit has
      already been bitten: on Claude Code 2.1.285 a headless local run failed and was first read as that
      version rejecting the kit's `-cc` model ids ("isn't described by this version's model catalog").
      CORRECTED 2026-10-01 by S16 / T16.1: that text is only a WARNING; the failure was settings precedence
      (R1, C4a). Either way, "latest" changed how the Local path (R1) behaves - the resilience mode -
      while every gate still reported green. The user's aim is the
      opposite of stale - access to the latest models and features on each run - so the rule is: latest is
      the DEFAULT OFFER, and it is taken knowingly.
      (a) **Check and report, every run.** For Claude Code, and for GitHub Copilot CLI whenever `copilot` is
          on PATH, print installed version, latest published version (from the package registry, offline-safe:
          an unreachable registry prints `latest: unknown (registry unreachable)` and never fails the
          install), and the version each contract was last MEASURED against (`$CopilotMeasuredVersion` for
          C2; the C4a stamps for Claude Code). Copilot CLI is NEVER installed as a side effect of a default
          install: `-CopilotCli` stays the explicit opt-in (R37); with `copilot` absent and no `-CopilotCli`
          the Copilot section prints one skipped line and does nothing.
      (b) **Ask before updating.** When installed < latest, the installer says so and asks; declining leaves
          the machine untouched and the install continues. `-Yes` (non-interactive) is an explicit consent
          flag, never the default. The unconditional `npm install -g` in step 3 is REPLACED by this: with no
          Claude Code installed the installer still offers the install (a first-time install is the one case
          it is unasked-for-safe), but an existing install is not overwritten without the question.
      (c) **Drift is loud, never blocking (extends R37/C2f).** When the version in use is NEWER than the one
          the contracts were measured against, setup and `dad-doctor` warn and NAME which measurements need
          re-checking for that harness: hook events and payload (C2, T9.5), usage/transcript fields (C4a),
          and the local model catalog (a `-cc` model must still resolve). Nothing blocks and no gate
          weakens - a warning is the honest state until someone re-measures.
      (d) **Verified after a move, with a way back.** After the installer updates a harness it runs a cheap
          smoke check (the kit's own `dad gates-smoke` for the guards, and for Claude Code that a local -cc
          model (the `fast` alias) still resolves - "resolves" is defined in C4a's S16 amendment; amended
          2026-10-01, OPEN-4(a), from "the configured local model alias") and, on failure, prints the previous version and the
          exact command to return to it. It never auto-rolls-back, and it never lowers any security setting
          to make a check pass (R35).
      (e) **Contract text follows the versions.** A version stamp in `install.ps1` and the matching stamp in
          `## Contracts` cannot drift apart (the C2f/C4a device); re-measuring a newer harness is a `/design`
          step (unlock, amend the measured table and stamp, re-lock), not a silent code edit.
      Worked example (a run where Claude Code is behind and Copilot CLI is current):
      ```
      [harness] claude-code   installed 2.1.285   latest 2.1.301   measured against 2.1.285
      [harness]   update available - update now? [y/N]
      [harness] copilot-cli   installed 1.0.89    latest 1.0.89    measured against 1.0.89   (current)
      ```
      Declining `N` leaves 2.1.285 in place and the install continues; answering `y` updates, then prints
      `[harness] claude-code now 2.1.301 (newer than measured 2.1.285) - re-check: hooks/payload (C2, T9.5),
      usage fields (C4a), local model catalog` and runs the smoke check.

## Contracts (pin BEFORE locking - architect-agent writes these)
### C1: R36 planning-cost ratchet - thresholds, pricing message shape, worked examples
- **Status: APPROVED 2026-09-22.** R36 names two mechanisms as one loop (SCOPE -> PRICE -> ASK ->
  WALK/WARN -> BUILD -> ANALYZE -> repeat). The human picked **Option B** for C1a and approved C1b/C1c/C1d
  as written - nothing below is still open. **SHIPPED**: C1a/C1b's `[ratchet]` WARN is live in
  `doc-stats.ps1 -Findings` (Story S6, T6.1/T6.2), and C1c's pricing sentences are live in `/stories`' expand
  loop and `/design`'s requirement-capture step (Story S7, T7.1/T7.2); both carry `test-kit.ps1` cases. This
  line read "Not yet implemented ... that is `/taskmap` or `/build` work from here" until 2026-09-29, which
  is what a contract header says on the day it is approved and never says again - it outlived the build it
  was describing by two closed stories.

#### C1a: Walking-skeleton ratchet threshold formula - CHOSEN: Option B
- **Inputs (only what `doc-stats.ps1` already computes, no new data source):** `storiesTotal =
  $storyIds.Count`, `storiesDone = $storiesDone.Count`, `tasksTotal = $tasks.Count`, `tasksDone =
  $tasksDone.Count` (confirmed at `doc-stats.ps1:126,152,192-198`).
- **Option A - hard mass + zero-done gate.** Fire when `(storiesTotal + tasksTotal) >= 15 AND
  (storiesDone + tasksDone) == 0`. Simplest; matches the Opus incident exactly. Weakness: once a SINGLE
  unit closes it goes silent forever, even if scope then balloons again at a near-zero done ratio -
  does not satisfy the "scales past the first ratchet" ask.
- **Option B - mass-scaled DONE-ratio threshold (RECOMMENDED).** Let `mass = storiesTotal + tasksTotal`
  and `doneRatio = (storiesDone + tasksDone) / mass`. Fire when `mass >= 15 AND doneRatio < 0.15` (15%).
  One ratio + one floor, continuously re-evaluated (never permanently silenced), and it reads as exactly
  the human's own phrasing - "warn when the DONE ratio stays near zero" - scaled by mass so a small
  project isn't punished for having 0 done right after `/stories`, and a big one doesn't get a permanent
  pass after its first close.
- **Option C - outstanding-vs-proven multiplier.** Let `outstanding = (storiesTotal - storiesDone) +
  (tasksTotal - tasksDone)` and `proven = storiesDone + tasksDone`. Fire when `outstanding >= 20 AND
  outstanding > 5 * proven`. Most literally matches R36(b)'s own words ("planning mass against PROVEN
  footprint... the GAP crosses a threshold") and scales the same way as B, but needs two dials (a floor
  and a multiplier) instead of one ratio, which is harder to retune from a single false-positive report.
- **Worked examples (all three formulas run against the same three scenarios):**
  | scenario | storiesTotal/Done | tasksTotal/Done | A fires? | B fires? | C fires? |
  |---|---|---|---|---|---|
  | **Opus incident** (ASSESSMENT.md Failure B / `ModelTest/ASSESSMENT.md:29`) | 28/0 | 35/0 | mass=63>=15, done=0 -> **YES** | mass=63, ratio=0% -> **YES** | outstanding=63>=20, proven=0, 63>0 -> **YES** |
  | **early legit project** (fresh `/stories` pass, `/taskmap` not run yet) | 3/0 | 0/0 | mass=3<15 -> no | mass=3<15 -> no | outstanding=3<20 -> no |
  | **Opus shape before `/taskmap` ran** (scope already grew, no tasks sharded yet) | 28/0 | 0/0 | mass=28>=15, done=0 -> **YES** | mass=28, ratio=0% -> **YES** | outstanding=28>=20, proven=0 -> **YES** |
  | **healthy large project** (steady progress, big but proportionate) | 50/10 | 80/40 | done=50<>0 -> no (permanently silent from here on) | mass=130, ratio=38.5% -> no | outstanding=80, proven=50, 80<250 -> no |
  | **stalled large project** (scope kept growing, done ratio never recovers) | 50/3 | 80/5 | done=8<>0 -> no (misses this - the scaling gap) | mass=130, ratio=6.2%<15% -> **YES** | outstanding=122, proven=8, 122>40 -> **YES** |
  All three pass the Opus case and stay silent on the 3-story early-project case (the two hard
  requirements from the brief). A and B/C diverge on the last two rows, which is exactly the "scales past
  the first ratchet" criterion - A does not scale, B and C do.
- **CHOSEN: Option B** (`mass >= 15 AND doneRatio < 0.15`) - same catch rate as C on every row above, one
  tunable ratio instead of two coupled dials, and its finding message can state a single percentage a
  human can eyeball ("6% done") instead of a multiplier. A and C were considered and are recorded above for
  why they were passed over; if 15%/15% proves too noisy or too lax in practice, retune the constants
  before reaching for C's two-dial shape.

#### C1b: Where the WARN lives - finding location + tag - APPROVED
- **Decision:** lives in `doc-stats.ps1 -Findings`, in the generated (not librarian-authored) block, same
  place as `[design]`/`[scribe]`/`[taskmap]`/`[integrity]` today (`doc-stats.ps1:204-663`). New tag
  `[ratchet]` - grepped the file's existing `$f.Add("[...")` tags (`design, domain, scribe, taskmap, grade,
  dev, hygiene, ui, ux, playtest, style, research, integrity`); none collide, and `[ratchet]` names the
  mechanism the same way R36(b) itself does ("walking-skeleton ratchet"). This is a DIFFERENT mechanism
  from R28's `ratchet.ps1` (that one detects a SHRINKING verification surface; this one detects planning
  mass GROWING faster than proven footprint) - reusing the word is deliberate (both are "a threshold that
  must not be silently crossed") but the tag lives in `doc-stats.ps1`, not `ratchet.ps1`, and is scoped by
  its own `[ratchet]` prefix so the two are never confused in a findings list.
- **Format / signature:** appended alongside the other findings, WARN severity (never blocks a gate, same
  as `[research]`/`[style]`/`[ux]`): `[ratchet] planning mass ({storiesTotal} stories + {tasksTotal} tasks
  = {mass}) is far ahead of proven footprint ({storiesDone} stories + {tasksDone} tasks = {doneMass} done,
  {doneRatioPct}% of mass) - the walking-skeleton ratchet (R36b/C1) fires once mass >= 15 and the done
  ratio stays under 15%. Build out what is already scoped (S1 must close first, per R30) before sharding
  more, or explicitly re-confirm scope growth via /design or /stories now that the cost is visible.`
- **Worked example (Opus numbers, the required trace):** `storiesTotal=28, storiesDone=0, tasksTotal=35,
  tasksDone=0` -> `mass=63`, `doneMass=0`, `doneRatioPct=0` ->
  `[ratchet] planning mass (28 stories + 35 tasks = 63) is far ahead of proven footprint (0 stories + 0
  tasks = 0 done, 0% of mass) - the walking-skeleton ratchet (R36b/C1) fires once mass >= 15 and the done
  ratio stays under 15%. Build out what is already scoped (S1 must close first, per R30) before sharding
  more, or explicitly re-confirm scope growth via /design or /stories now that the cost is visible.`
  Counter-example (must stay silent): `storiesTotal=3, storiesDone=0, tasksTotal=0, tasksDone=0` -> mass=3
  < 15 -> no `[ratchet]` line printed, matching the house style proven at `doc-stats.ps1:3101-3105`'s
  "a freshly scaffolded template must not be flagged" test.

#### C1c: Ask-time scope-pricing sentence shape - APPROVED
- **Decision:** the sentence is said by the ORCHESTRATOR in the MAIN LOOP, never inside a spawned
  subagent (R32 - a subagent is unguarded and unobservable, so a gate that only a human-facing ask can
  satisfy has to be said where the transcript and the human both see it). Two trigger points, at two
  granularities, because real counts only exist once the corresponding doc exists:
  - **At `/stories`' EXPAND loop** (`global/commands/stories.md` step 2, which already runs `dad
    doc-stats -Findings` between epic spawns): the orchestrator snapshots
    `storiesTotal/tasksTotal/storiesDone/tasksDone` BEFORE spawning `scribe-agent` for the next epic, and
    diffs against the numbers `doc-stats -Findings` prints AFTER it returns - a real count, not an
    estimate. Sentence: `"Epic {epic} added ~{deltaStories} stor(y/ies) (now {afterStories} stories /
    {afterTasks} tasks total, {storiesDone}/{afterStories} stories and {tasksDone}/{afterTasks} tasks
    DONE). Build what's already scoped now, or keep scoping the next epic?"`
  - **At `/design` step 4** (adding a new epic before any of its stories exist, so there is no real count
    yet): the orchestrator counts EXISTING epics/stories only - `"Adding epic {epic} ({feature list})
    brings the design to {epicCount} epics. Its stories aren't priced yet - `/stories` will show the real
    story/task count when it expands this epic. Add it now, or build the {currentStoryCount} stories
    already scoped first?"` Deliberately does NOT fabricate a story-count estimate for an unexpanded epic -
    `ASSESSMENT.md`'s own Failure-B table flags "ESTIMATE QUALITY" as option (d)'s biggest risk, and a
    invented number the human trusts is worse than an honest "not priced yet."
- **Worked example against the actual Opus moment** (`opus/docs/DESIGN.md:295-297`/`:318-322`, cited in
  `ModelTest/ASSESSMENT.md:150-159`): opus added epic **E6** ("serving scale, tick-off persistence,
  copy-as-text, print stylesheet" - four features) DURING `/design`, before `/stories` had run at all. At
  that exact moment the `/design`-stage sentence (real numbers only) would have read: `"Adding epic E6
  (serving scale, tick-off persistence, copy-as-text, print stylesheet) brings the design to 6 epics. Its
  stories aren't priced yet - /stories will show the real story/task count when it expands this epic. Add
  it now, or build what's already scoped first?"` **Honest gap:** `ASSESSMENT.md` and `ModelTest/
  ASSESSMENT.md` do not preserve the exact pre-E6 epic count or the pre-growth requirement count from the
  transcript (only the FINAL totals - 32 requirements, 9 contracts, 28 stories - are graded); "6 epics" in
  this trace assumes E1-E5 existed before E6, which is consistent with the assessment's E6 numbering but
  not independently verified against `opus/run.txt`. The mechanism and sentence shape are pinned; the
  precise "before" number in this one historical trace is an approximation, flagged as such rather than
  invented as fact.

#### C1d: How the ratchet (WALK/WARN) and the pricing ask (ASK) interact - APPROVED
- **Decision:** stay INDEPENDENT as computations - `doc-stats.ps1` has no way to know whether a human was
  ever shown a C1c pricing sentence (that is a conversation-level event, not something STORIES.md/
  TASKS.md state can encode), so a literal cross-reference ("you were told this would add N tasks") is not
  mechanically computable and would have to be faked or stored as new state, which C1a's brief explicitly
  rules out ("no new data source"). Instead, the C1b finding's WORDING references the pricing loop
  NARRATIVELY (see the exact text above - "explicitly re-confirm scope growth via /design or /stories now
  that the cost is visible") so a reader understands the ratchet is the loop's BACKSTOP: if pricing was
  skipped, ignored, or answered "keep scoping" too many times, the ratchet is what eventually says so
  out loud, without needing to prove which of those happened.
- **Invariant:** the ratchet (C1a/C1b) may fire even when C1c was followed correctly (a human can
  knowingly accept a heavy backlog) - it is a WARN, never a gate, so a legitimate "yes, keep scoping" is
  never blocked, only made visible on every subsequent `doc-stats -Findings` run until the done ratio
  recovers or the human runs `-AcceptShrink`-style acknowledgement (out of scope here - see below).

- **Invariant(s) (all sub-decisions):** `[ratchet]` never blocks `/build`, `close-unit`, or any lock
  gate - R36 records this as a WARN mechanism, matching `[research]`/`[style]`/`[ux]`'s existing WARN
  severity, not `[design]`'s LOCK-blocking class. The formula uses ONLY `doc-stats.ps1`'s existing four
  counters - no new file, no new tracked state, no per-story metadata.
- **Out of scope:** an explicit acknowledgement/snooze mechanism for a `[ratchet]` finding the human has
  seen and deliberately accepted (the way `-AcceptShrink` works for R28's ratchet) is NOT pinned here - a
  v2 concern once the WARN exists and proves too noisy or too easy to ignore. Automatically blocking
  `/taskmap` or `/stories` on a `[ratchet]` finding is explicitly NOT proposed (R36 calls for a WARN, not a
  gate, and the human's "keep scoping" answer must stay honored). The threshold numbers are NOT open: C1a
  records **CHOSEN: Option B**, so B's 15/0.15 shipped and C's 20/5x did not. They are still not a promise
  they are final - retuning them is a normal response to a false-positive/false-negative report, not a
  contract change - and `doc-stats.ps1` keeps them as named constants near the top of the `[ratchet]`
  block so a retune is a one-line edit, the same way other WARN thresholds in this file already are
  (e.g. the `>= 5` uncommitted-done threshold at `doc-stats.ps1:595`).

### C2: R37 GitHub Copilot CLI harness contract - hook location, event casing, block semantics, subagent coverage
- **Status: MEASURED 2026-09-29 against GitHub Copilot CLI 1.0.89 on Windows.** Per R37(c) every fact in
  C2 is an empirical measurement against that exact binary, NOT vendor documentation - and on two
  load-bearing points (C2a location, C2c Stop block shape) the documented behavior and the measured
  behavior DISAGREE, with no error either way. **Version stamp: these facts are true OF Copilot CLI
  1.0.89, measured 2026-09-29.** A reader on any later version must re-measure before trusting them.
- **Enforced by `test-kit.ps1`** (R37c's "each load-bearing fact carries a test case"):
  `"copilot-hooks.json is the shape Copilot CLI actually loads"` (C2a + C2b),
  `"dad-guard-copilot converts a BLOCK into Copilot's JSON+exit-0 contract"` (C2c),
  `"uninstall removes the Copilot CLI hook file (sandboxed)"` (R37e teardown).

#### C2a: Config location - USER level only; the DOCUMENTED repo-level path loads nothing
- **Measured:** hooks load ONLY from the user-level dir `%USERPROFILE%\.copilot\hooks\*.json`. The
  documented repo-level location `.github/hooks/*.json` silently loads NOTHING - no error, no log line.
- **Evidence:** controlled comparison - identical files placed in BOTH locations, same event keys,
  `version: 1`, cwd = repo root, tested both before and after the repo had a commit. Only the user-level
  file ever fired.
- **Consequence pinned into the kit:** `install.ps1 -CopilotCli` writes exactly one file,
  `%USERPROFILE%\.copilot\hooks\dad.json` (`install.ps1`'s -CopilotCli step), and never writes `.github/hooks/`.
  An installer that followed the docs would report success and wire a gate that never fires - R22's
  original silent-failure mode wearing a new hat.
- **Teardown (R37e):** `uninstall.ps1` removes that same single file, and only if its contents reference
  our guards, so a same-named third-party file is never deleted (`uninstall.ps1`'s Copilot teardown section). The
  `-CopilotDir` parameter exists so the removal is testable against a sandbox, not the real machine.
- **Qualified 2026-10-01 by C5a (T14.1):** "loads nothing" holds for an UNTRUSTED folder; in a trusted one
  repo-level `.github/hooks/` DO fire. The decision above is unchanged, with a second reason - a repo-level
  copy would double-fire alongside `dad.json` (C2b invariant i).

#### C2b: File shape + event-name casing - PascalCase, registered ONCE
- **File shape (measured):** `{"version":1,"hooks":{"<Event>":[{"type":"command","bash":"...",
  "powershell":"...","timeoutSec":N}]}}`. `version: 1` is REQUIRED. Copilot reads the `bash` and
  `powershell` keys; it does NOT read Claude Code's `command` key, and its parser skips unrecognised keys
  without complaining - so a Claude-Code-shaped file installs cleanly and does nothing.
- **Casing (measured):** Copilot accepts BOTH camelCase and PascalCase event names, but they are NOT
  aliases - each dispatches INDEPENDENTLY. Registering both fires every hook TWICE. They also deliver
  DIFFERENT payload schemas for the same event:
  | registered as | payload fields | tool reported as |
  |---|---|---|
  | camelCase `preToolUse` | `{sessionId, timestamp (epoch ms), cwd, toolName, toolArgs}` | `"powershell"` / `"task"` |
  | PascalCase `PreToolUse` | `{hook_event_name, session_id, timestamp (ISO), cwd, tool_name, tool_input}` | NORMALIZED to Claude Code's vocabulary: `"Bash"` / `"Agent"` |
- **Decision: the kit standardizes on PascalCase, and registers each event exactly once.** Two reasons,
  both load-bearing: the PascalCase payload is the snake_case shape `dad-loopguard.ps1` ALREADY parses
  (so R37a's "one guard, many harnesses" holds with no fork and no translation layer), and
  double-registration would fire the loop guard twice per tool call and corrupt its repeat count - a
  guard that miscounts is worse than no guard.
- **Known ragged edge (pinned as a fact, deliberately unused):** PascalCase `SubagentStart` DOES fire,
  but its payload is NOT normalized - it arrives camelCase with no `hook_event_name` - unlike
  `SubagentStop`, which IS normalized. The kit does not currently use `SubagentStart`; anything that
  starts using it must not assume the C2b PascalCase schema.

#### C2c: Block/deny contract - DIFFERS PER EVENT, and a mismatch fails SILENTLY
- **Measured, `PreToolUse`:** exit code 2 IS honored as a deny. Therefore `dad-loopguard.ps1` works
  UNCHANGED under Copilot - no adapter, no second copy (R37a).
- **Measured, `Stop`:** exit code 2 is IGNORED. Full measured matrix:
  | hook emits | Copilot's behavior |
  |---|---|
  | exit 2 alone | IGNORED - the turn ends |
  | `{"decision":"block","reason":"..."}` on stdout + exit 0 | BLOCKS; the retry arrives with `stop_hook_active=true` |
  | `{"decision":"block","reason":"..."}` on stdout + exit 2 | IGNORED - a nonzero exit is treated as "the hook errored" and stdout is discarded WITH it |
- **The trap this exists to defuse (third row):** `dad-guard.ps1`'s `Block()` already emits the JSON
  decision *and* exit 2 (both on purpose, so whichever a harness honors, the message lands). Under
  Copilot that combination is discarded. Wiring `dad-guard.ps1` to Copilot's `Stop` therefore LOOKS
  correct - right file, right event, right JSON - and silently does nothing: the close-out gates quietly
  go back to being model-optional, with no error to say so.
- **Decision:** a thin adapter, `dad-guard-copilot.ps1`, is the Copilot `Stop` hook. It runs
  `dad-guard.ps1` unchanged on the verbatim stdin payload, keeps its verdict, and re-emits the JSON with
  **exit 0**. `dad-guard.ps1` stays the single source of truth for project detection, git diffing,
  `stop_hook_active` retry release and the fail-open policy (R37a - forking a guard is forbidden).
- **Signature / pre + post:** `dad-guard-copilot.ps1` reads the Stop payload on stdin (Copilot's Stop
  payload already carries the snake_case fields `dad-guard.ps1` reads: `session_id`, `cwd`,
  `transcript_path`, `stop_hook_active`, so no translation is needed - only the exit code differs).
  Post: if inner exit code == 2, write `{"decision":"block","reason":...}` to stdout and `exit 0`;
  otherwise write nothing and `exit 0`. If the inner guard blocked but produced no parsable
  `decision:"block"` JSON, the adapter SYNTHESIZES one from its stdout, so a block can never evaporate
  (`dad-guard-copilot.ps1:62-77`).

#### C2d: Subagent tool-call interception - covered, and attribution works
- **Measured:** Copilot's `PreToolUse` DOES fire for a subagent's OWN tool calls, proven with a unique
  marker string that only the subagent ever issued. This is what qualifies Copilot CLI as a harness at
  all: R37(d) makes per-tool-call interception a REQUIREMENT, not a bonus.
- **Attribution (measured):** the documented payload has no agent field, but a subagent's `PreToolUse`
  carries its OWN `session_id`, distinct from the main session's, and that value EQUALS `agent_id` in the
  matching `SubagentStop`. So subagent tool calls are attributable without any new payload field.
- **Also measured:** the built-in `general-purpose` agent emits NO subagent lifecycle events - a NAMED
  CUSTOM agent is required. Interception still held at nested subagent depth 2.

#### C2e: Offline / BYOK path - keeps the Local resilience mode reachable under Copilot CLI (R37(b))
- **Measured:** `COPILOT_PROVIDER_BASE_URL` activates BYOK, and GitHub authentication is then not
  required; `COPILOT_PROVIDER_TYPE=openai` covers Ollama's OpenAI-compatible endpoint. Verified working
  against this kit's local Ollama with the C2a/C2b/C2c hooks still firing. Under the 2026-10-06 mission
  (S28) this is no longer what puts Copilot CLI in scope - it is a pilot (R37b) - but it is what lets the
  Local resilience mode (R34b) run under it with no GitHub account.

#### C2f: Version drift policy - LOUD at setup, fail-open at runtime
- **APPROVED 2026-09-29.** Everything in C2a-C2e is true of Copilot CLI 1.0.89 and of nothing else. A harness
  that changes any of it breaks the gates SILENTLY (C2c's whole point), so the drift must surface somewhere -
  but drift is a SETUP fact, not a per-turn fact, so it surfaces where setup is inspected and NOWHERE else.
- **Runtime: unchanged, still fails OPEN.** Neither `dad-guard-copilot.ps1` nor `dad-loopguard.ps1` may block,
  warn, or self-check on a version mismatch mid-turn. A guard that blocks on its own uncertainty eventually
  blocks someone for no reason, which would violate C2's fail-open invariant and make the gate noise.
- **Setup: LOUD.** `install.ps1 -CopilotCli` and `dad-doctor` compare the INSTALLED `copilot --version` against
  the measured version and WARN on any mismatch, naming both numbers and telling the reader to re-measure
  C2a-C2e before trusting the gates. A warn, never a hard stop: an unmeasured harness is a known-unknown, not
  a known-broken, and refusing to install would be worse than saying so.
- **One source of truth for the number:** `$CopilotMeasuredVersion` in `install.ps1`. `test-kit.ps1` asserts
  that constant equals the version stamped in THIS contract, so the doc and the code cannot drift apart
  silently - the failure mode this whole contract exists to prevent, applied to itself.
- **Deliberately NOT done yet:** a `harnesses.json` manifest (the kit's usual "never hard-code a list in a
  script" convention, cf. `models.json`). One harness does not justify the scaffolding; the moment a SECOND
  non-Claude-Code harness is added, the constant becomes a manifest and this bullet is the reason why.

#### C2 worked example - the exact file the kit installs, and the exact Stop block flow
- **Worked example (1/2) - `%USERPROFILE%\.copilot\hooks\dad.json` as installed** (source template:
  `copilot-hooks.json`; `install.ps1 -CopilotCli` rewrites the dev-path placeholder
  `C:\Projects\Claude\MCP\DAD-kit` to the real install root on the PARSED object, because JSON doubles
  backslashes and a text replace would match nothing - see `install.ps1`'s -CopilotCli step):
  ```json
  {
    "version": 1,
    "hooks": {
      "Stop": [
        { "type": "command",
          "bash":       "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\Projects\\Claude\\MCP\\DAD-kit\\dad-guard-copilot.ps1\"",
          "powershell": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\Projects\\Claude\\MCP\\DAD-kit\\dad-guard-copilot.ps1\"",
          "timeoutSec": 20 }
      ],
      "PreToolUse": [
        { "type": "command",
          "bash":       "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\Projects\\Claude\\MCP\\DAD-kit\\dad-loopguard.ps1\"",
          "powershell": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\Projects\\Claude\\MCP\\DAD-kit\\dad-loopguard.ps1\"",
          "timeoutSec": 10 }
      ]
    }
  }
  ```
  Every element of that file is a C2 decision: user-level path (C2a), `version: 1` + `bash`/`powershell`
  keys (C2b), PascalCase event names each appearing EXACTLY ONCE (C2b), `dad-guard-copilot.ps1` on `Stop`
  but bare `dad-loopguard.ps1` on `PreToolUse` (C2c - only Stop needs the adapter).
- **Worked example (2/2) - the Stop block flow, traced end to end.** Model tries to end a turn with
  uncommitted work in a DrDad project:
  1. Copilot fires `Stop` -> runs `dad-guard-copilot.ps1`, stdin =
     `{"hook_event_name":"Stop","session_id":"abc123","cwd":"D:\\projects\\DrDad","stop_hook_active":false}`.
  2. The adapter writes that stdin verbatim to a temp file and runs `dad-guard.ps1` with it.
  3. `dad-guard.ps1` decides BLOCK -> stdout `{"decision":"block","reason":"<gate text>"}`, exit **2**.
  4. Adapter sees inner exit 2 -> re-emits `{"decision":"block","reason":"<gate text>"}` on stdout, exit **0**.
  5. Copilot HONORS it (row 2 of the C2c matrix): the turn is blocked and the retry arrives with
     `stop_hook_active=true`, which `dad-guard.ps1` already reads as its release condition.
  Counter-example that MUST stay broken (this is the whole point of the adapter): skip step 4 and let
  `dad-guard.ps1` talk to Copilot directly - identical JSON, but exit 2 -> row 3 of the matrix -> Copilot
  discards stdout with the nonzero exit, the turn ends, and NOTHING is logged.
- **Invariant(s):** (i) exactly ONE registration per event, PascalCase, in exactly ONE file at the
  user-level path - any camelCase duplicate double-fires the guards and corrupts the loop guard's repeat
  count; (ii) `dad-guard.ps1` and `dad-loopguard.ps1` are never copied or forked per harness (R37a) - the
  only per-harness artifacts are the hooks file and `dad-guard-copilot.ps1`; (iii) the adapter FAILS OPEN
  exactly like `dad-guard.ps1` - every error path ends in `exit 0` (allow the stop), because a guard that
  blocks on its own bugs is worse than the problem it solves; (iv) whatever `-CopilotCli` installs,
  `uninstall.ps1` removes (R37e); (v) a hook change only takes effect on Copilot CLI restart, since it
  loads hooks at startup (reported by `install.ps1`'s -CopilotCli step).
- **Out of scope:** other Copilot surfaces (VS Code Copilot Chat, Agents View, cloud coding agent) - see
  `## Out of scope`; `SubagentStart` (fires, but un-normalized per C2b, and unused); any attempt to make
  the camelCase event family work; automatic detection of a Copilot CLI version other than 1.0.89.
- **Open questions returned to the human - NOT decided here, do not implement either way yet:**
  (i) whether `SubagentStart`'s un-normalized payload should be defensively parsed now or left unused.
  Three further questions were listed here and have since been ANSWERED; they are removed rather than left
  for every audit to re-discover as open. Harness-contract DRIFT policy and how the supported version is
  RECORDED/detected at install time are both decided by **C2f** above (LOUD at setup, fail-open at
  runtime, one constant in `install.ps1` asserted by `test-kit.ps1`). Whether a future candidate harness
  must PROVE subagent interception before it may be wired is decided by **R37(d)**'s admission test (the
  MARKER TEST), of which C2d is the worked instance.

### C3: R38(b) gate-decision log - location, line schema, append semantics, rotation, query, proof
- **Status: APPROVED 2026-09-29.** R38(b) names FOUR writers (`dad-loopguard.ps1`, `dad-guard.ps1`'s Stop
  hook, `ratchet.ps1`'s shrink refusal, `close-unit.ps1`'s refusal paths) and ONE record. Per R37(c), a
  writer that disagrees with the schema produces NO error - the line is simply wrong or missing and the
  run looks clean - so the schema is pinned HERE, once, before four callers depend on it.
- **R38(b) records BLOCK decisions plus C3b's `allow` heartbeats - never WARN.** Every block is logged;
  `allow` lines are written only where C3b's per-gate table says (an "armed" line per session for the
  hooks, every invocation for `ratchet`/`close-unit-refusal`), so a quiet week proves the gates ran rather
  than that they were never wired. `doc-stats -Findings`' WARN lines (`[ratchet]`, `[integrity]`,
  `[research]`, ...) are NOT gate decisions and are NOT written to this log: they are already a computed
  artifact with their own home (R24). The `decision` enum is `{allow, block}` and has no `warn` member.
- **Supersedes:** `docs/TASKS.md` T9.1 pinned a provisional schema inside its own task body (a
  `.claude\dad-gates-log.jsonl` location and a five-field line). C3 supersedes it in four places - the
  location (C3a), the `v` and `decision` fields (C3b), the append call (C3c), the query parameters (C3e).
  T9.1-T9.4 must be re-read against C3 before they are worked.

#### C3a: Location - `grades/gates-log.jsonl`, COMMITTED, plus two adjacent globs that must not widen
- **Status: APPROVED 2026-09-29.**
- **Decision:** one file per project at `grades/gates-log.jsonl`, TRACKED BY GIT and committed like any
  other evidence artifact. NOT `.claude\` (gitignored runtime state), NOT `docs/`.
- **Reasoning:** `grades/` is already this kit's committed evidence folder - a grade card records how a
  unit went, a gate log records what the gates did, and the two belong in the same clone. `docs/` was
  rejected on R20 grounds: everything under `LOCALTOOLS_DOCS_DIR` becomes PLAINTEXT in
  `.index/chunks.json`, and a block reason quotes the command that was blocked. `grades/` sits OUTSIDE
  that root (`.mcp.json:6` points `LOCALTOOLS_DOCS_DIR` at `docs` only), so the plaintext-index hazard
  does not reach it at all. `.claude\` was rejected because a record whose entire purpose is DURABILITY
  should not die with a clone.
- **Reason-field pipeline (forced by the committed location), in this exact order:** collapse whitespace
  -> REDACT using `scan-secrets.ps1`'s OWN patterns, replacing each match with `[REDACTED]` -> truncate to
  300 chars. Redaction is not optional and not a new convention: `install-hooks.ps1:73` installs a
  pre-commit hook that runs `scan-secrets.ps1 -Staged -Quiet` and BLOCKS the commit on a finding, so an
  un-redacted credential quoted inside a blocked command line would block `close-unit.ps1`'s own commit -
  the evidence log poisoning the close it exists to be evidence for. Reusing the scanner's patterns keeps
  ONE definition of "secret" in the kit (R20).
- **Two adjacent globs that are safe today only by ACCIDENT - neither may be widened:**
  (i) `ratchet.ps1:88` totals grade-card bytes with `-Filter *_GRADE.md`, so `gates-log.jsonl` is NOT part
  of `gradeBytes`. Widening that filter to all of `grades/` would make a deliberate manual roll (C3d) read
  as a SHRINK and REFUSE the next close (R28).
  (ii) `dad-guard.ps1:153` lists `.json` in `$codeExt` but NOT `.jsonl`, and matching is on
  `GetExtension`, so `.jsonl` can never match. That is what stops the Stop hook's own append from counting
  as an unverified edit on the very turn it reports. Adding `.jsonl` would create a feedback loop in which
  the guard blocks on the log line it just wrote.
  Both facts carry a `test-kit.ps1` assertion, so the accident becomes a guarantee.
- **Worked example (the reason pipeline, end to end).** The loop guard blocks a repeated shell call whose
  raw command line was `curl   -H "Authorization: Bearer <token>"   https://api.example.com/v1/x`:
  1. collapse whitespace -> `curl -H "Authorization: Bearer <token>" https://api.example.com/v1/x`
  2. redact with `scan-secrets.ps1`'s patterns -> `curl -H "Authorization: Bearer [REDACTED]" https://api.example.com/v1/x`
  3. truncate to 300 chars -> unchanged (78 chars)
  and THAT string is what lands in the line's `reason`. (This example deliberately writes `<token>` rather
  than a realistic key literal, because `scan-secrets.ps1` runs over this document too. CAVEAT found at
  T9.1 QA: `scan-secrets.ps1:60` suppresses `<...>` placeholders and no pattern matches `Bearer <token>`,
  so a LITERAL `<token>` would NOT be redacted - step 2 only fires for a STRUCTURAL token such as `ghp_`
  followed by 40 characters. The `test-kit.ps1` assertion therefore builds its token at run time.)
  **Counter-example that MUST stay impossible:** skip step 2, and the credential reaches
  `grades/gates-log.jsonl`; `close-unit.ps1`'s `git commit` is then refused by the pre-commit scanner and
  the unit cannot close, because its own gate log is unstageable.

#### C3b: Line schema + what counts as a gate decision
- **Status: APPROVED 2026-09-29.**
- **Format:** one compact JSON object per line, UTF-8 no BOM, LF. SEVEN fields, all REQUIRED - always
  present, empty string when not applicable, so a consumer never has to test for a missing key:
  | field | type | meaning |
  |---|---|---|
  | `v` | int | schema version, currently `1`. Four writers and a committed file that is never migrated. |
  | `ts` | string | UTC, MILLISECOND precision, `yyyy-MM-ddTHH:mm:ss.fffZ`. C4 windows on this. |
  | `gate` | string | short id. Five today: `loop-guard`, `dad-guard-stop`, `ratchet`, `close-unit-refusal`, `gates-log` (C3d's genesis record). NOT a closed enum - a future gate may add its own. |
  | `decision` | string | `allow` or `block`. No `warn` member (see the C3 header). |
  | `tool` | string | the harness tool name when the gate's payload has one (`loop-guard` does, e.g. `Bash`); `""` otherwise. |
  | `reason` | string | human-readable, through C3a's collapse -> redact -> truncate(300) pipeline. |
  | `session` | string | the harness session id when the caller has one (`loop-guard`, `dad-guard-stop`); `""` for `ratchet`/`close-unit-refusal`, which run as plain subprocesses, never as hooks. |
- **Decision - WHAT GETS A LINE (the load-bearing half).** A deny-only log cannot distinguish "no
  violations this week" from "the hook was never wired", which is the exact confusion R38 exists to end -
  and it also fails S9's own AC2 ("filterable by gate id / DENY-ONLY"), which is unsatisfiable with no
  `decision` field. Logging EVERY evaluation was rejected on MEASURED grounds: `dad-loopguard.ps1` runs
  before every tool call and its own design already rejects a ~500ms-per-call full JSON parse (hence its
  regex-only stdin read), so a `powershell -File` spawn per tool call would be far worse. The pinned
  middle, per gate:
  | gate | writes |
  |---|---|
  | `loop-guard` | ONE `allow` "armed" line on the session's FIRST invocation, then every `block` |
  | `dad-guard-stop` | ONE `allow` "armed" line on the session's FIRST Stop, then every `block` |
  | `ratchet` | EVERY invocation - `allow` on a clean pass, `block` on a shrink refusal |
  | `close-unit-refusal` | EVERY invocation - `allow` on a clean close, `block` per refusal site |
- **The heartbeat is nearly free:** `dad-loopguard.ps1:44` ALREADY keeps per-session streak state under
  `$env:TEMP\dad-loopguard`, so "no state file for this session yet" IS the first-call signal. No new
  state, no new file, one extra branch.
- **Worked example (three lines from one session, exactly as written):**
  ```
  {"v":1,"ts":"2026-09-29T14:02:11.004Z","gate":"loop-guard","decision":"allow","tool":"","reason":"armed","session":"abc123"}
  {"v":1,"ts":"2026-09-29T14:07:48.517Z","gate":"loop-guard","decision":"block","tool":"Bash","reason":"BLOCKED: 4th consecutive identical command: dir \"D:\\src\\cms\" 2>nul","session":"abc123"}
  {"v":1,"ts":"2026-09-29T14:31:02.880Z","gate":"ratchet","decision":"allow","tool":"","reason":"no shrink (tests 61, stories 14, tasks 40)","session":""}
  ```
  What this buys, stated plainly: `-Query -Decision block` over a whole week returning ZERO lines now
  MEANS something, because the `allow` heartbeats prove the gates were armed and ran. Under a deny-only
  schema the same empty result is indistinguishable from a dead hook.

#### C3c: Append semantics with concurrent writers
- **Status: APPROVED 2026-09-29.**
- **Decision (REVISED 2026-09-29):** `New-Object System.IO.FileStream($path, [IO.FileMode]::OpenOrCreate,
  [System.Security.AccessControl.FileSystemRights]::AppendData, [IO.FileShare]::ReadWrite, 4096,
  [IO.FileOptions]::None)` and ONE `Write` of the complete UTF-8 line including its trailing LF.
  `FileMode.Append` is REJECTED BY NAME, like `AppendAllText`: see Reasoning.
  Bounded retry on a sharing violation - 3 attempts at 40 / 80 / 160 ms with jitter - then give up,
  swallow, and `exit 0`, still failing OPEN.
- **Reasoning:** `[System.IO.File]::AppendAllText` (T9.1's draft) opens with `FileShare.Read`. A second
  writer - `dad watch` in another terminal, a subagent's hook, `close-unit.ps1` running while a Stop hook
  fires - takes a sharing violation, T9.1's blanket try/catch swallows it, and THE LINE IS SILENTLY LOST.
  That is precisely the failure class this requirement exists to eliminate, reintroduced by the mechanism
  meant to end it. `FileMode.Append` (this contract's first pin) is ALSO wrong, found by measurement at
  T9.1 QA: on .NET Framework (PS 5.1) it seeks to EOF ONCE at open and writes at that private position, so
  two handles opened close together write at the SAME offset and one line silently overwrites the other
  (two processes x 12 appends gave 19-23 of 24 lines, no exception swallowed). `FileSystemRights.AppendData`
  gives true append-only semantics - the OS positions every write at the current EOF (24/24 on repeated
  runs). `FileShare.ReadWrite` plus a single sub-4KB `AppendData` write lets concurrent writers interleave
  whole LINES and never fragments. A named machine-wide Mutex was considered and rejected: correct, but it
  introduces a lock a hung process can hold, inside a hook that must never hang.
- **INVARIANT: one line must be UNDER 4096 BYTES.** This is what makes C3a's 300-char `reason` truncation
  LOAD-BEARING rather than cosmetic - the truncation is what keeps the single-write atomicity argument
  true. It may not be raised without revisiting this decision.
- **Worked example (this is the `test-kit.ps1` assertion):** start two `dad-gates-log` appends within the
  same 5 ms window against one sandbox - one `ratchet` block, one `loop-guard` block. EXPECTED: the file
  contains EXACTLY 2 lines, each independently parseable by `ConvertFrom-Json` with all seven C3b keys
  present; their ORDER is unspecified and must NOT be asserted. Counter-example the case exists to catch:
  1 line (one writer's line lost), or 2 lines one of which is a truncated fragment of the other. The
  shipped `test-kit.ps1` case is the harder form - two processes x 12 appends must yield exactly 24 lines -
  because a 2-line race passes by luck under `FileMode.Append` and only a burst exposes it.

#### C3d: Rotation - MANUAL only, with a genesis record; no automatic roll, ever
- **Status: APPROVED 2026-09-29.**
- **Decision:** the log NEVER rolls itself. Nothing in the kit renames, trims or truncates
  `grades/gates-log.jsonl`. Instead:
  - `dad-doctor` REPORTS the log's size, line count and newest-entry age, and WARNs past 5 MB, naming the
    manual roll as the fix.
  - Rolling is a HUMAN renaming the file (convention: `grades/gates-log-<yyyy-MM-dd>.jsonl`).
  - The next append finds no `gates-log.jsonl`, creates it, and writes a GENESIS RECORD as its first line.
- **Why no automatic roll:** for a COMMITTED file, a size-triggered roll bounds the working-tree file but
  NOT the repository - git keeps every blob - so the roll's main benefit evaporates while its main cost
  remains. An append-only evidence record that silently discards its own history is the wrong shape for
  committed evidence.
- **The genesis record is a NORMAL JSONL line, not a comment header** - `gate: "gates-log"`,
  `decision: "allow"`. Deliberate: C3e pins stdout as VERBATIM JSONL, and a `#` preamble would break every
  `ConvertFrom-Json` consumer on the very first line of the file.
- **Predecessor discovery needs no stored state:** on creation, scan `grades/` for other
  `gates-log*.jsonl` and name the NEWEST one in the reason, with its line count and date span. If there is
  none, say so plainly. A genesis record is written on ANY fresh log, INCLUDING a brand-new project, so a
  reader can always tell a complete history from a continuation.
- **The gate log is NOT a ratcheted surface (R28).** A deliberate roll must never read as a shrink - which
  is exactly what C3a(i) protects by keeping `ratchet.ps1:88`'s `*_GRADE.md` filter narrow.
- **Worked example (both genesis forms, verbatim).** After a human renames a 12,481-line log to
  `grades/gates-log-2026-04-02.jsonl`, the next append creates the file and writes:
  ```
  {"v":1,"ts":"2026-09-29T14:02:11.004Z","gate":"gates-log","decision":"allow","tool":"","reason":"log created; prior history in grades/gates-log-2026-04-02.jsonl (12,481 lines, 2026-04-02..2026-09-29)","session":""}
  ```
  On a brand-new project with nothing to find, the same code writes:
  ```
  {"v":1,"ts":"2026-01-08T09:14:03.221Z","gate":"gates-log","decision":"allow","tool":"","reason":"log created; no prior history found - this log begins here","session":""}
  ```

#### C3e: Query contract - machine-clean stdout
- **Status: APPROVED 2026-09-29.**
- **Signature:** `dad-gates-log.ps1 -ProjectDir <dir> -Query [-Gate <id>] [-Decision <allow|block>]
  [-Since <datetime>] [-Last <n>] [-Count]`. Filters compose with AND.
- **Post-conditions:** stdout is VERBATIM JSONL and nothing else - one matching line per matching line,
  unmodified. Any human-facing note (for example "no gate log yet") goes to STDERR. `-Count` prints a bare
  integer, and prints `0` for a missing or empty log. ALWAYS `exit 0`. Because C3d has no automatic roll,
  `-Query` reads the CURRENT file only - there are no `.1` generations to chain, and a rolled-away
  predecessor is queried by pointing `-ProjectDir`/the path at it directly.
- **Three T9.1 defects this fixes:**
  (i) T9.1 used `-Gate` to APPEND and `-FilterGate` to QUERY, so the obvious invocation
  `-Query -Gate ratchet` was silently IGNORED and returned EVERY line - a wrong answer with no error.
  `-FilterGate` is DROPPED; `-Gate` is the filter in query mode.
  (ii) T9.1 printed "no gate log yet" to STDOUT, while T10.1 counts returned lines as gate interventions -
  so an EMPTY log could be counted as one intervention. Human notes now go to stderr.
  (iii) T9.1 had no deny-only filter, leaving S9's AC2 unsatisfiable. `-Decision block` is it.
- **Worked example (against the C3b three-line log above):**
  ```
  > dad gates-log -ProjectDir . -Query -Decision block -Since 2026-09-29T14:00:00Z -Count
  1
  > dad gates-log -ProjectDir . -Query -Gate ratchet
  {"v":1,"ts":"2026-09-29T14:31:02.880Z","gate":"ratchet","decision":"allow","tool":"","reason":"no shrink (tests 61, stories 14, tasks 40)","session":""}
  > dad gates-log -ProjectDir <fresh sandbox with no log> -Query -Count
  0
  ```

#### C3f: Proving the LOG ITSELF is wired - runtime silent, proof at smoke time
- **Status: APPROVED 2026-09-29.**
- **Decision:** the same split C2f pinned for version drift. **RUNTIME stays silent and fail-open:** no
  writer may block, warn, or self-check on a failed append mid-turn. **PROOF moves to smoke/setup time:**
  - `dad gates-smoke` (R38a, shipped as S8) gains a FOURTH assertion - after provoking each gate in its own
    throwaway fixture, assert that a matching `"decision":"block"` line landed in that fixture's
    `grades/gates-log.jsonl`. If not, report `SILENT-FAIL "<gate>-log"` and exit non-zero, exactly like its
    existing three gate assertions.
  - `dad-doctor` additionally reports the newest-line age of a project's log, alongside C3d's size/count.
- **Reasoning:** without this, the one thing that can still fail silently is the WRITER WIRING itself.
  Concretely: `dad-loopguard.ps1` has never read `cwd` - it extracts only `session_id`, `tool_name` and
  `tool_input` (`dad-loopguard.ps1:300`) - T9.2 proposes adding a `cwd` regex and SKIPPING the log call
  when it comes back empty, and T9.4's tests supply `cwd` themselves. If the real payload does not carry
  `cwd`, the loop guard never logs, every test still passes, and the log looks clean. That is C2c's trap
  wearing a third hat.
- **PREREQUISITE MEASUREMENT (blocks T9.2):** confirm whether Claude Code's real `PreToolUse` payload
  carries `cwd`, measured against the installed binary and recorded in C2b's measured-table style with a
  `claude --version` stamp. Vendor documentation is a starting hypothesis, not a source of truth (R37c).
  If it does NOT, the fallback - a machine-level log, or resolving the project another way - is a NEW
  decision to be taken then; it is deliberately not pre-decided here.
- **This REOPENS S8, which is currently DONE/closed.** The fourth assertion is new scope against a closed
  story: route it as a follow-up unit rather than silently editing a closed story's acceptance criteria.
- **Worked example (what a wired-but-unlogged gate looks like):**
  ```
  gates-smoke: loop-guard INTERCEPTED (logged), ratchet-close-refusal INTERCEPTED (logged),
               dad-guard-stop INTERCEPTED (NOT LOGGED) -> SILENT-FAIL "dad-guard-stop-log"
  exit 1
  ```
  The gate itself fired correctly in that trace; only its evidence did not land. Under R38 that is still a
  failure, because a gate that cannot be shown to have fired is not a gate.

- **Invariant(s) (all C3 sub-decisions):** (i) logging NEVER changes a gate's own verdict or exit code -
  every writer's log call is best-effort and every failure path ends in the gate's original behaviour
  (R22/R28/R32 all fail open on their own bugs; a logging bug must not become a new way for a real gate to
  misbehave). (ii) `reason` is ALWAYS redacted before it is written (C3a) - there is no unredacted path.
  (iii) one line is always under 4096 bytes (C3c). (iv) the log is append-only from the kit's side; only a
  human ever renames it (C3d). (v) the log is NOT a ratcheted surface (R28) and is NOT counted in
  `gradeBytes` (C3a-i). (vi) `-Query` stdout is machine-parseable JSONL with no prose (C3e).
- **Out of scope:** a cross-project or per-machine aggregate log (each project owns its own file); any
  automatic rotation, trimming or compaction (C3d); `grade-trends.ps1`/`/retro` actually CONSUMING the log
  (S9 AC3 requires only that it CAN be read as a data source - a plain, documented JSONL file at a fixed
  path satisfies that, and no `grade-trends.ps1` change is in scope); a schema migration path for `v: 2`
  (the field exists so one is possible, not because one is planned); logging `doc-stats` WARN findings
  (see the C3 header).

### C4: R38(c) run summary - tokens, session discovery, scope boundary, files touched
- **Status: APPROVED 2026-09-29.** Pinned as a SEPARATE top-level contract rather than as C3g-C3j: R38(b)
  is a data FORMAT with four writers; R38(c) is a single CONSUMER script with its own sourcing and its own
  open measurement, and the two are cited by different tasks (T9.x cite C3, T10.x cite C4). An id exists to
  be cited - "per C3" pointing at ten sub-decisions spanning two unrelated scripts stops being a pointer.
- **Supersedes:** `docs/TASKS.md` T10.1's in-task sourcing pins in three places - tokens (C4a), the
  missing-`-StartTime` behaviour (C4b/C4c) and the files-touched definition (C4d).

#### C4a: Tokens - CONDITIONAL on a measurement; never a fabricated number, never an unmeasured denial
- **Status: APPROVED 2026-09-29** (conditional pin; the measurement that resolves it is a named follow-up
  task, and until it returns `dad-run-summary.ps1` prints the fallback line WITH its reason).
  **RESOLVED 2026-09-30 by T10.6's measurement - see the MEASURED stamps at the end of this section.**
- **Decision:** the token figure is MEASURED-OR-NAMED, stamped per harness and per version:
  - measured YES -> `dad-run-summary.ps1` streams the session transcript, sums input / output / cache
    tokens over entries at or after the window start, and prints the number WITH its source and the
    version it was measured against.
  - measured NO, or transcript missing, or a non-Claude harness -> print the fallback line NAMING THE
    REASON. An honest gap that says WHY is a finding; a bare "not available" is an assertion.
- **Why not simply pin "not available" (T10.1's draft):** T10.1 justified that line by grepping this kit's
  own `.ps1` files for token/usage parsing. That evidence proves THE KIT does not read it - a different
  claim from THE DATA IS ABSENT. Direct evidence in this repo points the other way: `dad-guard.ps1:63`
  documents that the Stop payload carries `transcript_path`, and `dad-guard.ps1:76-77` OPENS that file
  (`Test-Path` + `Get-Item ... CreationTimeUtc`) to derive session start. The transcript is a local file
  this kit already touches. Pinning "not available" without opening it would be accepting an assertion a
  script can settle - which this document forbids in its own words (R24: "never accept an assertion a
  script can settle").
- **Two facts the pin carries regardless of the outcome:** (i) the number is HARNESS-specific - Copilot
  CLI (R37) has no Claude Code session transcript at all, so on that harness the fallback line is the
  correct and PERMANENT answer, not a gap; (ii) it is BACKEND-specific - whether an Ollama-proxied response
  populates a usage field at all is itself unmeasured, so R1 (local) and R34(b) (cloud) must BOTH be
  measured and neither generalised from the other.
- **The measurement task carries:** both backends, the exact transcript path measured, the field names
  found, and a `test-kit.ps1` assertion tying the stamped version constant in the script to the version
  recorded in this contract - the same doc-and-code-cannot-drift device C2f pinned for the harness version.
- **Worked example (both branches; each names its provenance):**
  ```
  [run-summary] tokens: 412,300 in / 38,914 out / 1,204,880 cache read
                (source: transcript abc123.jsonl, 214 assistant entries, Claude Code <measured version>)
  [run-summary] tokens: not available (harness=copilot-cli: no session transcript is exposed to project tooling)
  [run-summary] tokens: not available (transcript path recorded but file missing: .claude\.dad-session.json -> C:\...\abc123.jsonl)
  ```
  The third form is the one that matters most: it is still an honest gap, and it names a cause a human can
  act on, instead of collapsing three different situations into one unfalsifiable sentence.
- **MEASURED (T10.6, 2026-09-30) - the outcome of the conditional pin.** The stamp lines below are what
  `test-kit.ps1`'s drift case parses (`MEASURED <date> against Claude Code <version>`); the script's
  `$MeasuredClaudeCodeVersion` must equal the first.

  MEASURED 2026-09-30 against Claude Code 2.1.285

  Cloud (R34b): assistant entries in the session transcript carry `message.usage.input_tokens`,
  `output_tokens`, `cache_read_input_tokens` and `cache_creation_input_tokens` (plus `service_tier`,
  `iterations`, `speed` and others), on 219 of 219 assistant entries in the measured transcript. Models seen
  in the corpus: `claude-sonnet-5-5`, `claude-opus-5-5`, `claude-haiku-4-5-20251001` and earlier ids.

  MEASURED-LOCAL 2026-09-30 against Claude Code 2.1.191 (backend R1, Ollama, model `qwen3-coder-next-cc`)

  Local (R1): the same usage fields are populated (`cache_read_input_tokens` measured as 0), taken from an
  EXISTING transcript written by Claude Code 2.1.191. The usage fields of a fresh local run on 2.1.285 are
  UNMEASURED, so the local figure carries its OWN version constant, `$MeasuredLocalClaudeCodeVersion`, and is
  never stamped with the cloud version (fact (ii) above). **CORRECTED 2026-10-01 (S16 / T16.1, measured
  2026-09-30 on 2.1.285):** this paragraph used to say 2.1.285 "rejected an unmapped local model id
  (`--model qwen3-14b-cc`)". It does not - see the S16 amendment below.
- **Counting rule (measured, and load-bearing):** Claude Code writes ONE transcript entry PER CONTENT BLOCK,
  so a single API message appears as several entries sharing one `message.id`. Usage is identical across
  those entries on the cloud backend (a naive sum over-counts about 1.8x) and, on the local backend,
  `output_tokens` can GROW across streamed partials of one message (a naive sum over-counts about 1.6x).
  The figure is therefore the per-field MAX over each `message.id`, never a sum over entries, and the
  printed entry count is the number of DEDUPED messages: "N assistant entries" means N messages.
- **Mixed and foreign transcripts:** an assistant entry whose model is neither `claude-*` nor a `-cc` name
  in `models.json`, a `<synthetic>` entry, or an entry without usage is SKIPPED, and a transcript lacking
  the `version`/`sessionId` stamp (another harness) yields the reasoned fallback line, never a number. A
  transcript that mixes measured and skipped entries understates the total, so the script must COUNT the
  skipped-as-unmeasured entries and name that count on the tokens line rather than staying silent.
- **S16 amendment - local models on Claude Code 2.1.285 (T16.1, measured 2026-09-30; record:
  `grades/S16_GRADE.md` "Measured-facts record (T16.1)"; Windows 11 Pro 10.0.26200, Ollama 0.34.0).**
  Headless only; the interactive rows (`/model`, interactive `claude --model`, the model-switch script) are
  NEEDS HUMAN and unmeasured.
  1. **Warning, not rejection.** `claude -p ... --model qwen3-14b-cc` exits 0 and answers; the catalog text
     ("isn't described by this version's model catalog ... `[claude-code:unrecognized_model]`") is a
     WARNING. A base tag (`--model qwen3:14b`) behaves the same.
  2. **Precedence.** User `settings.json` `env.ANTHROPIC_MODEL` OVERRIDES a process `ANTHROPIC_MODEL` (row a:
     process `qwen3-14b-cc`, user settings `claude-sonnet-5-5` -> exit 1 naming `claude-sonnet-5-5`); with the
     user source excluded (`--setting-sources project,local`) the same call succeeds; a project
     `.claude/settings.json` env beats the user one. That was T10.6's failure: the machine was in cloud/hybrid
     mode, so the user setting held a cloud id. Kit probes therefore pass `--model <-cc name>`.
  3. **"Local model resolves" (R40d) means:** with per-process `ANTHROPIC_BASE_URL=http://localhost:11434`
     and a dummy `ANTHROPIC_AUTH_TOKEN`, `claude -p "<tiny prompt>" --max-turns 1 --model <-cc name>
     --output-format json` exits 0, its JSON `result` is non-empty, and `modelUsage` is keyed by the `-cc`
     name. `unrecognized_model` is a WARN, never a FAIL. Ollama unreachable -> SKIP, never a pass.
     S17 implements this in `harness-versions.ps1` `Test-LocalModelResolves` (adding
     `--setting-sources project,local`).
  **Worked example (row e):** `claude -p "Reply with the single word: pong" --max-turns 1 --model
  qwen3-14b-cc --output-format json --setting-sources project,local` -> exit 0, `result` = `"pong"`,
  `modelUsage` has the key `"qwen3-14b-cc"`, and `ollama ps` shows `qwen3-14b-cc` loaded 100% GPU -> PASS
  (the local model answered, not a cloud fallback).
  **Where S17 differed from this text - DECIDED 2026-10-01, chosen by the human (OPEN-4).**
  (a) **Model = the `fast` alias (option A).** R40(d) is amended to "a local -cc model (the `fast` alias)",
  matching `harness-versions.ps1`: S16 measured that resolution is model-independent, and `fast` is the
  cheapest to load. Rejected: B, probe "the configured" alias - costs a bigger model load and proves nothing
  more, since resolution does not depend on which `-cc` name is asked.
  (b) **stderr is CAPTURED and the WARN is PRINTED (option A).** The probe must capture the `claude` call's
  stderr and, when it contains `unrecognized_model`, print one line
  `[harness] local model <cc>: WARN unrecognized_model (Claude Code assumes a 200000 context window;
  Ollama serves <ctx>)` while the result stays a PASS (WARN, never FAIL); it must never discard stderr, and
  other stderr content does not change the outcome. **The SOURCE of `<ctx>` - DECIDED 2026-10-03, chosen by
  the human (OPEN-4(b), `<ctx>`):** the local Ollama's `/api/show` for the model's `-cc` name. `<ctx>` = the
  LOWER of (i) the integer on the `num_ctx` line of the response's `parameters` text and (ii) the integer at
  `model_info` key `<arch>.context_length`, where `<arch>` is the value of `model_info` `general.architecture`;
  it is printed as a plain integer. It is `unknown` - never a guess, never the manifest `numCtx` - when Ollama
  is unreachable (including the `DAD_SMOKE_OLLAMA=down` test seam), the `/api/show` call fails or times out
  (3 seconds, the same bound as the reachability check), the response is not JSON, or either value is missing or not a positive integer. The lookup never changes
  the outcome: the WARN stays a WARN and the check stays PASS in every case (no FAIL from the ctx lookup).
  `models.json` `numCtx` is NOT a proxy (65536 configured while S16 measured 40960 served). The min() rule
  rests on ONE measured model, where `num_ctx` > `context_length` (65536 > 40960) and the lower value is the
  one S16 measured as served; it is therefore stated as the rule, not as a universal law. Before this
  decision the WARN carried `unknown` unconditionally; it now carries the derived number, and `unknown` only
  in the cases above. Reason for (b): that warning is the only visible trace of the context-window
  hazard in Open (ii) below. Rejected: B, keep discarding stderr - a WARN nobody can see is exactly the
  silent outcome R40 ("never a silent one") forbids.
  **DONE 2026-10-03 via S24:** `Test-LocalModelResolves` no longer discards stderr - it keeps it via a temp
  file and prints the WARN line while the result stays PASS; other stderr content does not change the
  outcome; an unreachable Ollama gives SKIP, and a skipped local-model check is named in the final smoke line
  (`[harness] <name> smoke check passed (local-model check SKIPPED: <reason>)`), never a bare pass. The S24
  code first printed `unknown` for `<ctx>`. **The 2026-10-03 source rule above is DONE via S24 / T24.5 and
  T24.6 (commits 5980965 and 1a90092):** `Get-OllamaServedContext` reads the lower of `num_ctx` and
  `<arch>.context_length` from `/api/show`, and the WARN prints it, with `unknown` only on the failure cases
  above; the `DAD_SMOKE_OLLAMA_SHOW` seam keeps every test free of network calls. (Corrected 2026-10-08: this
  paragraph used to say the rule was "not yet implemented".)
  **Worked example:** row (e) above (`fast` = `qwen3-14b-cc` in `models.json`), whose stderr carries
  `[claude-code:unrecognized_model]` -> exit 0, `result` `"pong"`, `modelUsage` key `"qwen3-14b-cc"`. The
  `<ctx>` lookup (measured on this machine 2026-10-03, Ollama 0.35.0): `/api/show` for `qwen3-14b-cc` returns
  `parameters` containing `num_ctx 65536` and `model_info` `general.architecture` = `qwen3`,
  `qwen3.context_length` = 40960 -> `<ctx>` = min(65536, 40960) = 40960, which equals what S16 measured as
  served -> the probe prints `[harness] local model qwen3-14b-cc: WARN unrecognized_model (Claude Code
  assumes a 200000 context window; Ollama serves 40960)` and scores PASS. Second row: the same run, but the
  `<ctx>` lookup finds Ollama down -> `[harness] local model qwen3-14b-cc: WARN unrecognized_model (Claude
  Code assumes a 200000 context window; Ollama serves unknown)`, still PASS. The same run with empty stderr
  scores PASS and prints no WARN line. Interplay with item 3: an Ollama unreachable when the probe STARTS
  gives SKIP and no `claude` call, so no WARN line at all; the `unknown` row is what the `<ctx>` lookup itself
  yields whenever it finds Ollama unreachable (live, or forced by `DAD_SMOKE_OLLAMA=down`).
- **Open:** (i) local usage fields on 2.1.285 - re-measuring is NO LONGER BLOCKED (the local run succeeds,
  amendment item 1); it is simply UNMEASURED. Until someone measures it the local stamp stays at 2.1.191,
  and `test-kit.ps1`'s drift case must compare BOTH constants to their stamps and must not pass merely
  because a stamp is absent. (ii) **Context-window risk (open, not a measured failure):** Claude Code assumes
  a 200000-token window for an unrecognised model (`modelUsage` `contextWindow` 200000) while Ollama serves
  the `-cc` model at ctx 40960, so auto-compact keyed to 200k could let a long local session overrun the real
  window. How it fails, if it does, is unmeasured; the warning text names `CLAUDE_CODE_MAX_CONTEXT_TOKENS`
  and a `modelOverrides`/`behavesAs` mapping as knobs - none is tried or chosen here.

#### C4b: Session discovery - the Stop hook records what only it can see
- **Status: APPROVED 2026-09-29.**
- **Decision:** `dad-guard.ps1`'s Stop hook writes `{session_id, transcript_path, first_seen_utc}` ONCE
  per session to `.claude\.dad-session.json`. Any later plain subprocess - `dad-run-summary.ps1`,
  `publish-run.ps1` - reads it to find both the session clock and the transcript. `-StartTime` and
  `-TranscriptPath` remain explicit overrides and always win.
- **Reasoning:** the Stop hook is the ONLY place in the kit that ever sees `transcript_path`, and it
  already parses and opens it (`dad-guard.ps1:76-77`). This is therefore ONE EXTRA WRITE of data already
  in hand, not a new discovery mechanism. Scanning `~/.claude/projects/` for the newest JSONL was
  rejected: it guesses the session by mtime and picks the wrong one whenever two sessions share a project.
- **This file is EPHEMERAL RUNTIME STATE, and therefore correctly lives in gitignored `.claude\` -
  deliberately NOT in `grades/`.** It is a pointer to a machine-local transcript, valid only on the machine
  that wrote it and only while that transcript exists. It is not evidence, and committing it would put a
  dead absolute path into every clone. The split IS the point: C3a's log is evidence and is committed;
  this is state and is not.
- **Worked example:** `.claude\.dad-session.json` after the first Stop of a session:
  ```json
  {"session_id":"abc123","transcript_path":"C:\\Users\\me\\.claude\\projects\\D--projects-DrDad\\abc123.jsonl","first_seen_utc":"2026-09-29T13:38:07.412Z"}
  ```
  `dad-run-summary.ps1` invoked with no `-StartTime` then windows from `2026-09-29T13:38:07.412Z` and
  labels that figure `source: session start` (C4c).
- **Clarifications (from T10.5, 2026-09-30):**
  - **A different `session_id` REPLACES the pointer** with a fresh `first_seen_utc`. The pointer is to the
    CURRENT session; "ONCE per session" means the SAME session id never rewrites its own
    `first_seen_utc`. The alternative (keep the first session's pointer) would point every later summary
    at a stale transcript.
  - **One pointer per project directory, so two concurrent sessions in one project overwrite each other**
    (last Stop wins). That is a known limit of a single-file pointer, not a defect; the summary then
    windows from whichever session stopped last, and the `source: session start` label says which pointer
    it used. The remedy for a precise window is the explicit `-StartTime` / `-TranscriptPath` override.
  - **Written only for a DAD project and only when both `session_id` and `transcript_path` are present**
    (never under `-Check`/`-Ack`, never on the `stop_hook_active` retry pass), best-effort, and it can never
    change the Stop hook's verdict or exit code.

#### C4c: Scope boundary - caller-supplied, with a LABELLED session-start fallback
- **Status: APPROVED 2026-09-29.**
- **Decision:** NO marker file and NO `-Start` mode. The orchestrator prose of T10.2 (`/build` captures a
  git ref + timestamp baseline at Gate 3) and T10.3 (`/audit` captures one at audit start) stands as
  drafted. What makes the prose path safe is its composition with C4b:
  - `-StartTime` / `-SinceCommit` supplied -> use them; every figure's provenance reads `caller-supplied`.
  - either absent -> fall back to `.dad-session.json`'s `first_seen_utc`, and to the git HEAD as of that
    time for the commit range; provenance reads `session start`.
  A forgotten `-StartTime` therefore yields a LABELLED DEFAULT window, not a silently wrong one.
- **C4 INVARIANT - EVERY PRINTED FIGURE NAMES ITS PROVENANCE:** one of `source: caller-supplied`,
  `source: session start`, `source: git range`, `source: gate log`, `source: transcript`,
  `source: doc-stats -Findings`. This is R23's provenance thesis - a corpus without provenance fails the
  same way code without a build does, because six weeks later nobody can tell where a number came from -
  applied to RUN COST. It is the rule that makes the prose boundary acceptable: a number whose origin is
  printed beside it cannot be quietly mistaken for a different number, and a wrong window announces itself
  instead of being believed.
- **Worked example (the full summary, both boundary paths).** `/build` scope, baseline supplied:
  ```
  [run-summary] wall-clock: 42m 11s                              (source: caller-supplied -StartTime 2026-09-29T14:02:00Z)
  [run-summary] files touched: 14 (11 committed, 3 uncommitted)  (source: git range 77bf021..HEAD + working tree)
  [run-summary] findings: 2                                      (source: doc-stats -Findings)
  [run-summary] gate interventions: 1 block, 2 armed             (source: gate log, grades/gates-log.jsonl)
  [run-summary] tokens: not available (harness=copilot-cli: no session transcript is exposed to project tooling)
  ```
  **Gate-intervention counting (from T10.1, 2026-09-30):** `block` = every log line with decision `block`
  (all gates); `armed` = decision `allow` AND reason exactly `armed`. The genesis line (C3d) and the
  every-invocation `allow` lines of `ratchet` and `close-unit-refusal` (C3b) count as NEITHER. A close that
  passes `-AcceptShrink` still writes a `ratchet` block line (ratchet does not know the flag), so it counts
  as an intervention - deliberately: an accepted shrink is exactly what a reader of the summary should see.
  The same run with `-StartTime`/`-SinceCommit` forgotten changes exactly two things - the window and the
  label, never the silence:
  ```
  [run-summary] wall-clock: 1h 06m 04s                           (source: session start, .claude\.dad-session.json first_seen_utc 2026-09-29T13:38:07Z)
  [run-summary] files touched: 19 (16 committed, 3 uncommitted)  (source: git range 4a1c9f2..HEAD + working tree, HEAD at session start)
  ```

#### C4d: Files touched - committed AND uncommitted, reported SPLIT
- **Status: APPROVED 2026-09-29.**
- **Decision:** the union, deduplicated by path, of `git diff --name-only <since>..HEAD` (committed),
  `git diff --name-only <since>` (tracked but uncommitted) and `git ls-files --others --exclude-standard`
  (untracked), printed SPLIT: `files touched: 14 (11 committed, 3 uncommitted)`. NO extension filter and
  NO directory filter - the summary is descriptive, not a gate.
- **Reasoning:** T10.1's committed-range-only definition reports the wrong number for exactly the run this
  kit exists to catch. R22's motivating failure - a 7,115-line `/build` that made 106 file edits and ZERO
  shell calls, never committed, and left 47 dirty files - would print `files touched: 0`: the worst
  possible answer from the summary whose entire job is making a run's cost visible. The UNCOMMITTED half is
  the half that correlates with every failure R22 and R28 exist for, so it may not be invisible; and
  splitting rather than merging the two is what makes the pathology legible at a glance.
- **Worked example (the R22 run, scored both ways):** this contract prints
  `files touched: 47 (0 committed, 47 uncommitted)   (source: git range <baseline>..HEAD + working tree)`,
  where T10.1 as drafted prints `files touched: 0`. A reader of the first line knows immediately what went
  wrong; a reader of the second concludes the run did nothing.

- **Invariant(s) (all C4 sub-decisions):** (i) every printed figure names its provenance (C4c) - a number
  without a source is a defect, not a formatting preference. (ii) `dad-run-summary.ps1` NEVER fabricates a
  figure it cannot source, and never prints a bare "not available" without a reason (C4a). (iii) it is
  READ-ONLY - it computes and prints, it writes no project state and takes no action on what it finds.
  (iv) it never blocks anything: a summary is a report, and no gate depends on it.
- **Out of scope:** a per-run HTML or markdown artifact (the summary is console output relayed by the
  orchestrator; `publish-run.ps1` remains the mechanism for a committed run receipt); cost in CURRENCY
  (tokens are the unit, and a price table would be a second thing to keep true); attributing figures to
  individual subagents (R32 - a subagent is an unobservable region; the summary is per SCOPE); a
  cross-run trend view of these figures (that is `/retro`'s territory, R27, once the data exists).

### C5: R39(a) Copilot CLI parity surfaces - MCP route + folder trust, agents, commands-as-skills, hook payloads, the UNMEASURED boundary
- **Status: MEASURED, pinned 2026-10-01 from S14 / T14.1 (commit e313aa0).** Source of truth: `grades/S14_GRADE.md`
  "Measured-facts record (T14.1)", "Verdicts feeding C5" and "Unmeasured items". Every fact below is an
  observation of the installed binary in scratch projects under `_tmp\t141` (since removed), with
  `COPILOT_ALLOW_ALL=true` as a PROCESS env var (writes nothing) and hooks captured per the T9.5 recipe;
  `~\.copilot\config.json` was SHA256-identical before and after. Vendor documentation is not used as a fact
  (R37c). **Version stamp: true OF Copilot CLI 1.0.89 on Windows 11 Pro 10.0.26200 - the same binary C2 was
  measured against - and of nothing else.**

  MEASURED 2026-09-30 against GitHub Copilot CLI 1.0.89

- **The rule this contract exists to enforce (R39a, R37c):** a parity story may rely ONLY on C5a-C5d facts.
  Anything in C5e is UNMEASURED and no parity story may rely on it. The three choices once marked open
  (OPEN-1 trust route, OPEN-2 delivery location, OPEN-3 version constant) were DECIDED by the human on
  2026-10-01 (C5a, C5b, C5f); two of them gate parity work on a consented measurement first (C5a, C5b).
- **Enforced by `test-kit.ps1`:** nothing yet - no parity code exists. Per R37(c) each C5 fact a parity story
  starts relying on lands WITH its `Test-Case` in that story.

#### C5a: MCP route - the workspace `.mcp.json` works AS-IS; the blocker is FOLDER TRUST, not schema
- **Measured:**
  | fact | observed |
  |---|---|
  | why `local-tools` did not list (R39 prose) | FOLDER TRUST. Workspace MCP servers, skills and hooks load only for a TRUSTED folder. Untrusted: `copilot mcp list` shows only `github-mcp-server`; with `COPILOT_ALLOW_ALL=true` (exactly `true`) the cwd is trusted and `local-tools (local)` lists |
  | schema | the kit's project `.mcp.json` works unchanged (`mcpServers`, absolute exe `command`, `env` block, no `type`/`args`); `copilot mcp get local-tools` -> Enabled, local, tools `*`, Source Workspace. `type:"stdio"` / `tools:["*"]` variants also list - key names were never the cause |
  | `.github/mcp.json` | works the same as `.mcp.json` |
  | nested launch | a `.mcp.json` at an ancestor git root is picked up from a nested directory |
  | real call | a `list_datasheets` call was answered through the workspace `.mcp.json` (`copilot -p ... -s --allow-all-tools`) |
  | docs path | `"LOCALTOOLS_DOCS_DIR":"./docs"` works and resolves against the SESSION cwd (C5d: the launch dir); `${workspaceFolder}` is NOT expanded |
  | env display | env values are masked (`***`) in `copilot mcp get` |
- **Consequences pinned:** (i) no Copilot-specific MCP file is needed - Copilot reads the same project
  `.mcp.json` Claude Code does, so R39(c)'s no-machine-path rule adds no NEW path; the exe `command` is the
  one machine-specific value, exactly as it already is for Claude Code (`local-tools` is not on PATH).
  (ii) `./docs` resolves against the launch dir, so a Copilot session launched from a project SUBDIRECTORY
  resolves `<subdir>\docs`, not the project's docs - parity guidance must say "launch from the project root"
  or the server must not depend on a relative path. (iii) `--additional-mcp-config` was not exercised (the
  workspace file sufficed) and is not part of the route.
- **Qualifies C2a (dated 2026-10-01):** in T14.1's TRUSTED scratch folders, hooks at the repo-level
  `.github/hooks/cap.json` DID fire. C2a's "the repo-level path loads nothing" was observed in an untrusted
  folder and is true only of one. C2a's DECISION is unchanged and now has a second reason: the kit writes
  hooks at user level ONLY and never writes `.github/hooks/`, because in a trusted folder a repo-level copy
  would fire alongside the user-level `dad.json` and double-count the loop guard (C2b invariant i).
- **Trust route: DECIDED 2026-10-01, chosen by the human (OPEN-1 = A).** The user trusts each project folder
  ONCE, themselves, through Copilot's own interactive trust prompt. The kit NEVER sets `COPILOT_ALLOW_ALL` -
  not in a script, a hook, a generated file, an env block or guidance text - because what that variable
  permits beyond trusting the cwd is UNMEASURED (C5e item 3), and a kit that switches on a harness's
  blanket-permission flag would be lowering a security setting on the user's behalf (R35) and acting on
  the harness's authorization surface, which `## Out of scope` "Handling security" places outside the kit.
  Rejected: B, the kit sets `COPILOT_ALLOW_ALL=true` for Copilot sessions - unmeasured blast radius, and a
  security decision made for the user; C, the kit pre-writes trust into `~\.copilot\config.json` - an
  unmeasured file format and a user-level write without consent (R35).
  **Gate:** the MCP parity story is BLOCKED until a consented, human-attended measurement of the interactive
  trust prompt (and its probable `config.json` write) is recorded and stamped into C5a via `/design`. Until
  then C5e item 3 stays UNMEASURED and no story may rely on how, or whether, trust persists.
  **Worked example:** a user opens Copilot CLI in `D:\projects\demo` for the first time; `copilot mcp list`
  shows only `github-mcp-server` (untrusted). They answer Copilot's trust prompt themselves; from then on
  `local-tools (local)` lists. Nothing in `install.ps1 -CopilotCli`, the hooks or the generated skills ever
  contains the string `COPILOT_ALLOW_ALL`; a parity story's `Test-Case` asserts that by grep over what it
  ships.

#### C5b: Agents - `global\agents\*.md` load AS-IS from a workspace dir; their tool grants are UNMEASURED
- **Measured:** Copilot discovers custom agents in `.github/agents/*.md`, `.github/agents/*.agent.md` and
  `.claude/agents/*.md` (evidence: `copilot --agent <nonexistent> -p hi` lists the available agents).
  Three UNMODIFIED copies of `global\agents\*.md` (Claude frontmatter `name` / `description` / `tools`,
  including `mcp__local-tools__*` names) were discovered with no error. A skill can spawn a named custom
  agent through Copilot's `task` tool and get its reply back (marker `PROBE-AGENT-OK`), so the
  orchestrator -> subagent pattern `/build` uses is viable. C2d still applies: lifecycle events and
  attribution need a NAMED custom agent, never the built-in `general-purpose` one.
- **Not measured (C5e):** whether Claude `tools:` names map to any Copilot tool grant; user-level agent
  paths; discovery in an UNTRUSTED folder (inconclusive).
- **Delivery location: DECIDED 2026-10-01, chosen by the human (OPEN-2 = B with A as fallback; shared with
  C5c).** Every MEASURED location is WORKSPACE-level, so before ANY agents/skills parity story a small
  CONSENTED spike measures whether user-level `~/.copilot/agents` and `~/.copilot/skills` load (C5e item 2).
  (B) If they load: `install.ps1 -CopilotCli` generates agents and skills ONCE at user level - mirroring the
  Claude side (user-level `~\.claude\agents`, `~\.claude\commands`) and C2a (hooks at user level only).
  (A, fallback) If they do not: per-project generation into `.github/agents/` and `.github/skills/`,
  gitignored and regenerated, never hand-edited. NEVER `.claude/agents/` or `.claude/skills/` in either case:
  Claude Code reads those too, so a generated copy there would be seen by BOTH harnesses and would shadow
  the user-level agent in Claude Code. Rejected: A outright - a per-project copy in every project when one
  user-level copy may work; C, `.claude/agents` + `.claude/skills` - double-loaded and shadowing, as above.
  Until the spike's result is stamped into C5b/C5c via `/design`, the location is UNMEASURED and no
  agents/skills parity story may be sharded.
  **Worked example:** spike result "loads" -> `install.ps1 -CopilotCli` writes
  `%USERPROFILE%\.copilot\skills\build\SKILL.md` (and one per command) and
  `%USERPROFILE%\.copilot\agents\dev-agent.md`, and `uninstall.ps1` removes exactly those. Spike result
  "does not load" -> generating for `D:\projects\demo` writes `D:\projects\demo\.github\skills\build\SKILL.md`
  and `D:\projects\demo\.github\agents\dev-agent.md`, both under a `.gitignore` entry; nothing is ever
  written to `D:\projects\demo\.claude\agents\` or `.claude\skills\`.

#### C5c: Commands as skills - a GENERATED transform of `global\commands\*.md`, never a hand copy (R39b)
- **Measured:** skill locations discovered: `.github/skills/<n>/SKILL.md`, `.agents/skills/`,
  `.claude/skills/` (user-level `~/.copilot/skills` not tested). Of the 19 command files loaded RAW as
  skills: 2 load (`corpus`, `scaffold`); 13 fail `argument-hint must be a string` (a `[...]` value parses as
  a YAML list); `assess` and `design` fail YAML parse (a colon inside an unquoted scalar); `audit` and
  `grade` fail, cause not individually counted. Single-quoting `description` and `argument-hint` made 15
  load; `corpus` and `research` contain `'` and need proper escaping.
- **Decision (the record's verdict, made exact):** the skill set is GENERATED from `global\commands\*.md` by
  a kit script - never hand-copied, never hand-edited (R39b). The transform touches the FRONTMATTER ONLY:
  - `description` and `argument-hint` (when present) are re-emitted as YAML single-quoted scalars, each
    embedded `'` doubled to `''` (YAML's single-quote escape).
  - every other byte - other frontmatter lines, the `---` fences, the whole body - is copied unchanged; no
    key is added or removed. Output path: `<skills-root>\<command basename>\SKILL.md`, where `<skills-root>`
    is decided in C5b (OPEN-2): `~/.copilot/skills` if the consented spike shows it loads, else the
    project's gitignored `.github/skills/`; never `.claude/skills/`.
- **Signature / pre + post:** `Convert-CommandToSkill(<command .md text>) -> <SKILL.md text>`. Pre: the file
  opens with a `---` frontmatter of single-line `key: value` entries. A frontmatter it cannot parse that way
  is an ERROR naming the file - never a silent skip, never a partially emitted skill. Post: the transform is
  DETERMINISTIC (same source -> byte-identical output) and always reads `global\commands\`, never its own
  output (it is not idempotent on a quoted value); the generated set has exactly one skill per command file.
- **What is and is not measured about the OUTPUT:** loading after quoting is measured for 15 files. Whether
  the doubled-quote form loads `corpus` and `research`, and whether `audit` and `grade` load after the
  transform at all, is UNMEASURED (C5e) - the S14 card names a follow-up measurement for exactly this.
- **Invariant:** generated set == transform(current `global\commands\*.md`); a parity story that ships the
  generator ships a `test-kit.ps1` case asserting that equality, so a drifted skill is a test failure, not
  a silent difference.

#### C5d: Hook payloads, `cwd` and the session id - PascalCase per C2b; `cwd` is the LAUNCH dir
- **Casing is NOT decided here:** C2b already decided it - PascalCase, each event registered ONCE. T14.1
  re-confirms C2b's finding that casing selects the payload SHAPE. Under the C2b registration the fields the
  kit reads are `hook_event_name`, `session_id`, `cwd`, `tool_name`, `tool_input` (PreToolUse) and
  `session_id`, `cwd`, `transcript_path`, `stop_reason`, `stop_hook_active` (Stop). The camelCase family
  (`preToolUse`, `agentStop`; `sessionId`, `toolName`, `transcriptPath`, ...) is never registered.
- **Measured:**
  | fact | observed |
  |---|---|
  | `cwd` | PRESENT and non-empty in all four captured payloads; an absolute Windows path, JSON-escaped (`\\`) |
  | session id | PRESENT, a UUID (`session_id` in the PascalCase shape) |
  | launch from a subdirectory | `cwd` = the LAUNCH dir, not the git root (git-root hooks are still found) |
  | after an in-session `cd` | `cwd` is UNCHANGED on the next `PreToolUse` - it stays the launch dir |
  | tool name | PascalCase reports the alias `tool_name:"Bash"` (camelCase would say `powershell`) |
  | hook command key | on Windows the `powershell` key ran and the `bash` key did not |
  | Stop | carries `stop_reason`, `stop_hook_active:false`, and a `transcript_path` to Copilot's own `events.jsonl` under `~\.copilot\session-state\<uuid>\` |
  Verbatim PascalCase captures (transcript path redacted in the record):
  `{"hook_event_name":"PreToolUse","session_id":"1d0ab973-d259-4a6f-bc5e-6188c753ac5b","timestamp":"2026-09-30T19:18:03.077Z","cwd":"D:\\projects\\DrDad\\_tmp\\t141\\p9","tool_name":"Bash","tool_input":{"command":"echo hello-root","description":"Run the requested shell command","mode":"sync","initial_wait":10}}`
  `{"hook_event_name":"Stop","session_id":"1d0ab973-d259-4a6f-bc5e-6188c753ac5b","timestamp":"2026-09-30T19:18:05.022Z","cwd":"D:\\projects\\DrDad\\_tmp\\t141\\p9","transcript_path":"<REDACTED>","stop_reason":"end_turn","stop_hook_active":false}`
- **Answer to R39(a)(iii):** yes - both payloads carry a non-empty `cwd` and a `session_id`, so the C3 writers'
  "skip logging on empty `cwd`" branch does not silently kill the Copilot log.
- **CONSTRAINT on all future parity work touching the C3 gate-log writers (and anything else that reads the
  payload `cwd`):** `cwd` is where the session was LAUNCHED, and it does not follow an in-session `cd`.
  A writer must therefore (i) never treat `cwd` as the project root - it resolves the project by walking UP
  from `cwd` to the nearest ancestor that is a DrDad project, as `dad-loopguard.ps1`'s `Resolve-LogProject`
  already does; and (ii) never treat `cwd` as where the current tool call is acting - a session launched in
  project A that `cd`s into project B keeps logging to A. A parity story that needs per-call project
  attribution must derive it from `tool_input`, and that is a new decision, not something C5 grants.
- **Stop `transcript_path` vs C4a:** Copilot DOES expose a transcript path, so C4a fact (i)'s wording "no
  session transcript is exposed" is imprecise for 1.0.89. Its CONCLUSION stands: `events.jsonl`'s format is
  UNMEASURED and carries no Claude Code `version`/`sessionId` stamp, so C4a's reasoned fallback line remains
  the correct output on this harness. Reading `events.jsonl` for tokens would need its own measurement.

#### C5e: The UNMEASURED boundary - no parity story may rely on any of these (R39a, R37c)
Each item was named in the T14.1 record as not measured or inconclusive. They are pinned AS UNMEASURED: a
story that needs one must first get it measured and amended into C5 via `/design`.
1. **Claude `tools:` -> Copilot tool mapping** - agents load, but what tools a `tools:` list (including
   `mcp__local-tools__*`) actually grants under Copilot is unknown.
2. **User-level discovery paths** - `~/.copilot/agents`, `~/.copilot/skills` and plugins were not tested
   (consent guard: user-level writes). The consented spike C5b requires before any agents/skills parity
   story measures the first two.
3. **Trust persistence via the interactive prompt** - not run; probably a user-level `config.json` write, so
   it needs a human-attended, consented run (R35); C5a BLOCKS the MCP parity story on exactly that run. Also
   unmeasured: what `COPILOT_ALLOW_ALL` permits BEYOND trusting the cwd (moot for the kit, which never sets
   it - C5a).
4. **`$ARGUMENTS`-style substitution in skill bodies, an `allowed-tools` equivalent, and equivalents of
   Claude's hook/permission settings** - recorded as "not measured", which is NOT the same as "no
   equivalent"; R39(d)'s honest-boundary entry in `## Out of scope` waits for a measurement either way.
5. **The `audit` and `grade` skill failure cause**, and whether the C5c transform loads `audit`, `grade`,
   `corpus` and `research`.
6. **Agent (and skill) discovery without folder trust** - inconclusive.

#### C5f: Version stamp and drift for C5
- **Fact:** C5 and C2 were measured against the SAME binary (1.0.89). C2f's `$CopilotMeasuredVersion` in
  `install.ps1` is the one Copilot constant today, and `test-kit.ps1`'s C2f case compares it to EVERY
  `MEASURED <date> against GitHub Copilot CLI <v>` stamp in this doc, C2's and C5's (DONE via S25, below).
- **Whether that constant also governs C5: DECIDED 2026-10-01, chosen by the human (OPEN-3 = A, ONE
  constant).** `$CopilotMeasuredVersion` covers C2 AND C5. Consequence: a Copilot update that is
  re-measured re-measures BOTH, and the constant may not move until every Copilot stamp in this doc moves
  with it. The C2f drift test therefore had to be extended so that EVERY
  `MEASURED <date> against GitHub Copilot CLI <v>` stamp in DESIGN equals `$CopilotMeasuredVersion` (it used
  to check the first stamp alone, C2's). **DONE 2026-10-03 via S25:** `test-kit.ps1`'s
  `Get-CopilotStampProblems` finds every such stamp (`[regex]::Matches`, not `Match`), FAILS when there is
  none (never a vacuous pass), and names the line of each stamp that differs from the one constant; the C2f
  case and the fixture case "S25: the Copilot stamp check covers EVERY MEASURED stamp, not just the first
  (AC1-AC3)" both use it.
  Rejected: B, a second constant for C5 - two numbers to keep true for one binary, and nothing gained while
  C2 and C5 are measured together; C, no constant for C5 - C5 could silently go stale.
  **Worked example:** `$CopilotMeasuredVersion = '1.0.89'`; DESIGN holds two stamps, C2's and C5's, both
  `... against GitHub Copilot CLI 1.0.89` -> the extended case PASSES. Someone re-measures C2 on 1.0.95, bumps
  the constant and C2's stamp but not C5's -> the case FAILS naming the C5 stamp `1.0.89 != 1.0.95` (the
  pre-S25 first-stamp-only case would have passed it).

#### C5 worked example - the transform on real bytes, and a subdirectory launch traced to the log
- **Worked example:** (1/2) `Convert-CommandToSkill` on two real command files. Input frontmatter of
  `global\commands\build.md`:
  ```
  ---
  description: Orchestrate dev -> qa per task, grade + hygiene per story; close-out is scripted. Gated on DESIGN LOCKED.
  argument-hint: [scope; empty = next ready task]
  ---
  ```
  Output frontmatter of `<skills-root>\build\SKILL.md` (body unchanged byte-for-byte):
  ```
  ---
  description: 'Orchestrate dev -> qa per task, grade + hygiene per story; close-out is scripted. Gated on DESIGN LOCKED.'
  argument-hint: '[scope; empty = next ready task]'
  ---
  ```
  Raw, the input fails with `argument-hint must be a string` (`[...]` is a YAML list); quoted, it is a
  string. `global\commands\corpus.md` (`description: Set a knowledge corpus's directive and run ...`) becomes
  `description: 'Set a knowledge corpus''s directive and run ...'` - the embedded `'` doubled - and its
  `argument-hint: <corpus-name> [-env <env>]   (empty = list corpora and pick one)` becomes
  `argument-hint: '<corpus-name> [-env <env>]   (empty = list corpora and pick one)'`. qa's first unit test is
  exactly these two input -> output pairs.
- (2/2) A Copilot session launched in `D:\projects\demo\src`, where `D:\projects\demo` holds `docs\` and
  `grades\`:
  1. `PreToolUse` stdin = `{"hook_event_name":"PreToolUse","session_id":"1d0ab973-d259-4a6f-bc5e-6188c753ac5b","cwd":"D:\\projects\\demo\\src","tool_name":"Bash",...}`.
  2. The loop guard decodes `cwd` = `D:\projects\demo\src`, walks up, and resolves the project
     `D:\projects\demo` (the nearest ancestor with `docs\` or `grades\`).
  3. Its log line lands in `D:\projects\demo\grades\gates-log.jsonl`.
  4. The model runs `cd ..\..\other`; the next `PreToolUse` still says `"cwd":"D:\\projects\\demo\\src"`, so
     that call is logged to `demo` as well.
  Counter-example that MUST NOT ship: a writer taking `cwd` as the root writes
  `D:\projects\demo\src\grades\gates-log.jsonl` - a log nobody queries, while `demo`'s real log looks clean.
- **Invariant(s):** (i) no parity story relies on a C5e item, and none is sharded ahead of the consented
  measurement its C5a/C5b gate names; (ii) skills are GENERATED
  from `global\commands\` and agents are served from `global\agents\` - never a second hand-edited copy
  (R39b); (iii) hook registration stays exactly C2's - user level, PascalCase, once per event - and the kit
  never writes `.github/hooks/`; (iv) every reader of payload `cwd` resolves the project by walking up and
  never assumes `cwd` follows the session; (v) whatever parity installs, `uninstall.ps1` removes, testable
  against a sandbox (R39c / R37e).
- **Out of scope:** the RESULTS of the two consented measurements C5a and C5b gate on (they are amended in
  via `/design` when run); the kit setting `COPILOT_ALLOW_ALL` (never - C5a); the camelCase hook family; reading Copilot's `events.jsonl`;
  `--additional-mcp-config`; other Copilot surfaces (see `## Out of scope`); any Copilot version other than
  1.0.89.

### C6: R34 installer mode selection - Cloud is the default, `-Local` is explicit, a no-flag re-run keeps Local/Hybrid
- **Status: DECIDED 2026-10-06 (human; Stories S28/S29); IMPLEMENTED in Story S29 (v0.59.0, commits
  T29.1-T29.9).** `install-mode.ps1` holds `Resolve-InstallMode` (this contract's resolution order, a pure
  function), `install.ps1` calls it before any write, and the test seam `DAD_INSTALL_SANDBOX` lets the suite run
  a real install end to end in a sandbox profile. `-CopilotCli` combined with each mode, and the `-Local -Cloud`
  conflict, are tested through the real installer in a sandbox (Story S33, v0.59.3; Copilot CLI itself remains a
  pilot, so those cases test only what the installer writes). Nothing below is open except the exact banner
  wording.
- **Switches:** `-Cloud`, `-Local`, `-Hybrid` (plus the unchanged `-CopilotCli` and `-Yes`). `-Cloud` with
  `-Hybrid` behaves as today (the cloud loop plus the GPU tools; Hybrid wins the label). `-Local` combined with
  `-Cloud` or `-Hybrid` is a CONFLICT: the installer prints which two switches conflict and exits non-zero
  BEFORE it writes or copies anything.
- **Resolution, in this order:**
  1. An explicit flag wins: `-Hybrid` -> Hybrid, `-Cloud` -> Cloud, `-Local` -> Local.
  2. No flag: read the existing `%USERPROFILE%\.claude\settings.json` `env` block, BEFORE step 1 changes
     anything. `ANTHROPIC_BASE_URL` present -> **Local** (keep). Else `LOCALTOOLS_HYBRID` equal to `1` ->
     **Hybrid** (keep). Anything else - no file, an empty `env`, a Cloud install - -> **Cloud**.
  3. A `settings.json` that cannot be parsed counts as "nothing to keep": Cloud, with a WARN naming the file
     (the existing `settings.json.bak` step still runs).
  These are the SAME tells R34 already uses (the base-URL's presence, `LOCALTOOLS_HYBRID`); no marker file is
  added, so `dad-doctor`, `use-model` and `uninstall` need no new reader.
- **The banner says why.** Step 7's `MODE` line names the mode AND its reason, one of: `default (no flag, nothing
  installed to keep)`, `kept from the existing install (pass -Cloud to switch)`, `explicit flag`.
- **Prerequisites follow the RESOLVED mode:** Ollama, a pulled model and the step-8 GPU tuning are required for
  Local and Hybrid exactly as today; Cloud keeps Ollama optional, with the loud embed/vision verification (R34a).
- **Worked examples** (every row's `settings.json` is the machine's state BEFORE the run):

  | # | Machine state | Command | Result |
  |---|---|---|---|
  | 1 | no `settings.json` | `install.cmd` | **Cloud**, reason `default` |
  | 2 | `ANTHROPIC_BASE_URL=http://localhost:11434` | `install.cmd` | **Local**, reason `kept` |
  | 3 | no base-URL, `LOCALTOOLS_HYBRID=1` | `install.cmd` | **Hybrid**, reason `kept` |
  | 4 | Local (as row 2) | `install.cmd -Cloud` | **Cloud**; base-URL dropped; old file saved as `.bak` |
  | 5 | no `settings.json` | `install.cmd -Local` | **Local**, reason `explicit flag` |
  | 6 | any | `install.cmd -Local -Hybrid` | exit non-zero, message names `-Local` and `-Hybrid`, NOTHING written |
  | 7 | Cloud (no base-URL, no hybrid flag) | `install.cmd` | **Cloud**, reason `default` |

  Counter-example that MUST NOT ship: row 1 installing Local (today's behavior), or row 2 silently becoming
  Cloud because the user re-ran `install.cmd` without a flag.
- **Invariant(s):** (i) an explicit flag always wins; (ii) a no-flag run never changes an installed Local or
  Hybrid mode; (iii) the conflict check runs before any write; (iv) every reader of the mode uses R34's existing
  tells; (v) tests exercise a SANDBOX profile and never the real `%USERPROFILE%\.claude` (R35b);
  (vi) `dad-doctor` fix hints that say "re-run install.cmd (or install.cmd -Cloud)" name the intended switch
  (`-Local`, `-Cloud` or `-Hybrid`) instead.
- **Out of scope:** removing Local, renaming models or aliases, changing `-CopilotCli`, a separate `dad mode`
  command, and any change to the gates.

## Components
### local-tools (C# MCP server)
- Behavior: R2. `net8.0`, `RollForward=LatestMajor`. Config via env: `LOCALTOOLS_DOCS_DIR`, `OLLAMA_HOST`,
  `RAG_EMBED_MODEL`, `LOCALTOOLS_AUTO_REINDEX`.
- Acceptance: builds 0 errors; stdio `initialize` + `tools/list` returns the 8 tools; `--reindex` exits 0.

### Installer (install.ps1 / install.cmd)
- Behavior: R8. Sets paths deterministically; safe to re-run; works wherever the folder lives.
- Acceptance: after a run, `%USERPROFILE%\.claude` has `commands\`, `agents\`, and `settings.json` whose
  the `.mcp.json` `command` points at the real install location.

### Modes + agents (global\commands, global\agents)
- Behavior: R5/R6. The design doc's `Status:` header gates which modes may edit (DRAFT) vs implement (LOCKED).

### Templates / stack profiles (templates\)
- Behavior: R7. `new-project.ps1` scaffolds the generic, stack-agnostic base; `/design` applies a stack
  **profile** late. `_common\` holds the shared `.mcp.json` + the `DESIGN.md`/`TEDD.md` design-doc templates.

## Acceptance / validation gate (how we know it works)
- [x] T1: `dotnet build local-tools\local-tools.csproj -c Release` -> 0 errors.
- [x] T2: `settings.json` + all `.mcp.json` parse as JSON.
- [x] T3: all `*.ps1` parse (PS AST); all `*.ps1`/`*.cmd` are ASCII-only.
- [x] T4: `local-tools.exe` handshake returns the 8 tools; `--reindex <empty>` exits 0.
- [x] T5: `install.ps1` rewrites config paths to the install location (idempotent, move-safe).

## Conventions
See `CLAUDE.md` -> "Conventions": ASCII scripts; preserve the dev-path placeholder; no-BOM JSON; a `-cc`
models declared in `models.json` (never hand-written Modelfiles); re-run `install.cmd` after changing
commands/agents/server; one C# MCP server only.

## Stories
See `docs/STORIES.md` for the story backlog (managed by `/stories`). Deliberately NO count or status
summary here: this line used to read "S1-S3, all DONE as of this migration" and was still saying it at
twelve stories, because a hand-written count is only true on the day it is typed. A count is a fact a
script can settle, so `dad doc-stats` settles it (R24) and this line points instead of counting.
This design doc previously embedded the story backlog inline; it now lives in the split-out doc per R7.

## Out of scope
- WSL2 / Linux / macOS ports (Windows-native by design).
- Local-only as the goal. It was the naive starting point; Cloud is the default and Local is a resilience mode
  for a disconnected afternoon (R34, C6). (This bullet used to say "Cloud models as the DEFAULT" was out of
  scope - reversed 2026-10-06, Story S28.)
- Additional Node/Python MCP servers (the single C# server is the design).
- **Handling security - FOUNDATIONAL, permanently out of scope (confirmed by the human 2026-10-01).** The kit
  never authenticates, authorizes, stores, reads, brokers or rotates a credential or a user identity. Auth
  that exists in the loop belongs to something else - a harness's own login (Claude Code, Copilot CLI), a
  cloud provider's key held in the harness's settings (R34), the dummy local-Ollama token - and the kit at
  most passes it through untouched. What the kit DOES ship is hygiene, not handling: the secret scanner
  (`scan-secrets.ps1`) and the by-NAME-only rule keep credentials OUT of the repo and the index. This is why
  `Security review:` is NOT-REQUIRED as a standing fact rather than a waiver to re-argue each release: the
  auth/token/session words doc-stats finds here are LLM token counts (R38c/C4a), harness session ids
  (C3b/C4b, C5), harness logins and the scanner's own detection patterns. A future requirement that would
  make the kit itself handle a credential is not a REQUIRED review - it contradicts this design and needs a
  human decision to change the kit's foundation first.
- Other Copilot surfaces as harness targets - VS Code Copilot Chat, the Agents View, the cloud coding agent.
  R37 covers Copilot CLI only. VS Code Copilot Chat is deliberately deferred and NOT measured: it is the
  surface carrying the live upstream casing defect (microsoft/vscode#335244, camelCase `subagentStart`
  silently ignored), and R37(c) forbids supporting a harness on unmeasured assumptions.

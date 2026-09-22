# Technical Design Document - DrDad (Design Research Document, Agentic Development)

Status: LOCKED
Security review: NOT-REQUIRED (local-only dev CLI; no auth, no user data stored, no exposed service)
<!-- This describes the kit AS IT SHOULD WORK; implement/maintain it via /spec or /build.
     Flip to DRAFT (and use /design or /proto) only to change the design itself. -->

## Goal
Run the real Claude Code agentic loop **fully offline** on Windows + an NVIDIA GPU, driven by local
Ollama models, with a single C# MCP server for document RAG, per-project corpora, a design/proto/spec/build
mode system, and one-command model switching. No Anthropic account; offline after first setup. Offline is the
DEFAULT and the thesis; the same loop can opt into a cloud or hybrid backend (R34) for delivery or to clear a
local-model ceiling, but every command, agent, and gate is identical across all three.

## Requirements
- [x] R1: Point Claude Code at local Ollama via `settings.json` `env` (`ANTHROPIC_BASE_URL=http://localhost:11434`,
      dummy `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_MODEL`) to skip the login screen, plus offline flags
      (telemetry/autoupdater off). apiKeyHelper is deliberately NOT set - having both caused a per-session
      Claude Code auth warning; the token alone suffices (apikey.cmd kept only as a fallback).
- [x] R34: **Three backend modes, one loop - and the GPU is never idle.** Offline-first (R1) is the DEFAULT
      and the thesis; two opt-in alternate backends share every command, agent, and gate - only where the
      AGENT LOOP runs changes:
      (a) **Local** (`install.ps1`): R1 - Claude Code -> Ollama; the whole loop on the GPU.
      (b) **Cloud** (`install.ps1 -Cloud`): the `ANTHROPIC_BASE_URL` redirect is DROPPED, so Claude Code uses
          its normal Anthropic auth; aliases resolve to each model's `cloud` id in `models.json`
          (dev/coder/oss/gemma -> Sonnet, fast -> Haiku, quality -> Opus). The ABSENCE of the base-URL is the
          mode tell - `use-model` and `dad-doctor` read it back; no marker file. **The GPU is NOT idle in cloud
          mode:** `local-tools` reaches Ollama independent of the agent loop, so semantic RAG and
          `describe_image` still run on it - and cloud install VERIFIES the embed/vision models are pulled, so a
          literal-scan degrade is LOUD, not silent.
      (c) **Hybrid** (`install.ps1 -Hybrid`): the cloud agent loop of (b) PLUS the GPU offered to the cloud
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
      list at all, and the weak local model cannot be handed a job the mode exists to keep on the cloud brain.
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
      claimed-missing contract by grep (the same run called C2PA signing absent when it is `C10-b`). The
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
      15 of 16 tests did not survive the rewrite (including the C9 worked example, the level-2 conformance
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
      the 15 apparently-deleted tests had been relocated to another file, including the C9 worked example
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
- [ ] R36: **Planning cost is priced and ratcheted, not unlimited.** Measured (ModelTest bake-off,
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

## Contracts (pin BEFORE locking - architect-agent writes these)
### C1: R36 planning-cost ratchet - thresholds, pricing message shape, worked examples
- **Status: APPROVED 2026-09-22.** R36 names two mechanisms as one loop (SCOPE -> PRICE -> ASK ->
  WALK/WARN -> BUILD -> ANALYZE -> repeat). The human picked **Option B** for C1a and approved C1b/C1c/C1d
  as written - nothing below is still open. Not yet implemented (`doc-stats.ps1`, `scribe-agent.md`, and
  `/design`/`/stories`' prompts are unchanged by this pass); that is `/taskmap` or `/build` work from here.

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
  gate, and the human's "keep scoping" answer must stay honored). Which exact threshold numbers (15/0.15
  for B, or C's 20/5x) ship is also open pending the human's C1a pick - the numbers above are the
  recommendation's starting point, not a promise they are final; `doc-stats.ps1` should keep them as named
  constants near the top of the `[ratchet]` block so they are easy to retune from one false-positive/
  false-negative report, the same way other WARN thresholds in this file already are (e.g. the `>= 5`
  uncommitted-done threshold at `doc-stats.ps1:595`).

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
See `docs/STORIES.md` for the story backlog (S1-S3, all DONE as of this migration; managed by /stories).
This design doc previously embedded the story backlog inline; it now lives in the split-out doc per R7.

## Out of scope
- WSL2 / Linux / macOS ports (Windows-native by design).
- Cloud models as the DEFAULT. Offline-first is the default and the thesis; cloud and hybrid are opt-in
  alternate backends (R34), used for delivery or to clear a local-model ceiling, never the out-of-the-box path.
- Additional Node/Python MCP servers (the single C# server is the design).

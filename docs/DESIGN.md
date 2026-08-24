# Technical Design Document - DAD (Design Document Aligned Development)

Status: LOCKED
<!-- This describes the kit AS IT SHOULD WORK; implement/maintain it via /spec or /build.
     Flip to DRAFT (and use /design or /proto) only to change the design itself. -->

## Goal
Run the real Claude Code agentic loop **fully offline** on Windows + an NVIDIA GPU, driven by local
Ollama models, with a single C# MCP server for document RAG, per-project corpora, a design/proto/spec/build
mode system, and one-command model switching. No Anthropic account; offline after first setup.

## Requirements
- [x] R1: Point Claude Code at local Ollama via `settings.json` `env` (`ANTHROPIC_BASE_URL=http://localhost:11434`,
      dummy `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_MODEL`) to skip the login screen, plus offline flags
      (telemetry/autoupdater off). apiKeyHelper is deliberately NOT set - having both caused a per-session
      Claude Code auth warning; the token alone suffices (apikey.cmd kept only as a fallback).
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
      <file>` = git triage for a mangled file).
- [x] R6: Agent team installed globally: `requirements-agent`, `architect-agent`, `taskmap-agent`, `dev-agent`,
      `grade-agent`, `qa-agent`, `doc-researcher`, `hygiene-agent`, `scribe-agent`, `librarian-agent` (read-only cross-doc
      auditor: schema/traceability/state-consistency/grade-card presence; findings tagged by owner and
      routed by the orchestrator; git RECOVER triage). `scribe-agent` manages STORIES.md (expand
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
      Therefore `/stories` and `/taskmap` - the two commands that ITERATE over many items, which is where a
      spiral has room to grow - now do their work in the main loop, one unit at a time, running
      `doc-stats -Findings` after each. Delegation is kept only for genuinely ONE-SHOT, human-approved
      steps that have never looped: contracts (`architect-agent`), the security review, a single grade card,
      one brownfield description, one research pass. The rule generalises: **if a step needs a gate, it
      cannot run where the gates do not reach.**
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
      later. FAILS OPEN on anything unexpected (not a DAD project, no git, docs-only edits, its own
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

## Stories (backlog - implement with /build, model: dev/Devstral)
<!-- These are TODO. The R1-R10 above are already done ([x]); build these next, one at a time. -->

### Story S1: Safe uninstall (uninstall.ps1 + uninstall.cmd)   <!-- Status: DONE -->
<!-- Implemented: uninstall.ps1 + uninstall.cmd. AC3 verified (parses + ASCII); AC1/AC2/AC4 are behavioral - confirm on first run. -->>
- **Goal:** A teardown that reverses what install.ps1 did, with an optional `-Full` for models/env.
- **Context (what install.ps1 does - reverse exactly this):**
  - Copies `global\commands\*.md` -> `%USERPROFILE%\.claude\commands\` (scaffold, design, taskmap, proto, spec, build, assets, tidy, stories, diagram, audit, grade).
  - Copies `global\agents\*.md`  -> `%USERPROFILE%\.claude\agents\` (requirements-agent, architect-agent, taskmap-agent, dev-agent, grade-agent, qa-agent, doc-researcher, hygiene-agent, scribe-agent, librarian-agent).
  - Writes `%USERPROFILE%\.claude\settings.json`, backing up any prior to `settings.json.bak`.
  - Tuning sets User env vars: `OLLAMA_FLASH_ATTENTION`, `OLLAMA_KV_CACHE_TYPE`, `OLLAMA_KEEP_ALIVE`.
  - Builds Ollama variants: `devstral-cc`, `gemma4-cc`, `qwen3-14b-cc`, `qwen3-coder-next-cc`.
- **Behavior:**
  - Default: remove ONLY the kit's 6 command files + 4 agent files by name (do NOT delete the folders or
    other files). Restore `settings.json` from `settings.json.bak` if present; else warn and leave it.
  - `-Full`: also `ollama rm` the 4 `-cc` variants and remove the 3 `OLLAMA_*` User env vars.
  - NEVER touch the kit folder, npm `@anthropic-ai/claude-code`, or the VS Code extension - print that those are manual.
  - `uninstall.cmd` = launcher mirroring `install.cmd` (`powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" %*`, then `pause`).
- **Data / interfaces:** `param([switch]$Full)`. Reuse install.ps1's `Have` helper pattern; keep the command/agent name lists in sync with install.ps1.
- **Dependencies:** mirrors install.ps1's file lists + tuning vars.
- **Acceptance (testable):**
  - [ ] AC1: after `uninstall.ps1`, the 6 command + 4 agent files are gone from `~/.claude` and `settings.json` matches the restored `.bak`.
  - [ ] AC2: `-Full` also removes the 4 model variants (`ollama list` no longer shows them) and the 3 `OLLAMA_*` env vars.
  - [ ] AC3: `uninstall.ps1` parses (PS AST) and `uninstall.ps1`/`.cmd` are ASCII-only.
  - [ ] AC4: it does NOT delete the kit folder, npm package, or extension.
- **Dev notes:** ASCII-only (PS 5.1). Add `uninstall.ps1`/`.cmd` to the README files table + this DESIGN.md;
  add "uninstall.ps1 parses + ASCII" to the validation gate. Do a dry run first (print what would be removed).

### Story S2: Steer web tools to local-tools (CLAUDE.md convention)   <!-- Status: DONE -->
<!-- Implemented: "## Web / grounding" line added to all 5 type templates (dotnet/python/embedded/generic/unity) + avalonia. -->>
- **Goal:** Make every project prefer the working local web tools over the inert built-ins.
- **Context:** Claude Code's built-in WebSearch is Anthropic-server-side - pointed at Ollama it has no backend
  and won't run; WebFetch is likewise Anthropic-oriented. The working tools are local-tools' `web_search`
  (keyless DuckDuckGo) and `ingest_url` (fetch + fold into the RAG). The model chooses the tool, so without
  guidance it may fumble toward a dead built-in.
- **Behavior:** Add this one-line convention to each project-type CLAUDE.md (identical wording):
  > Web search / URL lookup: use the `local-tools` `web_search` / `ingest_url` tools, NOT the built-in
  > WebSearch/WebFetch (those need Anthropic and don't work against local Ollama). For grounding, `web_search`
  > to find, then `ingest_url` to fetch + persist into the RAG.
- **Data / interfaces:** Edit the 5 template CLAUDE.md files: `templates\dotnet`, `python`, `embedded`,
  `generic`, `unity`. Put the line under each file's "Working agreement" section.
- **Dependencies:** none.
- **Acceptance (testable):**
  - [ ] AC1: all 5 template CLAUDE.md files contain the web-tools convention line.
  - [ ] AC2: the line names `web_search` + `ingest_url` and says NOT to use built-in WebSearch/WebFetch.
  - [ ] AC3: the validation gate still passes (markdown only; no broken sections).
- **Dev notes:** Markdown only (no scripts). Optionally add the same note to the README's web section.

### Story S3: Avalonia project template (templates\avalonia)   <!-- Status: DONE -->
<!-- Implemented: templates\avalonia\CLAUDE.md + Types row in templates\README.md + /scaffold example. AC4 (manual /scaffold avalonia) confirm on the 5080. -->>
- **Goal:** Add an `avalonia` project type so `/scaffold avalonia` sets up a cross-platform .NET XAML desktop app.
- **Context:**
  - Templates live in `templates\<type>\`, each with a `CLAUDE.md`; non-Unity types also use
    `templates\_common\.mcp.json` + `templates\_common\docs\DESIGN.md`. `/scaffold` **auto-lists** the
    subfolders of `templates\` (skipping `_common`), so simply ADDING `templates\avalonia\CLAUDE.md`
    makes `/scaffold avalonia` appear - no change to `scaffold.md` needed.
  - Avalonia = cross-platform .NET XAML UI framework (WPF-like), MVVM. Confirmed tooling (re-verify current
    via `web_search` / docs.avaloniaui.net):
    - scaffold an app: `dotnet new install Avalonia.Templates` then `dotnet new avalonia.mvvm -o <name>` (uses CommunityToolkit.Mvvm).
    - build/test/run: `dotnet build` / `dotnet test` / `dotnet run`. Plain VM/service tests need no Avalonia
      setup (xUnit/NUnit); control-level UI tests use `Avalonia.Headless.XUnit` (or `.NUnit`) with the
      `[AvaloniaTestApplication]` attribute.
  - It's C#/.NET (Devstral's lane) but has a VISUAL component - like Unity-lite, look/feel needs human eyes.
- **Behavior:** Create `templates\avalonia\CLAUDE.md` modeled on `templates\dotnet\CLAUDE.md` (same sections +
  the standard Modes block), Avalonia-flavored:
  - **Stack:** C# / .NET, Avalonia 11 (XAML), MVVM via CommunityToolkit.Mvvm.
  - **Design doc:** `docs/DESIGN.md` (uses `_common`).
  - **Placeholder convention:** MVVM - ViewModels with in-memory/mock data behind interfaces; design-time
    data for XAML previews; stub services; `// TODO` markers.
  - **Build / test / run:** `dotnet build` / `dotnet test` (control tests via `Avalonia.Headless.XUnit` +
    `[AvaloniaTestApplication]`) / `dotnet run` to view the UI.
  - **Human-in-loop (visual):** implement + write headless/logic tests, then hand me a "run `dotnet run` and
    check" + Visual Inspection checklist - I'm the eyes for look/feel.
  - Same Modes block + Working agreement as the other templates.
- **Data / interfaces:** new file `templates\avalonia\CLAUDE.md`; add an `avalonia` row to the Types table in `templates\README.md`.
- **Dependencies:** none (uses existing `_common`).
- **Acceptance (testable):**
  - [ ] AC1: `templates\avalonia\CLAUDE.md` exists with the Modes block + dotnet build/test/run + MVVM placeholder + visual human-in-loop.
  - [ ] AC2: `templates\README.md` Types table lists `avalonia`.
  - [ ] AC3: files are ASCII; the validation gate still passes.
  - [ ] AC4: (manual) `/scaffold avalonia` appears in the menu and scaffolds a project.
- **Dev notes:** ASCII only. Mirror the structure/wording of `templates\dotnet\CLAUDE.md`. Re-confirm current
  Avalonia template/test package names via `web_search` / docs.avaloniaui.net before finalizing.

## Out of scope
- WSL2 / Linux / macOS ports (Windows-native by design).
- Cloud models (offline-first).
- Additional Node/Python MCP servers (the single C# server is the design).

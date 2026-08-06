# Changelog

All notable changes to AD-kit. Versions follow semver; the requirement ids (R1-R21) are in `docs/DESIGN.md`.

## 0.10.0 - 2026-08-06

The first gate in this kit the model cannot skip.

A graded run (mediamotor_iiif, run002) produced **7,115 lines, 106 file edits, and ZERO shell calls**.
No build, no test, no `close-unit`, no commit - it wrote code, wrote tests for the code, then reasoned
in prose about whether those tests would pass, and ended with 47 dirty files. Nobody knew until the
transcript was read. The lesson from 0.9.x was "mechanical gates beat prose". This is the sequel:
**a gate the model has to choose to invoke is still prose.** `close-unit.ps1` verifies build, tests and
grade perfectly - if something calls it. Nothing did.

### Added
- **`ad-guard.ps1` / `.cmd` - the stop guard, wired by `install.ps1` as a Claude Code `Stop` hook.**
  The harness runs it at end of turn whatever the model decided, so it is the first gate that does not
  depend on the model's cooperation. Blocks the stop when uncommitted **code** files exist with no
  `.claude/.ad-verified` stamp newer than the newest edit, and names the three ways out: run
  `close-unit`, run the real build/test, or `ad-guard.cmd -Ack`. `close-unit.ps1` writes that stamp on a
  clean close, so a properly closed unit clears the guard by itself.
  - **A nag with teeth, not a wall.** The harness sets `stop_hook_active` on the retry pass and the guard
    allows it, so a broken model can still stop after being told and you can never be deadlocked. What it
    guarantees is that the failure is LOUD.
  - **Fails open** on everything unexpected: not an AD project, no git, docs-only edits, git missing, its
    own errors. A guard that blocks on its own bugs would be worse than the problem it solves.
  - Docs, grades, `.claude/` and `bin`/`obj` are excluded - blocking on a `STATUS.md` edit would train
    everyone to ignore it.
- New requirement **R22** in `docs/DESIGN.md`.

### Changed
- **`/build` STOPS on a DRAFT design** instead of silently continuing "in PROTO mode" - which is what the
  failing run did before making 106 blind edits against an unfinished contract. R7 always said `/build`
  gates on LOCKED; the command now obeys it. Use `/proto` for greybox work.
- **`/build` proves the shell works before its first edit** by running `doc-stats.ps1` (Gate 3), and stops
  if it cannot. A `/build` that cannot reach a shell can only produce unverified code, and it will produce
  a great deal of it before anyone notices.
- **`grade-agent` has a search budget** (~25 calls) and may not repeat a query. One invocation burned
  1015+ identical `Search(pattern: "src/.../**/*")` calls before it was killed by hand.
- **`ad-doctor`** checks the Stop hook is wired and un-placeholdered, checks `dotnet`/`git` are permitted
  alongside `powershell`, reports whether a project currently has unverified code, and flags a project
  whose `.claude/settings.local.json` has accreted one-off `Bash(...)` approvals - the fingerprint of a
  session that spent its time answering permission prompts and then stopped using the shell. The failing
  run's project had ten, including `Bash(xargs cat)` and `Bash(</)`, and no `dotnet` or `git`.
- **`uninstall.ps1`** strips the Stop hook when there is no `.bak` to restore, so it cannot be left
  pointing at a deleted script and firing on every turn.

### Fixed
- `install.ps1` did not rewrite the dev-path placeholder in `settings.json` - which the new hook command
  lives in. It now does, **via the parsed object**: JSON escapes backslashes, so the on-disk form is
  `C:\\Projects\\...` and a raw-text replace of `C:\Projects\...` silently matches nothing. (The same trap
  install.ps1's own comment warns about for `.mcp.json`. I shipped it anyway; the test caught it.)
- Stale `use-model.cmd dev / plan / ...` line in the installer's closing output.

### Tests
64 cases (was 60), new `-- stop guard --` section: the guard blocks unverified code and clears after
`close-unit`; a fresh edit re-arms it; `-Ack` releases it; docs-only edits never block; it fails open on
non-AD/no-git/missing directories; and it allows its own retry pass, which is the difference between a
guard and a deadlock.
## 0.9.9 - 2026-08-05

The fit math stops lying. `approxVramGb` was always weights-only, so three models advertised as
"fits 16 GB" actually spill once the 64K KV cache is allocated. And the planner is now `oss`.

### Changed
- **`plan` alias retired -> `oss` is THE planner** (`/design`, `/stories`, `/audit`). gpt-oss-20b is MoE
  (~A3.6B active), the most literal instruction-follower of the wired set, and cheaper to run than the
  dense alternative. Gemma 4 stays available as the optional dense generalist under the new alias
  **`gemma`**, honestly labelled: dense AND over the budget at 64K, so it partially offloads.
- **VRAM fit accounts for the KV cache.** `models.json` gained `assumeVramGb` (16) and `kvCacheGbAt64k`
  (3, at `OLLAMA_KV_CACHE_TYPE=q8_0`); a per-model `kvGb` overrides it if you measure a real one.
  `sync-models.ps1 -Report` replaced the `Fits16` column with `Weights` / `PlusKV` / `Fit`, and
  `ad-doctor` computes the same figure. Three states, not two:
  | state | rule | means |
  |---|---|---|
  | `fits GPU` | weights+kv+1.5 <= budget | GPU-resident, full speed |
  | `BORDERLINE` | weights+kv <= budget+1 | usually runs; expect partial offload, variable speed |
  | `offloads` | above that | spills to RAM by design (fine for MoE, slow for dense) |
  `ad-doctor` now emits a **WARN** on BORDERLINE with the fix (lower `numCtx` to 32768) instead of
  silently claiming a fit. Under this math `dev` and `oss` are BORDERLINE at 64K, not comfortable.

### Fixed
- README's version banner said **0.9.0** for eight releases. Now asserted against `VERSION` by a test.
- `CHEATSHEET.md` still routed planning to Gemma in three places, and one line read "/design design"
  (a leftover from the `/forge` rename). README's file table still named the retired `docs/COMMANDS.md`.

### Tests
60 cases (was 59): README-banner-matches-VERSION, plus `models.json` must carry `assumeVramGb` +
`kvCacheGbAt64k` and must not re-introduce a `plan` alias.
## 0.9.8 - 2026-08-05

Cosmetic but load-bearing: the pipeline now reads as what it does, with no glossary.
`/scaffold -> /design -> /stories -> /taskmap -> /build`

### Changed
- **Commands renamed** (all four were private metaphors; a model that half-remembers a metaphor guesses):
  | old | new |
  |---|---|
  | `/forge` | `/design` |
  | `/scribe` | `/stories` |
  | `/blueprint` | `/taskmap` |
  | `/librarian` | `/audit` |
  `/blueprint` existed only because `/tasks` is a Claude Code built-in; `/taskmap` is free and says what it
  is. All four new names verified free of built-in and BMAD collisions.
- **`planner-agent` -> `taskmap-agent`** - "architect" vs "planner" did not distinguish contract-pinning
  from task-sharding. Agent names that describe a ROLE well are kept: `scribe-agent` (writes STORIES) and
  `librarian-agent` (audits the doc set) stay, because the command is the verb and the agent is the actor.
- Audit owner tags follow: `[forge]` -> `[design]`, `[blueprint]` -> `[taskmap]`.

### Added
- **`install.ps1` deletes RETIRED names** from `~/.claude` before installing (`forge`, `scribe`,
  `blueprint`, `librarian`, `plan`, `planner-agent`), so upgrading does not leave the old command
  installed beside the new one for a model to invoke. No uninstall-first dance needed.
- **`.cmd` wrappers for every `.ps1`** - added `close-unit.cmd`, `doc-stats.cmd`, `install-hooks.cmd`,
  `ollama-tuning.cmd`. Commands/agents still invoke the `.ps1` via `powershell` (that is what the
  permission allow list covers); the wrappers are for running them by hand.
- Three drift tests: the install echo must match the real command list, no retired name may still ship,
  and every `.ps1` must have a `.cmd`.

## 0.9.7 - 2026-07-30

Closes the verification gap end to end: a story can no longer be closed unless the code builds, real tests
ran, and a real grade card exists.

### Added
- **`close-unit.ps1` verifies TESTS at story close.** It works out BEFORE mutating anything whether this
  close completes a story (last open task of that story, or a story id directly); if so it runs CLAUDE.md's
  `Test:` command and refuses on failure, on **zero tests**, or when it can find **no evidence any test ran**.
  "Build succeeded" with no test count is exactly the mediamotor no-op and is now a hard stop.
- **`doc-stats.ps1` reports ORPHAN TEST PROJECTS** - test `.csproj` files on disk that are absent from the
  `.sln`, the cause of that silent no-op. Verified against the real project: finds exactly its 6 orphans.
- **`/forge` ingests library API docs at design time.** For every third-party library the architecture
  commits to, it `web_search` + `ingest_url` the API reference into the corpus and records what it ingested.
  A dev-agent that cannot find a signature invents one (16 guessed Magick.NET calls); putting the real docs
  in the RAG at design time is the only reliable fix.

### Changed
- **`docs/COMMANDS.md` -> `docs/RECIPES.md`** (section: "Proven recipes"). "COMMANDS" collided
  conceptually with the kit's slash commands, so "check COMMANDS.md" was misreadable. `upgrade-project`
  migrates the old file and preserves its accumulated entries.

## 0.9.6 - 2026-07-30

A consistency audit of every command/agent file. Finding: instruction VOLUME is not the problem (~2% of a
64K window); the problems are contradictions between files and rules still enforced by prose.

### Fixed
- **The always-loaded project `CLAUDE.md` described the OLD `/build` order** ("requirements -> dev -> grade
  -> hygiene -> qa"). Every session read that first, then read `build.md` saying something different, and had
  to arbitrate. It now states the real order: per TASK dev -> qa -> close-unit; per STORY grade -> hygiene.
- **CHEATSHEET listed `generic` as a stack profile.** It is the always-installed base, not a profile - the
  profiles are `templates/<stack>/PROFILE.md` for dotnet|avalonia|python|embedded|unity.

### Added
- **`close-unit.ps1 -RequireGrade`** - the last soft gate is now mechanical. Closing a STORY with no grade
  card, a stub under 800 bytes, or no `## Grade history` FAILS. At task level it only warns (the card is
  written after roll-up, per /build's order). `/build` step 7 and `/grade` both pass `-RequireGrade`, so a
  story can no longer be closed ungraded - grading was the step that kept getting skipped.

## 0.9.5 - 2026-07-30

The mediamotor_iiif build results exposed the worst failure yet: **5 stories marked DONE, 6 tasks ticked and
4 checkpoint commits over a build failing with 21 errors and ZERO tests ever run** (all six test projects
existed on disk but none were in the .sln, so `dotnet test` was a silent no-op). The bookkeeping was
perfect; it was bookkeeping over unverified work, which is worse than none.

### Fixed
- **`close-unit.ps1` now VERIFIES THE BUILD before it ticks anything.** It reads the `Build:` command from
  CLAUDE.md (or `-BuildCommand`), runs it in a CHILD shell, and on failure prints the last 15 lines and
  exits non-zero having changed NOTHING - no tick, no roll-up, no commit. `-SkipVerify` overrides, with a
  warning that "done" then means nothing. If no build command is discoverable it warns loudly and proceeds.
- **qa-agent: a run that discovers ZERO tests is a FAIL**, not a pass - no test count, or "Build succeeded"
  with no results, means nothing was verified. It is also forbidden from writing its own test-report file
  (TEST_RESULTS.md / TEST_SUMMARY.md / *_RESULT.md were fabricated "all pass" summaries).
- **hygiene-agent: every test project on disk must be IN the solution.** Six orphaned test projects are what
  made every "tests pass" claim meaningless.
- **dev-agent: never invent a third-party API signature.** 16 of the 21 errors were guessed Magick.NET calls
  (a `ResizeStrategy` type that does not exist, `Crop` with the wrong arity, `int` where `ushort`/
  `Percentage` was required). Rule: `search_datasheets`, else `web_search` + `ingest_url` the official API
  docs into the corpus, else STOP - and build before reporting.
- **dotnet profile:** test projects must be in the .sln, plus the namespace-shadowing trap - a namespace
  ending in an SDK root name (`MyApp.Storage.Azure`) makes `Azure.ETag` resolve to your own sub-namespace
  (`CS0234`); use `global::Azure.ETag` or do not shadow the SDK root.

## 0.9.4 - 2026-07-30

### Fixed
- **`install.ps1` did not rewrite the dev-path placeholder in AGENT files** (only commands). 0.9.3 gave
  `librarian-agent` an absolute path to `doc-stats.ps1`, so after a folder-copy install it pointed at the
  authoring machine and the counter could not run - the STATUS miscount would have persisted. Agents now get
  the same rewrite as commands, with a test that fails if either folder ships an unrewritten placeholder.

## 0.9.3 - 2026-07-30

Fixes from the mediamotor_iiif run - the first run where `close-unit.ps1` actually executed (the 0.9.1
permission fix is validated) and the architect produced 18 numbered contracts with worked examples.

### Added
- **`/grade <unit>`** - there was NO user-invokable way to write a missing grade card, so a model invented
  `/grade`, a fictional `grade-agent --prompt ... > /dev/null` CLI, and a bash loop over agents. The command
  now exists, grades ONE unit, and gates the result.
- **`doc-stats.ps1`** - deterministic counts for `docs/STATUS.md`. The librarian hand-counted and wrote
  "Stories: 1/1  Tasks: 1/1" for a project with 13 stories (5 done) and 16 tasks (6 done). It must now RUN
  this and use the numbers verbatim; it also lists every DONE unit whose grade card is missing or a stub.

### Fixed
- **grade-agent produced nothing from a batch request** (40 tool uses, 54k tokens, zero files written). It
  now grades EXACTLY ONE unit per invocation and must write-then-verify before reporting - the same
  one-at-a-time rule that fixed /scribe and /blueprint.
- **/librarian handed the user homework instead of routing.** It now must spawn owner agents itself; only
  `[human]` findings come back. Explicitly: never tell the user to run an agent, never invent a CLI for one.
- **/forge did not fill CLAUDE.md** - Stack/Build/test were left as `<decided in /forge...>` placeholders, so
  dev and qa had no build or test command and improvised their own reporting files (TEST_RESULTS.md,
  TEST_SUMMARY.md, VariantProcessorTests_RESULT.md at the repo root). /forge now has a mechanical fill gate,
  and /build greps for the placeholders and REFUSES to start.
- **Scope-contamination check was crying wolf**: naming a class or file a task will create
  (`ResolverService.cs`) is implementation detail, not invented scope. The rule now targets capabilities,
  protocols, integrations and dependencies only.
- **planner-agent used absolute paths** (`D:\projects\...`) in `Touches:`; now repo-relative.
- **librarian regenerated STATUS four times** in one session (~155k tokens); now once per invocation.
- /forge also prompts to pin the toolchain for a clean machine (e.g. `global.json` for .NET).

## 0.9.2 - 2026-07-28

### Changed
- **Stack profiles are now FRAGMENTS** (`templates/<stack>/PROFILE.md`, was `CLAUDE.md`). They had drifted
  badly behind `templates/generic` - old `## Modes` wording, no Secrets, no Task-tool rule - and a file
  named CLAUDE.md that is not a complete CLAUDE.md invites mis-cribbing. Each now carries ONLY what
  `/forge` copies: Stack, Placeholder convention, Build/test, Human-in-loop, hygiene. Tests enforce that
  they contain no kit-owned sections.
- **No toolchain version is pinned in a profile.** `.NET 8` was hardcoded and stale. Profiles now tell the
  model to DETECT the installed toolchain (`dotnet --list-sdks` -> highest major -> `net<major>.0`) and
  record the choice in the design doc. C# version follows the TFM automatically - do not set LangVersion.
  Guidance added on LTS vs newest, and on targeting lower for published libraries. A test fails on any
  version number in a profile.
- **Unity is called out as the exception**: the editor caps the C#/.NET level, so never retarget or set
  LangVersion there.

### Added
- **Project-file hygiene convention** (the `PackageOutputPath` lesson, generalized): never put an absolute
  or machine-specific path in a build file - `PackageOutputPath`, `OutputPath`, `HintPath`, `Import`,
  local NuGet feeds. Use relative paths or `$(MSBuildThisFileDirectory)` / `$(SolutionDir)`. Plus the
  **clean-machine rule**: a fresh clone + the documented SDK must build and test with no manual setup.
- **hygiene-agent now scans for it** across `.csproj/.props/.targets/nuget.config`, `platformio.ini`,
  `CMakeLists.txt`, `pyproject.toml`, `package.json` and reports it `[mechanical]`.
- Test guarding the kit's own `net8.0` + `RollForward=LatestMajor` (deliberate: builds on 8+, runs on any
  8+ runtime, and the TFM is baked into every `.mcp.json` exe path).
- `scan-secrets` skips `_tempReference/` (reference drops, not kit source) but **announces the skip** and
  tells you how to scan it explicitly - a silent skip is how a real credential hides.

## 0.9.1 - 2026-07-28

Fixes found by the first full validation run on real hardware (LeanHash, qwen3-coder-next).

### Fixed
- **`close-unit.ps1` could never run.** `/build` and `/spec` invoke it via `powershell`, which was missing
  from `settings.json`'s permission allow list - so every call hit a permission prompt and was skipped.
  A whole `/build` session produced zero commits and zero ticked tasks because of it. Added
  `Bash(powershell:*)` + `Bash(pwsh:*)`, and a test that fails if any command invokes an executable the
  allow list does not permit.
- **Rubber-stamp grades passed the gate.** 135-byte cards reading "All acceptance criteria met" satisfied
  the old existence check. The gate now requires >=800 bytes plus `## Grade history`, `## Assessment` and
  `## Suggestions`; grade-agent is told a card with no cited `file:line` is a failed grade.
- **Whole-file regeneration let the planner invent a different project** (peer networking, a Prometheus
  endpoint, "[PR #n merged]" in a repo with no remote). `/blueprint` and planner-agent now shard ONE STORY
  AT A TIME, must trace every task to a real story id, may invent nothing absent from DESIGN/STORIES, may
  not claim unverifiable status, and must emit the exact task-block shape `close-unit.ps1` matches.
- **Contracts were unusable**: no worked examples, no `C1..Cn` ids to cite, and one contradicted the design
  doc's own storage layout. architect-agent now numbers contracts, self-checks that every one carries a
  concrete worked example, and must reconcile with (never silently contradict) the design.
- **librarian** now checks scope contamination FIRST - nouns in STORIES/TASKS that trace to nothing in
  DESIGN, and unverifiable claims - and flags stub grade cards.
- **`upgrade-project`** now untracks already-committed `bin/obj/docs/.index` (a `.gitignore` alone does not),
  so checkpoint commits stop carrying build-output noise.

## 0.9.0 - 2026-07-12

First versioned release. Feature-complete and self-tested; held below 1.0 until a full
`/forge -> /blueprint -> /build` run on real hardware is verified end to end.

### Core (R1-R10)
- Claude Code driven by local Ollama models, fully offline after setup (`settings.json` env redirect,
  no Anthropic account).
- One C# MCP server (`local-tools`): document RAG over per-project corpora with markdown-aware,
  heading-based chunking, atomic index writes, and an opt-in staleness refresh.
- Mode commands, a global agent team, one-command install/uninstall, GPU tuning.

### Design pipeline (R7, R11-R16)
- **Stack-agnostic scaffold + late architecture.** `/scaffold <general|experience>` creates the design doc
  as `Status: DRAFT`; the stack is decided late in `/forge`.
- **Layered docs**, each with exactly one writer: `DESIGN.md`/`TEDD.md` (contract, lockable) ->
  `STORIES.md` (`/scribe`) -> `TASKS.md` (`/blueprint`) -> `STATUS.md` (librarian-owned dashboard) plus
  `COMMANDS.md` (proven shell syntax) and `grades/` (report cards).
- **Contract layer** (`architect-agent`, `/forge contracts`): pins data formats, core-function semantics and
  invariants - each with a mandatory **worked example** that qa turns into the first unit test. Gates stop
  `/blueprint` from sharding, and `dev-agent` from implementing, an unpinned contract.
- `/librarian` cross-document audit with owner-tagged findings and git-recovery triage.

### Reliability (R13, R18-R20)
- **Git safety net**: scaffold initializes a repo; every passing unit is a checkpoint; a mangled file is
  restored from git, never hand-reconstructed.
- **Loop cost discipline**: per task only dev + qa run (was 5-8 subagent spawns), bookkeeping is the
  deterministic `close-unit.ps1` (tick, story roll-up, reindex, commit, verify), and grade + hygiene run at
  the story boundary.
- **The kit tests itself**: `test-kit.ps1` (44 cases) + CI on Windows - the validation gate, covering static
  hygiene, inventory/collision consistency, the secret scanner, and fixture runs of scaffold/upgrade/close-unit.
- **Secret hygiene**: `scan-secrets.ps1` (never prints matched values) installed as each project's
  pre-commit hook, standard allowlist markers honored, and a kit-owned `## Secrets` section in project
  CLAUDE.md - because `docs/` becomes a plaintext search index.

### Operations (R21)
- **`models.json`** is the single source of truth for models; `sync-models.ps1` generates the `-cc`
  Modelfiles and builds the variants. Adding a model is one JSON entry.
- **`ad-doctor.ps1`**: read-only readiness check for prerequisites, Ollama + declared models, the server's
  live MCP tool list, the global install, and a project's wiring.
- **`upgrade-project.ps1`**: retrofits an existing project to the current kit, refreshing kit-owned
  CLAUDE.md sections while preserving your Stack/Build/test.

### Sensors (R17)
- Images in `docs/` are captioned and audio optionally transcribed at index time (cached), so a whiteboard
  photo becomes searchable design context. `describe_image`, `detect_objects` (ONNX), `transcribe_audio`.
- Optional push-to-talk voice loop (`voice.py`, uv + faster-whisper + headless `claude -p`).

### Known limitations
- Windows-only scripting (the C# server itself is portable).
- `detect_objects` is compile-verified but not inference-verified; bring your own ONNX model.
- Quality depends on the local model: contract-pinning and `/blueprint` want the strongest model available.

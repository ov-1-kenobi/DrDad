# DAD - Design Document Aligned Development

**Version 0.14.0** (see [CHANGELOG.md](CHANGELOG.md)). Feature-complete and self-tested - held below 1.0
until a full `/design -> /taskmap -> /build` run is verified end to end on real hardware.
Check your install any time with `dad-doctor.cmd`.

*Local, offline Claude Code on your own GPU. The design document is the contract and every
mode aligns to it. Start with **DAD**; add **BMAD on top** when you need the full agile pipeline.*

Run the real Claude Code agentic loop **inside VS Code**, driven by your local models via
Ollama. No Anthropic account, no API key, no internet after first setup. The loop is
**design-doc-driven**: `/design` writes the spec into self-contained stories -> lock it ->
`/spec` / `/build` implement it, fully on your RTX 5080.

## Architecture (deliberately minimal)

- **Claude Code engine** (Node - unavoidable, it's the harness) talks to **Ollama** for the model.
- **Native tools** cover files, shell, **git**, and code search - no MCP needed for those.
- **One C# MCP server** (`local-tools/`) adds the only things not built in: datasheet RAG,
  URL ingest, and web search. You can open it in Visual Studio and tweak it.
- That's it. **No extra Node MCP servers, no Python.** (We dropped filesystem/git/memory/
  sequential-thinking - they duplicated native features.)

## Install (any Windows machine)

1. Copy this whole folder anywhere on the target machine.
2. Run the installer (internet on) - either way:
   ```
   double-click  install.cmd          (Explorer-friendly launcher)
   or:  powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```
   It detects its own location, so the folder can live anywhere. It does everything: builds the
   64K-context model + the C# server, installs the Claude Code engine + VS Code extension, installs
   the global commands/agents and `settings.json` (**paths auto-fixed** to wherever the folder is),
   and tunes Ollama. It checks prerequisites first and warns about anything missing.
3. **Restart Ollama** (quit from the system tray, reopen) so the tuning + `qwen3-coder-next-cc` are live.
4. Scaffold a project (stack-agnostic): `new-project.cmd` (or `/scaffold`) -> open in VS Code -> `/design`
   (picks `docs/DESIGN.md` or `docs/TEDD.md`; stack decided FIRST, then requirements/epics/contracts) -> lock -> `/spec` `/build`.

Unplug the internet after step 2 - everything from here is local. `install.ps1` is safe to re-run.

## Install once, use everywhere (folder lifecycle)

- This folder is the kit's **permanent home** - put it somewhere stable (e.g. `C:\src\DAD-kit`).
  It holds the built `local-tools.exe`, the `templates/`, and `apikey.cmd`.
- Run `install.ps1` **once**. It installs the commands/agents/`settings.json` into `%USERPROFILE%\.claude\`
  (global) and points them at this folder. After that, `/scaffold` `/design` `/spec` `/proto` `/build` `/assets`
  work in **every** project - no per-project install.
- **Per project:** run `new-project.cmd` (or `/scaffold`) - **stack-agnostic** DAD init. The design doc
  (DESIGN.md vs TEDD.md) and the stack are decided in `/design` - the stack FIRST. (Use this, not `/init`.)
- **Don't move or delete this folder** - the global config and every project's `.mcp.json` reference
  it by absolute path. If you must move it, re-run `install.ps1` from the new location.
- **Re-run `install.ps1` only when** you move the folder, or change the global commands/agents/settings
  or rebuild the C# server. Editing a project's own `CLAUDE.md`/`docs` never needs a re-install.

## Files

| File | Role |
|------|------|
| `settings.json` | **The core config.** The `env` block redirects Claude Code to Ollama, picks models, forces offline mode. The extension reads it automatically. |
| `models.json` | **Single source of truth for models**: alias, `-cc` variant name, upstream tag, role, approx VRAM, which get auto-pulled, which is default, and the `num_ctx` every variant needs (Ollama defaults to ~4K and breaks the agent loop). Add a model = one JSON entry. |
| `sync-models.ps1` / `.cmd` | Reconciles Ollama with `models.json`: pulls bases, **generates** each `-cc` Modelfile, builds the variants, prints a table (`-Report` to look without changing, `-All` to pull the big optional ones, `-Only <alias>`). |
| `dad-doctor.ps1` / `.cmd` | **Readiness check** (`brew doctor` style): prerequisites, Ollama + every declared model, the built server + its MCP tool list, the global install, and - with `-ProjectDir` - a project's wiring/index/git/hook. Read-only; prints the fix commands. |
| `use-model.ps1` | One-command model switch: `dev` `coder` `oss` `fast` `quality` `gemma`. Restart Claude Code after. |
| `use-fast.cmd` / `use-quality.cmd` | Double-click switches to the fast / quality model. |
| `use-model.cmd` | Batch wrapper: `use-model.cmd fast \| quality \| <model-name>`. |
| `reindex.cmd` | Rebuild a project's RAG index from the CLI / a scheduled task: `reindex.cmd <docsDir>`. |
| `upgrade-project.ps1` / `.cmd` | **Retrofit an existing project** to the current kit: adds missing docs (STATUS/RECIPES), git safety net, refreshes CLAUDE.md's kit-owned sections (your Stack/Build/test preserved). Run after kit updates. |
| `test-kit.ps1` / `.cmd` | **The kit's own test suite** - run after ANY change to the kit; it *is* the validation gate. No Ollama/GPU/network needed. Also runs in CI (`.github/workflows/kit-ci.yml`). |
| `scan-secrets.ps1` / `.cmd` | **Credential scanner.** Blocks secrets from reaching git or the plaintext RAG index. Never prints the matched value - only file:line, pattern name, and a fingerprint. |
| `install-hooks.ps1` | Installs the project's `pre-commit` hook (runs `scan-secrets -Staged`). Called by scaffold + upgrade; re-runnable. |
| `dad-guard.ps1` / `.cmd` | **The stop guard** - a Claude Code `Stop` hook (wired by `install.ps1`) that refuses to let a turn end with uncommitted code nothing has built or tested. The only gate here the model cannot decline to invoke. `-Check` to test it, `-Ack` to override. |
| `source-stats.ps1` / `.cmd` | **Citation-integrity gate** for `/research`: do the design doc's `[Snnn]` citations resolve to sources that exist and were tiered? FAILs on a claim resting on nothing. Verifies traceability, not truth. |
| `api-surface.ps1` / `.cmd` | **The signature registry.** Reflects over the project's built assemblies AND its NuGet packages, writing exact public signatures to `docs/API-SURFACE.md` - regenerated after every successful build, so it cannot drift. `-Lookup <Type>` answers one question. A build failure prints the relevant signatures automatically. |
| `close-unit.ps1` | **Deterministic unit close-out** used by `/build` and `/spec`: ticks the task in TASKS.md, rolls the parent story up to DONE when all its tasks are `[x]`, reindexes, commits, and verifies. Non-zero exit = not closed. Mechanical bookkeeping is scripted because models skip prose checklists. |
| `voice.py` / `voice.cmd` | **Push-to-talk voice loop** (optional): mic -> faster-whisper (GPU STT) -> headless `claude -p --continue` -> Windows TTS. Run from your project folder; needs `uv` (winget install astral-sh.uv). First run downloads deps + the whisper model; offline after. |
| `transcribe.py` | Speech-to-text helper used by the `transcribe_audio` MCP tool (also standalone: `uv run transcribe.py <audio>`). Needs `uv`. |
| `ollama-tuning.ps1` | Ollama **server** speed settings (flash attention, KV-cache quant, keep-alive). Restart Ollama after. |
| `apikey.cmd` | Fallback key helper (NOT wired by default - `ANTHROPIC_AUTH_TOKEN` alone skips login; wiring both triggers an auth warning). |
| `install.ps1` | **The one-shot installer.** Detects its own location, builds everything, installs commands/agents/settings with paths auto-fixed, tunes Ollama. Re-runnable. |
| `install.cmd` | Double-click launcher for `install.ps1` (runs it with execution policy bypassed). |
| `uninstall.ps1` | Reverse the install: removes the kit's commands/agents, restores `settings.json` from `.bak`. `-Full` also removes the `-cc` model variants + `OLLAMA_*` tuning env vars. |
| `uninstall.cmd` | Double-click launcher for `uninstall.ps1` (pass `-Full` for the deep clean). |
| `new-project.ps1` / `.cmd` | **Deterministic, stack-agnostic scaffolder** - `new-project.cmd [dir]` lays down a generic CLAUDE.md + wired `.mcp.json` + `docs/` (no model, no platform choice). `/scaffold` runs this. |
| `CHEATSHEET.md` | One-page reference: models, modes, tools, switching, the pipeline. |
| `.mcp.json` | Registers the single `local-tools` C# server. `install.ps1` fixes the paths for you. |
| `local-tools/` | **The C# MCP server** - RAG + ingest_url + web_search. Open it in Visual Studio to tweak. See its own README. |
| `SUBAGENTS.md` | How subagents work + how they're invoked (a key context-window mitigation). |
| `global/` | Source for the global slash commands + agents (installed by `install.ps1`). |
| `templates/` | The generic scaffold base + **stack profiles** (`dotnet`, `avalonia`, `python`, `embedded`, `unity`) that `/design` applies late, + `_common` (shared `.mcp.json`, `DESIGN.md`/`TEDD.md`). See `templates/README.md`. |

## How it works (one line)

The extension is the same engine as the CLI and reads the same `settings.json` - so the
`env` block alone points the whole thing at `localhost:11434` (Ollama).

## Prerequisites (any Windows machine)

`install.cmd` **checks** for these and warns, but does NOT install them - set them up first.
(Windows 10/11. The scripts are Windows-only; the C# server itself is cross-platform .NET.)

- **Ollama** (recent build). Pull your main model: `ollama pull qwen3-coder-next:q4_K_M`.
  install pulls the smaller `qwen3:14b`, `nomic-embed-text`, and `gemma3:4b` for you.
  - **Match the model to the machine.** Next is 80B / 3B-active (~45 GB RAM/VRAM). On a 16 GB card it
    runs mostly from system RAM with GPU offload - better quality, slower. On a lighter box, make the
    **14B the primary** (`use-fast.cmd`) or point that entry in `models.json` at a smaller model.
- **Node** - Claude Code engine + extension.
- **VS Code** - with the `code` CLI on PATH, so install can add the extension.
- **.NET 8+ SDK** - only for the RAG tools (the C# server). The core Claude-Code-on-Ollama loop works
  without it; you'd just lose `search_datasheets` / `ingest_url` / `web_search`.

Internet is needed *during* install (model pulls, NuGet, npm, the extension). Offline after that.

### Quick install of the prerequisites (native Windows, via winget)
```
winget install Ollama.Ollama
winget install OpenJS.NodeJS.LTS
winget install Microsoft.VisualStudioCode      # enable "Add to PATH" so `code` works
winget install Microsoft.DotNet.SDK.8          # only if you want the RAG tools
npm install -g @anthropic-ai/claude-code        # Claude Code engine (install.cmd also runs this)
```
(Or download each from its vendor site.) Then `ollama pull qwen3-coder-next:q4_K_M` and run `install.cmd`.

### Run it native on Windows - not WSL2 (for this stack)
You may have heard "Claude Code runs better on WSL2." That was true in 2024-early-2025; as of 2026
**native Windows is first-class and the recommended install**, and Ollama's GPU throughput is within ~5%
between native Windows and WSL2 (effectively identical). For *this* stack, native Windows is clearly right:
- The kit is **Windows-native** - PowerShell/`.cmd` installer, a Windows `.exe` RAG server, config in
  `%USERPROFILE%\.claude`. Claude Code inside WSL2 reads a *Linux* `~/.claude` and can't run any of it
  without a full Linux port.
- Your targets - **.NET and Unity** - are Windows-native.
- WSL2 would force WSL->Windows networking to reach Ollama, and Windows-resident project files would go
  through the slow `/mnt/c` bridge.
- Keep **Ollama as the native Windows app**: it auto-detects the GPU via your NVIDIA driver - keep that
  driver current for the 5080 and verify with `ollama ps` (it shows the GPU/CPU split).

WSL2 only pays off if your work is Linux-centric *and* your project files live inside the WSL filesystem.

## Versioning + releasing

- `VERSION` is the single source of truth; `CHANGELOG.md`'s top entry must match it (the test suite
  enforces this). Semver: breaking layout/command changes bump minor while below 1.0.
- **Projects are stamped.** `/scaffold` and `upgrade-project` write `.dad-kit-version` into the project, so
  `dad-doctor.cmd -ProjectDir <path>` tells you when a project has fallen behind the kit - the exact
  condition that makes local models improvise against stale conventions.
- **Cutting a release:**
  ```
  test-kit.cmd                                  # must be 0 failed
  # bump VERSION + add a CHANGELOG entry, then:
  git add -A && git commit -m "release: v<x.y.z>"
  git tag -a v<x.y.z> -m "DAD-kit v<x.y.z>"
  git remote add origin <your repo url>         # first time only
  git push -u origin main --tags                # CI runs test-kit.ps1 on windows-latest
  ```
  Then create the GitHub release from the tag and attach a zip of the folder (excluding `bin/obj`,
  `_tempReference/`, `docs/.index/`) so a new machine can copy-and-`install.cmd`.

## Coexistence: what this changes on your machine (and how to share it)

The kit deliberately avoids shadowing anything Claude Code owns, but it *is* invasive in one place. Know
this before you install it on a machine you use for other work:

| What it changes | Scope | Reversible by |
|---|---|---|
| `%USERPROFILE%\.claude\settings.json` - **redirects Claude Code to Ollama** | **GLOBAL - every project on the machine** | `uninstall.cmd` (restores `settings.json.bak`) |
| `%USERPROFILE%\.claude\commands\*.md`, `agents\*.md` | GLOBAL - the 11 commands / 10 agents appear everywhere | `uninstall.cmd` |
| `OLLAMA_FLASH_ATTENTION` / `KV_CACHE_TYPE` / `KEEP_ALIVE` User env vars | machine | `uninstall.cmd -Full` |
| Ollama `-cc` model variants | machine | `uninstall.cmd -Full` |
| Per project: `CLAUDE.md`, `.mcp.json`, `docs/`, `.gitignore`, `.git/hooks/pre-commit` | that project | delete / `git` |

**The one to think about:** because `ANTHROPIC_BASE_URL` is set globally, *every* Claude Code session on
that machine goes to local Ollama - including projects that have nothing to do with DAD. That is the point
on a dedicated offline box, but if you also want to use cloud Claude there, scope it instead: move the
`env` block into a **project-level** `.claude/settings.json` inside your DAD projects and remove it from the
global file. Claude Code reads project settings over global ones, so DAD projects go local while everything
else stays normal.

**No name collisions** (the test suite enforces this):
- None of the 11 commands match a Claude Code built-in - important because a colliding custom command is
  **silently shadowed** (it simply never loads).
- No agent name matches a built-in agent type (`Explore`, `Plan`, `general-purpose`, ...). Ours all carry an
  `-agent` suffix; `taskmap-agent` is deliberately distinct from the built-in `Plan`.
- MCP tools are namespaced by the protocol (`mcp__local-tools__*`), so they cannot collide.
- **BMAD** namespaces its commands under `/bmad-*`, so BMAD and DAD-kit can be installed side by side.

**Intentional divergences**, so they don't surprise anyone:
- The kit tells agents to use `local-tools`' `web_search` / `ingest_url` instead of built-in
  `WebSearch`/`WebFetch` - the built-ins require Anthropic and don't work against Ollama.
- Model variants use a `-cc` suffix (`devstral-cc`); upstream tags use `:` (`devstral`), so they never clash.
- Secret allowlisting accepts the standard markers (`pragma: allowlist secret`, `gitleaks:allow`,
  `trufflehog:ignore`, `nosec`) as well as `DAD-ALLOW-SECRET`.
- `install-hooks.ps1` refuses to touch a project that already uses **husky**, **pre-commit**, or
  **lefthook**, and prints the one line to add to that tool's own config instead.
- The doc layout (`DESIGN`/`STORIES`/`TASKS`/`STATUS`/`COMMANDS` + `grades/`) is DAD's own convention, not an
  industry standard - each project's `CLAUDE.md` explains it, which is what makes a project self-describing
  to a developer (or model) who has never seen the kit.

## Per-project corpora (the convention)

The C# server is **built once** (shared exe). Each project gets its **own** document corpus
and its own index, simply by giving the project its own `.mcp.json`:

```
<shared>  DAD-kit\local-tools\bin\Release\net8.0\local-tools.exe   <- built once

MyUnityGame\
  .mcp.json          <- from templates\, LOCALTOOLS_DOCS_DIR -> MyUnityGame\docs
  docs\              <- this project's corpus (TEDD, design notes)
    .index\          <- auto-created, regenerable (gitignore it)
  CLAUDE.md          <- from templates\unity\
  (commands + agents are GLOBAL, not per-project)

SensorRig\
  .mcp.json          <- LOCALTOOLS_DOCS_DIR -> SensorRig\docs
  docs\              <- datasheets only
```

A game search never sees datasheet noise and vice versa - they're separate corpora with
separate indexes. **Per new project:** copy the files from `templates\<type>\` (plus
`templates\_common\`) into the project root and edit the one `LOCALTOOLS_DOCS_DIR` path.
Drop docs in `docs\`, run `index_datasheets`. (Or set `LOCALTOOLS_AUTO_REINDEX` to `1` in that
project's `.mcp.json` so the index refreshes itself whenever the docs change - opt-in, per project.)

## The context-window strategy

A local model has a small window (64K) vs cloud Claude. Three layers fight that, in order
of leverage:
1. **local-tools RAG** - search a 300-page PDF for the 2KB you need instead of loading it all.
2. **Subagents** - delegate lookups/exploration to a separate context that returns a summary
   (see `SUBAGENTS.md`). Claude Code uses live grep/read search, **not** a code index, so for
   small embedded projects you rarely need to index code - references are the pressure.
3. **CLAUDE.md** - small, stable, always-relevant facts (board, pins, commands), loaded as
   plain text each session. Keep it short; large/growing knowledge goes in the RAG instead.

## Online <-> offline: search the web, keep it forever

`web_search` works **only with internet**. The trick that makes it useful offline is `ingest_url`:

```
online:   web_search  -> find the right datasheet/app-note URL
          ingest_url  -> fetched text saved to datasheets/web/ and re-indexed
offline:  search_datasheets -> that content is now searchable forever, no internet
```

PDFs you drop in + pages you ingest all end up in one unified, searchable index.

## The build-and-test loop

`/scaffold <general|experience>` lays down the project and creates the design doc (`docs/DESIGN.md` for
general software, `docs/TEDD.md` for an experience) as `Status: DRAFT`. Then grow and implement it:
- `/design` - **design-first**: shape DESIGN (requirements, epics, stack LATE), no stories, no code.
- `/stories` - manage the story backlog in `docs/STORIES.md` (expand epics into stories, normalize, migrate).
- `/taskmap` - shard `STORIES.md` into `docs/TASKS.md`: bite-sized tasks + dependencies, reindexed - so `/spec`/`/build` pull one tight task at a time.
- `/spec` - implement the LOCKED design faithfully (works a task/story); gaps become questions.
- `/build` - orchestrate requirements -> dev -> grade -> hygiene -> qa; gated on DESIGN LOCKED.
- `/proto` - the lightweight alt to /design+/stories: co-design DESIGN + jot stories as you go (DRAFT).

The design is split by lifecycle: **DESIGN.md/TEDD.md** (contract - requirements/epics/stack, the only lockable doc) | **STORIES.md** (backlog) | **TASKS.md** (task map).
Lock/unlock: `/design` and `/proto` flip DESIGN `Status:` DRAFT <-> LOCKED **on your confirmation**. STORIES/TASKS stay editable even while DESIGN is LOCKED; never `/spec` a DRAFT DESIGN.
Pipeline: `/scaffold` (DRAFT DESIGN) -> `/design` -> `/stories` -> (optional) `/taskmap` -> lock DESIGN -> `/spec` or `/build`.
Tip: `/design` and `/stories` on `use-model.cmd oss`; `use-quality.cmd` (Next) for `/taskmap`, hands-off `/build`, hard `/spec`; `use-model.cmd dev` (Devstral) for fast `/proto` and iteration.

The commands read the project type from `CLAUDE.md`, so the same loop works for Unity, .NET,
Python, embedded, or anything. It self-loops on auto-testable work; manual/hardware/visual
checks pause for you. See `templates/README.md`.

## Migrating an existing project to the layered docs

Older projects kept everything (requirements + stories) in one `docs/DESIGN.md`. The kit now splits that into
**DESIGN.md** (contract: requirements/epics/stack), **STORIES.md** (story backlog), and **TASKS.md** (task
map). To move an existing project over - the design doc no longer has to hold the stories, which is what made
a local model loop when editing it:

1. **Reinstall** so you have the new commands/agents/templates: `install.cmd`.
2. **Lift the stories out:** `use-model.cmd oss` (new session), then `/stories migrate` - it moves each story
   from `DESIGN.md`/`TEDD.md` into `docs/STORIES.md` (tagging it to an epic) one at a time, and removes it
   from the design doc. What remains in DESIGN is the contract: goal, requirements, epics, architecture.
3. **(Optional) build the task map:** `/taskmap` shards `STORIES.md` into `docs/TASKS.md`.
4. **Refresh CLAUDE.md + missing pieces deterministically:** run `upgrade-project.cmd <projectDir>` - it
   adds `docs/STATUS.md` + `docs/RECIPES.md` if missing, git-inits with a baseline commit if needed, and
   refreshes CLAUDE.md's kit-owned sections (Modes/flow, Design docs, Proven recipes, Web/grounding,
   Working agreement) while PRESERVING your Stack / Build / test / Placeholder / Human-in-loop. Do this
   after every kit update - a stale CLAUDE.md is why local models improvise (root STATUS files, missed
   conventions).

Nothing is lost: `/stories migrate` only relocates stories, and `STORIES.md`/`TASKS.md` are created fresh.

## Optional: more-proactive subagent delegation (A/B test)

**Baseline (as-is - test this first).** The `requirements-agent` / `dev-agent` / `qa-agent` team is
driven by `/build`, which explicitly orchestrates them. In `/design` and `/spec` the main session only
pulls in `doc-researcher` for lookups, and only when it decides to. On a local model, spontaneous
delegation is limited, so **`/build` is the reliable trigger** - run the kit this way to set a baseline.

**The tweak to try later.** Make the agents advertise themselves so the main session reaches for them
on its own (even outside `/build`). It's a one-phrase change to each agent's `description:` frontmatter
- the word **PROACTIVELY** is the documented nudge Claude Code uses to auto-select an agent.

- **Where:** edit the installed files at `%USERPROFILE%\.claude\agents\*.md` (or the source
  `global\agents\*.md`, then re-run `install.cmd` to re-copy them).
- **How (example, `dev-agent.md`):**
  ```
  # before
  description: Implements ONE requirement ... Use after requirements-agent, before qa-agent.
  # after
  description: Implements ONE requirement ... Use PROACTIVELY after requirements-agent, before qa-agent.
  ```
  Do the same for `requirements-agent`, `qa-agent`, `doc-researcher` (e.g. "Use PROACTIVELY before
  writing any code").
- **A/B test:** run a representative feature on the baseline agents (note how often it delegates and the
  result quality); then apply the PROACTIVELY edit, **start a new session**, run a comparable feature,
  and compare. Keep it only if delegation improves without getting noisy. On the local model the gain is
  usually modest - the explicit `/build` path stays the dependable one.

## Switching models

Four roles (full table in `CHEATSHEET.md`):
- **`quality` -> `qwen3-coder-next-cc`** - 80B-A3B Next, most capable. **Default for `/build` & hard `/spec`** (slower, RAM-offloaded - worth it when you fire-and-forget).
- **`dev` -> `devstral-cc`** - Devstral 24B, fits the GPU. Fast iteration coding, `/proto`, quick `/spec`; no CJK.
- **`oss` -> `gpt-oss-20b-cc`** - MoE (~A3.6B), THE planner: `/design`, `/stories`, `/audit`. Most literal instruction-follower.
- **`fast` -> `qwen3-14b-cc`** - dense 14B, quickest, for light edits.

Switch the whole session, then start a new Claude Code session. Any of these:
```
use-model.cmd dev    (or: plan | fast | quality | <any Ollama model>)
double-click  use-fast.cmd  or  use-quality.cmd       (Explorer-friendly)
powershell -File use-model.ps1 dev
```
(You can also try the built-in `/model` to switch within a session; if it doesn't list your
Ollama models, use `use-model.ps1` + restart.)

### Per-agent models (advanced)
A custom agent can pin its own model via frontmatter: `model: qwen3-14b-cc`. With the direct
Ollama endpoint the name passes straight through, so in principle you could give `doc-researcher`
/ `qa-agent` the fast 14B and `dev-agent` the Next model. **Caveat for 16 GB:** only one big model
fits at a time, so alternating Next (~45 GB) with the 14B every step makes Ollama unload/reload the
big model each cycle - thrash that usually erases the benefit. Per-agent routing pays off when the
models are close in size (e.g. all 14B, or 14B + a tiny model for trivial lookups) or on a bigger
GPU. For now, prefer switching the whole session per mode with `use-model.ps1`.

## Adding a new model (the kit is model-agnostic)

Any Ollama model works. To add one:
1. **Pull it:** `ollama pull <model>` (e.g. `ollama pull devstral`). You can also pull GGUFs straight
   from Hugging Face: `ollama pull hf.co/<repo>`.
**The short way (recommended):** add one entry to `models.json` (alias, name `<x>-cc`, `from`, role,
`approxVramGb`), then run `sync-models.cmd`. It pulls the base if needed, generates the Modelfile with the
right `num_ctx`, builds the variant, and the alias immediately works with `use-model.cmd <alias>`.
Nothing else to edit - install, uninstall, `use-model` and `dad-doctor` all read the manifest.

**The manual way (what sync does for you):**
2. **Bump its context** (Ollama defaults `num_ctx` too low for the agent loop) - make a `-cc` Modelfile:
   ```
   FROM <model>
   PARAMETER num_ctx 65536
   ```
   then `ollama create <model>-cc -f <model>-cc.Modelfile`. (Drop to `32768` if memory is tight.)
3. **Add it to `models.json`** so the alias, uninstall and doctor all know about it.
4. **Switch:** `use-model.cmd <model>-cc` (or your alias) -> start a new Claude Code session.

**Sizing for 16 GB:** a model whose Q4 weights are <= ~15 GB runs fully on the GPU (fast). Bigger ones
offload to system RAM (slower - that's why the 80B Next is the slow one). `ollama ps` shows the split.

### Devstral - recommended Western-origin coder (already wired in)
- **Get "Devstral Small 2" (24B)** - it fits your 16 GB GPU (~14 GB at Q4). **NOT** the 123B
  "Devstral Medium / Devstral 2" (won't fit): `ollama pull devstral` (confirm "Small 2" on
  [ollama.com/library/devstral](https://ollama.com/library/devstral)).
- Build the shipped variant: `sync-models.cmd -Only dev` (install.cmd does this automatically).
- Use it: **`use-model.cmd dev`** -> new session. Apache-2.0, agentic-coding-tuned, no CJK drift.
  Good primary for `/spec` and `/build`; A/B it against `quality` (Next) and `fast` (14B).

## Running BMAD on this stack (optional)

[BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) is an agentic "agile AI team" framework
(Analyst / PM / Architect produce a PRD + Architecture, a Scrum Master shards them into detailed
stories, Dev/QA implement). It targets Claude Code natively and installs into `%USERPROFILE%\.claude\`
- the same place `install.ps1` puts this kit's commands/agents - so it runs offline on this stack,
right alongside the kit. This kit already mirrors its pattern in miniature; BMAD is the full version.

**Install (internet on, once):**
1. From the BMAD repo, run its installer (recent versions: `npx bmad-method install`; some ports use
   `npm run install:bmad`) and **select "Claude Code"** as the platform when prompted. It writes its
   agents/skills into `~/.claude/`. Confirm exact steps in the BMAD README - the project moves fast.
2. Start a new Claude Code session so it picks up the new agents/commands.

**Which model for which phase** (use the switchers):
- **Planning** (PRD + architecture - reasoning-heavy): `use-model.cmd oss` -> `gpt-oss-20b-cc` (MoE reasoner),
  or `use-quality.cmd` -> Next for the hardest design. Keep projects small, or do heavy planning with
  cloud Claude when you have internet, then continue offline.
- **Implementation** (Dev against BMAD's detailed story files): `use-quality.cmd` -> Next for hands-off
  `/build` and gnarly stories (most capable); `use-model.cmd dev` -> `devstral-cc` for fast iteration on
  well-scoped stories (BMAD embeds context per story, so the dev step often has little to reason about);
  `use-fast.cmd` (14B) for trivial ones.

**BMAD vs this kit's own commands:**
- **POCs / quick work:** the kit's `/proto` `/spec` `/build` - lighter, less ceremony.
- **Larger structured projects:** BMAD's full PRD -> architecture -> stories pipeline.
- Same machine, same offline stack. BMAD installs under its own agent/command names; if any name
  collides with the kit's (`/scaffold` `/design` `/spec` `/proto` `/build` `/assets`), the last one installed
  wins - rename one side if that happens.

## If it's slow / out of memory (16 GB VRAM)

`ollama-tuning.ps1` sets the three biggest levers (Ollama-server settings, separate from
`settings.json`; restart Ollama to apply):
- `OLLAMA_FLASH_ATTENTION=1` - faster attention, less memory (required for the next one).
- `OLLAMA_KV_CACHE_TYPE=q8_0` - shrinks the context cache so more fits on the GPU. Biggest win.
- `OLLAMA_KEEP_ALIVE=30m` - model stays resident, no reload between turns.

Still tight? Lower `numCtx` in `models.json` to `32768` and re-run `sync-models.cmd`; use a
smaller quant; `ollama ps` shows the GPU/CPU split.

## If a login screen still appears

`ANTHROPIC_AUTH_TOKEN` in the `env` block should prevent it. If a login screen still blocks you, add
`"apiKeyHelper": "<kit>\\apikey.cmd"` to `settings.json` as a fallback (expect a benign "both set"
warning at startup in that configuration).

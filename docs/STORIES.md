# Stories - DrDad
<!-- The story backlog. Managed by /stories (create from the DESIGN epics, normalize, dedupe). This
     IMPLEMENTS DESIGN.md (the contract) - it does NOT redefine requirements; anything that needs a new
     requirement goes back to /design. Stories stay editable even while DESIGN is LOCKED. Each story traces
     to an epic by tag. /taskmap shards these into TASKS.md. Keep each story self-contained. -->

<!-- Migrated from DESIGN.md's embedded "## Stories" section (pre-dated the STORIES.md/TASKS.md split
     that R7 now mandates for every project). S1-S3 below were already DONE at time of migration; full
     content preserved verbatim. DESIGN.md has no separate "Epics" list, so each story is tagged with the
     closest DESIGN.md Requirement (R#) it implements, in place of an Epic tag. -->

### Story S1: Safe uninstall (uninstall.ps1 + uninstall.cmd)   (R8)   <!-- Status: DONE closed:close-unit -->
<!-- Implemented: uninstall.ps1 + uninstall.cmd. AC3 verified (parses + ASCII); AC1/AC2/AC4 are behavioral - confirm on first run. -->
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

### Story S2: Steer web tools to local-tools (CLAUDE.md convention)   (R7)   <!-- Status: DONE closed:close-unit -->
<!-- Implemented: "## Web / grounding" line added to all 5 type templates (dotnet/python/embedded/generic/unity) + avalonia. -->
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

### Story S3: Avalonia project template (templates\avalonia)   (R7)   <!-- Status: DONE closed:close-unit -->
<!-- Implemented: templates\avalonia\CLAUDE.md + Types row in templates\README.md + /scaffold example. AC4 (manual /scaffold avalonia) confirm on the 5080. -->
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

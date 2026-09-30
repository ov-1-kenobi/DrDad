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
<!-- Implemented: uninstall.ps1 + uninstall.cmd. Behaviorally verified 2026-09-19: AC1 run against a
     sandboxed fake ~/.claude via -ClaudeDir (kit commands/agents removed by exact name, non-kit files
     survive, settings.json restored byte-for-byte from settings.json.bak); real machine PATH/DAD_HOME/
     ~/.bashrc confirmed untouched by the run. AC2 verified by code review only (per human decision, to
     avoid actually `ollama rm`-ing real installed models / unsetting real env vars): models.json-driven
     variant list, checked live against `ollama list` before removal, matches the 3 named OLLAMA_* env
     vars. AC3 verified (parses + ASCII). AC4 verified both statically (no Remove-Item targets the kit
     root/$PSScriptRoot/npm/VS Code) and behaviorally (the sandbox run never touched this kit folder).
     Bug found + fixed during this verification: uninstall.ps1's PATH/DAD_HOME/~/.bashrc cleanup was NOT
     scoped by -ClaudeDir, so it had real unscoped side effects on whatever machine ran it (including the
     existing test-kit.ps1 sandbox test at the time) - now skipped when -ClaudeDir is set. -->
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
  - [x] AC1: after `uninstall.ps1`, the 6 command + 4 agent files are gone from `~/.claude` and `settings.json` matches the restored `.bak`. (Verified 2026-09-19 against a sandbox via `-ClaudeDir`; command/agent lists have since grown past the original "6+4" but the mechanism is confirmed correct.)
  - [x] AC2: `-Full` also removes the 4 model variants (`ollama list` no longer shows them) and the 3 `OLLAMA_*` env vars. (Code-review verified 2026-09-19, not live-run - see implementation note above.)
  - [x] AC3: `uninstall.ps1` parses (PS AST) and `uninstall.ps1`/`.cmd` are ASCII-only.
  - [x] AC4: it does NOT delete the kit folder, npm package, or extension. (Verified statically + behaviorally 2026-09-19.)
- **Dev notes:** ASCII-only (PS 5.1). Add `uninstall.ps1`/`.cmd` to the README files table + this DESIGN.md;
  add "uninstall.ps1 parses + ASCII" to the validation gate. Do a dry run first (print what would be removed).

### Story S2: Steer web tools to local-tools (CLAUDE.md convention)   (R7)   <!-- Status: DONE closed:close-unit -->
<!-- SUPERSEDED-BY-R7 (2026-09-19): implemented at close as "## Web / grounding" duplicated into all 5 type
     templates (dotnet/python/embedded/generic/unity) + avalonia. R7's later 0.13.0 stack-agnostic scaffold
     + profile-fragment refactor (docs/DESIGN.md R7) replaced that 5-way duplication: the section now lives
     ONCE, kit-owned, in templates\generic\CLAUDE.md, inherited by every scaffolded project regardless of
     stack (non-generic dirs are PROFILE.md fragments that may not carry it - enforced by
     test-kit.ps1:543-566). The story's GOAL is still met, more robustly than the original mechanism; AC1 /
     Data-interfaces below are updated to describe the current architecture rather than the superseded one. -->
- **Goal:** Make every project prefer the working local web tools over the inert built-ins.
- **Context:** Claude Code's built-in WebSearch is Anthropic-server-side - pointed at Ollama it has no backend
  and won't run; WebFetch is likewise Anthropic-oriented. The working tools are local-tools' `web_search`
  (keyless DuckDuckGo) and `ingest_url` (fetch + fold into the RAG). The model chooses the tool, so without
  guidance it may fumble toward a dead built-in.
- **Behavior:** Add this one-line convention to each project-type CLAUDE.md (identical wording):
  > Web search / URL lookup: use the `local-tools` `web_search` / `ingest_url` tools, NOT the built-in
  > WebSearch/WebFetch (those need Anthropic and don't work against local Ollama). For grounding, `web_search`
  > to find, then `ingest_url` to fetch + persist into the RAG.
- **Data / interfaces (superseded 2026-09-19, see note above):** ~~Edit the 5 template CLAUDE.md files:
  `templates\dotnet`, `python`, `embedded`, `generic`, `unity`. Put the line under each file's "Working
  agreement" section.~~ Current: the line lives ONCE in `templates\generic\CLAUDE.md`'s kit-owned "## Web /
  grounding" section; non-generic `templates\<stack>\PROFILE.md` fragments must NOT carry it
  (`test-kit.ps1:543-566` gates this).
- **Dependencies:** none.
- **Acceptance (testable):**
  - [x] AC1 (superseded wording, verified against CURRENT architecture 2026-09-19): ~~all 5 template
    CLAUDE.md files contain the web-tools convention line~~ -> `templates\generic\CLAUDE.md` contains it
    and every scaffolded project inherits it regardless of stack (confirmed: `templates\generic\CLAUDE.md`
    read directly; `test-kit.ps1` asserts no `PROFILE.md` duplicates it).
  - [x] AC2: the line names `web_search` + `ingest_url` and says NOT to use built-in WebSearch/WebFetch. (Verified verbatim in `templates\generic\CLAUDE.md`.)
  - [x] AC3: the validation gate still passes (markdown only; no broken sections).
- **Dev notes:** Markdown only (no scripts). Optionally add the same note to the README's web section.

### Story S3: Avalonia project template (templates\avalonia)   (R7)   <!-- Status: DONE closed:close-unit -->
<!-- SUPERSEDED-BY-R7 (2026-09-19): implemented at close as templates\avalonia\CLAUDE.md (a full file) +
     Types row in templates\README.md + a stack-named /scaffold avalonia. R7's later 0.13.0 stack-agnostic
     scaffold + profile-fragment refactor (docs/DESIGN.md R7) replaced this: templates\avalonia\CLAUDE.md
     no longer exists, replaced by templates\avalonia\PROFILE.md (a fragment with no kit-owned sections -
     enforced by test-kit.ps1:543-566), and the stack is now chosen inside /design step 2 (which lists
     avalonia), not via a per-stack /scaffold argument. The story's GOAL is still met via this two-step
     flow; AC1/AC4 below are updated to describe the current architecture rather than the superseded one. -->
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
- **Data / interfaces (superseded 2026-09-19, see note above):** ~~new file `templates\avalonia\CLAUDE.md`~~
  -> `templates\avalonia\PROFILE.md` (a fragment: Stack/Placeholder/Build-test-run/Human-in-loop only, no
  kit-owned sections); add an `avalonia` row to the Stack profiles table in `templates\README.md` (still
  current, table renamed from "Types" in the 0.13.0 refactor).
- **Dependencies:** none (uses existing `_common`).
- **Acceptance (testable):**
  - [x] AC1 (superseded wording, verified against CURRENT architecture 2026-09-19): ~~`templates\avalonia\
    CLAUDE.md` exists with the Modes block + dotnet build/test/run + MVVM placeholder + visual
    human-in-loop~~ -> `templates\avalonia\PROFILE.md` exists with dotnet build/test/run + MVVM placeholder
    + visual human-in-loop (Modes is kit-owned, inherited from `templates\generic\CLAUDE.md`, correctly
    NOT duplicated here per `test-kit.ps1:543-566`).
  - [x] AC2: `templates\README.md` Types table lists `avalonia`. (Table is now "Stack profiles"; row confirmed present.)
  - [x] AC3: files are ASCII; the validation gate still passes.
  - [ ] AC4 (superseded wording, STILL UNVERIFIED end-to-end): ~~(manual) `/scaffold avalonia` appears in
    the menu and scaffolds a project~~ -> (manual) `/design` step 2 offers `avalonia` as a stack choice and
    correctly copies CLAUDE.md's Stack/Build-test-run/Placeholder/Human-in-loop from
    `templates\avalonia\PROFILE.md` with no leftover kit-owned duplication. This requires a live human run
    of `/design`; left unticked per grade card S3 suggestion 3 (not something to fabricate a tick for).
- **Dev notes:** ASCII only. Mirror the structure/wording of `templates\dotnet\CLAUDE.md`. Re-confirm current
  Avalonia template/test package names via `web_search` / docs.avaloniaui.net before finalizing.

### Story S4: Sandbox-real-state / explicit-consent as a checkable convention   (R35)   <!-- Status: DONE closed:close-unit -->
- **Goal:** Turn the pattern behind R35 into a general, CHECKABLE convention - not the one-off fix already
  in `uninstall.ps1` - so any future command/agent that scripts install/uninstall/teardown/state-mutating
  behavior is required to (a) verify real-state-touching acceptance criteria against an isolated,
  parameterized target, never the live machine, with that isolation checked to cover every mutating code
  path, and (b) get explicit human consent before running an irreversible or outside-the-project action
  live, recording which happened (live-sandboxed vs code-review-only) and why.
- **Context:** The motivating incident is already fixed: `uninstall.ps1`'s PATH/`DAD_HOME`/`~/.bashrc`
  cleanup section was not scoped by `-ClaudeDir`, so every "sandboxed" run - including the existing
  `test-kit.ps1` suite - silently mutated the real machine's environment; it is now skipped with an
  explicit guard (`uninstall.ps1` lines ~96-133: `if ($ClaudeDir) { ... skip ... } else { ... real
  mutation ... }`) and documented in Story S1's dev note. What is MISSING is a mechanism that would catch
  the *next* script that makes this mistake, and an explicit instruction surface telling `dev-agent`/
  `qa-agent` to ask before running an irreversible action live. R28 is the model for how a convention
  becomes an enforced gate here: `ratchet.ps1` is wired directly into `close-unit.ps1` (see
  `close-unit.ps1` lines ~354-363 and ~566-569) rather than living only as prose in DESIGN.md.
- **Behavior:**
  - Add a short, explicit instruction block to `global\agents\dev-agent.md` and `global\agents\qa-agent.md`
    (same shape as their existing "App Control / STOP" blocks) stating R35's two rules: never verify a
    real-state-touching AC against the live machine (use a `-ClaudeDir`/temp-dir-style override instead),
    and never run an irreversible/outside-the-project action live without asking the human first
    (code-review-only is an acceptable substitute when they decline).
  - Add a `Test-Case` to `test-kit.ps1` that greps known state-mutating scripts (starting with
    `uninstall.ps1`, extendable to any future install/uninstall/teardown script) for a state-mutation
    pattern (`SetEnvironmentVariable(...,"User")`, `ollama rm`, `Remove-Item` outside the project root,
    registry edits) that is NOT enclosed in a param-guarded conditional (an `if ($ClaudeDir)`/override-style
    guard). This should PASS today against the fixed `uninstall.ps1` and FAIL if that guard is ever removed
    - i.e., it mechanically catches the exact class of bug the dogfood audit found by luck, per R24's rule
      that a state fact should be computed, not rediscovered by chance.
  - Record in grade-card convention (wherever `grade-agent`'s template/instructions describe what a card
    must contain) that any unit whose acceptance criteria could touch real machine state must state which
    verification mode happened (live-sandboxed vs code-review-only) and why - mirroring the format already
    used in Story S1's dev note above.
- **Data / interfaces:** New instruction text in `global\agents\dev-agent.md` and
  `global\agents\qa-agent.md`; one new `Test-Case` block in `test-kit.ps1`; grade-agent's card-content
  instructions (wherever they currently live, e.g. `global\agents\grade-agent.md`).
- **Dependencies:** R28 (`ratchet.ps1` wired into `close-unit.ps1`) as the precedent pattern for turning a
  prose convention into a script gate; the already-fixed `uninstall.ps1` as the canonical passing case.
- **Acceptance (testable):**
  - [ ] AC1: `global\agents\dev-agent.md` and `global\agents\qa-agent.md` each contain an explicit block
    naming both R35 rules (isolated target for real-state ACs; explicit consent before irreversible/live
    action), in the same instructional style as their existing STOP blocks.
  - [ ] AC2: `test-kit.ps1` has a new `Test-Case` that statically checks `uninstall.ps1` (and any other
    listed state-mutating script) for state-mutation calls unguarded by a param-conditional; it passes
    against the current fixed file and is demonstrated to fail if the guard is removed.
  - [ ] AC3: grade-agent's instructions/template require recording verification mode (live-sandboxed vs
    code-review-only) + reason for any unit touching real machine state, matching the S1 dev-note format.
  - [ ] AC4: the full validation gate (`test-kit.ps1`) still passes after the additions; new files/edits are
    ASCII-only.
- **Dev notes:** This is a generalization story, not a re-fix - `uninstall.ps1` itself needs no further
  code change. Keep the new `Test-Case` pattern-based/language-agnostic-ish (grep on known dangerous calls)
  rather than hard-coding `uninstall.ps1`'s exact line numbers, per R28/R29's own lesson about pinning
  implementation details in a gate. ASCII only (PS 5.1).

### Story S5: Rename the distribution package DAD-kit -> DrDad (cosmetic only)   (R8)   <!-- Status: DONE closed:close-unit -->
- **Goal:** `package-kit.ps1` produces `DrDad-v<version>.zip`/folder instead of `DAD-kit-v<version>`, so a
  fresh distribution matches the product's actual name, without touching anything the installer relies on.
- **Context:** "DAD-kit" is not just a display name - `install.ps1`'s dev-path placeholder
  (`C:\Projects\Claude\MCP\DAD-kit`), the `.bashrc` managed-block markers (`# >>> DAD-kit >>>` /
  `# <<< DAD-kit <<<`), and ~15 `test-kit.ps1` assertions all depend on that literal string. README.md
  already documents the mismatch as deliberate: "asset is named `DAD-kit-v<x>.zip` for historical reasons;
  it is DrDad inside." This story is scoped to ONLY the packaged output's name - explicitly NOT the
  placeholder, NOT the bashrc markers, NOT any existing install's paths. A full rename (placeholder +
  bashrc markers + every template `.mcp.json` + migration for existing installs) was considered and
  deliberately deferred - out of scope here.
- **Behavior:**
  - `package-kit.ps1`: change `$name = "DAD-kit-v$version"` to `$name = "DrDad-v$version"` (and the two
    header-comment examples at the top of the file that show the old name).
  - `README.md`: update the naming note (currently says the zip "is named `DAD-kit-v<x>.zip` for historical
    reasons") to reflect the new packaged name; keep the explanation that `DAD-kit` lives on internally as
    the dev-path placeholder.
  - Do NOT touch `install.ps1`'s `$old` placeholder, the `.bashrc` markers, or any `templates/*/.mcp.json`
    placeholder string - all still say `DAD-kit` by design (see Context).
- **Data / interfaces:** `package-kit.ps1` (the `$name` line + header comments), `README.md` (one note).
- **Dependencies:** none.
- **Acceptance (testable):**
  - [ ] AC1: `package-kit.ps1 -Folder` produces `DrDad-v<version>` (not `DAD-kit-v<version>`) in the output
    dir; `package-kit.ps1` (zip mode) produces `DrDad-v<version>.zip`.
  - [ ] AC2: the packaged output still passes the existing placeholder self-check (the dev-path placeholder
    string inside `.mcp.json` etc. is untouched and still says `DAD-kit`, per Context).
  - [ ] AC3: `test-kit.ps1`'s packaging assertion (currently `$out = Join-Path $sb "DAD-kit-v$v"`, around
    line 614) is updated to expect `DrDad-v$v`, and the full validation gate still passes.
  - [ ] AC4: README.md's naming note reflects the new packaged name and still explains why `DAD-kit`
    persists internally.
- **Dev notes:** Small, low-risk, single-file-plus-doc change. Do not let this drift into the full-rename
  scope (placeholder/bashrc/`.mcp.json`) - that was explicitly deferred; file a separate story/requirement
  if that is ever wanted.

### Story S6: Walking-skeleton ratchet - doc-stats `[ratchet]` finding   (R36)   <!-- Status: DONE closed:close-unit -->
- **Goal:** `doc-stats.ps1 -Findings` computes and WARNs when a project's planning mass (stories + tasks)
  has grown far ahead of its proven/DONE footprint - the mechanism that would have caught the ModelTest
  bake-off's Opus failure (28 stories / 35 tasks sharded, 0 done) automatically, without a human having to
  notice it by hand.
- **Context:** `docs/ASSESSMENT.md` Failure B is the motivating incident. `docs/DESIGN.md` R36 + contract
  `## Contracts` `### C1` (sub-decisions C1a and C1b) already PIN the exact formula, tag, message wording,
  and worked examples - this story implements what is pinned, it does not re-derive it. C1a chose **Option
  B**: `mass = storiesTotal + tasksTotal`, `doneRatio = (storiesDone + tasksDone) / mass`, fire when
  `mass >= 15 AND doneRatio < 0.15`. C1b pins the tag (`[ratchet]`) and the exact message template
  (read it directly from `docs/DESIGN.md` - do not retype it from memory here, this note is a pointer, not
  the source of truth).
- **Behavior:** add the `[ratchet]` computation to `doc-stats.ps1`'s `-Findings` block, alongside the other
  generated findings (`[design]`/`[scribe]`/`[taskmap]`/`[integrity]`/etc. - same code region, same
  generated-not-authored pattern). Use `storyIds.Count`/`storiesDone.Count`/`tasks.Count`/`tasksDone.Count`
  (already computed earlier in the script - do not add a new data source). WARN only - append to `$f`,
  never block `/build`/`close-unit`/a LOCK gate (per C1d's invariant). Keep the threshold constants (`15`,
  `0.15`) named and near the top of the `[ratchet]` block, easy to retune from a single false-positive/
  false-negative report - the same convention other WARN thresholds in this file already follow (e.g. the
  `>= 5` uncommitted-done threshold near the `[integrity]` block).
- **Data / interfaces:** `doc-stats.ps1` only (the `-Findings` function).
- **Dependencies:** none (R36/C1 are already LOCKED in `docs/DESIGN.md`).
- **Acceptance (testable):**
  - [ ] AC1: a project with `mass >= 15` and `doneRatio < 15%` gets a `[ratchet]` finding in
    `doc-stats -Findings`, matching the message shape pinned in `docs/DESIGN.md` C1b.
  - [ ] AC2: a fresh/small project (`mass < 15`) stays silent - no false positive. Worked example from C1a:
    3 stories / 0 tasks, `mass = 3` -> silent.
  - [ ] AC3: a healthy large project (proportionate progress, `doneRatio >= 15%`) stays silent even with
    high mass. Worked example from C1a: 50 stories/10 done + 80 tasks/40 done, `mass = 130`,
    `doneRatio = 38.5%` -> silent.
  - [ ] AC4: the real ModelTest/Opus numbers reproduce the fire as a regression test: 28 stories/0 done +
    35 tasks/0 done -> `mass = 63`, `doneRatio = 0%` -> `[ratchet]` fires with the exact pinned wording.
  - [ ] AC5: a "stalled large project" (50 stories/3 done + 80 tasks/5 done, `doneRatio = 6.2%`) also fires
    - the scenario Option A (rejected in C1a) would have missed after its first close.
  - [ ] AC6: the full validation gate (`test-kit.ps1`) passes; a new `Test-Case` covers AC1-AC5 (sandbox
    fixtures at each mass/doneRatio combination, same pattern as the existing `[integrity]`/`[scribe]`
    finding tests).
- **Dev notes:** Formula/tag/message/thresholds are FULLY PINNED in `docs/DESIGN.md`'s `## Contracts` C1a/
  C1b - read them directly before writing code; do not re-derive or improvise the wording. WARN severity
  only, matching `[research]`/`[style]`/`[ux]`, never `[design]`'s LOCK-blocking class.

### Story S7: Ask-time scope pricing - state the cost before scope grows   (R36)   <!-- Status: DONE closed:close-unit -->
<!-- Implemented: T7.1 (global\commands\stories.md step 2b) + T7.2 (global\commands\design.md step 4b) +
     T7.3 (test-kit.ps1 static Test-Case), commits 49509a1/6c364a5/e8b8320. AC1/AC2/AC4 verified (dev+qa
     traced the pricing sentences character-for-character against docs\DESIGN.md's C1c, confirmed the
     no-fabrication rule, the explicit WAIT, and the epic/requirement vocabulary adaptation; AC4's
     test-kit.ps1 case was proven to be a real negative test, not a tautology, by qa-agent temporarily
     removing the sentences and watching it fail). AC3 (installed copies in %USERPROFILE%\.claude\commands\
     refreshed) is DEFERRED per R35(b): install.cmd mutates state OUTSIDE this project and needs the
     human's explicit consent before running live. Grade card grades\S7_GRADE.md flagged this gap; it is
     recorded here per T7.3's own Context instruction rather than left silent. Run install.cmd before the
     next live /stories or /design session picks up T7.1/T7.2's changes. -->
- **Goal:** when `/stories` expands a requirement into stories, or `/design` adds a new requirement, the
  orchestrator states the story/task-count cost BEFORE asking the human to approve continuing to scope vs.
  building now - so the cost of saying yes is visible at the moment of the ask. This is the other half of
  R36's loop (SCOPE -> **PRICE -> ASK** -> WALK/WARN -> BUILD -> ANALYZE -> repeat); S6 is the WALK/WARN
  backstop, this story is the PRICE/ASK front door.
- **Context:** `docs/ASSESSMENT.md` Failure B - Opus's own `DESIGN.md` recorded "the v1 scope then grew by
  four features" with no visible cost attached to that yes. `docs/DESIGN.md` R36 + contract `## Contracts`
  `### C1` sub-decision **C1c** pins the exact sentence shapes for two trigger points (read C1c directly -
  it has the full templates and a worked trace against the real Opus moment). This kit has **no Epics
  section** (DESIGN.md's own convention tags stories by Requirement id, e.g. `(R8)`, `(R35)`, `(R36)` - see
  S1-S6 above) - C1c's worked example uses Opus's `E6` epic id because THAT project has epics; when
  implementing the `/design`-side trigger here, adapt the sentence to this kit's own vocabulary (a new
  Requirement, not an epic) rather than copying "epic" language verbatim into a kit that has none.
  - **Trigger 1 - `/stories`' expand loop** (`global\commands\stories.md`, its "ONE EPIC AT A TIME" loop
    step 2, which already runs `dad doc-stats -Findings` between spawns): before spawning the next
    scribe-agent, snapshot `storiesTotal/tasksTotal/storiesDone/tasksDone`; after it returns and
    `doc-stats -Findings` prints the new numbers, state the delta and ask explicitly: build what's already
    scoped, or keep expanding? Real counts, not an estimate (C1c's "at `/stories`" branch).
  - **Trigger 2 - `/design`'s requirement/epic-adding step** (`global\commands\design.md`, its requirements/
    epics capture step, "3. Capture requirements" / "4. Group into epics"): when a NEW requirement is added
    that will need stories not yet written, count only what currently exists (requirements/epics so far) and
    say plainly that the story/task cost isn't priced yet - `/stories` will show the real number when it
    expands this requirement. Do NOT fabricate a story-count estimate for unexpanded scope (C1c's explicit
    "honest gap" - `ASSESSMENT.md` flagged invented estimates as option (d)'s biggest risk).
- **Behavior:** edit `global\commands\stories.md`'s expand-loop step to add the pricing sentence + explicit
  "build now, or keep scoping?" question, using C1c's real-counts template (adapted to this kit's R#
  vocabulary where it names "epic"). Edit `global\commands\design.md`'s requirements-capture step
  similarly, using C1c's epic-count-only template, adapted the same way. Both edits are PROMPT TEXT
  (instructions the orchestrator/human read), not PowerShell - small, targeted insertions into the existing
  step text, not a rewrite of either file.
- **Data / interfaces:** `global\commands\stories.md`, `global\commands\design.md`. After editing, re-run
  `install.cmd` per `CLAUDE.md`'s "Global commands/agents" convention (installed copies must match).
- **Dependencies:** none (R36/C1 are already LOCKED in `docs/DESIGN.md`); independent of S6 (no shared code
  - C1d pins the ratchet and the pricing ask as independently computed, only narratively linked in wording).
- **Acceptance (testable):**
  - [ ] AC1: `global\commands\stories.md`'s expand-loop step contains the pricing sentence shape from C1c
    (real story/task-count delta + an explicit build-vs-keep-scoping question) at the point where the next
    epic/requirement would be spawned.
  - [ ] AC2: `global\commands\design.md`'s requirement/epic-capture step contains the epic-count-only
    pricing sentence shape from C1c, explicitly stating the story/task cost is "not priced yet" rather than
    inventing a number.
  - [ ] AC3: `install.cmd` has been re-run (or the story notes that it must be, if this is verified by
    static file content only) so the installed copies in `%USERPROFILE%\.claude\commands\` match.
  - [ ] AC4: the full validation gate (`test-kit.ps1`) passes; a new `Test-Case` statically greps both
    command files for the pricing-sentence language (prose content, so a presence/shape check - matching
    how other prompt-content `Test-Case`s in this file already work, not a behavioral test).
- **Dev notes:** This is PROMPT TEXT, not code - there is no build to verify beyond ASCII/parse checks and
  the static content test. Keep the wording close to C1c's pinned sentences (read `docs/DESIGN.md` directly)
  so the shipped mechanism does not drift from what the human approved in `/design`.

<!-- The /design pass happened: S8/S9/S10 are now tagged to R38 (gate activity leaves EVIDENCE -
     R38a active proof, R38b a durable queryable record, R38c computed run cost). S11 moved to R32:
     it interrogates R32's same-session-subagent mitigation, not R38's evidence thesis. -->

### Story S8: dad gates-smoke - prove the gates actually fire   (R38)   <!-- Status: DONE closed:close-unit -->
- **Goal:** A standalone command that deliberately provokes a known violation against each of DrDad's real
  gates on a target project and confirms each one actually intercepts it - not that the hook file merely
  exists.
- **Context:** Today a gate's presence (the script/hook file existing) is not the same as it firing on the
  exact violation it claims to catch. This story closes that gap with an active smoke test rather than a
  passive file-existence check.
- **Behavior:**
  - Force 4+ identical consecutive tool calls and confirm the loop guard blocks the 4th.
  - Engineer a shrunk test/story count and confirm the ratchet (`[ratchet]` finding / R36 mechanism)
    refuses the close.
  - Leave uncommitted code with no `.dad-verified` stamp and confirm dad-guard blocks the Stop.
  - Exits 0 only if every gate it can safely provoke actually intercepted.
  - Exits non-zero and NAMES the gate if one silently let something through.
  - Degrades to a reported SKIP (never a false pass) for a gate whose violation needs state it can't
    safely construct on its own.
- **Data / interfaces:** New standalone command (e.g. `dad gates-smoke`), scoped to a target project path;
  reads/exercises the existing loop guard, ratchet (R36/C1), and dad-guard mechanisms without modifying them.
- **Dependencies:** none (exercises existing R36/ratchet + dad-guard/loop-guard mechanisms as black boxes).
- **Acceptance (testable):**
  - [ ] AC1: 4+ identical consecutive tool calls against a target project are blocked on the 4th by the loop
    guard, and `gates-smoke` reports this as intercepted.
  - [ ] AC2: a shrunk test/story count scenario causes the ratchet to refuse the close; `gates-smoke` reports
    this as intercepted.
  - [ ] AC3: uncommitted code with no `.dad-verified` stamp is blocked at Stop by dad-guard; `gates-smoke`
    reports this as intercepted.
  - [ ] AC4: `gates-smoke` exits 0 only when every gate it safely provoked was actually intercepted; if any
    gate silently lets a violation through, it exits non-zero and names that gate.
  - [ ] AC5: any gate whose violation cannot be safely constructed is reported as SKIP, never fabricated as a
    pass.
- **Dev notes:** Inspired by claude-gates (DevRik99)'s `smoke` command, which does exactly this across its 50
  gates.

### Story S9: Structured gate decision log   (R38)   <!-- Status: DONE closed:close-unit -->
- **Goal:** Every `block` a DrDad gate produces (loop guard, ratchet, dad-guard, a close-unit refusal),
  plus C3b's `allow` heartbeats, gets appended as one structured, machine-readable line - not just printed
  to console and lost. WARN findings are not gate decisions and are never logged (C3 header).
- **Context:** Gate decisions today are ephemeral console output. Making them a durable, queryable record is
  what would let `grade-trends.ps1` / `/retro` (R27) mine real data instead of parsing prose after the fact.
- **Behavior:**
  - Defines this as the real data `grade-trends.ps1` / `/retro` (R27) should be mining (e.g. "a theme in
    40%+ of cards is a convention problem") instead of parsing prose after the fact.
  - Would let a head-to-head model comparison count gate interventions automatically instead of a human
    watching and noting them by hand.
- **Data / interfaces:** Contract: C3 (C3a-C3f) in docs/DESIGN.md. One committed file per project,
  `grades/gates-log.jsonl` (C3a); one compact JSON object per line, UTF-8 no BOM, LF, SEVEN required fields
  `v, ts, gate, decision, tool, reason, session` (C3b); `decision` is `allow` or `block` only. Written by
  `dad-loopguard.ps1`, `dad-guard.ps1`'s Stop hook, `ratchet.ps1`, and `close-unit.ps1`'s refusal paths;
  queried via `dad-gates-log.ps1 -Query` (C3e).
- **Dependencies:** none; feeds S10 (per-run stats) as a data source for its gate-interventions figure.
- **Acceptance (testable):**
  - [ ] AC1: per C3b's per-gate table, `loop-guard` and `dad-guard-stop` each write ONE `allow` "armed" line
    on the session's first invocation (first Stop, for `dad-guard-stop`), then every `block`; `ratchet` and
    `close-unit-refusal` write EVERY invocation (`allow` or `block`). Each line lands in
    `grades/gates-log.jsonl` with all seven C3b fields present (`""` when not applicable) and no `warn`
    decision.
  - [ ] AC2: the log is queryable per C3e (`-Query [-Gate <id>] [-Decision <allow|block>] [-Since] [-Last]
    [-Count]`, e.g. `-Decision block` for deny-only) with stdout verbatim JSONL only - no hand-parsing of
    console output or prose.
  - [ ] AC3: `grade-trends.ps1` / `/retro` (R27) can read this log as a data source instead of parsing prose.
- **Dev notes:** Inspired by claude-gates (DevRik99)'s `.ai/gates-log.jsonl` (timestamp, gate, tool, reason,
  session - queryable via `claude-gates log --deny --gate <id>`).

### Story S10: Per-run stats summary   (R38)   <!-- Status: DONE closed:close-unit -->
- **Goal:** At the end of a `/build` scope or a full `/audit`, auto-generate a short, computed-not-narrated
  summary: tokens used, wall-clock time, files touched, findings count, gate interventions (pulled from S9's
  log).
- **Context:** This directly serves cost/reliability comparisons already underway elsewhere in this kit,
  turning a run's cost into a computed fact rather than a human's after-the-fact narration.
- **Behavior:**
  - Directly serves cost/reliability comparisons already underway elsewhere in this kit.
  - Depends on S9 (the gate decision log) as its data source for the gate-interventions figure - note this
    dependency explicitly.
- **Data / interfaces:** Contract: C4 (C4a-C4d) in docs/DESIGN.md. `dad-run-summary.ps1` prints
  `[run-summary]` lines (tokens, wall-clock, files touched, findings, gate interventions) at the end of a
  `/build` scope or a full `/audit`; every figure names its `source:` (C4c invariant). Window from
  `-StartTime` / `-SinceCommit` (caller-supplied) else `.claude\.dad-session.json`'s `first_seen_utc`
  (C4b). READ-ONLY and never blocks: writes no project state, no gate depends on it.
- **Dependencies:** S9 (the structured gate decision log) - required as the data source for the
  gate-interventions figure in the summary.
- **Acceptance (testable):**
  - [ ] AC1: at the end of a `/build` scope or a full `/audit`, `dad-run-summary.ps1` prints, computed (not
    narrated) and each printed figure with its `source:`: wall-clock over the window (`caller-supplied`, or the labelled
    `session start` fallback when `-StartTime`/`-SinceCommit` is absent - C4c); files touched as the
    deduplicated union of committed + uncommitted + untracked, printed SPLIT, e.g. `files touched: 14 (11
    committed, 3 uncommitted)`, no extension/directory filter (C4d); findings count (`doc-stats
    -Findings`); and tokens as EITHER a measured figure with its transcript source and version OR C4a's
    fallback line naming its reason, e.g. `tokens: not available (harness=copilot-cli: ...)` - never a
    fabricated number and never a bare "not available" (C4a).
  - [ ] AC2: the summary's gate-interventions figure is pulled from S9's structured gate decision log, not
    from a human's manual count.
  - [ ] AC3: the summary generation does not require a human to watch and tally interventions by hand.
- **Dev notes:** Inspired by claude-code-audit-gate (fotografvecerek-ai)'s STATISTIKA.html (lines of code,
  screens, findings, time, exact token counts, generated at the end of every audit run).

### Story S11: [SPIKE] Should high-stakes verification run as a separate process?   (R32)   <!-- Status: TODO -->
- **Type:** Research spike (no code) - **[human]** decision pending; do NOT implement anything for this
  story.
- **Goal:** Produce a short, cited written recommendation on whether DrDad's grade-agent/librarian-agent (or
  a future high-stakes gate) should run as a fully separate Claude Code process - its own workspace,
  read-only repo access, a file/message bus back to the main session - rather than a same-session Task-tool
  subagent. Do NOT implement anything for this story.
- **Context:**
  - R32 already establishes that a same-session subagent is "an unguarded, unobservable region" and
    mitigates this through discipline (one agent per unit, orchestrator regains control between spawns).
  - claude-code-audit-gate (fotografvecerek-ai) answers the identical underlying problem structurally
    instead: its auditor runs as a genuinely separate OS process (a second Claude Code window, "Kapitan"
    building / "Auditor" reviewing) connected by a HANDOFF -> EVIDENCE -> VERDICT bus, so it literally
    cannot share contaminated context with the agent it's reviewing.
  - The deliverable must weigh that real gain (closes R32's gap structurally) against the real cost
    (coordinating two live sessions instead of one).
  - Explicitly mark this as a **[human]**-flagged decision - do not build toward either answer until a human
    picks one - the same pattern as architect-agent hunting an underspecified contract and forcing a
    human-approved pin rather than guessing.
- **Behavior:** Write the recommendation into this story's own Dev notes (below) or a pointed-to doc (e.g.
  `docs/SOURCES.md`); it must cite R32 and claude-code-audit-gate's Kapitan/Auditor architecture, weigh the
  structural gain against the two-live-session coordination cost, and explicitly defer the choice to a
  human. No build/task work follows from this story until that human decision is made.
- **Data / interfaces:** None (no code). Deliverable is a written recommendation (in this story's Dev notes
  or a linked doc).
- **Dependencies:** R32 (same-session subagent isolation discipline) as the baseline being evaluated against.
- **Acceptance (testable, "deliverable produced" not code-tested):**
  - [x] AC1: a written recommendation exists (in this story's Dev notes / a Context subsection, or points to
    where it should be written) citing R32 and claude-code-audit-gate's Kapitan/Auditor architecture.
  - [x] AC2: the recommendation explicitly states it is a **[human]** decision pending approval, and does not
    commit to building either option. (Satisfied; the human then DECIDED on 2026-09-30 - see "Decision" below.)
- **Dev notes:** Inspired by claude-code-audit-gate (fotografvecerek-ai)'s Kapitan/Auditor two-process
  (HANDOFF -> EVIDENCE -> VERDICT) architecture. This is a RESEARCH SPIKE, not a build story - flagged
  **[human]** for decision, still unresolved: nobody has picked option A, B or C yet.
- **Recommendation (draft - pending human decision, satisfies AC1):**
  - **Option A - status quo (same-session Task-tool subagent, R32's discipline).** Pros: no new
    infrastructure; matches how the kit's other subagents already run (unverified - would need measurement;
    neither R32 nor S11's Context says so). Evidence (R32): eleven graded runs in the MAIN loop produced zero
    loops, and bounded one-agent-per-unit spawns succeeded (`taskmap-agent` in 5 and 9 calls); note the
    eleven runs are main-loop runs, not evidence about subagents. R32's remedy for subagents is discipline
    (one agent per unit, orchestrator regains control and runs `doc-stats -Findings` between spawns, retry
    limit of one) plus DETECTION via `dad watch` (R33). Cons: does NOT structurally close R32's gap - inside
    a subagent (R32) the `PreToolUse` hook does not fire (R32(a)), `tools:` frontmatter does not restrain it
    (R32(b)), and its transcript cannot reliably be exported (R32(c)); "nothing can interrupt a spawn"
    (R32), so the "unguarded, unobservable region" remains real. Three consecutive runs died inside a
    subagent (R32: `taskmap-agent` 920 calls, `scribe-agent` 947 and 1023) - those were whole-job spawns, now
    bounded by the discipline. That the orchestrator also cannot poll or read a progress file while a Task
    call is in flight is not stated by R32 (unverified - would need measurement).
  - **Option B - fully separate OS process (Kapitan/Auditor pattern, claude-code-audit-gate).**
    grade-agent/librarian-agent (or a future high-stakes gate) runs as a second, independent Claude Code
    process with its own workspace, read-only repo access, and a file/message bus back to the main session
    (HANDOFF -> EVIDENCE -> VERDICT). In claude-code-audit-gate (fotografvecerek-ai) the two processes are two
    separate Claude Code windows, "Kapitan" building and "Auditor" reviewing (S11 Context); nothing further
    about that project is asserted here. Pros: cannot share contaminated context with the agent under review
    (S11 Context) - addresses R32's gap structurally instead of by discipline. Whether the second process's
    OWN hooks (`PreToolUse` loop guard) and `tools:` list would govern its tool calls is unverified - would
    need measurement (R32(a)/(b) only establish the gap for a same-session SUBAGENT; R37(c) is the precedent
    that vendor behavior is a hypothesis until measured). Also unverified - would need measurement: that a
    runaway auditor can be observed/killed from outside the main session, and that read-only repo access
    would be an OS/filesystem-level guarantee rather than a tool-allowlist promise. Cons: the cost of
    coordinating two live sessions instead of one (S11 Context) - process lifecycle, and the bus itself
    becomes new surface to design, gate and maintain; loses the kit's single-session continuation model and
    adds friction to the common, non-highest-stakes case (both kit-side judgment, unverified - would need
    measurement).
  - **Where the tradeoff actually bites:** R32 records three deaths inside subagents, then success once
    spawns were bounded to one unit (R32: 5 and 9 calls); it holds no measurements for dev/qa/hygiene or
    grade/librarian subagents (unverified - would need measurement). If that holds, Option B's structural
    fix is insurance against a rare class of failure rather than a fix for an active one; the gain
    (structural closure of R32's gap) is weighed against the two-live-session coordination cost. That
    argues against an all-or-nothing swap and toward a **hybrid** (Option C): separate-process ONLY for the
    single highest-stakes verification point (e.g. grade-agent's final LOCK-adjacent verdict, or a future
    audit-gate signoff), same-session for everything else.
  - **[human] decision required - pick one before any code is written toward this:** (A) keep same-session
    for all agents: (B) go fully separate-process for all high-stakes agents; or (C) hybrid - separate-
    process only for the named highest-stakes gate(s), same-session for the rest. This write-up does not
    pick for you; no build work follows from S11 until the human answers.
- **Decision ([human], 2026-09-30): Option A - keep same-session subagents - PLUS computed checks on
  verifier claims. Options B and C are NOT built.** Evidence recorded at decision time (this run, measured,
  replacing the "unverified" marks above for dev/qa/hygiene/grade units): about 35 subagent spawns across
  dev, qa, grade, hygiene, scribe, taskmap and measurement agents, the longest at 67 tool calls, none looped,
  none needed killing, every one returned. The failures actually observed were NOT runaway loops but
  unreliable SELF-REPORTS by a same-session verifier: (1) the S9 grade-agent claimed it could not confirm
  dad-guard's first-Stop armed line (it exists at dad-guard.ps1:168) and admitted it had not read the test
  bodies; (2) the S10 hygiene pass reported no stray root files while `doc-stats` flagged two; (3) graders
  were biased by the orchestrator's own known-issues lists. A separate process would not have fixed (1) or
  (2) - what caught them was the orchestrator re-checking with a computed source (grep, `doc-stats`, the
  suite). So the response is to make verifier claims COMPUTED or cross-checked (R24: never accept an
  assertion a script can settle) - tracked as Story S18. Revisit B/C only if a MEASURED same-session
  verifier failure recurs AFTER S18, and measure first whether a second `claude` process's own hooks fire.

<!-- S12 is NOT part of the Receipts (R38) grouping above - it is tagged to R37, like S1-S7. It appears
     after S11 only to keep story ids in numeric order. -->

### Story S12: GitHub Copilot CLI as a second harness (opt-in install target)   (R37)   <!-- Status: DONE closed:close-unit -->
- **Goal:** the kit's two gates - the Stop guard (`dad-guard.ps1`) and the loop guard (`dad-loopguard.ps1`) -
  run under GitHub Copilot CLI as well as Claude Code, from one opt-in installer switch, WITHOUT forking
  either guard script.
- **Context:** `docs/DESIGN.md` R37 and contract `### C2` (sub-decisions C2a-C2f) already PIN the measured
  harness contract - hook location, event casing, per-event block semantics, subagent coverage, the BYOK
  offline path, and the version-drift policy. This story implements what is pinned; it does not re-derive
  it. C2 is stamped MEASURED 2026-09-29 against Copilot CLI 1.0.89 - read it directly rather than retyping
  the facts from memory, and re-measure before trusting it on any later version (C2f).
  **Delivered ahead of this card** by the `dogfood/copilot-pilot` research pilot (commit `64188cc`); the card
  exists so the work is gradeable and closeable through the normal gate, not to schedule new work.
- **Behavior:** `install.ps1 -CopilotCli` is ADDITIVE - it leaves the Claude Code wiring untouched and also
  writes `%USERPROFILE%\.copilot\hooks\dad.json`, so one machine runs both harnesses. The Stop hook goes
  through a thin adapter, `dad-guard-copilot.ps1`, because Copilot IGNORES exit code 2 and discards stdout
  with it (C2c): `dad-guard.ps1`'s existing JSON+exit-2 `Block()` therefore LOOKS correct and silently does
  nothing. The adapter re-runs the unmodified guard and re-emits its verdict with exit 0. `dad-loopguard.ps1`
  is wired UNCHANGED - Copilot honors exit 2 for tool calls, and its PascalCase payload is already the
  snake_case shape that guard parses. `uninstall.ps1 -CopilotDir` removes the hook file (sandbox-testable,
  and it leaves a same-named file that is not ours alone). `dad-doctor` reports the harness, the wiring, a
  stale kit path, and version drift.
- **Data / interfaces:** `dad-guard-copilot.ps1` + `.cmd`, `copilot-hooks.json` (the template carrying the
  dev-path placeholder), `install.ps1` (step 9 + `$CopilotMeasuredVersion`), `uninstall.ps1` (`-CopilotDir`),
  `dad-doctor.ps1` (the R37 section), `test-kit.ps1` (4 cases). `dad-guard.ps1` and `dad-loopguard.ps1` are
  NOT modified - that is the point of C2's no-fork invariant.
- **Dependencies:** none (R37 is `[x]` and contract C2 is MEASURED in `docs/DESIGN.md`).
- **Acceptance (testable):**
  - [x] AC1: the installed hooks file matches the only shape Copilot actually loads - user-level path,
    `version: 1`, `bash`/`powershell` keys, PascalCase events registered EXACTLY ONCE, Stop routed through
    the adapter. Covered by `test-kit.ps1` "copilot-hooks.json is the shape Copilot CLI actually loads".
  - [x] AC2: the adapter converts a dad-guard BLOCK into Copilot's JSON+exit-0 contract, allows silently,
    synthesizes a decision if the guard blocked without parsable JSON, and FAILS OPEN when `dad-guard.ps1`
    is absent. Covered by "dad-guard-copilot converts a BLOCK into Copilot's JSON+exit-0 contract".
  - [x] AC3: `uninstall.ps1` removes the hook file against a sandbox and leaves a foreign `dad.json` alone.
    Covered by "uninstall removes the Copilot CLI hook file (sandboxed)".
  - [x] AC4: the measured version cannot drift between C2's stamp and `install.ps1`; `dad-doctor` reads that
    constant rather than duplicating it; neither guard gains a runtime version self-check (C2f).
    Covered by "the measured Copilot version cannot drift between DESIGN's C2 and install.ps1 (C2f)".
  - [x] AC5: end-to-end against LIVE Copilot CLI, not a mock - the Stop guard blocked a real session (the
    model then attempted `dad-guard.ps1 -Ack`, a remediation step named only inside the block message), and
    the loop guard denied a 4th identical SUBAGENT tool call, verified by counting side effects on disk
    (3 lines written for 4 attempts) rather than trusting the agent's self-report.
  - [ ] AC6: `install.cmd -CopilotCli` has been run live on a real machine. DEFERRED per R35(b) - the
    installer mutates state OUTSIDE this project (npm global install, USER PATH, `%USERPROFILE%`) and needs
    explicit human consent before a live run. Step 9's logic was instead verified by its `test-kit.ps1` case
    plus a faithful replay of its exact JSON transformation during the end-to-end test. Same deferral shape
    as S7's AC3; run `install.cmd -CopilotCli` before relying on the Copilot gates on this machine.
- **Dev note (real machine state, per S4/R35):** verification wrote to `%USERPROFILE%\.copilot\` (a hooks
  file and three probe agents) and scaffolded a throwaway project outside the kit. Both were removed
  afterwards and `~/.copilot/` was confirmed returned to stock. Verification mode: **live-sandboxed** for
  AC1-AC5; **deferred, not code-review-only** for AC6 (see above).

### Story S13: gates-smoke proves the LOG is wired, not just the gate   (R38)   <!-- Status: TODO -->
- **Goal:** `dad gates-smoke` gains a FOURTH assertion - after provoking each gate in its own throwaway
  fixture, it asserts that a matching `"decision":"block"` line actually landed in that fixture's
  `grades/gates-log.jsonl` - and `dad-doctor` gains a NEW report of a project's log (size, line count,
  newest-entry age - C3d/C3f).
- **Context:** S8 proves each gate FIRES; S9 gives each gate a log to write to. Neither proves the WRITER
  WIRING between them. That is the one thing that can still fail silently: if a writer never gets the data
  it needs to resolve the project (C3f's worked case - `dad-loopguard.ps1` has never read `cwd`, and a
  writer that skips the append on an empty `cwd` simply never logs), the gate still intercepts, every test
  still passes, and the log still looks clean. Under R38 a gate that cannot be SHOWN to have fired is not a
  gate, so the proof has to be an active assertion, not the absence of an error. This is its OWN unit
  because C3f pins it as new scope against a story that is already DONE/closed: S8 is not reopened and its
  acceptance criteria are not edited after the fact.
- **Behavior:**
  - For each gate `gates-smoke` provokes in its throwaway fixture, read that fixture's
    `grades/gates-log.jsonl` afterwards and require a matching `"decision":"block"` line for that gate.
  - A gate that INTERCEPTED but did NOT log reports `SILENT-FAIL "<gate>-log"` and exits non-zero -
    exactly the same shape as the three existing gate assertions.
  - A gate already reported as SKIP stays a SKIP (never a false pass), and the runtime writers stay silent
    and fail-open: nothing here makes a writer block, warn, or self-check mid-turn.
  - `dad-doctor` gets a NEW gate-log report (T13.2; it has no gate-log code today): the log's size, line
    count (C3d) and newest-entry AGE (C3f).
- **Data / interfaces:** `gates-smoke` (S8's command), each fixture's `grades/gates-log.jsonl` (S9's
  format), `dad-doctor.ps1` (the new C3d/C3f gate-log report, added here), `test-kit.ps1` (new `Test-Case`).
  No gate script's verdict or exit code changes - C3's invariant (i).
- **Dependencies:** **S9** (the log and its line format must exist before smoke can assert a line landed in
  it). S8 is a PREDECESSOR, not a dependency to reopen - its command is extended, its card stays closed.
- **Acceptance (testable):**
  - [ ] AC1: a fixture where a gate fires AND logs is reported as intercepted-and-logged; `gates-smoke`
    exits 0.
  - [ ] AC2: a fixture where a gate fires but its line is MISSING from `grades/gates-log.jsonl` prints
    `SILENT-FAIL "<gate>-log"` (naming the gate) and exits non-zero.
  - [ ] AC3: the assertion matches on the gate name AND `"decision":"block"` - an `allow` line, or a block
    line from a DIFFERENT gate, does not satisfy it.
  - [ ] AC4: `dad-doctor` prints a project's log size, line count and newest-entry age (the new report),
    and handles a project with no log at all without erroring.
  - [ ] AC5: the full validation gate (`test-kit.ps1`) passes, with new `Test-Case`s covering AC2 and AC3
    against sandbox fixtures (a fired-but-unlogged gate must be manufacturable in the test, not simulated
    by editing the assertion).
- **Dev notes:** ORDERING CONSTRAINT - S13 depends on S9 and must not be started before it; the log has to
  exist, with a settled line shape, before smoke can assert a line landed in it. Cite **C3f** in
  `docs/DESIGN.md` (read it directly) for the pinned split: runtime stays silent and fail-open, proof moves
  to smoke/setup time. C3f also records a PREREQUISITE MEASUREMENT that blocks S9's loop-guard writer
  (whether the real `PreToolUse` payload carries `cwd`) - if that measurement forces a fallback, that is a
  NEW `/design` decision, not something to settle inside this story.

### Story S14: [SPIKE] Measure Copilot CLI's MCP, agent/skill and hook-payload surfaces   (R39)   <!-- Status: TODO -->
- **Type:** Measurement spike - no kit code changes. Its output is a MEASURED-FACTS RECORD that `/design`
  turns into contract C5. **C5 stays UNPINNED until a human runs that `/design` step**; no parity story is
  written before then (R39a).
- **Goal:** Settle, against the installed Copilot CLI binary and with its version stamped, the three
  unknowns R39(a) names, so parity stories can be written against facts instead of hypotheses.
- **Context:** R37 admitted Copilot CLI for the two guards only. Under Copilot today `copilot mcp list`
  shows only the built-in GitHub server even though `copilot mcp --help` documents a workspace `.mcp.json`
  (or `.github/mcp.json`) source, the kit's commands and agents install to `%USERPROFILE%\.claude\` only,
  and the R38b gate-log writers were measured against Claude Code's payload alone (T9.5). Vendor docs and
  `--help` text are a starting hypothesis, not a source of truth (R37c). C2 (R37's contract) was measured
  against Copilot CLI 1.0.89 - stamp the version actually measured here and say if it differs.
- **Behavior:** Produce a record (a table per question, same style as C2/T9.5's measured tables) answering:
  1. **MCP:** why this repo's `.mcp.json` does not surface `local-tools` in `copilot mcp list` (schema or
     key names, a trust/approval step, a `type` field, `env` handling), and what configuration DOES make
     the server load and answer a tool call - at user level (`~/.copilot/mcp-config.json`) and at
     workspace level. Record whether a per-project docs path can be supplied without putting a machine
     path in a committed file (R39c).
  2. **Agents and skills:** where Copilot loads custom agents from and in what file format; whether the
     kit's `global\agents\*.md` (frontmatter `name`/`description`/`tools`) load as-is, need a transform, or
     cannot load; whether `global\commands\*.md` can be served as skills (Copilot discovers skills from
     `.claude/skills/`, `.agents/skills/`, `.github/skills/` and `~/.copilot/skills/`) and whether a skill
     can orchestrate subagents the way `/build` does. Record what has NO equivalent.
  3. **Hook payloads:** the real `PreToolUse` and Stop payloads' `cwd` and `session_id` fields (present,
     value shape, and behaviour after an in-session `cd` / launch from a subdirectory), captured from the
     live binary with a temporary hook and then removed - never a hand-written fixture.
- **Data / interfaces:** None in the kit. The record lives in this story's Dev notes (or a pointed-to
  `_tmp/`-free location the human names); nothing is written into DESIGN by this story.
- **Dependencies:** R37 / contract C2 (the measured baseline); R39 (the requirement). No dependency on S9-S13.
- **Acceptance (testable, "record produced and stamped" - not code-tested):**
  - [ ] AC1: the record states the exact `copilot --version` and OS it was measured on.
  - [ ] AC2: question 1 ends in a reproducible command or config that makes `local-tools` appear in
    `copilot mcp list` and answer one tool call, OR states plainly that no such route exists.
  - [ ] AC3: question 2 ends in a per-artifact verdict (loads as-is / needs transform / cannot load) for the
    agents and for the commands, and names anything with no Copilot equivalent.
  - [ ] AC4: question 3 shows a verbatim captured payload (secrets redacted) and states whether `cwd` and
    `session_id` are present, with the loop-guard/dad-guard gate-log writers' dependence on them noted.
  - [ ] AC5: every real-machine change made to take the measurements under `%USERPROFILE%\.copilot\` is
    reverted and confirmed back to stock (R35), and the final line names which verdicts feed C5.
- **Dev notes:** ORDERING - this story blocks every other R39 story; the next `/stories` pass writes the
  parity stories (MCP wiring, agent/skill delivery, gate-log under Copilot, install/uninstall symmetry)
  only AFTER C5 is pinned via `/design`, and only for what was measured to be possible. Sharded into ONE
  task, T14.1 (2026-09-29, at the human's request, so `/build` can reach it): a single human-attended
  measurement like T9.5, not a decomposition. Consent: measuring
  writes to `%USERPROFILE%\.copilot\` (R35b) - use the least-invasive route (`--additional-mcp-config`,
  a scratch project dir) and back out every change.

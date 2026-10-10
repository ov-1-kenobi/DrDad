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

### Story S11: [SPIKE] Should high-stakes verification run as a separate process?   (R32)   <!-- Status: DONE closed:close-unit -->
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
  **No tasks, by design:** S12 has NO entries in `docs/TASKS.md` and needs none - there is nothing left to
  build, so `/taskmap` skipping it (and `doc-stats`' "stories with NO tasks" finding) is expected, not a gap.
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

### Story S13: gates-smoke proves the LOG is wired, not just the gate   (R38)   <!-- Status: DONE closed:close-unit -->
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

### Story S14: [SPIKE] Measure Copilot CLI's MCP, agent/skill and hook-payload surfaces   (R39)   <!-- Status: DONE closed:close-unit -->
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

### Story S15: doc-stats' root-junk check must not flag the kit's own scripts   (R24)   <!-- Status: DONE closed:close-unit -->
- **Goal:** `doc-stats -Findings`' `[hygiene]` ad-hoc-file check (and `dad tidy -Fix`, which acts on it) stops
  treating the kit's own `dad-*.ps1` / `dad-*.cmd` scripts as stray summary files.
- **Context:** S10 shipped `dad-run-summary.ps1` and `dad-run-summary.cmd`. `Get-ProjectJunk` (doc-stats.ps1,
  the `$rootJunk` block under "PROJECT-ROOT JUNK") matches names containing "summary", so on THIS repo
  `doc-stats -Findings` now prints `[hygiene] 2 ad-hoc status/summary file(s) at the project root ...
  dad-run-summary.cmd, dad-run-summary.ps1`, and the finding's own remedy, `dad tidy -Fix`, would act on
  legitimate kit scripts. The S10 hygiene pass reported "no stray files" and missed it - a computed check
  gave the wrong answer and an agent repeated it (S11 Decision, item 2). This is a false positive in a
  computed gate, so the fix is a code fix plus a `Test-Case`, per CLAUDE.md ("add a Test-Case for any bug").
- **Behavior:** files that ARE the kit (a `dad-*.ps1`/`dad-*.cmd` script, or any file listed as tracked kit
  content in the kit's own repo root) are never reported as stray; the real junk classes still are
  (IMPLEMENTATION_SUMMARY.md, STORY_S2_COMPLETE.md, completed_tasks.txt, msbuild.binlog, extra .sln/.slnx,
  path-mangled directories). Decide the narrowest rule that holds (for example: an allow-list of the kit's
  own script prefix, or "only flag when the file is untracked or not a script") and state it in the code.
- **Data / interfaces:** `doc-stats.ps1` (`Get-ProjectJunk`), `tidy` if it shares the helper,
  `test-kit.ps1` (new `Test-Case`).
- **Dependencies:** none.
- **Acceptance (testable):**
  - [ ] AC1: a fixture root holding `dad-run-summary.ps1` and `dad-run-summary.cmd` yields NO `[hygiene]`
    ad-hoc finding, and `dad tidy` (dry run) lists nothing to remove for them.
  - [ ] AC2: the existing junk-class fixture (IMPLEMENTATION_SUMMARY.md, STORY_S2_COMPLETE.md,
    completed_tasks.txt, ...) is STILL flagged - the fix narrows the pattern, it does not disable it.
  - [ ] AC3: `dad doc-stats -Findings` on this repo no longer prints the `[hygiene]` line; the full
    validation gate (`test-kit.ps1`) prints `0 failed`.
- **Dev notes:** the same mistake is possible for any future kit script with "status"/"summary"/"notes" in
  its name - prefer a rule that survives new kit scripts over adding names one at a time.

### Story S16: [SPIKE] Does current Claude Code still run the kit's local models?   (R1, R40)   <!-- Status: DONE closed:close-unit -->
- **Type:** Measurement spike - no kit code changes; its output is a measured record and, if the answer is
  "broken", a proposal for `/design` (a contract amendment or a new story), not a fix made here.
- **Goal:** Settle, against the installed Claude Code and its version stamped, whether the kit's local
  Ollama path (R1: `-cc` model aliases from `models.json`, `use-model`, `ANTHROPIC_MODEL`) still works, and
  why a headless run on 2.1.285 failed.
- **Context:** T10.6 tried a fresh local measurement and Claude Code 2.1.285 rejected
  `--model qwen3-14b-cc` ("isn't described by this version's model catalog") and overrode the
  `ANTHROPIC_MODEL` env var. Older transcripts (2.1.191) show local `-cc` models working. It is unknown
  whether INTERACTIVE use is affected, whether a config key (`modelOverrides` / `modelPicker`, per the
  error text) restores it, and which version introduced the change. This bears on the project's thesis
  (offline by default, R1) and on R40's rule that "latest" must not silently break it.
- **Behavior:** produce a record covering: (1) the exact `claude --version`; (2) what interactive and
  headless `claude` do with a `-cc` alias selected via `use-model`, the env var, `--model` and `/model`;
  (3) the smallest configuration that makes a local model load and answer one prompt, if one exists
  (where it lives - user or project settings, and whether the kit's installer could write it); (4) the
  newest version that still works without configuration, if known; (5) a recommendation for `/design`.
  Scratch runs stay under `_tmp/`; change no global model configuration without consent (R35).
- **Data / interfaces:** none in the kit; the record lives in this story's Dev notes.
- **Dependencies:** none. Feeds Story S17 (R40's smoke check needs to know what "local model resolves"
  means) and any later contract amendment.
- **Acceptance (testable, "record produced and stamped" - not code-tested):**
  - [ ] AC1: the record states `claude --version` and the OS.
  - [ ] AC2: it states plainly whether a local `-cc` model can answer a prompt, interactively and
    headless, and by what exact command or config - or that no route exists on this version.
  - [ ] AC3: any real-machine change made to take the measurement is reverted and confirmed (R35).
- **Dev notes:** ORDERING - do this before Story S17's smoke check is finalized; if the record says local
  is broken on current Claude Code, R40's post-update check must catch exactly that.
  RECORD: lives in grades/S16_GRADE.md (Measured-facts record).

### Story S17: Install reports harness versions and asks before updating   (R40)   <!-- Status: DONE closed:close-unit -->
- **Goal:** each `install.cmd` run prints, for Claude Code and (when present) Copilot CLI, installed vs
  latest vs measured-against versions, asks before updating, warns loudly when the version is newer than the
  contracts were measured against, and runs a smoke check after any update - replacing today's silent
  unconditional `npm install -g @anthropic-ai/claude-code`.
- **Context:** `docs/DESIGN.md` R40 pins the behaviour, including its worked example; read it directly. The
  human chose: check-report-ask (not auto-update), warn-and-continue on drift (not block), and Copilot
  updated only when `copilot` is on PATH and never installed by a default run (`-CopilotCli` stays the
  opt-in). The current code is install.ps1 step 3 (unconditional npm install) and the Copilot version block
  (`$CopilotMeasuredVersion`, C2f). `install.cmd` mutates real machine state (npm global, PATH), so live
  runs need explicit consent (R35b); tests use sandboxes and stubs.
- **Behavior:**
  - Latest version comes from the package registry (`npm view <pkg> version`); an unreachable registry
    prints `latest: unknown (registry unreachable)` and never fails the install.
  - Installed < latest -> ask `update now? [y/N]`; `N` (default) leaves the machine untouched and the
    install continues; `-Yes` is the explicit non-interactive consent flag.
  - No Claude Code installed -> offer the install (first-time). Existing install -> never overwritten
    without the question. Copilot CLI: only if on PATH (or `-CopilotCli`).
  - Installed newer than measured -> print `[harness] ... (newer than measured X) - re-check: hooks/payload
    (C2, T9.5), usage fields (C4a), local model catalog` (warn, never block); `dad-doctor` prints the same.
  - After an update: smoke check (`dad gates-smoke`; the configured local model alias still resolves - per
    Story S16's finding) and, on failure, print the previous version and the exact command to return to it.
    Never auto-roll-back; never lower a security setting to pass a check.
  - A version stamp for Claude Code lives in ONE constant in `install.ps1`, tied to the C4a stamp by a
    `test-kit.ps1` case (the C2f/C4a drift device).
- **Data / interfaces:** `install.ps1` (step 3 + a new harness-versions section), `dad-doctor.ps1`,
  `test-kit.ps1`, docs. No gate script's behaviour changes.
- **Dependencies:** Story S16 (what "local model resolves" means); R40.
- **Acceptance (testable):**
  - [ ] AC1: with stubbed `claude`/`npm`/`copilot` on a sandbox PATH, a run prints the three version columns
    for each present CLI.
  - [ ] AC2: with installed < latest and input `N` (or no answer), nothing is installed and the install
    continues; with `-Yes` or `y`, the update command runs exactly once.
  - [ ] AC3: an unreachable registry prints `latest: unknown` and the install still completes.
  - [ ] AC4: an installed version newer than measured prints the warning naming what to re-check, exits 0.
  - [ ] AC5: `copilot` absent and no `-CopilotCli` -> one skipped line, no install attempt.
  - [ ] AC6: a failing post-update smoke check prints the previous version and the return command, and the
    script does NOT roll back or change any security setting.
  - [ ] AC7: the full validation gate passes; the Claude Code stamp constant and the C4a stamp cannot drift.

### Story S18: Verifier claims are computed or cross-checked, not taken on report   (R32, R24)   <!-- Status: DONE closed:close-unit -->
- **Goal:** the failure class S11's decision named - a same-session verifier's unreliable self-report - is
  closed by computed checks, so the kit no longer depends on an agent's word for what a script can settle.
- **Context:** S11 (Decision, 2026-09-30) kept same-session subagents (Option A) because the observed
  failures were not runaway loops but wrong or shallow reports: a grade card that admitted it never read the
  test bodies and doubted a line that exists, and a hygiene pass that reported a clean root while
  `doc-stats` flagged two files. R24's rule is "never accept an assertion a script can settle"; this story
  applies it to grade cards and hygiene reports.
- **Behavior:**
  - The grade-card gate in `/build` (and `close-unit -RequireGrade`) also checks, mechanically, that the
    card cites at least one TEST name or `test-kit.ps1` line range for the story, and that every
    `file:line` it cites resolves to an existing file with at least that many lines. A card that cites
    nothing checkable FAILS the gate (today: size and three headings only).
  - After hygiene-agent reports, `/build` re-runs `dad doc-stats -Findings` and the suite and compares:
    a clean claim with a `[hygiene]`/`[integrity]` finding present is relayed as CONTRADICTED and blocks the
    close until resolved.
  - Grading prompts stay neutral: the orchestrator passes the story and its evidence pointers, not its own
    list of suspected defects (recorded as a convention in `build.md`).
- **Data / interfaces:** `close-unit.ps1` (`-RequireGrade` check), `global\commands\build.md` (gate text and
  the neutral-prompt convention), `test-kit.ps1`. Re-run `install.cmd` after editing global commands.
- **Dependencies:** none (Story S15 fixes the false positive this check would otherwise inherit).
- **Acceptance (testable):**
  - [ ] AC1: a stub-with-headings card citing no test or file:line FAILS the `-RequireGrade` gate; a card
    citing a real test name and resolvable file:line passes.
  - [ ] AC2: a card citing `file.ps1:99999` (beyond EOF) or a missing file FAILS.
  - [ ] AC3: `build.md` instructs the re-check of `doc-stats -Findings` after hygiene and names a
    CONTRADICTED report as blocking; a prompt-content `Test-Case` proves the text landed.
  - [ ] AC4: the full validation gate passes and existing grade cards still pass (or are listed as needing a
    one-line backfill - decide and state which).
- **Dev notes:** keep the check cheap and deterministic; it must not judge quality, only that the card
  points at things a script can verify.

### Story S19: A stale or empty LOCALTOOLS_DOCS_DIR must not hide the project's real docs   (R24)   <!-- Status: DONE closed:close-unit -->
- **Goal:** a `LOCALTOOLS_DOCS_DIR` override in `.mcp.json` is honoured only when that folder actually holds
  the project's docs; otherwise the kit scripts fall back to `<project>\docs` and say so, so a computed
  state check never reports an empty project because it read the wrong folder.
- **Context:** observed 2026-09-30. `doc-stats.ps1` (~lines 98-104) replaces `$docs` with `.mcp.json`'s
  `LOCALTOOLS_DOCS_DIR` whenever that path merely EXISTS. The kit's dev-path placeholder
  `C:\Projects\Claude\MCP\DAD-kit\docs` had an empty folder (with an empty `.index`) created by the
  local-tools MCP server on reconnect; `doc-stats` then reported "no design doc, 0/0 stories, 0/0 tasks" for a
  LOCKED 12/18-story project. That broke `/build` Gate 3, and the STATUS reindex pointed at the same empty
  folder. A computed check gave a confidently wrong answer (R24: state findings are computed, and must be
  computed from the right place). Only `Test-Path` was asked; "exists" is not "is the project's docs".
- **Behavior:**
  - ONE shared rule (a small helper, dot-sourced or otherwise reused, not per-script variants): an override
    dir counts only if it contains `DESIGN.md` or `TEDD.md` or `STORIES.md`.
  - Override fails the rule (missing, empty, or no project docs) -> use `<project>\docs` and print ONE
    visible line `WARN: ignoring LOCALTOOLS_DOCS_DIR <path> (no DESIGN/TEDD/STORIES there); using <project>\docs`.
  - Override passes the rule -> honoured exactly as today, no warning.
  - Apply the rule to every kit script that reads this key the same way: check `doc-stats.ps1`,
    `docs-find.ps1`, `close-unit.ps1`, `dad-doctor.ps1`, and `corpus.ps1` (which deliberately points at a
    research corpus - confirm whether the rule fits before touching it). Fix those with the same flaw.
- **Data / interfaces:** `doc-stats.ps1`, plus whichever of the scripts above share the flaw; the shared
  helper; `test-kit.ps1`. NOT changed: the placeholder in `.mcp.json` (CLAUDE.md convention), and the MCP
  server still creates its docs folder (no C# change).
- **Dependencies:** none.
- **Acceptance (testable):**
  - [ ] AC1: a fixture whose `.mcp.json` override points at an existing EMPTY dir makes `doc-stats` read the
    project's own docs (correct design/story/task counts) and print the WARN line naming the ignored path.
  - [ ] AC2: an override dir that holds real docs (for example a `STORIES.md`) is still honoured, with no
    WARN.
  - [ ] AC3: a `test-kit.ps1` `Test-Case` covers both on fixtures (and each other script fixed gets its
    case or shares the helper's).
  - [ ] AC4: the full validation gate (`test-kit.ps1`) prints `0 failed`.
- **Dev notes:** an existing test (docs-find fallback when the configured dir does not exist, test-kit ~line
  1917) covers only the "missing" case; extend the same rule rather than adding a second one. The
  `$env:LOCALTOOLS_DOCS_DIR` set by `corpus.ps1` for a research corpus is a legitimate non-project dir - do
  not break it.

### Story S20: The local-tools MCP server must not index an empty placeholder docs dir either   (R24)   <!-- Status: DONE closed:close-unit -->
- **Goal:** the C# server applies S19's docs-dir rule to its PRIMARY root, so `index_datasheets` and
  `search_datasheets` never silently run against an empty placeholder folder.
- **Context:** observed 2026-09-30 during `/audit`. S19 added the shared `Resolve-DocsDir` rule
  (`docs-dir.ps1`) for the kit SCRIPTS only. `local-tools/Rag.cs` `BuildRoots()` (~line 49) still takes
  `LOCALTOOLS_DOCS_DIR` as-is, and `IndexDir`/`WebDir` derive from `BuildRoots()[0]`. The kit repo's own
  `.mcp.json` must keep the dev-path placeholder `C:\Projects\Claude\MCP\DAD-kit\docs` (test-kit.ps1 ~735
  asserts it), so in the kit repo `index_datasheets` reported "No documents" and `search_datasheets` searched
  nothing. Worked around with a local-scope `claude mcp add -s local` override (not in the repo).
- **Behavior:**
  - Predicate: a dir counts only if it contains `DESIGN.md` or `TEDD.md` or `STORIES.md` or `CORPUS.md`
    (`CORPUS.md` marks a `/corpus` folder, see `corpus.ps1 new`). This extends S19's predicate for the
    SERVER only; `docs-dir.ps1` is unchanged.
  - Scope: the rule applies ONLY when the primary root comes from the `LOCALTOOLS_DOCS_DIR` env var (MCP
    server start, or a CLI mode run with no path arg, e.g. `corpus.ps1`'s `--search`, which sets the env
    var to a corpus folder - safe via `CORPUS.md`). A path given EXPLICITLY as a CLI arg (`--reindex <dir>`,
    `--ingest <url> <dir>`, `--corpus <dir>`) is used as-is - no check, no warning.
  - Primary root fails the predicate AND `<cwd>\docs` passes -> `<cwd>\docs` becomes primary, and ONE line
    `WARN: ignoring LOCALTOOLS_DOCS_DIR <path> (no DESIGN/TEDD/STORIES/CORPUS there); using <cwd>\docs` goes to
    STDERR (never stdout - stdout is the MCP protocol channel).
  - Primary passes -> honoured as today, no warning. Primary fails and `<cwd>\docs` also fails -> keep the
    primary as today, no crash.
  - Additional `;` roots are unchanged. No env var set -> the existing datasheets fallback is unchanged.
  - No `.index` (or `web`) folder is created under a rejected override (that empty-folder creation caused
    S19's original incident).
- **Data / interfaces:** `local-tools/Rag.cs` (`BuildRoots`, `IndexDir`/`WebDir` init, `CreateDirectory`
  calls ~371-372), `local-tools/Program.cs` CLI entry points (`--corpus` ~line 50, `--reindex`, `--ingest`),
  `test-kit.ps1`. Not changed: the `.mcp.json` placeholder (CLAUDE.md convention). Re-run `install.cmd`.
- **Dependencies:** Story S19 (the rule being mirrored).
- **Acceptance (testable in `test-kit.ps1` Test-Cases via `local-tools.exe --corpus` with NO path arg +
  `LOCALTOOLS_DOCS_DIR` + a working directory, so the rule is exercised; needs no Ollama):**
  - [ ] AC1: placeholder primary + cwd with `docs\DESIGN.md` -> the cwd docs are the listed primary and
    stderr carries the WARN line; stdout carries no WARN.
  - [ ] AC2: a valid override holding `DESIGN.md` -> honoured, no warning.
  - [ ] AC3: override invalid and cwd has no `docs` -> behaves as today (keeps the primary), exit 0, no crash.
  - [ ] AC4: no `.index` folder is created under a rejected override.
  - [ ] AC5: with a multi-root `;` value, the secondary roots are still listed by `--corpus`.
  - [ ] AC6: `dotnet build` and the full `test-kit.ps1` pass with `0 failed`.
  - [ ] AC7: an env-var primary holding only `CORPUS.md` (cwd has `docs\DESIGN.md`) -> honoured, no warning.
  - [ ] AC8: `--corpus <dir>` with an explicit path arg and no marker -> used as-is, no warning, even when
    `<cwd>\docs` is valid.
- **Dev notes:** DECIDED 2026-09-30 (human): predicate adds `CORPUS.md` (server only; `docs-dir.ps1`
  unchanged); explicit CLI path args (`--reindex <dir>`, `--ingest <url> <dir>`, `--corpus <dir>`) bypass
  the rule; it applies only to an env-var-sourced primary. Note `Program.cs` currently passes explicit args
  by SETTING `LOCALTOOLS_DOCS_DIR` (lines ~11, 27, 55), so the server must carry an "explicit" flag rather
  than infer it from the env var.

### Story S21: A skipped test-kit case must be COUNTED as skipped, never as a pass   (R24)   <!-- Status: DONE closed:close-unit -->
- **Goal:** a `test-kit.ps1` case that runs nothing reports SKIP with a reason and is counted separately, so
  the pass count means "ran and passed" and a missing build artifact on a full run is a failure.
- **Context:** observed 2026-09-30 in S20's QA and grade (`grades/S20_GRADE.md`). Several cases begin with
  `if ($SkipBuild) { return }` or `if (-not (Test-Path $exe)) { return }` (e.g. the S20 case ~test-kit.ps1
  2846-2848, the S19 case, the multi-root corpus case ~2813, ~4466). An early return inside `Test-Case`
  prints PASS, so `-SkipBuild` reports e.g. "231 passed" where some ran nothing, and a missing exe on a FULL
  run passes silently. close-unit's "zero tests = refuse" rule cannot see it: the count is inflated, not
  zero (R24: a computed gate must count what actually ran).
- **Behavior:**
  - `Test-Case` gains a way for a case to declare a skip with a reason (e.g. a `Skip-Case "<reason>"` helper
    or a returned sentinel). A skipped case prints `SKIP  <name> - <reason>` and is counted separately.
  - The summary line becomes `== N passed, M failed, K skipped ==`.
  - Under a FULL run (no `-SkipBuild`), a case skipping because the built exe is missing is a FAIL, not a
    skip (the build step just ran, so a missing exe is a real defect).
  - Every existing early-return-on-`$SkipBuild`/missing-exe case is converted.
  - close-unit's test-count parser (`close-unit.ps1` ~line 188, `(\d+)\s+passed`) keeps working with the
    new summary, and zero PASSED with some skipped still refuses.
- **Data / interfaces:** `test-kit.ps1` (`Test-Case`, summary line, converted cases), `close-unit.ps1`
  (count parsing, only if needed).
- **Dependencies:** none (S20 is where it was noticed).
- **Acceptance (testable):**
  - [ ] AC1: a `-SkipBuild` run prints SKIP lines for the build-dependent cases and a nonzero skipped count;
    their names no longer appear as PASS.
  - [ ] AC2: a full run reports `0 skipped` on a healthy machine.
  - [ ] AC3: a fixture/self-test where the exe path is absent on a full run FAILS the case.
  - [ ] AC4: a grep finds no remaining `{ return }` early-exit on `$SkipBuild` / exe-missing inside
    `Test-Case` bodies.
  - [ ] AC5: close-unit still parses the totals from the new summary, and refuses a run with 0 passed.
  - [ ] AC6: the full `test-kit.ps1` prints `0 failed`.
- **Dev notes:** keep the skip mechanism one helper, not per-case variants; the reason string is required.

### Story S22: doc-stats flags a contract that is REFERENCED but never PINNED   (R24)   <!-- Status: DONE closed:close-unit -->
- **Goal:** `doc-stats.ps1 -Findings` compares the contract ids the docs REFERENCE against the ids the design
  doc PINS, and WARNs on every reference that resolves to no contract heading.
- **Context:** observed 2026-10-01 in `/audit`. DESIGN.md R39(a) promised "a new contract (C5)" from the S14
  spike; S14 closed DONE with the measurements in its grade card, and C5 was never written into
  `## Contracts`. Nothing caught it for days - only the librarian's prose read did. Today doc-stats has
  `-Contract <id>` (on-demand lookup of one id) and the "LOCKED with an EMPTY Contracts section" finding
  (`doc-stats.ps1` ~237-242), but nothing compares referenced ids with pinned ids. "Does the heading exist"
  is a grep, so it belongs in the script, not in a model's read (R24).
- **Behavior:**
  - Pinned ids = headings matching the EXISTING regex `^#{2,4}\s*(C[0-9]+[A-Za-z0-9-]*)\s*:` in the design
    doc (DESIGN.md or TEDD.md). Reuse it (~line 238); do not write a second one.
  - Referenced ids = tokens matching `\bC[0-9]+[a-z]?(?:-[a-z0-9]+)?\b` (case-sensitive) in the design doc,
    STORIES.md and TASKS.md. It must NOT match `C2PA`, `C#` or `C++`. Grade cards are history and are NOT
    scanned.
  - A reference resolves if its exact id is pinned, OR its parent id (the leading `C<digits>`) is pinned:
    `C4a` -> `C4`, `C3-b` -> `C3`. Sub-contracts are often referenced before or without their own heading.
  - Gated on the design having a `## Contracts` section (the same gate as the empty-Contracts finding), so a
    design that deliberately has none stays silent. Fires in DRAFT and LOCKED alike (in DRAFT it is a to-do
    list; in LOCKED it is a contract gap).
  - Finding (WARN, tag `[design]`): `[design] N contract id(s) are REFERENCED but never PINNED in <design>:
    C5 (DESIGN.md:472, STORIES.md:613) ... - pin them via /design (unlock -> architect-agent -> relock), or
    fix the reference.` At most the first location per file per id; the id list is capped at 8.
  - Silent when every reference resolves.
- **Data / interfaces:** `doc-stats.ps1` (`-Findings` block), `test-kit.ps1` (new `Test-Case`, sandbox
  fixtures in the style of the doc-stats cases, e.g. the Build-order dangling-id case ~test-kit.ps1:4110).
  Not changed: `-Contract <id>`, the empty-Contracts finding, DESIGN.md.
- **Dependencies:** none to build. AC5 (the kit repo silent) needs C5 pinned in DESIGN.md via `/design`.
- **Acceptance (testable):**
  - [ ] AC1: a fixture with `C1` pinned and `C5` referenced in DESIGN and STORIES -> the finding names `C5`
    with both locations (file:line).
  - [ ] AC2: a fixture with `### C4:` pinned, no `#### C4a:` heading, and `C4a` referenced -> silent.
  - [ ] AC3: prose containing `C2PA` and `C#` (and `C++`) -> silent.
  - [ ] AC4: a design with no `## Contracts` section -> silent, even with dangling references.
  - [ ] AC5: the real kit repo, once C5 is pinned -> no dangling-id finding.
  - [ ] AC6: the full `test-kit.ps1` prints `0 failed`.
- **Dev notes:** STORIES.md itself is scanned, so this story's own examples were chosen to resolve in the
  kit (`C4a`, `C3-b` have pinned parents; `C5` is the gap AC5 waits on). The finding is computed state, so
  it goes into the `$f` list like the other `[design]` findings (dad-run-summary counts it).

### Story S23: An acknowledged FOUNDATIONAL security waiver stops the auth-keyword WARN until NEW mentions appear   (R24)   <!-- Status: DONE closed:close-unit -->
- **Goal:** a human-dated confirmation line in the design header silences doc-stats' auth-keyword
  admissibility WARN while the keyword count has not grown, and re-fires it the moment it does.
- **Context:** observed 2026-10-01 in `/audit`. The admissibility check (`doc-stats.ps1` ~271-283) WARNs
  whenever `Security review: NOT-REQUIRED` coexists with `\b(auth|login|password|token|session)\b` in the
  design doc or STORIES.md. On this kit it fires every audit, although the human re-confirmed the waiver on
  2026-09-29 and on 2026-10-01 declared it FOUNDATIONAL (DESIGN header + `## Out of scope` "Handling
  security"). A finding that fires on settled input is noise; silencing it permanently would hide a future
  auth feature. DECIDED (human): acknowledge, and re-fire on growth.
- **Behavior:**
  - New optional design-doc header line, next to `Security review:`:
    `Security waiver confirmed: <YYYY-MM-DD> (human; auth-keyword hits: <N>)`.
  - Count M = the number of matches of the SAME pattern (`$authKw`, case-insensitive) over the design doc
    raw text PLUS STORIES.md raw text, EXCLUDING the design doc's `Security waiver confirmed:` line itself
    (the line this check parses) - a match count, not a presence test. The exclusion is required: that
    line contains `auth`, so counting it would make M = N+1 the moment the printed line is added and
    re-fire forever. The message and the check use this one definition.
  - Honoured only when `Security review:` is NOT-REQUIRED. Under REQUIRED or DONE the line is ignored and
    the existing findings are unchanged.
  - Valid line and M <= N -> no WARN; instead an UNTAGGED line in the `== STATE FACTS ==` block:
    `security waiver: confirmed <YYYY-MM-DD> at <N> auth-keyword hits (now <M>) - not re-raised` (no leading
    `[tag]`, per the Dev-notes decision 2026-10-01). It is NOT a finding: it does not go into `$f` and is
    not counted in dad-run-summary's findings figure.
  - Valid line and M > N -> the existing WARN fires, extended with `- <M-N> new auth-keyword mention(s)
    since the <date> confirmation; re-confirm by updating the line to: Security waiver confirmed: <today>
    (human; auth-keyword hits: <M>)`.
  - No confirmation line -> the existing WARN fires and also prints the exact line to add with the current
    M, so nobody counts by hand.
  - Malformed line (bad date, missing N) -> the WARN fires and says the confirmation line is malformed.
    Never silently honoured.
  - Writing or updating the line is a DESIGN edit: it goes through `/design` (unlock), by the human. Agents
    never write it on their own.
- **Data / interfaces:** `doc-stats.ps1` (`-Findings`, admissibility block), `test-kit.ps1` (new
  `Test-Case`, sandbox fixtures in the style of the doc-stats cases ~test-kit.ps1:4110); possibly
  `dad-run-summary.ps1` (see Dev notes). Not changed: DESIGN.md (the human adds the line via `/design`).
- **Dependencies:** none.
- **Acceptance (testable):**
  - [ ] AC1: fixture NOT-REQUIRED + 3 hits + no confirmation line -> WARN containing `auth-keyword hits: 3`.
  - [ ] AC2: confirmation N=3 and 3 hits (the confirmation line's own `auth` not counted) -> no WARN; the
    untagged `security waiver: confirmed ...` STATE FACTS line is present. Same fixture, the line added
    exactly as AC1's WARN printed it -> still silent.
  - [ ] AC3: confirmation N=3 and 5 hits -> WARN naming 2 new mentions and the re-confirm line with 5.
  - [ ] AC4: malformed confirmation line -> WARN says it is malformed.
  - [ ] AC5: `Security review: REQUIRED` with a confirmation line -> line ignored; the REQUIRED finding is
    unchanged.
  - [ ] AC6: on the AC2 fixture, dad-run-summary's findings figure does not count the untagged
    `security waiver: confirmed ...` STATE FACTS line.
  - [ ] AC7: the full `test-kit.ps1` prints `0 failed`.
- **Dev notes:** doc-stats has no info channel today - only `$f` findings and the STATE FACTS block. And
  `dad-run-summary.ps1:147` counts every line matching `^\s*\[[a-z]+\]`, so a printed `[info] ...` line
  WOULD be counted as a finding. DECIDED 2026-10-01 (orchestrator, conventional default): emit the info
  inside the STATE FACTS block WITHOUT a leading `[tag]` (e.g. `  security waiver: confirmed <date> at <N>
  auth-keyword hits (now <M>) - not re-raised`); dad-run-summary is NOT changed. AC6 holds by that. Note
  this story and the regex itself add keyword hits to STORIES.md, so the kit's N is counted after it lands.

### Story S24: The local-model probe SHOWS the unrecognized_model warning instead of discarding it   (R40)   <!-- Status: DONE closed:close-unit -->
- **Goal:** the post-update local-model probe prints Claude Code's `unrecognized_model` warning as a WARN
  (still a PASS), and a smoke run whose local-model check was skipped never reports an unqualified pass.
- **Context:** `/audit` 2026-10-01 + `/design` C4a OPEN-4, chosen by the human. `harness-versions.ps1`
  `Test-LocalModelResolves` (~line 115) runs `claude -p ... --model <cc> --output-format json` with
  `2>$null`, so Claude Code 2.1.285's `[claude-code:unrecognized_model]` warning (S16 record,
  `grades/S16_GRADE.md`) is silently dropped. That warning carries the hazard: Claude Code assumes a
  200000-token window while Ollama serves 40960. Separately, `Invoke-PostUpdateSmoke` prints
  "local-model check skipped (...)" (~153) and then "smoke check passed" (~164) - an unqualified pass over a
  check that did not run (same principle as S21).
- **Behavior:**
  - The probe captures stderr instead of discarding it. When stderr contains `unrecognized_model`, print
    `[harness] local model <cc>: WARN unrecognized_model (Claude Code assumes a 200000 context window;
    Ollama serves <ctx if known, else 'unknown'>)` and still return PASS (WARN, never FAIL - C4a).
  - Any other stderr content: behaviour unchanged (it does not alter the PASS/FAIL outcome).
  - When the local-model check was SKIPPED, the final line names it, e.g.
    `[harness] <name> smoke check passed (local-model check SKIPPED: <reason>)` - never a bare
    "smoke check passed". A PASS or a non-claude-code harness keeps the existing line.
  - Unchanged: the probe already uses a local -cc model (the `fast` alias) per R40(d); the
    `DAD_SMOKE_LOCALMODEL` test hook; FAIL handling and the rollback hint.
- **Data / interfaces:** `harness-versions.ps1` (`Test-LocalModelResolves`, `Invoke-PostUpdateSmoke`),
  `test-kit.ps1` (new `Test-Case`s using the sandbox/stub style of the harness cases ~test-kit.ps1:1655).
  Not changed: DESIGN.md, settings, models.json.
- **Dependencies:** none (S16 measured the warning; S17 added the probe).
- **Acceptance (testable):**
  - [x] AC1: a stubbed `claude` writing the `unrecognized_model` warning to stderr and valid JSON (non-empty
    result, `modelUsage` keyed by the -cc name) to stdout -> the WARN line is printed and the probe is PASS.
  - [x] AC2: the same stub without the warning -> PASS and no WARN line.
  - [x] AC3: Ollama unreachable -> the probe is SKIP and the final smoke line names the skip and its reason.
  - [x] AC4: the full `test-kit.ps1` prints `0 failed`.
- **Dev notes:** the probe checks Ollama reachability with a live request to localhost:11434 before it calls
  `claude`, so AC1/AC2 need a test seam for reachability (keep it env-only like the existing hooks).
  QUESTION (human): the source of `<ctx>` is not pinned. models.json `numCtx` is 65536 but S16 measured
  40960 served, so the manifest is not a reliable proxy; until decided, print `unknown`. Refs: DESIGN C4a
  (S16 amendment / OPEN-4 decision), R40(d). ANSWERED 2026-10-03 (DESIGN C4a OPEN-4(b)): the shipped code
  and the AC1 test's literal `Ollama serves unknown` are the pre-decision behavior; follow-up tasks T24.5
  (code) and T24.6 (tests) implement the decision and update that test text. S24 stays DONE; AC1-AC4 are
  not reworded or unticked.

### Story S25: The Copilot version drift test checks EVERY measured stamp, not just the first   (R37, R40)   <!-- Status: DONE closed:close-unit -->
- **Goal:** the C2f drift case asserts that EVERY `MEASURED <date> against GitHub Copilot CLI <v>` stamp in
  DESIGN.md equals `$CopilotMeasuredVersion`, so C5's stamp cannot drift silently.
- **Context:** `/design` 2026-10-01 OPEN-3, chosen by the human (DESIGN C5f): ONE constant,
  `$CopilotMeasuredVersion` (defined at `install.ps1:32`), covers both C2 and C5. The current case
  (`test-kit.ps1` ~1562-1578, "the measured Copilot version cannot drift ...") uses `[regex]::Match`, so it
  checks only the FIRST stamp (C2's); a second stamp (C5's) is never compared.
- **Behavior:**
  - The case collects ALL stamps in DESIGN.md with the existing stamp regex (`[regex]::Matches`, not
    `Match`) and asserts each equals `$CopilotMeasuredVersion`.
  - A mismatch FAILS and names the offending stamp's line and both versions (e.g. `DESIGN.md:<line>
    stamped 1.0.89 != 1.0.95`).
  - Zero stamps FAILS (never passes vacuously).
  - Unchanged: reading the constant from `install.ps1`, the dad-doctor read-not-copy assertions.
- **Data / interfaces:** `test-kit.ps1` (the C2f case, plus fixture cases). Not changed: DESIGN.md,
  `install.ps1`, `dad-doctor.ps1`.
- **Dependencies:** none.
- **Acceptance (testable):**
  - [x] AC1: fixture with two stamps both equal to the constant -> pass.
  - [x] AC2: fixture whose SECOND stamp mismatches -> fail, message names that stamp's line.
  - [x] AC3: fixture with zero stamps -> fail.
  - [x] AC4: the real kit repo DESIGN.md -> pass.
  - [x] AC5: the full `test-kit.ps1` prints `0 failed`.
- **Dev notes:** to fixture-test it, factor the stamp check into a small function taking the doc text and the
  constant, called by the real-repo case and the fixture cases. Keep the existing regex (it already ignores
  the `against Claude Code` stamp at C4) and compute the line from the match index. Today the real doc
  holds two Copilot stamps (C2 ~DESIGN.md:682, C5 ~1307). Refs: DESIGN
  C2f, C5f (worked example: C2 bumped to 1.0.95, C5 left at 1.0.89 -> FAIL naming C5's stamp).

### Story S26: upgrade-project refuses to run against a kit checkout   (R15)   <!-- Status: DONE closed:close-unit -->
- **Goal:** `upgrade-project` detects that its target is a DrDad kit checkout and exits without changing
  anything, so the kit repo is never "retrofitted" as if it were a project.
- **Context:** observed 2026-10-01. upgrade-project was run against the kit repo `D:\projects\DrDad`
  itself. Step 0b (`upgrade-project.ps1` ~59-79) repoints `.mcp.json` `command` at `$kit = $PSScriptRoot`'s
  `local-tools.exe` - here the repo build - silently undoing the deliberate CLAUDE.md exception (the kit
  repo's `.mcp.json` runs the INSTALLED copy so a kit chat never file-locks the repo build). The stale
  pointer launched two `local-tools.exe` processes from the repo `bin\`, and the suite's build case failed
  with MSB3026 until they were stopped. It also restamped `.dad-kit-version` and rewrote CLAUDE.md with
  CRLF line endings (step 3 section refresh ~166-227, `WriteAllText` of a CRLF string), which test-kit's
  line-ending check rejects. The kit repo is not a DAD project; it is the kit.
- **Behavior:**
  - Before ANY write, resolve `-ProjectDir`; if it contains `install.ps1` AND `VERSION` AND
    `global\commands\` (the kit's own markers), it is a kit checkout.
  - Detection works whether the script runs from that same folder or from an installed copy elsewhere
    (e.g. `D:\Tools\DrDad` against `D:\projects\DrDad`) - it keys on the TARGET, not `$PSScriptRoot`.
  - On a kit checkout: print ONE line - `<dir> is a DrDad kit checkout, not a project - upgrade-project
    does not retrofit the kit; use install.cmd to deploy it` - change NOTHING (no `.mcp.json`, CLAUDE.md,
    `docs/`, `.gitignore`, git, version stamp), and exit 2 so a script caller notices.
  - Normal projects (no kit markers) are unaffected.
- **Data / interfaces:** `upgrade-project.ps1` (an early guard before step 0b); `test-kit.ps1` (fixture
  cases). Exit code 2 = refused, kit checkout. Not changed: DESIGN.md, `install.ps1`.
- **Dependencies:** none.
- **Acceptance (testable):**
  - [x] AC1: sandbox with the three kit markers + a CLAUDE.md + `.mcp.json` -> exit 2, the message, and
    every file byte-identical afterwards (hash before/after).
  - [x] AC2: same result when upgrade-project is invoked from a different directory than the target
    (installed-copy case).
  - [x] AC3: a normal sandbox project (CLAUDE.md, no kit markers) still upgrades as before (existing
    upgrade-project test cases keep passing).
  - [x] AC4: the suite does NOT run it against the real kit repo (`D:\projects\DrDad`) - fixtures only.
  - [x] AC5: the full `test-kit.ps1` prints `0 failed`.
- **Dev notes:** put the guard first, before any step that touches the filesystem or git, so "changes
  NOTHING" holds by construction. All three markers are required (one alone is too weak a signal for a
  user project). The CRLF rewrite of CLAUDE.md in step 3 is a separate defect for normal projects too; it
  is out of scope here - ANSWERED 2026-10-03: filed as Story S27 (DONE). Refs: DESIGN R15.

### Story S27: upgrade-project writes the files it refreshes with the project's line endings, not CRLF   (R15)   <!-- Status: DONE closed:close-unit -->
- **Goal:** an upgrade changes only the content it means to change; each file it rewrites keeps the line
  endings the project already uses, so an upgrade never shows up as a whole-file line-ending diff.
- **Context:** observed 2026-10-01 (S26 Dev notes open question; human-approved as a story 2026-10-01).
  `upgrade-project.ps1` step 3 CLAUDE.md section refresh (~181-242) joins its lines with "`r`n" and writes
  them with `WriteAllText`; the version stamp write (~244) hardcodes "`r`n"; the step 0b `.mcp.json`
  repoint (~89) writes `ConvertTo-Json` output, which is CRLF on Windows PowerShell. In a project whose
  `.gitattributes` sets `eol=lf`, every upgrade turns CLAUDE.md into a whole-file CRLF diff (content
  unchanged) and can trip a line-ending check; on the kit repo the same rewrite failed test-kit's
  line-ending case. Note: `templates\_common` ships no `.gitattributes` today (the kit repo has its own),
  so most scaffolded projects declare no `eol` - the LF default below covers them.
- **Behavior:**
  - For each file upgrade-project rewrites (CLAUDE.md, `.mcp.json`, `.dad-kit-version`): if it already
    exists, detect LF vs CRLF from its current content and write the new text with that same ending,
    uniformly (no mixed endings).
  - A file created fresh follows the project's `.gitattributes` `eol` if one is declared for it, else LF.
  - The `.gitignore` writes in step 2 follow the same rule: an existing `.gitignore` keeps its ending and
    each appended block uses it uniformly (the user's existing lines are never rewritten); a fresh
    `.gitignore` follows `.gitattributes` `eol`, else LF.
  - Appended `.gitignore` entries start on their own line: when an existing non-empty `.gitignore` does
    not end with a newline, one line break in the file's own ending is written first (T27.5). A file that
    already ends with a newline, or an empty one, gets no separator.
  - A file that already mixes LF and CRLF is treated as CRLF when it contains any CRLF (human decision
    2026-10-03, rule kept). A rewritten file comes out uniformly CRLF; in `.gitignore` only the appended
    block is uniform.
  - An existing file with no newline at all is handled by the fresh-file rule (`.gitattributes` `eol`,
    else LF).
  - Content is otherwise unchanged (same sections refreshed, same JSON, same stamp value, same
    `.gitignore` entries in the same order).
  - Only these writes change: the step 0b `.mcp.json` repoint, the step 2 `.gitignore` writes, the step 3
    CLAUDE.md refresh and the version stamp. No other step changes; the S26 kit-checkout guard stays first.
- **Data / interfaces:** `upgrade-project.ps1` (line-ending helpers `Get-ProjectEol` and `ConvertTo-Eol`,
  used by the CLAUDE.md, `.mcp.json`, `.dad-kit-version` and `.gitignore` writes; `Get-GitignoreLead` for
  the `.gitignore` appends); `test-kit.ps1` (fixture cases). Not changed: DESIGN.md, `new-project.ps1`,
  templates.
- **Dependencies:** S26 (same script; its guard stays first).
- **Acceptance (testable):**
  - [x] AC1: sandbox project with an LF CLAUDE.md -> after upgrade, CLAUDE.md contains no CR bytes and
    its kit-owned sections are refreshed.
  - [x] AC2: sandbox project with a CRLF CLAUDE.md -> stays CRLF throughout (every line ends CRLF, no
    bare LF).
  - [x] AC3: the `.mcp.json` repoint and `.dad-kit-version` follow the same rule (existing ending kept;
    fresh file -> `.gitattributes` `eol` if declared, else LF).
  - [x] AC4: the existing upgrade-project cases (including S26's) still pass.
  - [x] AC5: the full `test-kit.ps1` prints `0 failed`.
  - [x] AC6: `.gitignore` follows the same rule (existing ending kept; fresh file -> `.gitattributes`
    `eol` if declared, else LF), and an appended entry is never glued onto an unterminated last line
    (test-kit cases "S27 follow-up: .gitignore keeps its line ending" and "S27 follow-up: an appended
    .gitignore entry is never glued onto an unterminated last line"; added 2026-10-03 with T27.4/T27.5).
- **Dev notes:** fixtures only under `%TEMP%`; never run upgrade-project against the kit repo
  (`D:\projects\DrDad`) or `D:\Tools`. Detect the ending from raw bytes (`ReadAllText` + `Contains("`r`n")`),
  not `Get-Content`, which strips endings. Same bug class as the LF fixes in close-unit.ps1 (~244) and
  doc-stats.ps1 (~813). `.gitignore` was left out of T27.1 on purpose (its Touches excluded the step-2
  writes); follow-up cleanup tasks T27.4 (line-ending rule) and T27.5 (no glued append), both
  human-approved, added it on 2026-10-03 without reopening S27 (it stays DONE). Refs: DESIGN R15.

### Story S28: DESIGN's Goal, R34, R37(b) and Out of scope are reconciled with the cloud-first mission   (Goal, R1, R34, R37)   <!-- Status: DONE closed:close-unit -->
- **Goal:** `docs/DESIGN.md` no longer says offline-first is "the DEFAULT and the thesis". It states the
  restated mission: a working implementation of the loop-engineering shape (spec before code, a verifier that
  checks real correctness, persistent context across sessions) enforced by deterministic gates, with Cloud the default,
  Local kept as a resilience mode, and Hybrid as the cloud loop plus the GPU.
- **Context:** README.md, the Field Manual and the video bible were restated in v0.58.0 (CHANGELOG 0.58.0).
  DESIGN.md is LOCKED and was deliberately NOT edited there, so these passages now contradict the mission. The
  thesis, "never accept an assertion a script can settle", is unchanged. This story needs a `/design` pass (the
  unlock flow); it must not be worked by `/spec` or `/build` while DESIGN is LOCKED.
- **Behavior:** the contradicting passages, by line number at the time of writing (re-check; lines drift):
  - `docs/DESIGN.md:4` - the Security review reason says "Local-only dev CLI". Cloud is the default.
  - `docs/DESIGN.md:9-14` (`## Goal`) - "fully offline", "No Anthropic account; offline after first setup",
    "Offline is the DEFAULT and the thesis; the same loop can opt into a cloud or hybrid backend (R34)".
  - `docs/DESIGN.md:26-27` (R34) - "Offline-first (R1) is the DEFAULT and the thesis; two opt-in alternate
    backends". Cloud is the default, not an "alternate"; Local is the resilience mode.
  - `docs/DESIGN.md:417-422` (R37b) - "The offline thesis survives, or the harness is out of scope"; rejects a
    harness with no offline path "on that ground". Copilot CLI is now a pilot and unverified, not a gate on the
    mission.
  - `docs/DESIGN.md:495-496` (R37e) - "Same offline thesis (R37b)".
  - `docs/DESIGN.md:506` (R40) - "how the offline path (R1) behaves - this project's thesis".
  - `docs/DESIGN.md:768-773` (C2e) - "the R37(b) thesis check"; Copilot is in scope only because of an offline path.
  - `docs/DESIGN.md:1594-1595` (`## Out of scope`) - "Cloud models as the DEFAULT. Offline-first is the default
    and the thesis; cloud and hybrid are opt-in alternate backends".
  - Review, probably fine as mechanics (offline-capable retrieval, not a framing of the thesis):
    `docs/DESIGN.md:108`, `:122` ("everything downstream stays offline"), `:362` ("build offline after").
  - DECIDED by the human 2026-10-06: Cloud is the default, and the mode order is Cloud, then Local, then
    Hybrid. R34(a) and `install.ps1` ("MODE" banners near lines 366-383) still encode Local as the no-flag
    default today; R34 must be reworded to match, and the code change is Story S29.
- **Data / interfaces:** `docs/DESIGN.md` prose only (Goal, R34, R37b/e, R40, C2e, Out of scope, line 4).
  Not changed: any code, `install.ps1`, `models.json`, tests, README.
- **Dependencies:** none. Needs the human's `/design` unlock; DESIGN returns to LOCKED on their confirmation.
- **Acceptance (testable):**
  - [x] AC1: `docs/DESIGN.md` `## Goal` states the restated mission and names Local as a resilience mode.
  - [x] AC2: grep for `Offline is the DEFAULT` and `Offline-first .* is the default and the thesis` over
    `docs/DESIGN.md` finds no hit.
  - [x] AC3: R34 orders the modes Cloud (default), Local, Hybrid and describes Local as the resilience mode with its use case.
  - [x] AC4: R34 or its contract records the 2026-10-06 decision: Cloud is the default, the mode order is
    Cloud, Local, Hybrid.
  - [x] AC5: `dad doc-stats -Findings` reports no new finding beyond the expected no-tasks entry for S29, and the full `test-kit.ps1` prints `0 failed`.
- **Dev notes:** DESIGN edits go through `/design` (architect-agent) with the unlock/relock flow; never hand-edit
  while LOCKED. R1 itself (the Local wiring) stays valid as the description of Local mode. Keep ASCII. If the
  default flips, that is a code change (`install.ps1`, `dad-doctor.ps1`, tests) and needs its own tasks.

### Story S29: install.ps1 defaults to Cloud, and a Local install becomes an explicit option   (R34, R1)   <!-- Status: DONE closed:close-unit -->
- **Goal:** `install.ps1` with no flag installs Cloud mode, and a Local install is requested explicitly. Mode order
  everywhere is Cloud, Local, Hybrid.
- **Context:** the human DECIDED 2026-10-06 that Cloud is the default (see S28 and CHANGELOG 0.58.0). Today the
  no-flag install is Local and Cloud needs `-Cloud` (README "Quickstart" says so and tells readers to pass
  `-Cloud` until this lands). This is a FINDING recorded during the mission restatement: a Local install needs an
  option of its own once the no-flag path is Cloud. It changes behavior, so it needs its design wording first
  (S28 / a `/design` pass on R34) and then tasks via `/taskmap`; it is not worked from this card alone.
- **Behavior:**
  - No flag on a machine with nothing to keep -> Cloud (the ANTHROPIC_BASE_URL redirect dropped, aliases resolve to each model's `cloud` id).
  - `-Local` (the switch name, decided in C6) -> today's Local; `-Local` with `-Cloud` or `-Hybrid` is a conflict that exits non-zero before writing anything.
  - `-Hybrid` is unchanged. `-CopilotCli` still combines with any of them.
  - The consent text, the end-of-install "MODE" banners, `dad doctor` and `use-model` read the mode back
    from the same single tell as today (the absence or presence of the base-URL), and still agree.
  - A no-flag re-run keeps an installed Local or Hybrid mode (C6): it never silently flips an existing setup.
  - Local-only prerequisites (Ollama, a pulled model) are required only when Local or Hybrid is asked for.
- **Data / interfaces:** `install.ps1` (parameters, mode selection, banners), `dad-doctor.ps1`, `uninstall.ps1`
  if it names the modes, `README.md` and `overview/*.html` (remove the "no flag is still Local" notes), tests in
  `test-kit.ps1`. Not changed: `models.json` aliases, the gates.
- **Dependencies:** S28 (done: the DESIGN wording). The behavior is PINNED in DESIGN contract C6 (decided 2026-10-06): the switch is `-Local`, a no-flag re-run keeps an installed Local or Hybrid mode, and `-Local` with `-Cloud`/`-Hybrid` is a conflict that writes nothing. Write the tasks against C6's worked-example table.
- **Acceptance (testable):**
  - [x] AC1: a sandbox install with no flag produces Cloud settings (no `ANTHROPIC_BASE_URL`), and `dad doctor`
    reports Cloud.
  - [x] AC2: the explicit Local switch produces today's Local settings and `dad doctor` reports Local.
  - [ ] AC3: `-Hybrid` and `-CopilotCli` behave as before. (partly verified: -Hybrid yes, -CopilotCli combined with the other modes not exercised - see grades/S29_GRADE.md)
  - [x] AC4: a test pins the no-flag default so it cannot drift silently.
  - [x] AC5: README and `overview/` no longer say the no-flag install is Local; the full `test-kit.ps1` prints
    `0 failed`.
- **Dev notes:** installs only into a sandbox profile in tests (R35b: never touch the real `%USERPROFILE%\.claude`).
  Keep ASCII. No open design questions remain: switch name and re-install semantics are decided in C6.

### Story S30: The ratchet counts tests marked by an attribute derived from FactAttribute/TheoryAttribute, and -AcceptShrink records its reason   (R28, R29)   <!-- Status: DONE closed:close-unit -->
- **Goal:** converting `[Fact]` to a project-defined attribute that derives from `FactAttribute` (or `TheoryAttribute`) no longer lowers the ratchet's test count, and a deliberate `-AcceptShrink` records WHY in the commit.
- **Context:** field report from `D:\projects\GalacticDataNetwork\gdn1` (2026-10-09). Converting 10 real-ipfs tests to `[RealIpfsFact]` (`RealIpfsFactAttribute : FactAttribute`, which sets `Skip` when an env var is unset) moved the ratchet's tests count from 228 to 219 and made `close-unit` refuse with "VERIFICATION SURFACE SHRANK". `recover-lost` correctly reported nothing named had vanished. Cause: `ratchet.ps1` counts the literal markers `[Fact]`, `[Theory]`, `[Test]`, `[TestMethod]` (line 69, `$testMarkers`), so `[RealIpfsFact]` is invisible. `gdn1` also defines `RealIpfsEnvFactAttribute : FactAttribute` (internal, in a test file), so discovery must find attributes declared anywhere in the project, not only in a shared file. `recover-lost.ps1`'s `Get-Units` matches NAMES and already accepts any attribute prefix, so it needs a regression test, not new logic. Pre-existing, NOT in scope: `[Fact(Skip="...")]` and `[Fact, Trait(...)]` are not counted either (the markers are exact `[Fact]`); widening that would raise counts everywhere, so it is recorded as a follow-up question, not changed here.
- **Behavior:**
  - `ratchet.ps1` first scans the same source files it already counts (`*.cs`, `*.fs`, `*.vb`) for `class X : <bases>` where a base is `FactAttribute` or `TheoryAttribute` (optionally namespace-qualified, e.g. `Xunit.FactAttribute`), then repeats until no new class is found, so `class Y : X` (X already derived) is found too. For each such class it adds `[X]`, `[X(...)]`, and the same with the `Attribute` suffix, also inside an attribute list (`[Trait("a","b"), X]`), to the test-marker pattern. The literal base markers stay as they are.
  - The same pattern set is used in `Find-ShrunkFiles` (the per-file "which file lost markers" report) for BOTH the working-tree file and the same file at the baseline commit, so a `[Fact]` -> `[RealIpfsFact]` conversion shows no shrink in either.
  - Discovery fails OPEN: if the scan errors, the ratchet falls back to the base markers and prints a one-line note; it never blocks a close on its own bug (R28).
  - The count never double-counts one line carrying two markers (counting stays per line, as today).
  - `close-unit.ps1` gains `-Reason "<text>"`. With `-AcceptShrink`, the reason is stamped into the commit as a trailer `Shrink-accepted: <reason> (human)` and into the gate-log line; `-AcceptShrink` WITHOUT `-Reason` still works but adds a warning that no reason was recorded; `-Reason` without a shrink to accept is ignored with a note. Existing `-AcceptShrink` calls are unchanged.
  - `recover-lost.ps1`: no behavior change; a test pins that converting an attribute while keeping every method name reports nothing lost.
- **Data / interfaces:** `ratchet.ps1` (marker discovery, `Find-ShrunkFiles`), `close-unit.ps1` (`-Reason`, trailer, warning), `test-kit.ps1` (fixture cases). Not changed: `docs/DESIGN.md` (R28 and R29 do not pin the marker list), `recover-lost.ps1` logic, the baseline file format.
- **Dependencies:** none.
- **Acceptance (testable):**
  - [x] AC1: fixture project with `class RealIpfsFactAttribute : FactAttribute` and 10 tests -> converting them from `[Fact]` to `[RealIpfsFact]` leaves the ratchet's tests count unchanged and `close-unit` does not refuse.
  - [x] AC2: `[RealIpfsFact(Skip="x")]`, `[RealIpfsFactAttribute]`, `[Trait("a","b"), RealIpfsFact]`, an attribute derived from a derived attribute (`class Z : RealIpfsFactAttribute`), a `TheoryAttribute`-derived one, and a namespace-qualified base (`: Xunit.FactAttribute`) are all counted; a class that merely mentions `FactAttribute` in a comment or string is not.
  - [x] AC3: `Find-ShrunkFiles` reports no shrunk file for the conversion in AC1.
  - [x] AC4: a real removal of 3 tests with the derived attribute present still trips the ratchet (the fix does not blind it).
  - [x] AC5: a scan error falls back to the base markers with a note and exit code unchanged.
  - [x] AC6: `close-unit -AcceptShrink -Reason "..."` puts the `Shrink-accepted:` trailer in the commit; `-AcceptShrink` alone still passes with the warning.
  - [x] AC7: a `recover-lost` fixture where an attribute is converted but every method name stays reports nothing lost.
  - [x] AC8: run read-only on `D:\projects\GalacticDataNetwork\gdn1` (no `-Update`, its baseline file untouched) the ratchet counts the baseline plus every derived-attribute test line (observed 2026-10-09: baseline 227, current 239 = 227 + 11 `[RealIpfsFact]` + 1 `[RealIpfsEnvFact]`; the report's 228/219 came from an earlier snapshot of that repo).
  - [x] AC9: the full `test-kit.ps1` prints `0 failed`.
- **Dev notes:** one new test-kit case per behavior, with a mutation check each (e.g. drop the transitive loop -> AC2 derived-of-derived fails; drop the fallback -> AC5 fails). `Write-GateLog` appends a line to the target project's `grades/gates-log.jsonl`, so AC8 adds one line to gdn1's log; say so in the report and do not edit anything else in gdn1. gdn1's own baseline stays 219 until its owner re-runs `ratchet.ps1 -Update` or a clean `close-unit` there. Keep ASCII. Refs: DESIGN R28, R29.

### Story S31: Every git-dependent test-kit case really runs, and the failures that were hiding behind the broken guard are fixed   (R28, R29, R37)   <!-- Status: DONE closed:close-unit -->
- **Goal:** the 17 `test-kit.ps1` cases that begin `if (-not $haveGit) { return }` before `$haveGit` exists stop passing without running, and each of the cases that then fail is triaged and fixed (fixture or product), so a green suite means those behaviors were exercised.
- **Context:** found 2026-10-09 while building S30 (T30.2). `$haveGit` is assigned at `test-kit.ps1` ~line 6013, after 17 guards at ~225, 2162, 2197, 2545, 2602, 2660, 2874, 3473, 3543, 3605, 3706, 3748, 3935, 3995, 5104, 5243, 5815 (line numbers drift: find them by the text `if (-not $haveGit) { return }` appearing before the assignment). Before the assignment the variable is `$null`, so `-not $haveGit` is true, the case returns at once and the runner counts it as PASS: those cases have never verified anything in their current position. Guards AFTER line 6013 work. QA ran `$haveGit = $true; & .\test-kit.ps1`: 266 passed, 7 failed, +33 s. The seven (names as in the suite): (1) "dad-guard BLOCKS unverified code and clears after close-unit" (close-unit failed in the fixture); (2) "recover-lost finds what vanished, and knows MOVED from LOST" (loss was not detected); (3) "close-unit REFUSES to close over a shrink, and only ratchets on success" (close-unit says "Could not find any evidence tests ran ... No test count in the output"); (4) "a visible surface passes through ux-agent -> ui-agent, and close-unit records it (-UxReviewed)" (no WARN on a surface change with no UX pass); (5) "an experience unit is playtested (playtest-agent -> human), and close-unit records it (-Playtested)" (no WARN on experience code with no playtest); (6) "doc-stats flags a hand-ticked task committed WITHOUT close-unit (doc-only commit, wrong shape)" (not flagged); (7) "close-unit REFUSES to bank new work under an already-closed id" (the correct id was refused too). Likely a common cause for 1, 3, 4, 5, 7: those fixtures predate close-unit's rule that the Test command must print a parseable test count; (2) and (6) may be real defects. S21 recorded the pattern ("other early returns inside Test-Case bodies") but assumed `$haveGit` is set near the top of the suite; it is not.
  - CONFIRMED PRODUCT DEFECT, found 2026-10-09 in T30.4 and reproduced by hand: `recover-lost.ps1` misses deleted methods whose bodies are empty. Its C# method pattern in `$unitPatterns` (`([^;]*)` then `{`) spans lines, so in a file of `[Fact] public void CaseN() { }` methods with no `;` between them the first match swallows everything up to the last `)`, and only `Case1` is recorded as a unit. Deleting `Case3` printed "nothing named has vanished." with exit 0. The R29 safety net therefore under-detects loss in exactly the small-method files it was built for. Fix the pattern (one method signature must not cross a line that already holds a complete `)` ... `{`), keep the existing cases passing, and add a regression case with empty-bodied methods (the T30.4 case uses bodies containing `;` on purpose so it passes today). This is verdict PRODUCT for the failing case "recover-lost finds what vanished, and knows MOVED from LOST".
- **Behavior:**
  - Fix the guards so they work wherever the case sits. Preferred: hoist `$haveGit = [bool](Get-Command git -ErrorAction SilentlyContinue)` to the top of `test-kit.ps1` (next to the other prerequisites) and keep the 40-odd guards as written, then convert each early `return` that means "git is missing" to `Skip-Case "git is not installed"` so a missing git is counted SKIP, not PASS (S21 Behavior 4). Do not change what a case asserts while changing its guard.
  - The suite gains a guard test: a static check that no `$haveGit` (or other variable) is read in a `Test-Case` body above the line where it is first assigned, so this cannot recur (the same class: any `if (-not $x) { return }` where `$x` is assigned later).
  - Triage each of the seven, one at a time: decide FIXTURE (the test is stale: update its fixture to the current close-unit/doc-stats contract, e.g. a Test command that prints a count; keep the original intent and assertions) or PRODUCT (the script is wrong: fix the script and keep the assertion). A product fix needs its own regression case; a case may only be weakened with a recorded human decision.
  - After the fix the suite count rises only if cases were added; no case is deleted (the ratchet applies to the kit's own tests too).
- **Data / interfaces:** `test-kit.ps1` (guards, the guard test, fixtures of the seven cases); possibly `close-unit.ps1`, `recover-lost.ps1`, `doc-stats.ps1`, `dad-guard.ps1` ONLY where triage proves a product defect. Not changed: `docs/DESIGN.md` unless triage finds a contract wrong (then stop and ask for a `/design` pass).
- **Dependencies:** S30 (T30.3 and T30.4 add cases in the same file and must not use the broken guard).
- **Acceptance (testable):**
  - [x] AC1: no `Test-Case` body reads `$haveGit` before it is assigned; a static test enforces it and FAILS on a seeded violation (mutation check).
  - [x] AC2: with git absent from PATH the 17 formerly vacuous cases report SKIP, not PASS (a fixture run with a PATH that has no git, output shows SKIP lines).
  - [x] AC3: all 17 cases run and pass on this machine; the 7 formerly failing ones each have a recorded verdict (FIXTURE or PRODUCT) in the story's Dev notes, with the fix.
  - [x] AC4: every PRODUCT fix has its own regression Test-Case and a mutation check, including: a deleted method with an EMPTY body (`public void Case3() { }`) is reported GONE by `recover-lost`.
  - [x] AC5: the full `test-kit.ps1` prints `0 failed`, `0 skipped` on a machine with git, and its passed count is at least the pre-fix count plus the added cases.
- **Dev notes:** run the 17 cases for real first (`$haveGit = $true; & .\test-kit.ps1` in a child shell, output to %TEMP%) to get the current failure list before touching anything; the suite takes ~8 min. Fixtures live under `New-Sandbox`; never touch a real project. Do the tasks strictly sequentially (all edit `test-kit.ps1`). Refs: S21 (skip-aware summary, T21.x), S30 (T30.2 finding), DESIGN R28/R29/R37 where the cases belong.
  VERDICTS recorded 2026-10-09 (T31.2-T31.8): case (1) dad-guard BLOCKS unverified code - FIXTURE, the Test command printed no test count; case (2) recover-lost finds what vanished - PRODUCT, the method pattern `\([^;]*\)` spanned lines (fixed to `[^;{}]*`; accepted loss: a default parameter containing braces such as `new T { }`); case (3) close-unit REFUSES a shrink - FIXTURE, no test count; case (4) ux-agent / -UxReviewed - FIXTURE, the sandbox had no CLAUDE.md so close-unit stopped before the UX check; case (5) playtest / -Playtested - FIXTURE, same missing CLAUDE.md; case (6) doc-stats hand-ticked task - PRODUCT, the detector required the checkbox AFTER the task id (headings put it before); case (7) already-closed id - FIXTURE, no test count. Known limits left open: recover-lost still misses generic methods (`Foo<T>(...)`), and the static guard check (Find-EarlyGuardViolations) only inspects guards that are top-level statements of a Test-Case body. Result: 0 failed, 0 skipped, 278 passed on a machine with git (v0.59.2).

### Story S32: The remaining git-dependent test-kit guards report SKIP, never a silent PASS, when git is missing   (R24, R28)   <!-- Status: TODO -->
- **Goal:** every `Test-Case` that needs git says `Skip-Case "git is not installed"` when git is missing, so the suite never counts an unrun git case as PASS (S21 Behavior 4).
- **Context:** S31 (T31.1) converted the 17 guards that sat above the `$haveGit` assignment. Fifteen more bare `if (-not $haveGit) { return }` guards remain below it, at `test-kit.ps1` ~6373, 6562, 6594, 6629, 6651, 6748, 6793, 6833, 6871, 6899, 6970, 7011, 7873, 7908, 7957 (line numbers drift: find them by the text). They work on a machine with git, but on a machine without git they return at once and the runner counts PASS. The S31 grade card (`grades/S31_GRADE.md`, suggestion 1) recommends converting them and raising the S31 AC2 count check to match. The static detector `Find-EarlyGuardViolations` only catches a guard whose variable is assigned LATER; it does not catch a guard that returns when the prerequisite is simply absent.
- **Behavior:**
  - Replace each remaining `if (-not $haveGit) { return }` with `if (-not $haveGit) { Skip-Case "git is not installed" }`; change nothing else in those cases.
  - Extend the static check so a `Test-Case` whose first statement is a bare `if (-not $x) { return }` guard on a prerequisite flag (`$haveGit` and any similar `$have*` flag) FAILS with the case name: a missing prerequisite must be a SKIP, not a return. Keep the seeded-violation mutation checks.
  - Raise the S31 AC2 assertion that counts `Skip-Case "git is not installed"` to the new total, and keep its stand-in run (a git-free PATH reports SKIP).
  - No case is removed and no assertion is weakened.
- **Data / interfaces:** `test-kit.ps1` only. Not changed: any script, `docs/DESIGN.md`.
- **Dependencies:** S31.
- **Acceptance (testable):**
  - [ ] AC1: no `if (-not $haveGit) { return }` remains in `test-kit.ps1`.
  - [ ] AC2: the static check fails on a seeded bare-return prerequisite guard (mutation) and passes on the real file.
  - [ ] AC3: with git absent from PATH a stand-in for a converted guard reports SKIP (the S31 AC2 case, count raised).
  - [ ] AC4: the full `test-kit.ps1` prints `0 failed`, `0 skipped` on a machine with git, and the passed count is unchanged apart from added cases.
- **Dev notes:** one task is enough if the guards convert mechanically; then one for the detector extension. Both edit `test-kit.ps1`, so run sequentially. Refs: S21, S31 (T31.1, T31.9), `grades/S31_GRADE.md`.

### Story S33: install.ps1 -CopilotCli combined with each backend mode, and -Local with -Cloud through the real installer, are tested in a sandbox   (R34, R37)   <!-- Status: TODO -->
- **Goal:** the installer's C6 behavior is proven for `-CopilotCli` together with Cloud, Local and Hybrid, and for the `-Local -Cloud` conflict, by running the real `install.ps1` under the `DAD_INSTALL_SANDBOX` seam.
- **Context:** `grades/S29_GRADE.md` (suggestion 2) and the S29 AC3 note: C6 says `-CopilotCli` combines with any mode and leaves the Claude Code wiring untouched, but no test runs the real installer with `-CopilotCli`. Also, the `-Local -Cloud` conflict is pinned only through the resolver (`S29 AC1-AC4`); the real-installer conflict run covers `-Local -Hybrid` only. GitHub Copilot CLI is a PILOT and unverified (R37b), so these cases test the kit's own wiring (what the installer writes into the sandbox profile), never a real Copilot binary.
- **Behavior:**
  - A sandbox run (the same `Run-Install` helper pattern as `S29 AC1/AC2: a real install.ps1 run in a sandbox profile ...`: `USERPROFILE`, `HOME` and `DAD_INSTALL_SANDBOX` under `%TEMP%`, narrowed PATH) for each of `-Cloud -CopilotCli`, `-Local -CopilotCli`, `-Hybrid -CopilotCli` asserts: the Claude Code `settings.json` mode is the same as the same run without `-CopilotCli` (Cloud has no `ANTHROPIC_BASE_URL`, Local has it, Hybrid has `LOCALTOOLS_HYBRID=1`), and the Copilot hooks file `<profile>\.copilot\hooks\dad.json` exists and is the kit's `copilot-hooks.json` with the dev-path placeholder rewritten.
  - A run of `install.ps1 -Local -Cloud` exits non-zero before writing anything and names both switches (empty sandbox profile), like the existing `-Local -Hybrid` case.
  - Every case snapshots the REAL machine (USER Path, `DAD_HOME`, the Ollama user variables, real `settings.json` and `.bashrc` hashes, real `~/.copilot`) before and after and asserts they are unchanged.
- **Data / interfaces:** `test-kit.ps1` only (cases and, if useful, a shared `Run-Install` helper factored out of the S29 case). Not changed: `install.ps1`, `install-mode.ps1`, `docs/DESIGN.md`.
- **Dependencies:** S29 (seam and resolver), S32 optional (same file; run sequentially).
- **Acceptance (testable):**
  - [ ] AC1: three sandbox cases (`-Cloud`, `-Local`, `-Hybrid`, each with `-CopilotCli`) pass and each has a mutation check (e.g. force the Copilot wiring to rewrite the Claude settings, or skip writing `dad.json`).
  - [ ] AC2: the real-installer `-Local -Cloud` case exits non-zero, names both switches and leaves the sandbox profile empty (the conflict `exit 1` stays before `== Prerequisites ==`).
  - [ ] AC3: before/after snapshots of the real machine are identical for every case.
  - [ ] AC4: the full `test-kit.ps1` prints `0 failed`.
- **Dev notes:** NEVER run `install.ps1` outside the seam with any flag; the first run of a new flag combination is done once by hand with the wide snapshot protocol used in T29.9 (record `git status`, USER Path, `DAD_HOME`, `.bashrc`, `settings.json`, global git config, `npm ls -g`, `~/.copilot` before and after) before the case is written. Under a narrowed PATH `Have copilot` is false, so `-CopilotCli` is the only thing that triggers the Copilot section. Refs: `grades/S29_GRADE.md`, DESIGN C2, C5, C6.

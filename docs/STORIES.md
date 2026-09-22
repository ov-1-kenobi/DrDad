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

### Story S6: Walking-skeleton ratchet - doc-stats `[ratchet]` finding   (R36)   <!-- Status: TODO -->
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

### Story S7: Ask-time scope pricing - state the cost before scope grows   (R36)   <!-- Status: TODO -->
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

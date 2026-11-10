# Story S38 - Refactor: generated project files are portable and belong where they are used : report card

**Current grade: B**  (as of 2026-11-10, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-11-10        | B     | initial implementation (commits ddeb376, b635882, cc76ad8 per the story's Dev notes) |

## Assessment (this iteration)

How this was graded: by READING the source and the test cases. I did not run anything. The story was
implemented directly from a review's issue list and marked DONE by hand at the owner's request, not closed
through close-unit, so there is **no close evidence file** (`grades/S38_EVIDENCE.md` does not exist). The
last full suite run on this branch reported 309 passed, 2 failed; the two were fixed and re-checked
individually and a final full run is still pending. Nothing below claims the suite is green.

- **Correctness: good, with two edge cases.** The four behaviours are present in the code:
  - Portable `.mcp.json`: `new-project.ps1:90` writes the command from `Get-DadPortableExe`
    (`docs-dir.ps1:10`) and `new-project.ps1:91` writes the relative `docs`. `docs-dir.ps1:30` joins a
    relative docs dir to the project root, not the caller's directory.
  - v2 hook: `install-hooks.ps1:96` reads `DAD_HOME` at commit time, `install-hooks.ps1:98` falls back to
    the installing kit, `install-hooks.ps1:100` prints "DrDad kit not found" and aborts when neither
    resolves. A v1 hook is detected and rewritten (`install-hooks.ps1:53`, `install-hooks.ps1:68`).
  - API surface: default output is `.claude` (`local-tools/ApiSurface.cs:41`, and passed explicitly at
    `api-surface.ps1:168`); test projects are skipped whole by marker or name
    (`local-tools/ApiSurface.cs:77`, `local-tools/ApiSurface.cs:178`); a legacy copy is moved only when it
    carries the generator header (`api-surface.ps1:50`) and is untracked (`api-surface.ps1:55`); the new
    file is ignored for projects whose `.gitignore` predates `.claude/` (`api-surface.ps1:72`).
    Readers follow the move: `close-unit.ps1:120`, `doc-stats.ps1:363`.
  - Gate log: `new-project.ps1:104` writes it before `git add -A` at `new-project.ps1:151`;
    `upgrade-project.ps1:173` adds it only when absent.
  - Edge case 1: `upgrade-project.ps1:145` treats ANY absolute docs dir that does not exist right now and
    whose leaf is `docs` as this project's own, and rewrites it. A deliberate external corpus on an
    unmounted drive or offline share (`...\shared\docs`) would be repointed. The old value is printed
    (`upgrade-project.ps1:150`) but the run does not stop.
  - Edge case 2 (read, not run): in `docs-dir.ps1:29` the first root of a `;` list is extracted, but
    `docs-dir.ps1:30` assigns it back only when it is RELATIVE. With a rooted first root, `$d` stays the
    whole `a;b` string, `docs-dir.ps1:35` fails, and the helper warns and returns `<proj>\docs` - while
    the server (`local-tools/Rag.cs:70`) honours the list. Possibly older than this story, but the 0.60.0
    comment on line 28 says the first root is primary.
- **Acceptance: all four ACs have a case that exercises them; two parts are thinner than the AC wording.**
  - AC1: `0.60.0 #1: new-project writes a PORTABLE .mcp.json (no absolute path) and a v2 hook that finds the kit through DAD_HOME`
    at `test-kit.ps1:8851` asserts the portable command (`test-kit.ps1:8859`), no drive path
    (`test-kit.ps1:8861`), and commits through the hook with a set and a stale `DAD_HOME`
    (`test-kit.ps1:8875`, `test-kit.ps1:8883`). Gap: `test-kit.ps1:32` sets `DAD_HOME` to the kit itself,
    which is also the hook's fallback, so no assertion distinguishes "found through DAD_HOME" from "found
    through the fallback" - that is checked only as hook TEXT (`test-kit.ps1:8870`). I found no case for
    the neither-resolves branch (`install-hooks.ps1:99`); the Behavior line names it, the AC does not.
  - AC2: `test-kit.ps1:8888` covers the absolute rewrite, v1 -> v2 hook (`test-kit.ps1:8912`), external
    dir untouched (`test-kit.ps1:8928`), moved project (`test-kit.ps1:8938`). Idempotence is asserted for
    `.mcp.json` only (`test-kit.ps1:8917`), not the hook.
  - AC3: `test-kit.ps1:9126` builds a real fixture and asserts no test assembly (`test-kit.ps1:9161`),
    not in docs (`test-kit.ps1:9162`), git-ignored (`test-kit.ps1:9165`); `test-kit.ps1:9174` covers the
    upgrade move and the hand-written file. The first case is skipped under `-SkipBuild`
    (`test-kit.ps1:9127`). The name-rule check at `test-kit.ps1:9200` tests a COPY of the regex and pins
    the source text with `Contains`; it does not call `IsTestProject`, so the csproj-marker half
    (`local-tools/ApiSurface.cs:181`) has no behavioural test.
  - AC4: `test-kit.ps1:9337` asserts the log is in the root commit (`test-kit.ps1:9350`), the tree is
    clean (`test-kit.ps1:9351`), and a second upgrade does not append (`test-kit.ps1:9363`).
- **Design: matches the story's Data / interfaces list; not checked against DESIGN.md.** The story is
  tagged `R: pending, see T46.5`, so there is no requirement id to trace, and I did not read
  `docs/DESIGN.md` or any `## Contracts` entry for the gate-log format - that check is a gap in this card.
  No scope creep seen. The dev-path placeholder convention is respected: the template is copied and only
  the project copy is rewritten (`new-project.ps1:82`). `dad-doctor.ps1:471` and `dad-doctor.ps1:515`
  report the portable form and the v2 hook, sharing `Expand-DadHome` (`docs-dir.ps1:12`).
- **Quality: readable, heavily commented with the incident behind each rule, JSON written without BOM**
  (`new-project.ps1:95`, `upgrade-project.ps1:155`). Small leftovers: the `.Tests` suffix test at
  `local-tools/ApiSurface.cs:88` is now redundant with the name rule; the comment at `api-surface.ps1:116`
  still explains line endings in terms of `docs\*.md`; `new-project.ps1:122` is mis-indented. The name
  rule also skips a PRODUCT project whose name ends in `Spec`, `Specs` or `Test` (for example
  `Acme.OpenApi.Spec`), silently and whole.
- **Hygiene: agent and command text follows the move** (`global/agents/dev-agent.md:28`,
  `global/commands/document.md:27`, `global/agents/survey-agent.md:32`). No new dependency. I did not check
  the uninstall inventory or `VERIFICATION.md`.
- **Verification mode** (these ACs touch machine state: `DAD_HOME`, git hooks, files in a project):
  - AC1: Code-review verified 2026-11-10, not live-run by me. The case is sandboxed by design: a temp
    project from `New-Sandbox` (`test-kit.ps1:8853`) and a process-scoped `DAD_HOME` restored in a
    `finally` (`test-kit.ps1:8884`). The real `${DAD_HOME}` expansion by Claude Code and by Copilot CLI is
    NOT measured (the story's Dev notes say so; T46.6). The server resolves the relative `docs` against
    its process directory (`local-tools/Rag.cs:73`), which also depends on how the editor launches it.
  - AC2: Code-review verified 2026-11-10, not live-run by me; sandboxed fixture (`test-kit.ps1:8890`).
  - AC3: Code-review verified 2026-11-10, not live-run by me; sandboxed fixture (`test-kit.ps1:9131`).
  - AC4: Code-review verified 2026-11-10, not live-run by me; sandboxed fixture (`test-kit.ps1:9339`).
  - Whether anyone ran these four cases after the last edits is not something I can tell: no close
    evidence file, and the final full suite run is pending.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [dev] Make AC1 prove the `DAD_HOME` route: in the case at `test-kit.ps1:8851`, point `DAD_HOME` at a
   second kit copy whose scanner behaves observably differently (or make the hook's fallback dead) and
   assert the commit still passes; add the neither-resolves commit and assert it aborts with the
   "kit not found" line from `install-hooks.ps1:100`.
2. [dev] `upgrade-project.ps1:145`: do not rewrite a missing absolute docs dir just because its leaf is
   `docs` when it could be an external corpus (UNC path, or a drive that is not present); leave it and
   print a NOTE, or require the path to share the project's folder name. Add a case beside
   `test-kit.ps1:8938`.
3. [dev] `docs-dir.ps1:30`: for a `;` list, use the first root as the primary whether or not it is rooted,
   so the scripts and the server (`local-tools/Rag.cs:70`) agree; add a case. Confirm first whether this
   predates S38.
4. [human] The portable form rests on `${DAD_HOME}` being expanded by Claude Code and Copilot CLI, which
   is unmeasured (T46.6), and the story is DONE with no close evidence file and a pending full suite run.
   Decide whether DONE stands before T46.6 and that run, or whether S38 goes back through close-unit.
5. [dev] Give the csproj-marker half of `IsTestProject` (`local-tools/ApiSurface.cs:181`) a behavioural
   test, and decide whether a product project named `*.Spec` / `*.Test` should be skipped without a word;
   at least print the skipped project names in the result line at `local-tools/ApiSurface.cs:173`.
6. [mechanical] Drop the redundant `.Tests` suffix condition at `local-tools/ApiSurface.cs:88`; update
   the stale `docs\*.md` comment at `api-surface.ps1:116`; fix the indent at `new-project.ps1:122`.

# Templates & stack profiles

Scaffolding is stack-agnostic; the **stack is chosen FIRST inside `/design`**, before requirements and
contracts. That order was reversed in 0.13.0 and for good reason: `CLAUDE.md` has no Build/test command
until a stack exists, so `/build`'s first gate refuses to start and `close-unit` can verify nothing; the
contracts name real library types anyway; and the library docs cannot be ingested until the libraries are
known - which is how one project shipped 16 compile errors from guessed API calls.

1. **Scaffold (stack-agnostic):** `new-project.cmd <general|experience> [dir]` (or `/scaffold`) lays down a
   **generic** `CLAUDE.md` + `.mcp.json` (wired to this project's `docs/`) + `docs/`. The KIND is required
   and comes first - it picks the design doc. **No platform is chosen here.**
2. **`/design` step 2 - the STACK:** it proposes 2-3 architectures that fit, you choose, and it fills
   `CLAUDE.md`'s Stack + Build/test/run + placeholder + human-in-loop from the matching **profile fragment**
   below, then records the choice and rationale in the design doc.
3. **`/design` steps 2b-5:** security review, requirements, epics, then contracts pinned by `architect-agent`.
4. `Status: LOCKED` -> `/stories` -> `/taskmap` -> `/spec` or `/build`.

## Stack profiles (applied by /design's step 2 - not chosen at scaffold)

Each `<stack>/PROFILE.md` is a **fragment**: it contains ONLY the sections `/design` copies into
`CLAUDE.md`, and deliberately nothing else. Every other section of `CLAUDE.md` is kit-owned and already
there - which is why these are not whole `CLAUDE.md` files, and why they pin no toolchain version (they
tell you to detect the installed one instead). Both properties are enforced by `test-kit.ps1`.

| Profile | For | Build / Test |
|---------|-----|--------------|
| `generic/`  | the scaffold default (a whole `CLAUDE.md`, not a fragment); any stack | you fill in |
| `dotnet/`   | C# / .NET fullstack, APIs, services | `dotnet build` / `dotnet test` |
| `web/`      | web front ends and lite web/mobile apps (see also `ui-agent`) | per the profile |
| `avalonia/` | C# / .NET cross-platform desktop UI (Avalonia 11 / XAML, MVVM) | `dotnet build` / `dotnet test` / `dotnet run` |
| `python/`   | Python apps, services, data | `pytest`, `ruff`, `mypy` |
| `embedded/` | MCU / IoT firmware (uses the datasheet RAG) | `pio run` / `pio test -e native` |
| `unity/`    | Unity experiences (PROFILE.md + BuildScript.cs to copy; TEDD from _common; playtest-agent) | Unity CLI batchmode |

`_common/` holds the shared `.mcp.json` and the doc templates: `docs/DESIGN.md`, `docs/TEDD.md`,
`docs/STORIES.md`, `docs/TASKS.md`, `docs/STATUS.md`, `docs/SOURCES.md`, `docs/RECIPES.md`, `docs/STYLE.md`
(the visual contract - palette / type / tone / branding for a UI project).

## Scaffold a project

- **Terminal (recommended):** `new-project.cmd general` (current folder), or
  `new-project.cmd general C:\src\MyApp` for a named folder. `experience` instead of `general` gives you
  `docs/TEDD.md`. Omitting the kind prints the usage and exits 1 - it is not optional.
- **In Claude Code:** `/scaffold`.

Either way you get a generic, stack-agnostic DrDad project. Then run `/design`, which decides the stack as
its second step.

## By hand

Copy `_common\.mcp.json` + `templates\generic\CLAUDE.md` into your project, make a `docs\` folder, and edit
`.mcp.json`'s `LOCALTOOLS_DOCS_DIR` to that `docs\`. Then `/design`.

## Adding a new stack profile later

Write a new `<stack>\PROFILE.md` containing ONLY the `CLAUDE.md` sections to copy (Stack, Build / test,
Placeholder convention, Human-in-loop, and any hygiene section), with no toolchain version pinned. Add it to
the table above and to `/design` step 2's profile list. No new commands or agents needed.

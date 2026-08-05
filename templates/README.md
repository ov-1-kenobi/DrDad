# Templates & stack profiles

AD does NOT lock a platform at scaffold time. The flow is requirements-first; the stack emerges late.

1. **Scaffold (stack-agnostic):** `new-project.cmd [dir]` (or `/scaffold`) lays down a **generic** `CLAUDE.md`
   + `.mcp.json` (wired to this project's `docs/`) + an empty `docs/`. **No platform is chosen here.**
2. **`/design`** asks: general project (`docs/DESIGN.md`) or experience (`docs/TEDD.md`), then captures
   requirements as **stack-agnostic stories**.
3. **Architecture, decided LATE:** once the stories are implementable, `/design` proposes solution
   architectures that FIT the stories, you choose one, and it fills `CLAUDE.md`'s build/test/conventions from
   the matching **stack profile** below + records the choice in the design doc.
4. `Status: LOCKED` -> `/spec` or `/build`.

## Stack profiles (applied by /design's architecture step - NOT chosen at scaffold)
Each `<stack>/CLAUDE.md` is a profile `/design` cribs the build/test/run + placeholder + human-in-loop from,
once you've chosen a stack:

| Profile | For | Build / Test |
|---------|-----|--------------|
| `generic/`  | the scaffold default; any stack (fill in) | you fill in |
| `dotnet/`   | C# / .NET fullstack, APIs, services | `dotnet build` / `dotnet test` |
| `avalonia/` | C# / .NET cross-platform desktop UI (Avalonia 11 / XAML, MVVM) | `dotnet build` / `dotnet test` / `dotnet run` |
| `python/`   | Python apps, services, data | `pytest`, `ruff`, `mypy` |
| `embedded/` | MCU / IoT firmware (uses the datasheet RAG) | `pio run` / `pio test -e native` |
| `unity/`    | Unity experiences (TEDD.md, ASSETS.md, BuildScript.cs, `/assets`) | Unity CLI batchmode |

`_common/` holds the shared `.mcp.json` and the design-doc templates (`docs/DESIGN.md`, `docs/TEDD.md`).

## Scaffold a project
- **Terminal (recommended):** `new-project.cmd` (current folder) or `new-project.cmd C:\src\MyApp`.
- **In Claude Code:** `/scaffold`.
Either way you get a generic, stack-agnostic AD project. Then run `/design` to pick the design doc and
capture stories - the stack is decided later.

## By hand
Copy `_common\.mcp.json` + `templates\generic\CLAUDE.md` into your project, make a `docs\` folder, and edit
`.mcp.json`'s `LOCALTOOLS_DOCS_DIR` to that `docs\`. Then `/design`.

## Adding a new stack profile later
Write a new `<stack>\CLAUDE.md` with the build/test/placeholder/human-in-loop slots filled. `/design` can
then crib from it when that stack is chosen. No new commands or agents needed.

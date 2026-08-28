# Unity stack (reference)

Unity is a `/design` **stack profile** like the others - NOT a template you copy wholesale. The flow is the
same as every stack:

1. **Scaffold** (stack-agnostic): `new-project.cmd experience <dir>` (or `/scaffold`, kind = experience).
   You get a generic `CLAUDE.md`, `.mcp.json`, and `docs/TEDD.md` (from `templates/_common`).
2. **`/design`** proposes engines that fit; when you pick Unity it copies this folder's **`PROFILE.md`**
   sections into `CLAUDE.md` (engine, batchmode build/test, greybox placeholders, human-in-loop) and ingests
   the Unity API docs your stories will touch. The design doc stays `docs/TEDD.md`.
3. **Lock** the TEDD -> `/stories` -> `/taskmap` -> `/build`. `/build` verifies through the Unity CLI (a
   headless batchmode build + EditMode/PlayMode tests) and, for an interactive unit, routes
   **playtest-agent** to structure the feel-review you sign off on (`close-unit -Playtested`).

## What this folder holds
- **`PROFILE.md`** - the fragment `/design` applies; the only thing every Unity project uses.
- **`Assets/Editor/BuildScript.cs`** - the headless build entry point (`BuildScript.PerformBuild`) the
  PROFILE's build command calls. Copy it into your project's `Assets/Editor/`.
- **`docs/ASSETS.md`** - an example art/asset list; `/assets` regenerates one from your TEDD.
- **`.mcp.json`** - an example wiring; the scaffold writes your project's own.

The design doc (`docs/TEDD.md`) is deliberately NOT kept here - it lives in `templates/_common` so it cannot
drift from the general experience template. It used to be duplicated here and went stale; that copy is gone.

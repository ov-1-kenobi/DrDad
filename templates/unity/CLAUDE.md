# Project: <game name>

## Engine / stack
- Unity <version, e.g. 2022.3 LTS> - confirm API against this version.
- Language: C# (.NET as bundled with Unity).

## Modes (forge / proto / spec)  <- read this
**If I haven't said which, ASK before proceeding.**
- `/forge` - design-first: architect & validate the spec INTO `docs/TEDD.md` (DRAFT), no code.
- `/proto` - co-design: build greybox + record dated decisions into `docs/TEDD.md` (DRAFT).
- `/spec` - implement the TEDD faithfully. `docs/TEDD.md` is **LOCKED** and read-only;
  gaps become questions; never invent design.
- `/build [scope]` - orchestrated build: you (main session) delegate to requirements-agent ->
  dev-agent -> qa-agent and relay between them (subagents don't call each other). Mode follows
  the TEDD `Status:`.

The TEDD's `Status:` header is the source of truth:
**never edit a LOCKED TEDD; never run `/spec` against a DRAFT.**

## Design source
- Design doc: `docs/TEDD.md`  (the file /spec, /proto, /build read for this project).
- The TEDD and design notes live in `docs/` and are indexed in the `local-tools` MCP server.
- Use `search_datasheets` (or the `doc-researcher` subagent) to pull exact spec - cite the section.
  Do not hold the whole TEDD in context; retrieve the relevant part.

## Placeholders (art/design handoff)
- All art/audio/visual assets are referenced via `[SerializeField]` or ScriptableObjects.
- Stub them with greybox primitives (cube/capsule/quad) + `// TODO: artist assigns`.
- Keep a running asset list in `docs/ASSETS.md` as systems are built.

## Build / test  (fill in <VER> and <PROJECT> for this machine)
Unity exe: `C:\Program Files\Unity\Hub\Editor\<VER>\Editor\Unity.exe`
Project:   `<PROJECT>` = this project's root folder.
**Close the Unity Editor before running these - a project can only be open in one instance.**
Exit code 0 = success. `-logFile -` streams the log to the console.

- **Build (headless)** - uses `Assets/Editor/BuildScript.cs`:
  ```
  & "C:\Program Files\Unity\Hub\Editor\<VER>\Editor\Unity.exe" -batchmode -nographics -quit `
    -projectPath "<PROJECT>" -executeMethod BuildScript.PerformBuild -logFile -
  ```
- **EditMode tests** (pure logic - fast):
  ```
  & "C:\Program Files\Unity\Hub\Editor\<VER>\Editor\Unity.exe" -runTests -batchmode `
    -projectPath "<PROJECT>" -testPlatform EditMode -testResults "<PROJECT>\TestResults\edit.xml" -logFile -
  ```
- **PlayMode tests** (runtime behavior - omit `-nographics`; some setups need a display):
  ```
  & "C:\Program Files\Unity\Hub\Editor\<VER>\Editor\Unity.exe" -runTests -batchmode `
    -projectPath "<PROJECT>" -testPlatform PlayMode -testResults "<PROJECT>\TestResults\play.xml" -logFile -
  ```
  Do NOT add `-quit` to `-runTests` (it self-quits). Exit code 0 = all passed; non-zero = failures.
  Read the `TestResults\*.xml` (NUnit3) for which assertions failed.
- Prefer constructing scenes/prefabs via Editor scripts (C#), not by hand-editing scene/prefab YAML.

## Asset list
- Keep `docs/ASSETS.md` current; regenerate it from the TEDD with the `/assets` command.

## Web / grounding
- Web search / URL lookup: use the `local-tools` `web_search` / `ingest_url` tools, NOT the built-in
  WebSearch/WebFetch (those need Anthropic and don't work against local Ollama). For grounding,
  `web_search` to find, then `ingest_url` to fetch + persist into the RAG.

## Working agreement
- Confirm every value against the TEDD before using it; cite it.
- After each change: build + run tests. Don't say "done" until they pass.
- Anything visual or "feel"-based: hand me a Manual Editor Steps + Visual Inspection
  checklist and wait - I'm the eyes in the loop.

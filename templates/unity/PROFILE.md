# Stack profile: Unity (C#)
<!-- A FRAGMENT, not a CLAUDE.md. /forge copies these sections into the project's CLAUDE.md during the
     architecture step. Kit-owned sections come from templates/generic/CLAUDE.md - do not duplicate them.
     Note: Unity projects use docs/TEDD.md as the design doc (an "experience"). -->

## Engine / stack
- Unity <version, e.g. 6 LTS or 2022.3 LTS> - confirm every API against THIS editor version.
- **Unity is the exception to "use the newest C#/.NET".** The editor bundles its own runtime and caps the
  language level: do NOT set `<LangVersion>`, do NOT retarget the TFM, and do not assume desktop-.NET
  features exist. Check what your editor version supports in Unity's own docs before using a modern
  language feature, and record the editor version in the TEDD's "Solution architecture".
- Package versions come from `Packages/manifest.json` - pin them; do not float.

## Placeholders (art/design handoff)
- All art/audio/visual assets are referenced via `[SerializeField]` or ScriptableObjects.
- Stub them with greybox primitives (cube/capsule/quad) + `// TODO: artist assigns`.
- Keep a running asset list in `docs/ASSETS.md` (regenerate it from the TEDD with `/assets`).

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
  Read `TestResults\*.xml` (NUnit3) for which assertions failed.
- Prefer constructing scenes/prefabs via Editor scripts (C#), not by hand-editing scene/prefab YAML.
- The editor path above is machine-specific ON PURPOSE (it is a local tool, not a build input). Keep it out
  of committed project files - it belongs in CLAUDE.md only.

## Human-in-loop (visual)
- Anything visual or "feel"-based: hand me Manual Editor Steps + a Visual Inspection checklist and wait -
  I'm the eyes in the loop.

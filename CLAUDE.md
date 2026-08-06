# Project: DAD - Design Document Aligned Development (kit maintenance)

This folder IS the **DAD** kit (local, offline Claude Code). Editing it here maintains the kit itself.
(DAD = the lightweight local runtime + design-doc loop; **BMAD on DAD** = BMAD running on top of it.)

## Stack
- C# / .NET 8 (`RollForward=LatestMajor`, so it builds on .NET 8+ SDK and runs on .NET 8+ runtime)
  - the `local-tools` MCP server in `local-tools\`.
- PowerShell + `.cmd` - the installer and helper scripts.
- Markdown - templates, global commands/agents, and docs.

## Design doc
- Design doc: `docs/DESIGN.md` (Status: LOCKED). It defines what the kit must do.
- Indexed in `local-tools`; use `search_datasheets` / the `doc-researcher` subagent to pull from it.

## Modes
- Use `/spec` or `/build` to implement/maintain against `docs/DESIGN.md` (it's LOCKED).
- Use `/design` or `/proto` only after flipping `docs/DESIGN.md` to DRAFT to change the design itself.
- Use `dev` (Devstral) for edits; `quality` (Next) for a genuinely hard change.

## Build
- C# server: `dotnet build local-tools\local-tools.csproj -c Release`
  -> produces `local-tools\bin\Release\net8.0\local-tools.exe` (what `.mcp.json` launches).

## Validation gate (run after ANY change; don't say "done" until it passes)
**Run the suite - that IS the gate:**
```
.\test-kit.ps1              (or test-kit.cmd; -SkipBuild for a fast docs/scripts-only pass)
```
It must print `0 failed`. It covers: PowerShell parse, config JSON, ASCII-only text, python helpers,
the dev-path placeholder, inventory consistency (uninstall lists vs actual command/agent files, agent
frontmatter names, agents referenced by commands existing, commands naming the Task tool, description
frontmatter), the secret scanner's behavior + the kit being credential-clean, `new-project` /
`upgrade-project` / `close-unit` behavior on fixtures, the `dotnet build`, the MCP server's advertised
tool list, and `--reindex`. CI runs the same script on Windows (`.github/workflows/kit-ci.yml`).
Add a `Test-Case` for any bug you fix here - that is how this gate stays useful.

## Conventions (do NOT break these)
- **Keep ALL kit text ASCII** (`.ps1`, `.cmd`, `.md`, `.json`): no em-dashes (use `-`), arrows (use `->`),
  or smart quotes. PS 5.1 misparses non-ASCII in scripts, and command/agent descriptions get mangled when
  `install` copies them and when shown in a cp437/cp1252 console. Use `->`, `-`, `<->`, straight quotes.
- **Preserve the dev-path placeholder** `C:\Projects\Claude\MCP\DAD-kit` in config files - `install.ps1`
  rewrites it to the real install location. Do NOT replace it with a hard-coded absolute path.
- **JSON config = no BOM** (Node/Claude Code reads it). Scripts that write JSON use UTF-8 without BOM.
- **Models live in `models.json`** - one entry per model (alias / `-cc` name / base tag / role / VRAM).
  `sync-models.ps1` GENERATES the Modelfiles (`FROM <model>` + `PARAMETER num_ctx`) because Ollama's
  default context is too small for the agent loop. Never hand-write a `.Modelfile`, and never hard-code a
  model list in a script - `use-model`, `install`, `uninstall` and `dad-doctor` all read the manifest.
- **Global commands/agents** live in `global\`; `install.ps1` copies them to `%USERPROFILE%\.claude\`.
  After editing them or the C# server, **re-run `install.cmd`**.
- **One C# server only** - do not add Node/Python MCP servers; native Claude Code + `local-tools` is the design.

## Working agreement
- After any change, run the full validation gate; report its results.
- Keep changes small and scoped. Confirm behavior against `docs/DESIGN.md`; cite it.

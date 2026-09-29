# UI tooling (optional - the kit installs NONE of this)

DrDad is offline, one-C#-server, and multi-stack (C# / Python / JS). Fine-grained UI quality needs tools that
break at least one of those, so the kit does NOT install them. It ships an OFFLINE built-in loop that works on
every stack, and points at the external tools for when you want more.

## The offline built-in loop (every stack, including Razor / HTMX)

What makes agent-built UI good is three levers: (1) grounding against real components, (2) grounding against
reference IMAGES, (3) a see->adjust loop where the model SEES its output. DrDad ships (2) and (3):

- **Reference images** - put target screenshots in `docs/references/` and list them under STYLE.md's
  `## Reference`. A picture beats a prose style guide.
- **See->adjust** - `/build`'s `[ui]` step renders the surface, captures a screenshot, and `ux-agent`
  `describe_image`s the RENDERED pixels against STYLE.md + the references. This catches what a markup review
  cannot: cms3 shipped Bootstrap markup with NO Bootstrap linked, so every page rendered unstyled - the build
  passed and the tests passed, and only a screenshot shows it.

Offline, no account, no extra MCP server.

## Optional external tools (online; install them YOURSELF)

For component-grounding (lever 1) or stronger design generation. These need the network - and one needs an
account - so they do NOT fit the offline default and `install.ps1` / `upgrade-project` will not add them.
Set them up per-project when you want them. Commands verified 2026-09; re-check before relying on them.

### shadcn MCP  (JS / React / Vue + Tailwind projects ONLY)
Grounds the model against the LIVE shadcn/ui registry (current props, import paths) instead of stale training.
Requires a `components.json` in the project - so it is React/Vue + Tailwind ONLY, NOT C#/.NET, Python, or a
Razor / HTMX app. It is a Node MCP server and needs network.
- Init:  `npx shadcn@latest mcp init --client claude`
- Or add to `.mcp.json`:  `{ "mcpServers": { "shadcn": { "command": "npx", "args": ["shadcn@latest", "mcp"] } } }`
- Restart Claude Code after adding it.

### superdesign  (design-judgment skill; needs an ACCOUNT)
A skill that gives the agent design taste. Installs as a Claude Code PLUGIN and uses a hosted service - it
needs `superdesign login` and network at runtime, so it is not offline and the kit cannot script it.
- In Claude Code:  `/plugin marketplace add superdesigndev/superdesign-skill`  then  `/plugin install superdesign@superdesign`
- Companion CLI:   `npm install -g @superdesign/cli@latest`  then  `superdesign login`
- Invoke:  `/superdesign:superdesign`   (do NOT also run `npx skills add ...` - that installs a second, unnamespaced copy)

### v0 / bolt / lovable  (external app builders, NOT Claude Code)
For pixel-quality UI from scratch, a dedicated builder (v0 by Vercel on the shadcn/Next stack, etc.) often
beats any CLI kit. Build the UI there, bring it back, and let DrDad build + gate the tested spine behind it.

## Which to reach for
- **C# / .NET, Python, Razor / HTMX:** the offline loop above. shadcn does not apply.
- **React / Vue + Tailwind:** add shadcn MCP (per-project) for component grounding; optionally superdesign for
  design judgement; the offline loop still applies on top.
- **UI is the whole product / must be beautiful:** consider building it in v0 / bolt / lovable and using DrDad
  for the backend spine.

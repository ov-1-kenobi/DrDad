# Project: <name>

## Stack
- C# / .NET, **Avalonia 11** (cross-platform XAML UI), **MVVM** via CommunityToolkit.Mvvm.
- Scaffold a fresh app once: `dotnet new install Avalonia.Templates` then `dotnet new avalonia.mvvm -o <name>`.
  (Re-confirm current template/package names at docs.avaloniaui.net.)

## Modes (forge / proto / spec)  <- read this
If I haven't said which, ASK first.
- `/forge` - design-first: architect & validate the spec INTO the design doc (DRAFT), no code.
- `/proto` - co-design: build greybox + record dated decisions into the design doc (DRAFT).
- `/spec` - implement the design doc faithfully; it is LOCKED & read-only; gaps -> questions.
- `/build [scope]` - orchestrate requirements-agent -> dev-agent -> qa-agent; mode follows the doc Status.
The design doc's `Status:` header is the source of truth: never edit LOCKED; never `/spec` a DRAFT.
Pipeline: forge or proto (DRAFT) -> set LOCKED -> spec/build (implement).

## Design doc
- Design doc: `docs/DESIGN.md` (indexed in `local-tools`; use `search_datasheets` / `doc-researcher`, cite it).

## Placeholder convention
- MVVM: ViewModels hold logic with in-memory/mock data behind interfaces; stub services with fakes marked
  `// TODO: real impl`. Use design-time data (`d:DataContext`) so XAML previews render. Views stay thin XAML.

## Build / test / run
- Build: `dotnet build`
- Test:  `dotnet test` - plain ViewModel/service/logic tests need no Avalonia setup (xUnit/NUnit);
  control-level UI tests use `Avalonia.Headless.XUnit` (or `.NUnit`) with the `[AvaloniaTestApplication]` attribute.
- Run (to see the UI): `dotnet run`

## Web / grounding
- Web search / URL lookup: use the `local-tools` `web_search` / `ingest_url` tools, NOT the built-in
  WebSearch/WebFetch (those need Anthropic and don't work against local Ollama). For grounding,
  `web_search` to find, then `ingest_url` to fetch + persist into the RAG.

## Human-in-loop (visual)
- Avalonia has a real UI: implement + write headless/logic tests, then hand me a "run `dotnet run` and
  check" + Visual Inspection checklist - I'm the eyes for look/feel and layout.

## Working agreement
- Confirm values against the design doc; cite it. Never invent - missing info is a question.
- After each change: build + test. Don't say "done" until they pass. Keep changes small and scoped.

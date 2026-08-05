# Stack profile: Avalonia (C# / XAML / MVVM)
<!-- A FRAGMENT, not a CLAUDE.md. /design copies these sections into the project's CLAUDE.md during the
     architecture step. Kit-owned sections (Modes, Design docs, Secrets, Working agreement) come from
     templates/generic/CLAUDE.md - never duplicate them here. -->

## Stack
- C# / .NET with **Avalonia** (cross-platform XAML UI) and **MVVM** via CommunityToolkit.Mvvm.
- **Do NOT copy a version number from this file.** Target the newest SDK on the machine
  (`dotnet --list-sdks` -> highest major -> `net<major>.0`) and use the current Avalonia major; confirm
  template/package names at docs.avaloniaui.net rather than trusting a version written here.
  Record the chosen TFM + Avalonia version in the design doc's "Solution architecture".
- C# version follows the TFM automatically; do not set `<LangVersion>`.
- Scaffold a fresh app once: `dotnet new install Avalonia.Templates` then `dotnet new avalonia.mvvm -o <name>`.

## Placeholder convention
- MVVM: ViewModels hold logic with in-memory/mock data behind interfaces; stub services with fakes marked
  `// TODO: real impl`. Use design-time data (`d:DataContext`) so XAML previews render. Views stay thin XAML.

## Build / test / run
- Build: `dotnet build`
- Test:  `dotnet test` - plain ViewModel/service/logic tests need no Avalonia setup (xUnit/NUnit);
  control-level UI tests use `Avalonia.Headless.XUnit` (or `.NUnit`) with `[AvaloniaTestApplication]`.
- Run (to see the UI): `dotnet run`

## Project-file hygiene
- **Never hard-code an absolute or machine-specific path** in `.csproj`/`.props`/`.targets` -
  `PackageOutputPath`, `OutputPath`, `HintPath`, `Import`, or a local NuGet feed. Use
  `$(MSBuildThisFileDirectory)` / `$(SolutionDir)` / relative paths.
- **Clean-machine rule:** a fresh clone + the documented SDK must build and test with no manual setup.

## Human-in-loop (visual)
- Avalonia has a real UI: implement + write headless/logic tests, then hand me a "run `dotnet run` and
  check" plus a Visual Inspection checklist - I'm the eyes for look/feel and layout.

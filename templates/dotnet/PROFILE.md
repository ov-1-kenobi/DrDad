# Stack profile: .NET / C#
<!-- A FRAGMENT, not a CLAUDE.md. /forge copies these sections into the project's CLAUDE.md during the
     architecture step: Stack, Placeholder convention, Build / test, Human-in-loop, Project-file hygiene.
     Everything else (Modes, Design docs, Secrets, Proven commands, Working agreement) is kit-owned and
     comes from templates/generic/CLAUDE.md - never duplicate it here, it only goes stale. -->

## Stack
- C# / .NET - <ASP.NET Core Web API | Blazor | worker service | console | library>.
- **Do NOT copy a version number from this file.** Target the newest SDK on the machine: run
  `dotnet --list-sdks`, take the highest major, and set `<TargetFramework>net<major>.0</TargetFramework>`.
  Record the chosen TFM in the design doc's "Solution architecture" so it is pinned per project.
- **C# version follows the TFM automatically** (net8 -> C# 12, net9 -> C# 13, net10 -> C# 14). Do not set
  `<LangVersion>`, and never `preview`, unless a specific feature requires it - then say why in the design doc.
- Choose an **LTS (even-numbered)** release if this project needs a long support window; newest is fine for
  a POC. If you publish a NuGet library, target LOWER (or multi-target) for consumer reach, not newest.
- Key libraries: <EF Core, MediatR, etc.>

## Placeholder convention
- Program to interfaces. Stub external services (DB, APIs, queues) with in-memory/mock implementations
  behind the interface, marked `// TODO: real impl`; wire real ones later via DI.
- Config via appsettings + Options; secrets are referenced by NAME only, never hard-coded.

## Build / test
- Build: `dotnet build`
- Test:  `dotnet test`
- Format (optional): `dotnet format --verify-no-changes`

## Project-file hygiene (learned the hard way - this is why a solution "works here" and not on a clean box)
- **NEVER put an absolute or machine-specific path in a `.csproj` / `.props` / `.targets`.** That includes
  `PackageOutputPath`, `OutputPath`, `HintPath`, `<Import Project=...>`, and local NuGet feeds in
  `RestoreSources` / `nuget.config`. It builds on the authoring machine and fails everywhere else.
- Use relative paths or MSBuild well-knowns: `$(MSBuildThisFileDirectory)`, `$(MSBuildProjectDirectory)`,
  `$(SolutionDir)`, `$(ArtifactsPath)`.
- **Clean-machine rule:** a fresh clone plus the documented SDK must `build` and `test` with no manual
  setup. If a step needs a local tool, path or feed, it goes in the README as a prerequisite - never
  hard-coded into a project file.
- Prefer central versioning (`Directory.Build.props`, `Directory.Packages.props` for CPM) over per-project
  drift; keep every project in the solution on the same TFM unless there is a documented reason.
- **Every test project must be added to the `.sln`** (`dotnet sln add tests/**/*.csproj`). `dotnet test` on a
  solution that lists no test projects succeeds while running NOTHING - a silent no-op that makes every
  "tests pass" claim meaningless.
- **Namespace-shadowing trap:** if your namespace ends in a segment that matches an SDK root namespace
  (e.g. `MyApp.Storage.Azure` vs the `Azure` SDK), then `Azure.ETag` resolves to YOUR sub-namespace and you
  get `CS0234: 'ETag' does not exist in the namespace 'MyApp.Storage.Azure'`. Fix with `global::Azure.ETag`
  or a `using` alias - better, do not name a namespace segment after an SDK root.

## Human-in-loop
- Usually none. For HTTP endpoints, optionally a manual curl/HTTP smoke - I'll confirm if asked.

# Contributing to DAD-kit

The whole project is one idea: **never accept an assertion a script can settle.** Contributions are held to
the same standard as the kit itself.

## The one firm rule

**Every fix ships with a test that would have caught the bug.**

The test suite (`dad test-kit`, or `.\test-kit.ps1`) is not a formality here - it IS the gate, and it must
print `0 failed` before anything merges. A change without a test is a prose promise, and prose promises are
exactly what this kit exists to replace. Nearly every test in the suite names the real incident that
motivated it; add yours the same way.

```
.\test-kit.ps1                 full suite (needs .NET SDK for the server tests)
.\test-kit.ps1 -SkipBuild      fast docs/scripts pass, no build
```

No Ollama, GPU, or network is required to run the suite.

## What a good contribution looks like

- **Fixes a measured failure.** The best PRs start "on a real run, X happened." If you have a transcript,
  open a Run Report issue first (there is a template) so the incident is recorded even if the fix takes a
  while.
- **Prefers a script gate to a prose instruction.** If a check can be computed, compute it. Prose that asks
  the model to be careful has failed at every layer of this project; a script that refuses to proceed has
  not.
- **Fails loudly, not silently.** A gate that passes by doing nothing is worse than no gate. Guards here
  fail OPEN on their own errors (so a bug in a guard cannot wedge a session) but fail LOUD on the thing
  they check.
- **Is small and scoped**, and cites the design doc (`docs/DESIGN.md`, requirements R1..Rn) where relevant.

## Conventions that the suite enforces

- **ASCII only** in all `.ps1`, `.cmd`, `.md`, and `.json` - no em-dashes, smart quotes, arrows, or emoji.
  PowerShell 5.1 misparses non-ASCII in scripts and consoles mangle it. Use `-`, `->`, straight quotes.
- **One entry point:** user-facing operations run through `dad <subcommand>`. Add a `<name>.cmd` wrapper for
  any new script.
- **Line endings:** LF everywhere, CRLF for `.cmd`/`.bat` (a `.gitattributes` enforces it; the suite checks
  it).
- **JSON is written without a BOM** and edited via parse/serialize, never string-replace (backslashes).
- **Models live in `models.json`** - one entry per model; never hand-write a Modelfile or hard-code a model
  list.
- **PowerShell scripts take `[CmdletBinding()]`** so a mistyped parameter is an error, not a silent default.

## Development loop

1. Make the change.
2. Add or update a `Test-Case` in `test-kit.ps1` that would fail without your change.
3. Run `.\test-kit.ps1` until it prints `0 failed`.
4. Add a `CHANGELOG.md` entry describing the incident and the fix, and bump `VERSION` to match if the change
   is user-visible (the suite checks that the CHANGELOG's top entry matches `VERSION`).
5. Open a PR (there is a template).

## What not to send

- A behavior change with no test.
- A workaround that weakens security (disabling a service, adding a Defender exclusion, forcing past a WDAC
  block). The kit refuses these on purpose; so do we.
- Redistributed model weights or a bundled copy of Claude Code. DAD-kit orchestrates those; it never ships
  them.

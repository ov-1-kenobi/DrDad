# DrDad - Design Research Document, Agentic Development

**Version 0.51.0** - local, offline, agentic software development on your own GPU.

DrDad runs the real Claude Code agentic loop against **local Ollama models** - no Anthropic account, no
API key, no internet after first setup - and wraps it in **deterministic gates** so a small local model
cannot quietly wreck your project. The design document is the contract; every mode aligns to it.

Built for one specific person: the developer with a capable-but-not-frontier GPU (this was tuned on a
16 GB RTX 5080) who wants an agentic coding loop that stays on their own machine.

---

## Status: honest

This is **pre-1.0 and candid about it.**

- The gates are real, tested (130+ cases, green), and each one was earned from a **measured failure** on a
  real run - see [CHANGELOG.md](CHANGELOG.md), which reads as a field log of every way a local model
  sabotaged itself and the deterministic check that stopped it.
- **A full `/design -> /build -> close` has not yet completed on a local model without human repair.** The
  best run to date produced a real ASP.NET Core app - controllers, EF Core migrations, integration tests,
  15 of 44 tasks closed - before an external Windows policy blocked test execution. Getting one clean,
  reproducible end-to-end run is the current goal, in the open.
- **Windows-only, by design.** Built for a Windows + Ollama box: PowerShell + `.cmd` scripts, a
  Windows-native installer and hooks. Cross-platform is a deliberate post-1.0 question (the C# server is
  already portable; the plumbing is not), not a near-term goal.

If you want a polished product, this is not it yet. If you want to watch a local-first agentic harness get
hardened failure by failure - and help - you are in the right place.

---

## The idea: never accept an assertion a script can settle

A 14-32B local model, driven hard, does things a frontier model rarely does: it deletes tests to make a
suite pass, reports work it did not do, writes a task list no tool can parse, and loops one failing command
a thousand times. Prompting against this does not hold - across many graded runs, **every prose rule failed
at least once and every deterministic gate held.** So DrDad's rule is: if a script can check it, a script
checks it, and the model does not get a vote.

A few of the gates, each from a real incident:

- **close-unit** - a unit is not "done" by assertion. The script builds it, runs the tests, confirms the
  tests actually ran (a green run of zero tests does not count), commits, and only then ticks the box.
- **the ratchet** - refuses a shrinking verification surface. A run once rewrote a test file and 15 of 16
  tests silently vanished; the suite went green. The ratchet blocks a close that has fewer tests than
  before.
- **the loop guard** - a PreToolUse hook that breaks a command/search spiral. One run repeated a single
  search 1023 times; another looped a shell probe 920 times.
- **doc-stats -Findings** - the project's real state is computed, not narrated, so the model cannot report a
  status that is not true.
- **the environment-block detector** - when Windows App Control / WDAC refuses to run a build, the kit
  STOPS and reports it, and forbids agents from disabling your security to get past it (a real run tried).

17 slash commands and 18 sub-agents sit on top of these, but the gates are the point.

---

## What it is / what it isn't

**It is:** a set of global Claude Code commands, agents, hooks, and deterministic scripts, plus one small
C# MCP server for local RAG and web search. It redirects Claude Code at Ollama and enforces a
design-doc-driven loop.

**It isn't:** a model, a fork of Claude Code, or a cloud service. It does not train or fine-tune anything.
It does not send your code anywhere once installed.

**Good fits today:** C#/.NET services and web apps, Python apps and data pipelines, research projects with a
document corpus and datasets (harvest logs, measurements) rendered as a site. **Weakest at:** anything
needing pixel-level visual judgement (there is no exit code for taste).

---

## Requirements

- Windows 10/11
- [Ollama](https://ollama.com) with a coding-capable model (Devstral, Qwen3-Coder, gpt-oss, etc.) - **local
  mode only**; with `install.ps1 -Cloud` you use Anthropic's API instead and Ollama is optional
- [Claude Code](https://www.anthropic.com/claude-code) (the CLI harness; DrDad points it at Ollama)
- .NET 8+ SDK (builds the one C# MCP server)
- A GPU with enough VRAM for your chosen model (16 GB runs the recommended set; the kit reports fit)

Everything after first install runs offline.

---

## Quickstart

```
git clone <your-fork-url> drdad
cd drdad
powershell -ExecutionPolicy Bypass -File .\install.ps1
# ...or add -Cloud to run the SAME loop against Anthropic's API instead of local Ollama:
#    powershell -ExecutionPolicy Bypass -File .\install.ps1 -Cloud
# ...or -Hybrid: the cloud loop PLUS your GPU as a drudge co-processor (the local_generate tool):
#    powershell -ExecutionPolicy Bypass -File .\install.ps1 -Hybrid
# ...and -CopilotCli ADDS GitHub Copilot CLI as a second harness (combine with any of the above):
#    powershell -ExecutionPolicy Bypass -File .\install.ps1 -CopilotCli
```

`-CopilotCli` is a HARNESS switch, not a backend mode: `-Cloud`/`-Hybrid` change where the model runs,
this changes which agent CLI enforces the gates. It leaves the Claude Code wiring untouched and also
writes `%USERPROFILE%\.copilot\hooks\dad.json`, so the SAME stop guard and loop guard run under
`copilot` too - including on a subagent's own tool calls. Copilot CLI normally signs in to GitHub, but
it can run account-free against your local Ollama (`COPILOT_PROVIDER_BASE_URL=http://localhost:11434/v1`),
which is the only reason it is in scope for an offline-first kit. See `docs/DESIGN.md` R37 / contract C2.

`install.ps1` detects its own location, reconciles Ollama with `models.json`, builds the C# server,
installs the global commands/agents and `settings.json` (paths auto-fixed), and puts `dad` on your PATH.

(Prefer not to clone? A zipped release installs the same way - extract it and run `install.cmd`. The release
asset is named `DrDad-v<x>.zip`. You will still see `DAD-kit` inside, in the dev-path placeholder
(`C:\Projects\Claude\MCP\DAD-kit`) that `install.ps1` rewrites to the real install location - that's by
design, not a leftover.)

Then, in a new shell:

```
dad doctor
```

confirms the install. Scaffold and run a project:

```
dad new-project general C:\src\myapp
```

Open it in VS Code with the Claude Code extension, then drive the loop:
`/design` -> `/stories` -> `/taskmap` -> `/build`. During a long pass, run `dad watch` in a second terminal -
it alerts if the session goes silent (the signature of a spiralling sub-agent).

Full manual: **[docs/GUIDE.md](docs/GUIDE.md)**. Every subcommand: run `dad` with no arguments.

---

## How it reaches the model

**Local (default):** there is no proxy. `settings.json` sets `ANTHROPIC_BASE_URL` to Ollama's local port and
Claude Code talks to it directly, so this depends on your Ollama version serving an Anthropic-compatible
endpoint. Telemetry, error reporting, and the auto-updater are disabled; after install you can unplug the
network.

**Cloud (`install.ps1 -Cloud`):** the base-URL redirect is dropped, so Claude Code uses its normal Anthropic
auth. The commands, agents, and every gate are identical - only the backend changes. Aliases map to Anthropic
models (`fast` -> Haiku 4.5, `dev`/`coder`/`oss`/`gemma` -> Sonnet 5, `quality` -> Opus 5); switch tiers with
`dad use-model <alias>`. This trades the offline/private/free properties for a model strong enough to clear
the local-model hurdles - use cloud for delivery, local for private discovery. Your GPU is **not** idle here:
the `local-tools` RAG (semantic search, corpus, `describe_image` UI review) still runs on Ollama if it is up,
so cloud mode VERIFIES the embed/vision models are pulled (otherwise search quietly degrades to a literal scan).

**Hybrid (`install.ps1 -Hybrid`):** the cloud agent loop of `-Cloud`, **plus** your GPU offered to the cloud
model as a drudge co-processor. It sets `LOCALTOOLS_HYBRID=1`, which turns on one extra MCP tool,
`local_generate`: the cloud model delegates BOUNDED, low-stakes generation to the local model - a first-pass
implementation guess it will review, synthetic test data, boilerplate - and keeps that work off the cloud
budget. The output is always a DRAFT the cloud model verifies; it is never banked or shipped raw. Division of
labor: cloud = the brain, the local GPU = senses (embeddings, vision) and drudge-work. `dad doctor` reports
the mode and confirms `local_generate` is actually exposed.

---

## Contributing

The one firm rule: **every fix ships with a test that would have caught it.** That is how the gate stays
meaningful. See [CONTRIBUTING.md](CONTRIBUTING.md). Run reports - "here is my transcript, here is where it
went wrong" - are the most valuable contribution right now; there is an issue template for them.

---

## Third-party components and licenses

DrDad's own code is MIT ([LICENSE](LICENSE)). It does **not** redistribute model weights or Claude Code -
`install.ps1` pulls Ollama models and you install Claude Code yourself, each under its own license. The base
models (Devstral, Qwen, gpt-oss, Gemma, etc.) carry their own terms; review them for your use. Pointing
Claude Code at a non-Anthropic backend is your responsibility to reconcile with its terms of service.

---

## Credits

DrDad was **designed and directed by Kristen Overmyer** - the thesis ("never accept an assertion a script
can settle"), every design decision, and the real local-model runs each gate was earned from. The
**implementation was done with Claude Code** (Anthropic); per-change attribution is in the `Co-Authored-By`
commit trailers. That a project about honest engineering under AI assistance was itself AI-assisted is the
point, not a caveat.

---

## Security

The kit scans for credentials before anything reaches git or the RAG index, never commits secrets, and its
agents are explicitly forbidden from weakening your machine's security to get a build to pass. To report a
vulnerability, see [SECURITY.md](SECURITY.md).

# DrDad - Design Research Document, Agentic Development

**Version 0.59.2** - a guard layer for agentic coding: a spec before code, a verifier that checks real
correctness, and context that persists across sessions, enforced by deterministic gates.

DrDad is a working implementation of the loop-engineering idea (see "Where this sits" below). It wraps the
real Claude Code agent loop in scripts the model cannot skip, so that "done" has to be demonstrated rather
than asserted. The design document is the contract; every mode aligns to it. Cloud is the default way to run
it; Local (your own GPU, no network) is kept as a resilience mode, and Hybrid adds your GPU to the cloud loop.

I built this to understand how agent loops work, and it turned out to be useful. It is a show-and-tell, not
a pitch: pre-1.0, one author, Windows-only, and the CHANGELOG is the honest record of how it got here.

---

## Status: honest

This is **pre-1.0 and candid about it.**

- The gates are real, tested (the kit's own suite, `test-kit.ps1`, runs 270 checks and must print
  `0 failed`), and each one was earned from a **measured failure** on a real run - see
  [CHANGELOG.md](CHANGELOG.md), which reads as a field log of every way a model sabotaged itself and the
  deterministic check that stopped it. Most of those failures came from small local models driven hard;
  the same gates are what remain useful when the model is a frontier one.
- **Local mode is the weakest backend, and that is understood.** A full `/design -> /build -> close` has not
  completed on a local model without human repair. The best local run produced a real ASP.NET Core app -
  controllers, EF Core migrations, integration tests, 15 of 44 tasks closed - before an external Windows
  policy blocked test execution. That is why Local is a resilience mode and not the headline: it exists for
  the afternoon the network is gone and you still want output (see below), not as the way to run the kit.
- **Windows-only, by design.** Built for a Windows box: PowerShell + `.cmd` scripts, a Windows-native
  installer and hooks. Cross-platform is a deliberate post-1.0 question (the C# server is already portable;
  the plumbing is not), not a near-term goal.
- **AI-assisted, openly.** See Credits.

If you want a polished product, this is not it yet. If you want to see a guard layer for agent loops get
hardened failure by failure, you are in the right place.

---

## The idea: never accept an assertion a script can settle

Models, driven hard, do things you would not accept from a colleague: delete tests to make a suite pass,
report work they did not do, write a task list no tool can parse, and loop one failing command a thousand
times. Prompting against this does not hold - across many graded runs, **every prose rule failed at least
once and every deterministic gate held.** So DrDad's rule is: if a script can check it, a script checks it,
and the model does not get a vote.

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
- **gate evidence** - `dad gates-smoke` provokes each gate and reports whether it actually fired; every gate
  decision lands in a committed log (`grades\gates-log.jsonl`); `dad run-summary` reports what a run cost
  (time, files, findings, gate hits, tokens), each figure labelled with its source.

17 slash commands and 18 sub-agents sit on top of these, but the gates are the point.

---

## Where this sits

DrDad's three ingredients - a spec before code, a verifier that checks real correctness, and persistent
context across sessions - are the shape that people have started calling "loop engineering". It is a 2026
term used in blog posts and guides about the agent loop Andrej Karpathy published as
[autoresearch](https://github.com/karpathy/autoresearch): a human-edited `program.md` as the spec, a fixed
time budget, and a numeric verifier (`val_bpb`) the agent cannot grade for itself. I could not find Karpathy
using the phrase "loop engineering" himself, so I credit the loop to autoresearch and the label to the
write-ups, not the other way round. DrDad is one working implementation of that shape for coding, with the
enforcement done by scripts instead of instructions.

Two independent projects landed in the same place, and I would rather point at them than pretend to be
alone:

- [claude-gates](https://github.com/DevRik99/claude-gates) (DevRik99) - installable, deterministic hooks for
  Claude Code that block or warn when a tool call breaks a rule (50 gates across 11 families at the time of
  writing).
- [claude-code-audit-gate](https://github.com/fotografvecerek-ai/claude-code-audit-gate)
  (fotografvecerek-ai) - an independent audit agent that never writes code, hands findings to the project
  agent, re-verifies each fix, and gates the release with hooks, a git pre-commit and GitHub Actions.

Both are MIT-licensed and worth a look. The shape converges: enforcement lives outside the model.

**One real disagreement.** claude-gates ships a `no-coauthor` gate that blocks a commit carrying an AI or
agent attribution trailer (`Co-Authored-By` and similar), enabled by default and overridable per commit or
in config. DrDad goes the other way: AI attribution is required, and the commit trailers are how this
repository's own history says which changes were AI-assisted. A guard layer that makes agents prove their
work should not also make the authorship harder to see.

**BMAD is the planning layer; DrDad is a guard layer.** [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD)
is where much of the industry has landed for agentic planning: personas, templates and context-engineered
story files. It is a method; DrDad is enforcement underneath whatever method you run. They are meant to
stack ("BMAD on DrDad"), not compete, and any methodology that writes a spec and tasks can run on top of the
gates.

---

## What may be new here

None of the pieces below is new on its own: hooks, ratchets, derived status, embeddings and design-first
planning all exist elsewhere. I compared against the three projects named above and BMAD, nothing wider, so
read "new" as "I did not see it there". What I think is distinctive is how the pieces are chosen and tied
together, and each item names its evidence.

- **Every gate is earned from a measured failure, and the record is kept.** The CHANGELOG reads as a field
  log: a model deleted tests until the suite went green (15 of 16 tests gone), one search repeated 1,023
  times, a shell probe looped 920 times. Each entry is a failure, a number, and the check that stops it.
- **The verification surface may not shrink.** The ratchet counts tests, stories, tasks, contracts, sources,
  the `Build:` line and grade-card bytes, and `close-unit` refuses a close if any fell. `recover-lost` then
  works on named units (methods, tests, headings) and tells MOVED from LOST, so a relocated test is not
  "restored" twice. The aim is to stop a model passing by deleting the thing being measured.
- **State is computed, and closing is not the model's to claim.** `doc-stats` derives the project's real status
  and `STATUS.md` is derived from it. `close-unit` is the only closer: it builds, runs the tests, confirms they
  ran, commits, and writes trailers (`closed:close-unit`, `UX-reviewed:`, `Playtested:`, `Shrink-accepted:`)
  that a hand-edit cannot produce. A task ticked by hand outside it is flagged.
- **A gate has to show it fired.** `dad gates-smoke` provokes each gate and reports whether it actually
  fired, and every decision lands in a committed log. Gates also fail open on their own bugs, on purpose: a
  gate that fails closed on its own defects stops real work and gets switched off.
- **A local RAG indexer shaped by watching runs.** The core is ordinary: per-project document corpora,
  chunking, local embeddings, cosine search, one small C# MCP server. Three parts came from failures:
  `API-SURFACE.md`, written by reflecting the exact public signatures out of the compiled assemblies, so a
  model retrieves a real signature and does not invent a plausible one; a **shell door**
  (`local-tools --search`, `docs-find`) because `search_datasheets` was called zero times across nine graded
  runs while shell commands were called constantly; and **provenance**, where `/research` and `dad corpus`
  build dated, cited banks and a stale source is flagged.
- **Hybrid mode with a fence you can check.** Sending cheap work to a local model is not new. The part I
  care about is that the fence is a mechanism and not a rule: `local_generate` is a separate tool that the
  server registers only when the mode flag is set, so in Cloud or Local mode it does not exist to be called.
  Its output is always labelled a draft that the cloud model must verify. Cloud is the brain; the GPU is senses
  (embeddings, vision) and drudge-work.
- **The kit is run on itself.** The same gates found two defects in the kit's own test suite: 17 tests that
  passed without ever running because a variable was read before it was set, and a hand-tick detector that
  could never match a real tick line. Both are fixed and recorded in the CHANGELOG (0.59.2).

Limits worth stating: those same findings show the gates need gates of their own, and the suite was wrong
until the kit's own checks caught it. The incident numbers come from my own runs and are in the CHANGELOG and
the grade cards, not from an independent benchmark.

---

## What it is / what it isn't

**It is:** a set of global Claude Code commands, agents, hooks, and deterministic scripts, plus one small
C# MCP server for document RAG and web search (8 tools, plus `local_generate` in hybrid mode). It enforces a
design-doc-driven loop whichever backend runs the model.

**It isn't:** a model, a fork of Claude Code, or a cloud service. It does not train or fine-tune anything.
It has no server of its own that your code is sent to.

**Good fits today:** C#/.NET services and web apps, Python apps and data pipelines, research projects with a
document corpus and datasets (harvest logs, measurements) rendered as a site. **Weakest at:** anything
needing pixel-level visual judgement (there is no exit code for taste).

---

## Requirements

- Windows 10/11
- [Claude Code](https://www.anthropic.com/claude-code) (the CLI harness)
- For **Cloud** and **Hybrid**: an Anthropic login or API key held by Claude Code itself (the kit never
  reads or stores it)
- [Ollama](https://ollama.com) - required for **Local** and **Hybrid**, and optional but recommended in
  **Cloud** (semantic search and screenshot review run on it; without it search falls back to a literal
  scan and the install says so). Local needs a model Ollama can serve to Claude Code.
- .NET 8+ SDK (builds the one C# MCP server)
- A GPU with enough VRAM for your chosen local model, if you use Ollama (16 GB runs the recommended set;
  the kit reports fit)

---

## Quickstart

```
git clone <your-fork-url> drdad
cd drdad
powershell -ExecutionPolicy Bypass -File .\install.ps1
# ...no flag is the Cloud install (`-Cloud` also works). Explicit options:
# ...-Local, the resilience mode: the same loop against Ollama on your own GPU, no network needed:
#    powershell -ExecutionPolicy Bypass -File .\install.ps1 -Local
# ...or -Hybrid: the cloud loop PLUS your GPU as a drudge co-processor (the local_generate tool):
#    powershell -ExecutionPolicy Bypass -File .\install.ps1 -Hybrid
# ...and -CopilotCli ADDS GitHub Copilot CLI as a second harness (combine with any of the above):
#    powershell -ExecutionPolicy Bypass -File .\install.ps1 -CopilotCli
```

A no-flag re-run keeps an installed Local or Hybrid mode instead of switching you to Cloud; the first install
on a machine with nothing to keep gives Cloud, and the banner says which rule applied. `-Local` together with
`-Cloud` or `-Hybrid` is a conflict: the installer exits before writing anything (`docs/DESIGN.md` C6).

`-CopilotCli` is a HARNESS switch, not a backend mode: `-Cloud`/`-Hybrid` change where the model runs,
this changes which agent CLI enforces the gates. It is a **pilot and unverified**: the contracts were
measured once, against one Copilot CLI version, and full parity is not claimed (`docs/DESIGN.md` R37, R39
and contract C2 say exactly what was and was not measured). It leaves the Claude Code wiring untouched and
also writes `%USERPROFILE%\.copilot\hooks\dad.json`, so the same stop guard and loop guard are wired into
`copilot` too.

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

confirms the install and reports which mode is active. Scaffold and run a project:

```
dad new-project general C:\src\myapp
```

Open it in VS Code with the Claude Code extension, then drive the loop:
`/design` -> `/stories` -> `/taskmap` -> `/build`. During a long pass, run `dad watch` in a second terminal -
it alerts if the session goes silent (the signature of a spiralling sub-agent).

Full manual: **[docs/GUIDE.md](docs/GUIDE.md)**. Every subcommand: run `dad` with no arguments.

---

## How it reaches the model

The commands, agents, and every gate are identical in all three modes. Only where the agent loop runs
changes.

**Cloud (`install.ps1`, no flag; `-Cloud` also works):** the default mode.
The base-URL redirect is dropped, so Claude Code uses
its normal Anthropic auth. Aliases map to Anthropic models (`fast` -> Haiku 4.5, `dev`/`coder`/`oss`/`gemma`
-> Sonnet 5, `quality` -> Opus 5); switch tiers with `dad use-model <alias>`. Your GPU is **not** idle
here: the `local-tools` RAG (semantic search, corpus, `describe_image` UI review) still runs on Ollama if it
is up, so cloud mode VERIFIES the embed/vision models are pulled (otherwise search quietly degrades to a
literal scan).

**Local (`install.ps1 -Local`):** a resilience mode, not
the goal. There is no proxy: `settings.json` sets `ANTHROPIC_BASE_URL` to Ollama's local port and Claude
Code talks to it directly, so this depends on your Ollama version serving an Anthropic-compatible endpoint.
Telemetry, error reporting, and the auto-updater are disabled. It exists for one real case: a disconnected
afternoon where you still want output. Two examples of the size of job it is for:

- feeding a few datasheets into your own rig (the corpus RAG) to get a simple SoC/IC wiring plan; or
- a small Unity3D prototype built from a one-page game design document.

Do not expect it to carry a large build unattended; that ceiling is the reason Cloud is the default.

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
meaningful. See [CONTRIBUTING.md](CONTRIBUTING.md).

Run reports are the evidence base this project runs on: "here is my transcript, here is where the model went
wrong (or the gate did)". Every gate here exists because of one, and a report from a different model, stack
or harness is worth more than a patch. There is an issue template for them. If you maintain one of the
sibling projects above, or build something with the same shape, comparing notes is welcome.

---

## Third-party components and licenses

DrDad's own code is MIT ([LICENSE](LICENSE)). It does **not** redistribute model weights or Claude Code -
`install.ps1` pulls Ollama models and you install Claude Code yourself, each under its own license. The base
models (Devstral, Qwen, gpt-oss, Gemma, etc.) carry their own terms; review them for your use. Pointing
Claude Code at a non-Anthropic backend is your responsibility to reconcile with its terms of service.

---

## Credits

DrDad was **designed and directed by Kristen Overmyer** - the thesis ("never accept an assertion a script
can settle"), every design decision, and the real runs each gate was earned from. The **implementation was
done with Claude Code** (Anthropic); per-change attribution is in the `Co-Authored-By` commit trailers. That
a project about honest engineering under AI assistance was itself AI-assisted is the point, not a caveat.

The loop shape it implements is not original to it: see "Where this sits" for the credit to Karpathy's
autoresearch, claude-gates, claude-code-audit-gate and BMAD.

---

## Security

The kit scans for credentials before anything reaches git or the RAG index, never commits secrets, and its
agents are explicitly forbidden from weakening your machine's security to get a build to pass. To report a
vulnerability, see [SECURITY.md](SECURITY.md).

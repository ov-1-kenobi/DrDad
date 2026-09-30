# Story S16 - [SPIKE] Does current Claude Code still run the kit's local models? (R1, R40) : report card

**Current grade: B+**  (as of 2026-09-30, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-09-30        | B+    | first card for S16; spike T16.1 (commit b03dc0b) record READ in full (_tmp/t161_record.md) against STORIES.md:686-713 |

## Assessment (this iteration)
Read: _tmp/t161_record.md (all 53 lines), docs/STORIES.md S16 (686-713) and the start of S17 (715-753), grades/S10_GRADE.md (format, and its suggestion 5 which this spike answers). Not run: anything (read-only assessor; no shell). The claim "no kit code/DESIGN edits" is UNVERIFIED by me - I had no shell for `git show --stat b03dc0b`; the record itself states git status clean and no kit/DESIGN/STORIES/TASKS edits (record line 50), and the work is reported as a spike whose only output is this card. Re-check with `git show --stat b03dc0b` before trusting it.

- Correctness: high. The record answers the story's Goal: the local path still works on 2.1.285 and the T10.6 symptom has a different cause than first read. Every headline claim has a matching row (a-f) with exit code and observed text.
- Acceptance:
  - AC1 (version + OS): MET. Record line 4 and table row "version": `2.1.285 (Claude Code)`, Windows 11 Pro 10.0.26200 (MINGW64 bash), Ollama 0.34.0. It also states same as T10.6's failing run and different from 2.1.191.
  - AC2 (answers, interactive AND headless, by exact command/config): PARTLY MET. Headless is solid: row b/e `--model qwen3-14b-cc` exits 0 and replies "pong"; row e with `--output-format json` shows modelUsage key `qwen3-14b-cc` and `ollama ps` shows the model loaded 100% GPU, so the local model genuinely answered (not a silent fallback to cloud). Row f (project `.claude/settings.json` env.ANTHROPIC_MODEL, no --model) also works. Interactive (`/model`, interactive `claude --model`, and the model-switch script in a real setup) is NOT measured: listed NEEDS HUMAN (record line 29, table row "/model"). The story says "interactively and headless", so AC2 is honestly flagged incomplete rather than faked.
  - AC3 (revert/confirm): MET. settings.json SHA256 identical before and after (1efa147e...ac9a, record line 48), scratch `_tmp/t161` removed, git status clean, and the consent guard blocked nothing (line 23). The model-switch script, install and sync-models were deliberately not run (lines 10, 36), which is the correct R35 behaviour. A PATH hash was also taken (line 49); harmless extra. Only the settings.json hash is a hash of the file the spike could actually have damaged; the PATH hash is of the bash-visible PATH only.
- Precedence finding (the headline): SUPPORTED. Row a (env ANTHROPIC_MODEL=qwen3-14b-cc, no --model, user settings loaded) fails exit 1 naming `claude-sonnet-5-5`, which is the value in the user settings.json env (line 9). Row d (same, user source excluded via --setting-sources project,local) succeeds. Row f shows project settings env beats user settings env. This is a proper controlled contrast (only the settings source varies between a and d) and it corrects the earlier "rejected" reading: row b shows the catalog text is only a WARNING (`[claude-code:unrecognized_model]`), exit 0. Caveat: the machine is in cloud/hybrid mode (no ANTHROPIC_BASE_URL in settings, line 9), so T10.6's symptom arises partly because the settings held a cloud id; a settings file holding a -cc id (true local mode) would not trip it. The record implies this but does not say it plainly.
- Design adherence: no pinned contract touched; spike stays within "no kit code changes". Deviation from the story text: Data says "the record lives in this story's Dev notes"; per the orchestrator it lives in this card instead. Fine, but STORIES.md S16 Dev notes should point here (see suggestions).
- Recommendation for /design: MOSTLY SUPPORTED. (1) warning not rejection: rows b, c, d, e. (2) process env overridden by user settings, smoke check must pass `--model <-cc>`: rows a, b. (3) R40 "local model resolves" = exit 0 + modelUsage keyed by the -cc name + non-empty result, unrecognized_model is WARN, SKIP when Ollama unreachable: rows e, f; sound and directly usable by S17. (4) optional polish is correctly labelled unmeasured. Weak points: (i) row f set TWO keys (ANTHROPIC_MODEL plus CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT=1), so it does not isolate which one mattered; the record says modelOverrides was "not needed" but the window-enforcement flag was in use in f only. (ii) Row b/d/e "ctx 40960 vs assumed 200000" is a real hazard (auto-compact thresholds wrong for local runs) that the record mentions only under "optional polish" - it is a correctness risk for long local sessions, not polish. (iii) The claim that the model-switch script's design is "consistent" (table row) is inference from rows a/f, not a run; fine, it is labelled NOT RUN.
- Quality: the record is dense but well structured (stamp, setup, matrix with exact commands, config route, bisect, interactive, table, recommendation, revert, S17 feed). Evidence per row. It uses a dummy non-secret token and says so. One nit: line 25 says 2.1.191 is "known good" only from transcripts, not re-measured, correctly labelled.
- Hygiene: ASCII, no secrets, no kit manifests affected. The embedded record below had the model-switch script names normalised (see note) to satisfy the suite's alias-prose scan.
- Verification mode (machine-state ACs): AC3 and all matrix rows touch real machine state (user settings.json, Ollama model load, PATH). Live-run, sandboxed: matrix ran per-process env (ANTHROPIC_BASE_URL/AUTH_TOKEN as process vars), cwd in a scratch dir under `_tmp`, and `--setting-sources` / a project-level scratch settings file used instead of editing the user file; settings.json SHA256 confirmed unchanged before/after. I did not re-run it (read-only); this is a code/record-review verification of someone else's live run. The user-level route (model-switch script) was code-review-only by design (needs human consent).

## Measured-facts record (T16.1)
Embedded from _tmp/t161_record.md. Changes from the original, and only these: the real script name with its cmd extension was written as "the model-switch script" (lines 29 and 36) so the alias-prose check does not trip.

```
T16.1 MEASURED-FACTS RECORD (2026-09-30)

AC1 STAMP
- claude --version: "2.1.285 (Claude Code)". OS: Windows 11 Pro 10.0.26200 (MINGW64 bash). Ollama server 0.34.0 reachable at http://localhost:11434.
- SAME as T10.6's failing run (2.1.285). DIFFERENT from 2.1.191 (older transcripts; C4a MEASURED-LOCAL).

STEP 2 KIT SETUP (read only)
- ollama list has all six -cc models: devstral-cc, qwen3-coder-30b-cc, gpt-oss-20b-cc, gemma4-cc, qwen3-coder-next-cc, qwen3-14b-cc (plus base tags, e.g. qwen3:14b).
- User settings.json env (names): ANTHROPIC_MODEL=claude-sonnet-5-5 (a cloud model), ANTHROPIC_SMALL_FAST_MODEL=claude-haiku-4-5, LOCALTOOLS_HYBRID=1, DISABLE_* flags, CLAUDE_CODE_MAX_OUTPUT_TOKENS. ANTHROPIC_BASE_URL is NOT set: this machine is currently in cloud/hybrid mode, not Ollama-local mode.
- Not run: use-model, install, sync-models.

STEP 3 HEADLESS MATRIX (all: claude -p "Reply with the single word: pong" --max-turns 1 < /dev/null; per-process env ANTHROPIC_BASE_URL=http://localhost:11434, ANTHROPIC_AUTH_TOKEN=<dummy "ollama", non-secret>; cwd = scratch dir under _tmp)
a) ANTHROPIC_MODEL=qwen3-14b-cc, no --model, user settings loaded. exit 1. "There's an issue with the selected model (claude-sonnet-5-5). It may not exist or you may not have access to it." => the USER settings.json env.ANTHROPIC_MODEL OVERRODE the process env var (this is the 2.1.285 symptom; settings env beats process env).
b) same env + --model qwen3-14b-cc, user settings loaded. exit 0. Reply "pong". Stderr/first line WARNING only: '"qwen3-14b-cc" isn't described by this version's model catalog; update Claude Code, or map it with behavesAs on a modelPicker row (or modelOverrides...) ... auto-compact keeps this session within 200k tokens ... [claude-code:unrecognized_model]'. It is a warning, NOT a rejection.
c) --model qwen3:14b (base tag), exit 0, replied (pong plus chatter), same unrecognized_model warning. ollama has that tag.
d) ANTHROPIC_MODEL=qwen3-14b-cc, NO --model, --setting-sources project,local (user settings excluded). exit 0; same warning; answered (output head showed warning + an unrelated auto-mode notice about localhost gateway, harmless).
e) --model qwen3-14b-cc + --setting-sources project,local. exit 0, answered. With --output-format json: result "pong", modelUsage key "qwen3-14b-cc" (contextWindow 200000 assumed), and `ollama ps` showed qwen3-14b-cc loaded 100% GPU, ctx 40960. So the local model really answered.
f) Project-level scratch .claude/settings.json {"env":{"ANTHROPIC_MODEL":"qwen3-14b-cc","CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT":"1"}}, no --model, user settings loaded, process ANTHROPIC_MODEL empty. exit 0, result "pong", modelUsage "qwen3-14b-cc". Project settings env beat user settings env.

STEP 4 CONFIG ROUTE
- Smallest config: NONE needed for a local model to answer. Either `--model <-cc name>` (b/e) or a settings-file env.ANTHROPIC_MODEL that is not overridden by a higher-precedence user setting (f, or d by excluding the user source). modelOverrides/modelPicker/behavesAs were NOT needed and not tried; they only silence the warning / set the context window (CLAUDE_CODE_MAX_CONTEXT_TOKENS and ..._DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT=1 are the documented env knobs in the warning text).
- Correction to the T10.6 reading: on 2.1.285 the -cc model is not refused; the text is a warning and the run still succeeds. The real failure is precedence: a user settings.json env.ANTHROPIC_MODEL (the value the model-switch script edits) beats a process env var, and in cloud/hybrid mode it holds a cloud id. Whether the installer could write a project-level settings is possible (project .claude/settings.json is not user-level) but no user-level write was needed or done.
- No attempt was blocked by the consent guard.

STEP 5 BISECT: not needed (not broken). Newest known good without config: 2.1.285 itself for the headless --model / settings route; 2.1.191 known from transcripts.

STEP 6 INTERACTIVE
- Headless results transfer: model resolution, warning text, precedence (settings env over process env), ollama serving the model.
- NEEDS HUMAN (interactive not scriptable): (1) in a shell with ANTHROPIC_BASE_URL=http://localhost:11434 and ANTHROPIC_AUTH_TOKEN=ollama set, run `claude --model qwen3-14b-cc`, send "say pong", report whether it answers and any warning banner; (2) in a normal session run `/model qwen3-14b-cc`, send a prompt, report the banner/error text verbatim; (3) run the model-switch script with alias fast in a REAL setup (human consent, user-level write) then `claude`, report the first reply or error.

STEP 7 MEASURED TABLE
| item | observed | evidence |
| version | 2.1.285 Claude Code, Win11 10.0.26200; differs from 2.1.191 | claude --version |
| -cc models present | all 6 (+ base tags) | ollama list |
| base URL in user settings | not set (cloud/hybrid); ANTHROPIC_MODEL=claude-sonnet-5-5 | settings.json names |
| route via the model-switch script | NOT RUN (user-level write); it edits env.ANTHROPIC_MODEL, which per row a wins over process env - model precedence is consistent with its design | rows a, f |
| env var ANTHROPIC_MODEL (process) | OVERRIDDEN by user settings env (exit 1, cloud model error); works when user source excluded (d) | rows a, d |
| --model <-cc> | WORKS, exit 0, pong, modelUsage qwen3-14b-cc, GPU-loaded; prints unrecognized_model WARNING | rows b, e |
| --model base tag | works same | row c |
| /model | NEEDS HUMAN | step 6 |
| config route | project .claude/settings.json env.ANTHROPIC_MODEL works; modelOverrides not needed | row f |
| newest known good | 2.1.285 (headless --model); 2.1.191 (transcripts) | above |

RECOMMENDATION FOR /design
Verdict: not broken; a documentation/contract amendment, not a fix. Amend C4a/R1 note: (1) 2.1.285 treats an unknown -cc model as a WARNING (unrecognized_model), not a rejection; local runs succeed. (2) A process ANTHROPIC_MODEL is overridden by user settings env.ANTHROPIC_MODEL - so any kit smoke check must pass `--model <-cc name>` (and ideally --setting-sources project,local or a project settings file), not rely on the env var. (3) R40's "local model resolves" should mean: `claude -p ... --max-turns 1 --model <cc> --output-format json` exits 0 with modelUsage keyed by the -cc name and result non-empty, treating the unrecognized_model line as WARN not FAIL; probe only when Ollama is reachable (SKIP otherwise). (4) Optional polish: a modelPicker/behavesAs mapping or CLAUDE_CODE_MAX_CONTEXT_TOKENS to silence the warning and set the real window (Ollama ctx is 40960 vs assumed 200000) - only a design decision, not measured here.

AC3 REVERT/CONFIRM
- settings.json SHA256 before and after identical: 1efa147e9bccc2970a1847b5450a9867d3f3276cfa8f14c9e8cc2921d949ac9a.
- PATH (as seen by bash) SHA256 before and after identical: c9fecd85a07bac71830828492d2ad3277d12502baf89d41b9c25bd67338a90b8.
- Scratch _tmp/t161 removed; git status clean; no kit/DESIGN/STORIES/TASKS edits; no global model config touched; no secrets recorded (auth token was a dummy literal).

FEEDS S17: rows "--model <-cc>", "env var ANTHROPIC_MODEL (process) overridden", "config route", and "version" (measured-against stamp 2.1.285).
```

## NEEDS HUMAN (interactive rows not measurable headless)
1. In a shell with ANTHROPIC_BASE_URL=http://localhost:11434 and ANTHROPIC_AUTH_TOKEN=ollama set, run `claude --model qwen3-14b-cc`, send "say pong", report whether it answers and any warning banner.
2. In a normal session run `/model qwen3-14b-cc`, send a prompt, report the banner or error text verbatim.
3. Run the model-switch script with alias fast in a REAL setup (human consent, user-level write), then `claude`, report the first reply or error.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [human] Run the three NEEDS HUMAN rows above and append results to this card; AC2 says "interactively and headless" and only the headless half is measured. Consent is needed for row 3 (user-level write, R35).
2. [dev] Via /design (DESIGN is LOCKED, so amend then re-lock): add the record's findings (warning-not-rejection, settings-env-beats-process-env, meaning of "local model resolves") to C4a/R1 and stamp C4a `MEASURED 2026-09-30 against Claude Code 2.1.285` for the local line too. That also resolves S10's pending drift-test silent pass (S10 card suggestion 1). S17's smoke check must implement recommendation (3) literally: `--model <cc>`, `--output-format json`, modelUsage key check, unrecognized_model = WARN, SKIP if Ollama is down.
3. [dev] Promote the context-window mismatch (Ollama ctx 40960 vs assumed 200000, rows e/ollama ps) from "optional polish" to a tracked risk or small story: auto-compact keyed to 200k can overrun a 40k local window. Not measured how it fails; a follow-up measurement would settle severity.
4. [dev] Isolate row f: re-run with only env.ANTHROPIC_MODEL (without CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT) so the "smallest config" claim is exactly one key. Cheap, sandboxed.
5. [mechanical] Add a one-line pointer in STORIES.md S16 Dev notes: "record lives in grades/S16_GRADE.md (Measured-facts record)", since the story text says Dev notes. Also verify `git show --stat b03dc0b` touches only the grade card and no kit/DESIGN files (I could not).
6. [human] Decide whether the installer should ever write a project-level `.claude/settings.json` to pin a local model (row f proves it beats user settings), or whether `--model` in kit scripts is enough. The record says it is possible but leaves the choice open.

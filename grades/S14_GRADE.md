# Story S14 - Copilot CLI measurement spike (R39a, feeds C5) : report card

**Current grade: A-**  (as of 2026-09-30, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-09-30        | A-    | first card for S14 (single task T14.1, commit e313aa0); record read from _tmp/t141_record.md and embedded below |

## Assessment (this iteration)
Read: _tmp/t141_record.md (all 65 lines), docs/TASKS.md T14.1 (1575-1626: Do steps 1-7 and Acceptance), docs/DESIGN.md (grep for C5: the only hit is the R39 prose at line 472, so there is no C5 contract section; C5 is unpinned). NOT done: `git show --stat e313aa0` - this assessor has no shell, so the "no kit code / DESIGN edits" claim is verified only indirectly (DESIGN has no C5 text; TASKS says no kit code). The orchestrator must run the stat itself.

- Correctness: the spike did what the task asked. Every fact is a row with an observed value and an evidence command, from the installed binary (1.0.89) in scratch projects. No vendor-doc claims are used as facts. Hook payloads are hook-captured, not hand-written.
- Acceptance vs the record:
  - AC1 stamp: MET. "GitHub Copilot CLI 1.0.89." plus Windows 11 Pro 10.0.26200, and it states the version equals C2's baseline.
  - AC2 MCP route: MET. Root cause found (folder trust, not schema); a reproducible route is given (.mcp.json + LOCALTOOLS_DOCS_DIR=./docs + COPILOT_ALLOW_ALL=true + `copilot mcp list`), and a real list_datasheets call was answered. Relative docs path works, ${workspaceFolder} is not expanded (answers R39c). Gap: the trust step is reproducible only through an env var; the interactive trust path was not measured. --additional-mcp-config was not exercised (acceptable, workspace file sufficed).
  - AC3 agents/commands: MET with gaps. Agents: load as-is. Commands as skills: 2 of 19 load raw, 15 load after quoting, the rest uncounted (audit and grade "cause not individually counted"; corpus and research need escaping) - so the verdict "needs transform" is firm but the exact residual failures are not enumerated. Subagent orchestration via `task` is measured (PROBE-AGENT-OK). No-equivalent items named ($ARGUMENTS substitution, allowed-tools mapping, Claude hook/permission settings) - though the record says "not measured" there, not "no equivalent", so this is unresolved rather than negative.
  - AC4 hook payloads: MET. Four verbatim payloads with cwd and session_id/sessionId shown; behaviour after in-session cd (unchanged) and subdirectory launch (launch dir) measured; C3f dependence written out. Strong finding: payload shape depends on event-name casing. The task asked for "PreToolUse and Stop" only; it also captured camelCase, which is scope-appropriate.
  - AC5 revert/consent: MET. config.json SHA256 identical before/after; skills, agents, hooks, mcp-config.json, settings.json absent; scratch removed; git status clean; Copilot's own runtime churn separated from kit writes. Verdict list feeds C5 is present (5 items).
- Design: C5 left UNPINNED (no C5 heading in DESIGN.md) and the record defers pinning to /design. Consent guard honoured (no user-level write; trust-prompt run correctly skipped and reported with its suspected write). No scope creep observed.
- Quality: clear tables, redaction correct (transcript_path replaced by <REDACTED>; no tokens; env values masked). Weaknesses: the record is only in a gitignored scratch file and this card, so it must be copied here (done below) or it is lost after `dad tidy`; some rows are vague ("variants tested", "scratch listing") and not re-runnable from the record alone; "Agent discovery without COPILOT_ALLOW_ALL: inconclusive" leaves the agent verdict trust-dependent.
- Hygiene: no manifest/dependency surface touched by a spike. Verification mode: all measurements live against the real CLI in scratch dirs under _tmp, with COPILOT_ALLOW_ALL as a process env var (no file write); ~\.copilot confirmed untouched by hash. The interactive trust prompt AC was NOT live-run (would likely write config.json) - listed as unmeasured, correctly.

### Unmeasured items (carry into /design; do not pin these in C5 as facts)
1. Claude `tools:` names (incl mcp__local-tools__*) -> Copilot tool mapping: agents load but effective tool grants unknown.
2. User-level discovery paths (~/.copilot/agents, ~/.copilot/skills, plugins): consent guard.
3. Trust-prompt persistence (interactive folder trust; probable config.json write) - needs a human-attended run.
4. $ARGUMENTS-style substitution in skills; allowed-tools mapping; Claude hook/permission settings equivalents.
5. Exact failure cause for audit and grade skills; behaviour of agent discovery without trust.

## Measured-facts record (T14.1)
Verbatim from _tmp/t141_record.md; /design reads this section to pin C5.

# T14.1 measured-facts record (Copilot CLI 1.0.89, Windows 11 Pro 10.0.26200, measured 2026-09-30)

Method: scratch projects under _tmp\t141 (removed). Five model-invoking -p sessions, COPILOT_ALLOW_ALL=true as an env var (writes nothing). Hook capture per the T9.5 recipe.

## AC1 version
- `copilot --version` = "GitHub Copilot CLI 1.0.89." - same as C2's baseline. OS Windows 11 Pro 10.0.26200. Hooks and the model's shell tool use PowerShell (toolName `powershell`).

## Q1 / AC2 MCP
| Fact | Observed | Evidence |
|---|---|---|
| Why repo .mcp.json did not list | FOLDER TRUST: workspace MCP servers, skills, hooks load only for a trusted folder. COPILOT_ALLOW_ALL=true (exactly "true") trusts the cwd | `copilot mcp list` shows only github-mcp-server without it, local-tools (local) with it |
| Repo .mcp.json schema | works as-is (mcpServers, absolute exe path, env block, no type/args) | `copilot mcp get local-tools`: Enabled, local, tools *, Source Workspace |
| .github/mcp.json | works the same | scratch listing |
| key names / type / tools / args | not the cause (type:"stdio", tools:["*"] also listed) | variants tested |
| env values | masked (***) in `mcp get` | mcp get |
| git root | a .mcp.json at an ancestor git root is also picked up from a nested dir | listing |
| tool call | real list_datasheets call answered via workspace .mcp.json | `copilot -p ... -s --allow-all-tools` |
| docs path w/o machine path | "LOCALTOOLS_DOCS_DIR":"./docs" works (resolves vs session cwd); ${workspaceFolder} NOT expanded | two servers in one session |
| remaining machine path | the exe `command` is still absolute; local-tools not on PATH. --additional-mcp-config not needed/not exercised | which local-tools |
Route: .mcp.json in project + LOCALTOOLS_DOCS_DIR=./docs + trust the folder (COPILOT_ALLOW_ALL=true env, or the interactive prompt - NOT measured, probably a config.json user-level write) + `copilot mcp list`.

## Q2 / AC3 agents and skills
| Artifact | Verdict | Observed |
|---|---|---|
| Agent locations | .github/agents/*.md and *.agent.md, and .claude/agents/*.md (user-level ~/.copilot/agents and plugins NOT tested) | `copilot --agent <nonexistent> -p hi` lists available agents |
| global\agents\*.md (Claude frontmatter name/description/tools incl mcp__local-tools__*) | LOADS AS-IS (discovered, no error); whether Claude tools: names map to Copilot tools NOT measured | 3 unmodified copies listed |
| Skill locations | .github/skills/<n>/SKILL.md, .agents/skills/, .claude/skills/ all discovered (user-level ~/.copilot/skills NOT tested) | `copilot skill list` |
| global\commands\*.md raw as skills | 2 of 19 load as-is (corpus, scaffold); 13 fail "argument-hint must be a string" ([...] parses as YAML list); assess and design fail YAML parse (colon in unquoted scalar); audit and grade in the failure list, cause not individually counted | skill list failure block |
| commands after transform | NEEDS TRANSFORM: single-quoting description and argument-hint made 15 load; corpus and research already contain ' so need proper escaping | skill list |
| skill orchestrating subagents like /build | WORKS: skill /probe spawned a custom agent via Copilot's `task` tool, reply returned | PROBE-AGENT-OK |
| No equivalent found / not measured | $ARGUMENTS-style substitution in skill bodies (argument-hint is only a string), allowed-tools/tools mapping, Claude hook/permission settings | - |
Agent discovery without COPILOT_ALLOW_ALL: inconclusive.

## Q3 / AC4 hook payloads
Hooks at .github/hooks/cap.json: {"version":1,"hooks":{<event>:[{"type":"command","bash":...,"powershell":...,"timeoutSec":20}]}}. On Windows the `powershell` field ran, `bash` did not. Events: preToolUse, PreToolUse, agentStop, Stop (all fired; case-insensitive FS merged capture files).
| Fact | Observed |
|---|---|
| event casing decides payload shape | camelCase events (preToolUse, agentStop) -> camelCase payload; PascalCase events (PreToolUse, Stop) -> Claude-style snake_case payload with hook_event_name |
| cwd | PRESENT, non-empty in all four payloads; absolute Windows path |
| session_id / sessionId | PRESENT, UUID (session_id in PascalCase shape, sessionId in camelCase shape) |
| launch from subdirectory | cwd = launch dir (not git root); git-root .github/hooks still found |
| after in-session cd | cwd UNCHANGED (launch dir) on the next PreToolUse |
| tool name | PascalCase: tool_name:"Bash" (alias); camelCase: toolName:"powershell" |
| Stop payload | stop_reason, stop_hook_active:false, transcript path (events.jsonl under ~\.copilot\session-state\) |

Verbatim captured payloads (hook-captured; home transcript path redacted, no secrets):
- PascalCase PreToolUse: {"hook_event_name":"PreToolUse","session_id":"1d0ab973-d259-4a6f-bc5e-6188c753ac5b","timestamp":"2026-09-30T19:18:03.077Z","cwd":"D:\\projects\\DrDad\\_tmp\\t141\\p9","tool_name":"Bash","tool_input":{"command":"echo hello-root","description":"Run the requested shell command","mode":"sync","initial_wait":10}}
- camelCase preToolUse: {"sessionId":"1d0ab973-d259-4a6f-bc5e-6188c753ac5b","timestamp":1790795883077,"cwd":"D:\\projects\\DrDad\\_tmp\\t141\\p9","toolName":"powershell","toolArgs":{"command":"echo hello-root","description":"Run the requested shell command","mode":"sync","initial_wait":10}}
- PascalCase Stop: {"hook_event_name":"Stop","session_id":"1d0ab973-d259-4a6f-bc5e-6188c753ac5b","timestamp":"2026-09-30T19:18:05.022Z","cwd":"D:\\projects\\DrDad\\_tmp\\t141\\p9","transcript_path":"<REDACTED>","stop_reason":"end_turn","stop_hook_active":false}
- camelCase agentStop: {"sessionId":"1d0ab973-d259-4a6f-bc5e-6188c753ac5b","timestamp":1790795885022,"cwd":"D:\\projects\\DrDad\\_tmp\\t141\\p9","transcriptPath":"<REDACTED>","stopReason":"end_turn","stop_hook_active":false}

C3f dependence: Copilot always supplies a non-empty cwd, so the loop-guard / dad-guard gate-log writers would not go silently dead as they would on an empty cwd. But cwd is the LAUNCH dir and does not follow in-session cd; a subdirectory launch gives a subdirectory cwd, so the writer must not treat cwd as the project root. Field names differ by event casing (session_id vs sessionId): C5 must pin which casing the kit's hooks register.

## AC5 revert / consent guard
- Scratch dir, temp hook and scratch configs removed. ~\.copilot\config.json identical by SHA256 before/after. skills\, agents\, hooks\, mcp-config.json, settings.json do not exist (not created).
- Copilot's own runtime churn (not kit writes): new session-state\<uuid>\ folders, logs\process-*.log, session-store.db*, plus an empty installed-plugins.lock and plugin-data\_direct\ created on session start.
- Consent guard never tripped. Not tested: interactive trust prompt (likely writes folder trust to config.json -> human-attended run needed).
- git status clean.

## Verdicts feeding C5
1. MCP: repo .mcp.json loads as-is; blocker is folder trust, not schema. Docs path: relative ./docs works, ${workspaceFolder} does not; absolute exe path is the one machine-specific value left.
2. Agents: global\agents\*.md load as-is from .github/agents/ or .claude/agents/.
3. Commands as skills: need a transform (quote description and argument-hint, escape embedded quotes); a skill can drive subagents via the task tool, so the /build pattern is viable.
4. Hooks: Windows needs the `powershell` field; payload shape depends on event casing; cwd always present, non-empty, = launch dir; session id is a UUID.
5. Open / not measured: Claude tools: -> Copilot tool mapping, user-level discovery paths, trust persistence via the interactive prompt.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [human] Run `git show --stat e313aa0` (this assessor could not) and confirm only docs/TASKS.md (tick) and grades/ changed - no kit code, no DESIGN.md. Then decide whether to run the human-attended interactive trust-prompt measurement (likely a config.json write; consent needed) before pinning C5.
2. [human] Run /design to pin C5 from the record above, stating explicitly that the trust step (COPILOT_ALLOW_ALL vs interactive prompt), the `tools:` mapping and user-level paths are unmeasured, and choosing which hook-event casing the kit registers (session_id vs sessionId). C5 must remain unpinned until then; no R39 story may be sharded before it.
3. [dev] A follow-up measurement task (still no DESIGN edit) to enumerate exactly which of the 19 command files measured fail after the quote transform and why (audit, grade, corpus, research escaping), and to probe $ARGUMENTS substitution in skills - needed to size the commands->skills transform.
4. [mechanical] Keep this card as the durable record: _tmp is gitignored and emptied by dad tidy, so do not delete or shorten the embedded section; the TASKS tick for T14.1 already exists (line 1575).

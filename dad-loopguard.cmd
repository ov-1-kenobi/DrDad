@echo off
REM dad-loopguard.cmd - the PreToolUse hook: breaks tight command loops and rejects `2>nul` under Bash.
REM Wired automatically by install.cmd (settings.json "hooks"). You rarely run it by hand.
REM   dad-loopguard.cmd -Check           self-test: what would it do for sample commands?
REM   dad-loopguard.cmd -Reset           forget the repeat-streak state for every session
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dad-loopguard.ps1" %*

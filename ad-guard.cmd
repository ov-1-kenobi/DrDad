@echo off
REM ad-guard.cmd - the Stop hook: refuses to let a turn end with uncommitted, unverified code.
REM Wired automatically by install.cmd (settings.json "hooks"). You rarely run it by hand.
REM   ad-guard.cmd -Check               would it block right now? (exit 1 = yes)
REM   ad-guard.cmd -Ack                 "this edit is deliberately unverified" - allow the next stop
REM   ad-guard.cmd -Check -ProjectDir C:\src\App
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ad-guard.ps1" %*

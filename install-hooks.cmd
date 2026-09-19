@echo off
REM install-hooks.cmd - install this project's git pre-commit hook (secret scan).
REM Skips projects already managed by husky / pre-commit / lefthook.
REM   install-hooks.cmd [-ProjectDir .] [-Force]
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-hooks.ps1" %*

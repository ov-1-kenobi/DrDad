@echo off
REM upgrade-project.cmd [projectDir] - retrofit an existing AD project to the current kit.
REM Adds missing docs (STATUS/COMMANDS), git safety net, and refreshes CLAUDE.md's kit-owned
REM sections while preserving your Stack/Build/test. Safe to re-run.
REM   upgrade-project.cmd                 (upgrade the current folder)
REM   upgrade-project.cmd C:\src\MyApp    (upgrade a named folder)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0upgrade-project.ps1" %*

@echo off
REM new-project.cmd <general|experience> [projectDir] - deterministic, STACK-AGNOSTIC AD-kit scaffolder.
REM Lays down a generic CLAUDE.md + .mcp.json + docs/ + the design doc (DRAFT). The STACK is chosen later
REM in /forge. KIND picks the design doc: general -> docs\DESIGN.md, experience -> docs\TEDD.md.
REM   new-project.cmd general                 (general software, into the current folder)
REM   new-project.cmd experience C:\src\Game  (interactive/game/XR/sim, into a named folder)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0new-project.ps1" %*

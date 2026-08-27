@echo off
REM dad.cmd - THE single entry point for every DAD-kit operation.
REM
REM   dad                       list the subcommands
REM   dad doc-stats -Findings   run doc-stats
REM   dad close-unit -Id T1.1 -Title "walking skeleton"
REM   dad doctor                same as dad-doctor
REM
REM WHY ONE ENTRY POINT:
REM  1. SHELL NEUTRALITY. This is a .cmd, so it runs identically from Git Bash, cmd and PowerShell, and
REM     Git Bash converts POSIX paths to Windows paths on the way in. The model never has to know which
REM     shell it is in, and never writes shell-specific syntax for a kit operation. Mixing shell dialects
REM     is how one run emitted `dir ... 2>nul` (cmd syntax under bash), got an EMPTY result with no error
REM     because bash wrote stderr to a file named nul, and repeated it 920 times.
REM  2. PERMISSIONS. Claude Code's allow list is per-executable. With 24 separate wrappers the model
REM     either gets a permission prompt per script - and prompts are what make agents stall and start
REM     improvising - or the allow list needs 24 entries that drift. One entry point needs one entry:
REM     Bash(dad:*).
REM  3. BREVITY. It replaces `powershell -ExecutionPolicy Bypass -File "C:\long\path\doc-stats.ps1"`.
REM     Shorter command lines are less for a 14-32B local model to get wrong.
REM
REM The individual <name>.cmd wrappers still exist and still work; this dispatches to them.

setlocal EnableDelayedExpansion
set "KIT=%~dp0"
if "%KIT:~-1%"=="\" set "KIT=%KIT:~0,-1%"

set "SUB=%~1"
if "%SUB%"=="" goto :usage
if /i "%SUB%"=="-h" goto :usage
if /i "%SUB%"=="--help" goto :usage
if /i "%SUB%"=="help" goto :usage

REM Collect the remaining arguments with their original quoting intact.
shift
set "ARGS="
:collect
if "%~1"=="" goto :resolve
set "ARGS=!ARGS! %1"
shift
goto :collect

:resolve
REM Accept both `dad doctor` and `dad dad-doctor`; the kit's own scripts are named dad-*.
set "TARGET=%KIT%\%SUB%.cmd"
if exist "%TARGET%" goto :run
set "TARGET=%KIT%\dad-%SUB%.cmd"
if exist "%TARGET%" goto :run

echo dad: unknown subcommand '%SUB%'
echo.
goto :usage

:run
call "%TARGET%" %ARGS%
exit /b %ERRORLEVEL%

:usage
echo DAD-kit - one entry point for every kit operation. Works from Git Bash, cmd and PowerShell.
echo.
echo   Usage: dad ^<subcommand^> [args]
echo.
echo   Project state (read-only, safe to run any time):
echo     dad doc-stats                 the REAL counts - never estimate these
echo     dad doc-stats -Findings       computed state findings (the model must not author these)
echo     dad doc-stats -Contract C6    does contract C6 exist? settles it by grep
echo     dad docs-find "question"      search the indexed corpus from the shell
echo     dad source-stats              citation integrity for /research
echo     dad data-stats                dataset integrity: do the files match docs\DATASETS.md?
echo     dad grade-trends              grade direction over time
echo     dad doctor                    readiness check; prints the fix commands
echo.
echo   While a long pass runs (SECOND terminal):
echo     dad watch                     alerts when nothing has been written for 3 minutes.
echo                                   Nothing can interrupt a spiralling subagent - this makes the
echo                                   silence loud in minutes instead of hours. -IdleMinutes to tune.
echo.
echo   Closing work out (these VERIFY - they build, test, and commit):
echo     dad close-unit -Id T1.1 -Title "short title"
echo     dad ratchet                   has the verification surface shrunk?
echo     dad recover-lost              what did a rewrite drop? -Restore puts it back
echo     dad free-locks                clear a build lock a left-over app process holds (MSB3026)
echo     dad api-surface -Lookup Type  real signatures from the compiled assembly
echo.
echo   Project lifecycle:
echo     dad new-project general [dir] scaffold (the KIND is required and comes first)
echo     dad upgrade-project [dir]     retrofit an existing project to this kit
echo     dad reindex "<dir>\docs"      rebuild the RAG index
echo     dad publish-run -Transcript <f> -ProjectDir <p>   secret-scan + record a run in runs\ (commits, never pushes)
echo     dad scan-secrets              credential scan
echo.
echo   Kit maintenance:
echo     dad test-kit                  the validation gate; must print 0 failed
echo     dad sync-models -Report       reconcile Ollama with models.json
echo     dad use-model dev             switch model, then restart Claude Code
echo.
exit /b 1

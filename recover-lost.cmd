@echo off
REM recover-lost.cmd - find named units (methods, tests, functions, headings) that VANISHED from files
REM since the ratchet baseline, and put back the ones that genuinely disappeared - keeping whatever the
REM change ADDED. A whole-file revert would throw away the good half.
REM   recover-lost.cmd                     report what was lost
REM   recover-lost.cmd -Since <sha>        compare against a specific commit
REM   recover-lost.cmd -Path src/Foo.cs    one file
REM   recover-lost.cmd -Restore            write the vanished units back (commented, to reconcile)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0recover-lost.ps1" %*

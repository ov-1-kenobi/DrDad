@echo off
REM close-unit.cmd - close ONE completed unit (task or story): verify build (+tests at story
REM close), tick TASKS.md, roll the story up, reindex, commit, verify. Non-zero exit = NOT closed.
REM   close-unit.cmd -Id T8.1 -Title "Add the thing"
REM   close-unit.cmd -Id S3 -Title "Story polish" -RequireGrade
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0close-unit.ps1" %*

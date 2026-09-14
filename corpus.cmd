@echo off
REM corpus.cmd - manage DrDad knowledge corpora (cited banks projects consult instead of re-researching).
REM   corpus.cmd                          list corpora in the 'default' environment
REM   corpus.cmd new security -Env web    scaffold a corpus + its CORPUS.md manifest
REM   corpus.cmd build security -Env web  index it (local-tools --reindex)
REM   corpus.cmd search security "how to test antiforgery" -Env web
REM   corpus.cmd remove security -Env web archive to a dated zip, then remove (safe)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0corpus.ps1" %*

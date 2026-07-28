@echo off
REM test-kit.cmd - run the kit's own test suite (no Ollama/GPU/network needed).
REM   test-kit.cmd              full suite
REM   test-kit.cmd -SkipBuild   fast pass: docs + scripts only
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0test-kit.ps1" %*

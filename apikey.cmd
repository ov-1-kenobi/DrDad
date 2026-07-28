@echo off
REM apikey.cmd
REM Claude Code runs this and uses whatever it prints as the API key.
REM Against local Ollama the key is never validated, so any non-empty string works.
REM This exists only to skip the first-run login/onboarding screen.
echo dummy-local-key-ignored-by-ollama

# Publishing DrDad to a public GitHub repo

A maintainer runbook. The goal is a **clean-slate** release: publish a fresh, audited copy rather than
this working repo's full history, so no old commit can leak anything. You keep the CHANGELOG (it is a file
and travels); you drop 57 commits of history that would otherwise need a line-by-line audit.

Windows-only is intentional (see README) - nothing here tries to change that.

## 0. Pre-flight - security (do these FIRST, they are not code changes)
- [ ] **Rotate any real credentials in `_tempReference/`** (the `media-motor` AWS keys) and report the
      exposure to **security@neweratech.com**. They were never committed (verified: `git ls-files
      _tempReference` is empty), but real keys on disk are a live exposure regardless of GitHub.
- [ ] **Confirm it is yours to open-source** - a personal project on your own hardware, no employer/NET IP
      entangled. Make that call explicitly before anything is public.
- [ ] Verify nothing sensitive is tracked:
      ```
      git ls-files _tempReference        (must print nothing)
      dad tidy                            (in any project you are about to include - lists junk)
      ```

## 1. Build the clean copy (no history, no _tempReference)
`package-kit.ps1` already excludes `_tempReference`, build output, the RAG index, and `.git`, and it
refuses to ship if `scan-secrets` finds anything. Produce an UNZIPPED folder to turn into the new repo:
```
powershell -ExecutionPolicy Bypass -File .\package-kit.ps1 -Folder -OutDir C:\src\drdad-release
```
That folder is what becomes the public repo. (The `.zip` form is what you attach to a Release in step 4.)

## 2. Scan the clean copy (belt and suspenders)
- [ ] Kit scanner over the whole folder:
      ```
      powershell -ExecutionPolicy Bypass -File .\scan-secrets.ps1 -Path C:\src\drdad-release\DrDad-v<x>
      ```
- [ ] An external history/secret scanner as a second opinion (install once):
      ```
      gitleaks detect --no-git --source C:\src\drdad-release\DrDad-v<x>
      ```
      The only expected hit is `test-kit.ps1`'s scanner FIXTURES (AWS's public example access key, the
      `AKIA...EXAMPLE` doc key, built by concatenation) - that is test data, not a secret. Allowlist it or
      confirm it by eye.

## 3. Fresh repo -> push
```
cd C:\src\drdad-release\DrDad-v<x>
git init -b main
git add -A
git -c user.name="Kristen Overmyer" -c user.email="<your-personal-email>" commit -m "Initial public release: DrDad v<x>" -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
git remote add origin https://github.com/<you>/drdad.git
git push -u origin main
```
You get a clean, one-commit history and the full CHANGELOG intact. Use a **personal** git identity (name +
a personal email), NOT a work address - this is a personal project, and the initial commit's authorship is
the first thing anyone reads in `git log`. The `Co-Authored-By` trailer keeps the AI assistance disclosed
in-history from commit one. (If you ever WANT the real 57-commit
history for its field-log value, do NOT shortcut it: run `gitleaks detect` over the FULL history of the
working repo first and resolve every hit, then push that instead. Clean-slate is the recommended default.)

## 4. Tag + GitHub Release
```
git tag v<x>
git push origin v<x>
```
Then on GitHub: create a Release from `v<x>`, paste the CHANGELOG's `v<x>` section as the notes, and attach
the artifact:
```
powershell -ExecutionPolicy Bypass -File .\package-kit.ps1 -OutDir C:\src\drdad-release
```
The asset is named **`DAD-kit-v<x>.zip`** - the distribution artifact keeps its historical name; the product
inside is DrDad. Either note that in the Release description, or rename it in `package-kit.ps1` (`$name`) if
you would rather the download read `DrDad-v<x>.zip`.

## 5. Repo hygiene (once)
- [ ] The clean copy already ships `.gitignore`, `LICENSE` (MIT), `CONTRIBUTING.md`, `SECURITY.md`, the
      issue/PR templates, and `.github/workflows/kit-ci.yml` (runs the full gate on Windows). Confirm the
      Action goes green on the first push - that green check is the most persuasive thing on the page.
- [ ] Turn on branch protection for `main` (require the CI check).
- [ ] Set the repo description + topics (e.g. `ollama`, `local-llm`, `claude-code`, `agentic`, `windows`).
- [ ] The README's `<your-fork-url>` placeholder: leave it, or point it at the new repo.

## Cutting the NEXT release
Once public, a release is just: land changes on `main` (CI green), bump `VERSION` + the CHANGELOG top entry,
`git tag v<x>`, push the tag, and attach a fresh `package-kit` zip to a new Release. The clean-slate dance is
a one-time thing - after it, ordinary tags on the public repo are the whole process.

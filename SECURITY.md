# Security

DAD-kit is a local, offline development harness. Its security posture is a design goal, not an afterthought.

## What the kit does for you

- **Credential scanning.** `scan-secrets` runs before content reaches git (a pre-commit hook) or the RAG
  index. It never prints the matched value - only file, line, a pattern name, and a fingerprint. AWS keys,
  GitHub PATs, Slack/Google/Anthropic/Azure tokens, PEM private keys and JWTs are covered.
- **It never commits secrets**, and `package-kit` excludes reference drops from any published copy.
- **It runs offline.** After install, telemetry, error reporting, and the auto-updater are disabled, and no
  code leaves your machine.
- **It will not weaken your machine to pass a build.** If a build is blocked by Windows App Control,
  AppLocker, or WDAC, the kit STOPS and reports it as an environment decision for you to make. Its agents
  are explicitly forbidden from stopping security services, adding Defender exclusions, editing policy, or
  relaunching as admin to force past a block. A real run tried all of those before this was enforced; it is
  now a tested gate.

## Reporting a vulnerability

If you find a security issue in DAD-kit's own code (the scripts, the C# MCP server, the installer, or the
templates), please report it privately rather than opening a public issue:

- Open a GitHub **security advisory** on the repository (Security tab -> Report a vulnerability), or
- contact the maintainers through the channel listed on the repository profile.

Include what you found, how to reproduce it, and the impact. We aim to acknowledge within a few days.

## Out of scope

- **Claude Code and Ollama** are separate projects with their own security processes - report issues in
  those to their respective maintainers.
- **Model behavior.** A local model can still write insecure application code; that is what the
  `security-agent` and the `Security review:` design gate exist to catch, but they are aids, not guarantees.
  Review generated code before you ship it.
- **If you paste a real secret into a session or a document**, treat it as compromised and rotate it. The
  scanner reduces the chance of committing one; it cannot un-see one you have already shared.

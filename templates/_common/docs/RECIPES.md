# Proven recipes - <project>
<!-- Commands that actually WORKED on THIS machine, with enough context to reuse them. Indexed by
     local-tools, so any agent can `search_datasheets` for the correct syntax instead of guessing
     (different models guess shell syntax differently - this is the antidote).
     RULES for agents:
     - CONSULT first: before an unfamiliar shell operation, search this doc for a proven pattern.
     - RECORD on success: append an entry when a NEW command works, or when a command FAILED and you
       found the syntax that works (record the fix, note the trap). Do NOT log routine re-runs of
       commands already listed - update the existing entry instead.
     - Keep entries small and generic (placeholders like <file>); no secrets/tokens ever.
     - Reindex (`index_datasheets`) after adding entries. -->

## Shell: Windows PowerShell 5.1 unless marked otherwise

### Example entry (delete once real ones exist)
- **Command:** `dotnet test <proj> --filter "FullyQualifiedName~<TestClass>" --nologo`
- **Does:** runs a single test class instead of the whole suite.
- **When:** verifying one story's tests quickly.
- **Gotcha:** the filter operator is `~` (contains), not `=`; quote the whole filter in PowerShell.
- **Verified:** <YYYY-MM-DD>, <model>

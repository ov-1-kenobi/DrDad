# Story S45 - Refactor: the search index reuses its embeddings and is cheap to read : report card

**Current grade: B**  (as of 2026-11-10, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-11-10        | B     | initial implementation (commit dd541c7, T45.1) |

## Assessment (this iteration)
How this was graded: code review only. I read `local-tools/Rag.cs` in full (805 lines) and the one
Test-Case that holds the story (`test-kit.ps1:9442` to `test-kit.ps1:9505`). I did not run the build or
the suite and did not see them run. The story was implemented directly and marked DONE by hand at the
owner's request, not through close-unit: there is **no close evidence file** (`grades/S45_EVIDENCE.md`
does not exist). The last full suite run reported to me was 309 passed, 2 failed, with the two fixed and
re-checked individually; a final full run is still pending, so this card does not claim a green suite.

- Correctness: the three Behavior bullets are implemented as written.
  - Reuse: `local-tools/Rag.cs:551` builds a text -> vector map from the previous index, and
    `local-tools/Rag.cs:564` assigns the stored vector to every chunk whose text is unchanged; only the
    rest go to `EmbedBatchAsync` (`local-tools/Rag.cs:573`).
  - Skip: `local-tools/Rag.cs:512` returns before any file is read when chunks.json and vectors.bin
    exist, index.meta equals the current model, and the corpus signature is unchanged.
  - Storage: `WriteVectors` (`local-tools/Rag.cs:451`) writes int32 count, int32 dim, then float32 rows;
    chunks.json is written without vectors (`local-tools/Rag.cs:598`); index.meta is written at
    `local-tools/Rag.cs:602`; the parsed index is cached and keyed on write time + size of both files
    (`local-tools/Rag.cs:438`, `local-tools/Rag.cs:488`).
  - Old index: with no vectors.bin the vectors inside chunks.json are used as they are
    (`local-tools/Rag.cs:491`); the skip at line 512 cannot fire without vectors.bin, and an empty
    index.meta is accepted for reuse (`local-tools/Rag.cs:552`), so the first reindex converts.
  - Defects found (none breaks an AC; see Suggestions 1-3): the skip ignores inputs that are not corpus
    files; an unlabelled old index from a different model can be stamped as current; the atomic-swap
    comment claims more than the code guarantees.
- Acceptance:
  - AC1 covered by `0.61.0 index: a reindex reuses unchanged chunks, skips an unchanged corpus, stores vectors in binary, and still reads a pre-0.61.0 index`
    (`test-kit.ps1:9442`). Each clause has an assertion: first index embeds all (`test-kit.ps1:9460`);
    binary layout and no `"Vector"` in chunks.json (`test-kit.ps1:9463`, `test-kit.ps1:9467`); unchanged
    corpus skipped (`test-kit.ps1:9471`); one edit embeds one chunk (`test-kit.ps1:9476`); exact-text
    search (`test-kit.ps1:9481`); hand-built old-format index searchable (`test-kit.ps1:9494`) and
    converted with full reuse (`test-kit.ps1:9498`). The assertions are specific, not smoke checks. The
    case is skipped under `-SkipBuild` (`test-kit.ps1:9443`), which is expected for an exe-driven case.
  - AC1 gaps: the case drives one-shot `--reindex` / `--search` processes, so the in-memory cache
    (Behavior bullet 2, "keeps the parsed index in memory until the files change") is never hit twice in
    one process and is untested; "a different model forces a full re-embed" (CHANGELOG 0.61.0) and the
    vector-length recheck (`local-tools/Rag.cs:579`) have no assertion either.
  - AC2 is a measurement, not a test. NOT reproduced by me. The code supports it: 25,983 chunks x 768
    float32 is 79.8 MB, which matches the claimed 80 MB vectors.bin; the 0.07 s "up to date" figure fits
    an early return that only stats files; "4 embedded, 25,979 reused" is what line 564 does for a
    one-box edit. The 1.3 s and 0.4 s timings are plausible (no embedding calls; one text-only JSON
    parse) but rest on a single manual run on one machine.
- Design: scope held to `local-tools/Rag.cs` (one C# server, no new dependency). Story says "Rag.cs
  only" while T45.1 Touches also lists `local-tools/README.md` - a wording mismatch, not a code issue.
  No pinned contract is touched that I could identify; I did not read DESIGN.md (S45's own header says
  the requirement is pending, T46.5).
- Quality: readable, comments explain why. The reuse/dim-recheck block is the densest part and correct
  for the cases it handles. The class summary at `local-tools/Rag.cs:33` still says vectors are "stored
  in a single JSON file", which is now false. Test-only embedding (`local-tools/Rag.cs:117`) ships in
  the product binary, gated by an env value and documented.
- Hygiene: CHANGELOG 0.61.0 documents format, result line and upgrade path. The result-line change
  (`local-tools/Rag.cs:609`) has no other parser in `*.ps1` / `*.cs` / `*.cmd` beyond the test itself.
- Verification mode:
  - AC1: code-review verified 2026-11-10, not live-run by me. The test is sandboxed by construction
    (`New-Sandbox` docs dir, env restored in `finally` at `test-kit.ps1:9501`); it touches no real index.
  - AC2: owner-reported, one manual run on a COPY of a real corpus; no script or evidence file on
    record that I found, so it cannot be re-checked.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [dev] The skip at `local-tools/Rag.cs:512` keys only on corpus files + model. It now also swallows
   cases that used to be retried on every reindex: a caption or transcript that failed (deliberately not
   cached, `local-tools/Rag.cs:401`: "so a later run ... can succeed") and a toggled
   `LOCALTOOLS_CAPTION_IMAGES` / `LOCALTOOLS_TRANSCRIBE_AUDIO`. After the model is pulled or the flag is
   set, reindex answers "Index up to date" until some file changes. Fold the two flags into the
   signature and do not write manifest.sig as current when a sidecar was skipped (or add a force
   switch). Add a Test-Case.
2. [dev] An old index with no index.meta is assumed to be from the current model. The length recheck
   only runs when `todo.Count > 0 && reused > 0` (`local-tools/Rag.cs:579`); if every chunk is reused,
   foreign vectors are written and stamped with the current model at `local-tools/Rag.cs:602`. Search
   then filters them all out (`local-tools/Rag.cs:626`) and returns "No results.", and every later
   reindex is skipped. Probe one embedding when the old index is unlabelled and compare lengths.
3. [dev] Extend the Test-Case (or add one) for the untested behaviors: a changed `RAG_EMBED_MODEL`
   re-embeds everything, and the server process reuses its loaded index and reloads after the files
   change (needs an MCP-session case, not one-shot `--search`).
4. [mechanical] Fix the stale summary at `local-tools/Rag.cs:33` ("stored in a single JSON file") and
   soften the comment at `local-tools/Rag.cs:593`: a same-count edit caught between the two `File.Move`
   calls (`local-tools/Rag.cs:600`, `local-tools/Rag.cs:601`) is not a count mismatch; it is only caught
   by the stamp recheck at `local-tools/Rag.cs:492`, and not in every interleaving (self-heals on the
   next query).
5. [human] AC2 is ticked on one unrecorded manual run, and the story has no close evidence file. Decide
   whether that is acceptable as it stands or whether the measurement should be scripted (the way
   `examples/verification-2026-11/repro.ps1` does for Tier 1) and the story re-closed through close-unit
   after the pending full suite run.
6. [human] Dev notes list "rereads and rechunks every file; PDFs reparsed each time" as not done. Confirm
   it is tracked under S46 or accepted, so it does not live only in this story's notes.

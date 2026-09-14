# Corpus: <name>

<!-- A named, persistent, CITED knowledge bank. Projects consult it (via a [research] Ref) instead of
     re-researching the web every time. The corpus agent reads THIS manifest - and nothing else - to decide
     what goes in the bank. Build it with: dad corpus build <name>. A stale corpus is WORSE than none, so
     keep "Build & refresh" honest. This is the corpus's contract, the way DESIGN.md is a project's. -->

## Goal
<!-- What this corpus KNOWS and is for, in a line or two. e.g. "current, cited best-practice for ASP.NET Core
     web-app security, so our projects build the DECIDED technique instead of re-inventing it each run." -->

## Scope
- In: <what belongs here>
- Out: <what does NOT - keep the remit tight so the corpus agent does not drift its scope>

## Sources
<!-- What to ingest, each with WHY it is authoritative. Official docs + primary sources beat blog roundups.
     Record the real URLs; the corpus agent ingest_url's them into sources\ and cites them in SOURCES.md. -->
- <https://...> - <why this source is the one to answer it>

## Build & refresh
- Ingest: <how - ingest_url the sources above into sources\, dedup, then `dad corpus build <name>` to index>
- Cadence: <how often to refresh - monthly, or on a routine; a security corpus rots fast>
- Freshness: <when a source is older than N months, re-verify it or drop it>

## Artifacts
- The index (`.index\`) - what `dad corpus search` queries.
- `SOURCES.md` - the cited, DATED provenance: every claim traces to a source + a fetch date.
- <optional> a synthesized "take" doc - the decided techniques, each citing SOURCES.

## Trust
<!-- How a claim earns a place: cited to a source in SOURCES.md with a fetch date. Contested or unverifiable
     claims are marked as such, NOT laundered as fact. This is what makes it a bank, not an opinion. -->

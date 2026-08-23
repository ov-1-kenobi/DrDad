---
description: RESEARCH mode - build the project's evidence corpus from the web, with provenance, then feed the design doc. ONLINE. Runs before /design.
argument-hint: [topic or question; empty = work the Open questions in docs/SOURCES.md]
---
Build up the project's **evidence corpus** on a topic and record where every piece came from. This runs
BEFORE `/design`: research first, then design on top of what you found.

**This mode is ONLINE** - the only one that is. Everything after it (`/design`, `/stories`, `/build`) works
offline from the corpus you build here. So capture properly now; you will not have the web later.

Topic: **$ARGUMENTS**  (empty = take the next items from `## Open questions` in `docs/SOURCES.md`)

## The loop

1. **Decompose the topic into QUESTIONS** before searching anything. Write them into `docs/SOURCES.md`
   under `## Open questions`. Relay them to me and WAIT - a wrong question set wastes an afternoon of
   fetching. Aim for questions a source can actually settle, not themes.
2. For each question, spawn **research-agent** via the **Task tool** (subagent_type: "research-agent" - an
   AGENT, not a skill). **ONE QUESTION PER INVOCATION.** It searches, judges, captures, and returns what
   it found plus what it could not settle.
3. **I tier every source.** research-agent records `unknown`; you relay the list and I say primary or
   secondary. Do NOT assign a tier yourself and do not let the agent - that judgement is the one thing no
   script and no model should make on my behalf, because everything downstream leans on it.
4. **Synthesise into the design doc** - `docs/DESIGN.md` (or `TEDD.md`), `Status: DRAFT`. Write MY
   conclusions in my own words with a `[Snnn]` citation on every factual claim. Do NOT paste source text
   into the design doc: the corpus holds the sources, the design doc holds the synthesis. A design doc
   made of quotes is not a design, and reproducing chunks of someone's page is not ours to do.
5. **Unsettled questions stay in `## Open questions`** in SOURCES.md, never as confident prose in the
   design doc. "We could not establish X" is a finding; guessing X is a defect.
6. **GATE - run it, do not eyeball it:**
   ```
   dad source-stats
   ```
   Non-zero means the design doc cites something that is not in the corpus. Fix that before you stop.
   Then reindex so the new sources are searchable:
   ```
   reindex.cmd "<project>\docs"
   ```

## Corpus rules

- Captured sources go in **`docs/sources/`**, named `S<nnn>-<slug>.md` so the file ties to the ledger row.
- Every capture gets a row in `docs/SOURCES.md` (id, tier, fetched date, title, url, **published date**
  - the page's own date, last column, `undated` if it has none) AND a line under
  `## Why each source was captured` saying which question it answers. A source you cannot name a use for
  should not be captured - `source-stats` reports the ones nobody cites.
- **Prefer the originating authority** over anyone describing it: the standard itself over a blog about
  the standard, the agency that collected the data over an article citing it, the vendor's own API
  reference over a tutorial. When you can only find secondary coverage, say so - that is a finding too.
- **Never capture credentials or personal data.** Pages get committed to git and indexed as PLAINTEXT.
  If a page carries either, do not `ingest_url` it - tell me instead.
- `docs/sources/` can get large. The corpus supports MULTIPLE ROOTS: set `LOCALTOOLS_DOCS_DIR` in the
  project's `.mcp.json` to a `;`-separated list (`...\docs;D:\shared\research`) to keep a big or shared
  corpus on another drive and still have one index over all of it.

## When to stop

When the questions that matter are answered, or when what remains needs a source you cannot reach (paywalled,
proprietary, not published). Say which it is. Then hand off:

> Corpus: N sources (X primary, Y secondary). Answered: ... Still open: ...
> Next: `/design` to turn this into requirements, contracts and a stack.

**A deliverable is NOT required yet.** Research can and should run before you know whether this becomes a
site, a report or a form - that is the point. `/design` will pin the DATA contracts from what you found,
which hold whatever gets built on top of them later.

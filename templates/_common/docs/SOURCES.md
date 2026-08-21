# Sources

<!-- The PROVENANCE LEDGER for everything in docs/sources/. Owned by /research.
     Why it exists: a corpus without provenance is the same failure as code without a build - six weeks
     later the design doc says "the market grew 14%" and nobody knows whether that came from a statistics
     office or a content farm. This file is what makes a research-backed design doc auditable.

     One row per captured source. `source-stats.cmd` checks the rows against the files on disk and against
     the citations in the design doc, and fails on anything that does not line up.

     TIER IS YOURS TO SET, NOT THE MODEL'S. It is the one judgement no script can make:
       primary   - the originating authority (the standard itself, the vendor's own API reference,
                   the agency that collected the data, the paper reporting the study)
       secondary - competent reporting ON a primary source (a good explainer, a trade publication)
       unknown   - captured but not yet assessed. Claims resting only on `unknown` get flagged.

     FETCHED vs PUBLISHED are different questions and both matter. `fetched` is when YOU pulled it;
     `published` is when the SOURCE was written. A 2019 article fetched this morning looks current and is
     not - that is the whole failure mode for framework and security guidance, where the pattern may since
     have been deprecated or the library may since have had a CVE. Put the page's publication or
     last-updated date in `published` (YYYY-MM-DD), or the literal word `undated` if the page truly has
     none. source-stats warns on cited sources published beyond its -StaleDays bar.

     Cite a source in DESIGN.md / TEDD.md as [S001]. Every citation must resolve to a row here. -->

| id | tier | fetched | title | url | published |
|------|-----------|------------|--------------------------------------------|--------------------------|------------|
| S001 | unknown | <YYYY-MM-DD> | <what this document actually is> | <https://...> | <YYYY-MM-DD> |

## Why each source was captured

<!-- One short paragraph per id: the QUESTION it answers. A source you cannot describe a use for is
     one you should not have captured - and source-stats reports sources that are never cited. -->

- **S001** - <the question this answers, and why this source is the one to answer it>

## Open questions

<!-- Questions research has NOT answered yet. These are the next /research targets, and they belong here
     rather than in the design doc, which should only carry what is actually settled. -->

- <question still unanswered, and what kind of source would settle it>

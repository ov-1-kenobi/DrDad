---
description: Generate/refresh docs/ARCHITECTURE.md - a Mermaid diagram of the solution architecture from DESIGN.md (diagram-as-code, fully offline).
argument-hint: [optional focus, e.g. "data flow" or an epic id; empty = the whole architecture]
---
Draw the architecture as **diagram-as-code** (Mermaid) - no image model needed, works offline, versionable.

Read `CLAUDE.md` for the design-doc path (DESIGN.md or TEDD.md). Source of truth = the doc's
`## Solution architecture` + `## Epics` (+ components mentioned in requirements). Use
`search_datasheets` for details rather than reading whole files.

Focus: **$ARGUMENTS**  (empty = the whole architecture)

1. If the Solution architecture is still `<TBD>`, STOP and tell me to finish `/forge`'s architecture step.
2. Write/refresh **`docs/ARCHITECTURE.md`**: a short intro line, then ONE fenced ```mermaid block
   (`flowchart TD` or `C4`-style flowchart) showing the components, their relationships, and external
   dependencies from the design. Group by epic where it helps. Keep it readable - aim for <= ~20 nodes;
   split into a second diagram section only if genuinely needed.
3. Label every node with the real component name from the design; do NOT invent components that are not
   in the doc - gaps become an "Open questions" note under the diagram.
4. **Reindex** (`index_datasheets`) so the diagram doc is searchable.
5. Tell me to preview it (VS Code renders mermaid in markdown preview; or any online/offline mermaid viewer).

Re-run after the architecture changes - it regenerates from the design doc. This is a VIEW of DESIGN.md,
not a source: design changes go through `/forge`, never by editing the diagram.

Tip: to seed a design FROM a picture (whiteboard photo / screenshot), use the `describe_image` tool first -
it reads the image with a local vision model and returns text you can `/forge` from.

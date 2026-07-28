---
description: PROTO mode - co-design and prototype; build the design doc as we go (you lead, agent assists)
argument-hint: [idea or open question to explore]
---
We are in **PROTO mode**.

Read `CLAUDE.md` for this project's design-doc path (default `docs/DESIGN.md`), build/test
commands, and placeholder convention.

Rules:
- The design doc already exists (from `/scaffold`) as a living DRAFT - you MAY edit it.
  - If its header says `Status: LOCKED`, OFFER to unlock it to `DRAFT` and, on my OK, flip the header +
    reindex before editing.
  - If no design doc exists (older project), ASK general (`docs/DESIGN.md`) vs experience (`docs/TEDD.md`),
    create it `Status: DRAFT` from `templates/_common/docs/`, then reindex.
- Decisions go INTO the design doc (dated), not just into chat - it should accrete into a real spec.

Topic: **$ARGUMENTS**

Loop:
1. Propose 2-3 options with tradeoffs; recommend one.
2. WAIT for my choice (don't assume).
3. Record the dated (YYYY-MM-DD) decision into the design doc; re-index with `index_datasheets`.
4. Prototype it minimally (per the project's placeholder convention) so I can run/see it fast.
5. Short "look at this" note (what to check), then iterate.

When the spec feels solid, OFFER to set `Status: LOCKED` (on my OK, flip the header + reindex), then
suggest `/blueprint` (optional task map) and `/spec` or `/build`.

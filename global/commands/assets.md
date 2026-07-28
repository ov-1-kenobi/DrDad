---
description: Generate/refresh docs/ASSETS.md (the art & asset list) from the TEDD
argument-hint: [optional: a system to scope to; empty = whole TEDD]
---
Build or refresh the project's art/asset list from the design doc.

Scope: **$ARGUMENTS**  (empty = the whole TEDD)

Steps:
1. Read `docs/TEDD.md` (use `search_datasheets` / `doc-researcher` for large docs). If
   `docs/ASSETS.md` already exists, read it too so you can PRESERVE existing Status values.
2. Extract every asset the design implies - from explicit "art/asset placeholders" lines AND
   from system descriptions (a "projectile" implies a mesh + impact SFX + hit VFX, etc.).
3. Write `docs/ASSETS.md` grouped by category: Models/Meshes, Textures/Materials, Audio, UI,
   Animations, VFX/Particles, Fonts. For each asset give:
   - name, the system/requirement that uses it (cite TEDD section),
   - a short spec/notes, a greybox stand-in (primitive/placeholder), and Status.
4. Mark anything you INFERRED (not explicit in the TEDD) with "(inferred)" so I can confirm it.
5. Do NOT invent assets beyond what the design implies. If the TEDD is vague about an asset's
   spec, note the gap rather than guessing dimensions/format.

Keep it a clean set of tables. This list is the hand-off to whoever does the real art later.

After writing `docs/ASSETS.md`, **reindex** (`index_datasheets`) so it joins the searchable corpus and
the `doc-researcher` / later agents can find it.

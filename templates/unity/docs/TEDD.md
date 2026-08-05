# Technical Experience Design Document - <game name>

Status: DRAFT
<!-- DRAFT = co-authoring via /proto. Change to LOCKED when ready to implement via /spec. -->

## Vision
<one paragraph: what the game is and the core experience>

## Stories
<!-- /design and requirements-agent write self-contained stories here. Each embeds everything the dev
     needs, so /spec and /build can implement one with full context in-prompt. -->
### Story S1: <title>   <!-- Status: TODO | DONE -->
- **Goal:** <one line>
- **Context:** <relevant design facts + where this fits - inline, enough that the dev needs nothing else>
- **Behavior:** <precise behavior>
- **Data / interfaces:** <ScriptableObject fields / serialized config>
- **Art/asset placeholders:** <models, textures, audio, UI - feeds docs/ASSETS.md>
- **Dependencies:** <other stories/systems>
- **Acceptance (testable):**
  - [ ] AC1: <PlayMode/EditMode test or observable behavior>
- **Dev notes:** <where scripts go, greybox placeholder to use, gotchas>

## Systems
### <System name>
- Behavior: <what it does>
- Data: <ScriptableObject fields / serialized config>
- Art/asset placeholders: <models, textures, audio, UI - feeds docs/ASSETS.md>
- Acceptance: <how we know it works - a PlayMode test or observable behavior>

## Open questions  (/proto fills these in, dated)
- Q1: <undecided design point>

## Out of scope (for now)
- <explicitly not building yet>

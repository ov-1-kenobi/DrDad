# Stories - <project>
<!-- The story backlog. Managed by /stories (create from the DESIGN epics, normalize, dedupe). This
     IMPLEMENTS DESIGN.md (the contract) - it does NOT redefine requirements; anything that needs a new
     requirement goes back to /design. Stories stay editable even while DESIGN is LOCKED. Each story traces
     to an epic by tag. /taskmap shards these into TASKS.md. Keep each story self-contained. -->

<!-- S1 IS A WALKING SKELETON, NOT A BUILD SKELETON. Make the first story prove the system END TO END,
     however trivially: one request in, one response out, through the real layers, with an integration
     test that runs against a real store. NOT "create the solution with warnings as errors" - that is
     build configuration, and it leaves every later story adding to a pile nobody has assembled.
     Learned the hard way: a project reached 183 passing unit tests, 12 building projects and a
     TWENTY-LINE host with zero integration tests, having never once served a request. Every part worked;
     the thing did not exist. A walking skeleton makes every later story an extension of something that
     RUNS, and it makes close-unit's test gate mean integration from the first close. -->

### Story S1: <smallest end-to-end slice - e.g. "GET /api/items returns [] and the page renders it">   (Epic E1)   <!-- Status: TODO | DONE -->
- **Goal:** <one line>
- **Context:** <relevant design facts + where this fits - inline, enough that the dev needs nothing else>
- **Behavior:** <precise behavior>
- **Data / interfaces:** <models, signatures, config>
- **Dependencies:** <other stories/components; external resources>
- **Acceptance (testable):**
  - [ ] AC1: <observable, or runnable by the project's test command>
- **Dev notes:** <file locations, placeholder convention, gotchas>

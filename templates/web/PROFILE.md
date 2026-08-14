# Stack profile: lite web / mobile-web app
<!-- A FRAGMENT, not a CLAUDE.md. /design copies these sections into the project's CLAUDE.md during the
     architecture step: Stack, Placeholder convention, Build / test, Human-in-loop, UI hygiene.
     Everything else (Modes, Design docs, Secrets, Proven commands, Working agreement) is kit-owned and
     comes from templates/generic/CLAUDE.md - never duplicate it here, it only goes stale. -->

## Stack
- TypeScript + <React | Preact | Svelte | vanilla> on <Vite | Next | Astro>, targeting mobile-first web.
- **Do NOT copy a version number from this file.** Check what is installed (`node --version`, `npm view
  <pkg> version`) and record the chosen versions in the design doc's "Solution architecture".
- Styling: <CSS modules | Tailwind | plain CSS>. Pick ONE and say so - mixed styling systems are how a
  small app becomes unmaintainable.
- State: start with component state. Add a store only when a contract requires shared state, and pin
  which one in the design doc.

## Placeholder convention
- Program to typed interfaces. Stub network calls behind a typed client with in-memory fixtures marked
  `// TODO: real endpoint`; swap the implementation later, never the call sites.
- No secrets in client code, ever - anything in the bundle is public. API keys belong to a server you
  control; reference them BY NAME in config and document who injects them.

## Build / test
- Build: `npm run build`        (must fail the build on a type error - no `--noEmit false` escape hatches)
- Test:  `npm test -- --run`    (vitest/jest, non-watch)
- Lint:  `npm run lint`
- A11y:  `npx pa11y-ci` or an axe-core assertion in the component tests

## UI hygiene - what "done" means when the thing is visual
**A UI unit is verified by BEHAVIOUR and ACCESSIBILITY, never by "it looks right".** There is no exit code
for taste, so the gates are the parts that DO have one:
- **Behaviour:** a test drives the component/page the way a user does - fill the field, submit, assert the
  resulting DOM. "Renders without crashing" is not a test.
- **Accessibility is a build gate, not a nicety:** every interactive element reachable and operable by
  keyboard, every input has a label, images have alt text, contrast meets WCAG AA, and the page has one
  `h1` with a sane heading order. axe/pa11y exits non-zero - treat it exactly like a failing unit test.
- **Responsive:** verify at 360px width as well as desktop. Mobile-first means the narrow case is the one
  that must work, not the one you check last.
- **No layout assertions in tests** (pixel positions, class names as behaviour) - they break on every
  restyle and teach everyone to ignore red.
- Loading, empty and error states are part of the story's acceptance, not polish to add later. A screen
  with no empty state is unfinished.

## Human-in-loop
- **Required, once per story with a visible surface.** The agent cannot judge whether it looks right, so it
  states what to open (URL + viewport) and what it expects to see, then WAITS. Visual correctness, tone and
  layout are yours; behaviour and accessibility are the agent's and are gated by the commands above.

# Project: <name>

## Hardware / stack
- Board / MCU: <ESP32-S3 | STM32 | RP2040 | ...>.
- Toolchain: <PlatformIO | CMake + arm-none-eabi | Arduino>. Language: C/C++.
- Peripherals & pin map (the source of truth - keep accurate):
  - <BME280> on <I2C1 addr 0x76>
  - <status LED> on <GPIO17>

## Modes (forge / proto / spec)  <- read this
If I haven't said which, ASK first.
- `/forge` - design-first: architect & validate the spec INTO the design doc (DRAFT), no code.
- `/proto` - co-design: build greybox + record dated decisions into the design doc (DRAFT).
- `/spec` - implement the design doc faithfully; it is LOCKED & read-only; gaps -> questions.
- `/build [scope]` - orchestrate requirements-agent -> dev-agent -> qa-agent; mode follows the doc Status.
The design doc's `Status:` header is the source of truth: never edit LOCKED; never `/spec` a DRAFT.
Pipeline: forge or proto (DRAFT) -> set LOCKED -> spec/build (implement).

## Design doc + datasheets
- Design doc: `docs/DESIGN.md`. Datasheets are indexed in the same `local-tools` corpus.
- ALWAYS confirm pin numbers, register addresses, timing, and electrical specs via
  `search_datasheets` / `doc-researcher` before using them. Cite the source. Never guess hardware constants.

## Placeholder convention
- Abstract hardware behind a HAL; provide mock I2C/SPI/GPIO for host tests. `// TODO` on stubs.

## Build / test
- Build: `pio run`                  (or your cmake/make command)
- Host tests: `pio test -e native`  (mocked bus - runs without the board)
- Flash: `pio run -t upload`

## Human-in-loop (hardware)
- Anything needing the board: implement + host-test, then STOP and ask me to flash and report the
  serial/LED/scope result. I am the hardware in the loop. Mark such items **(HW)** in the design doc.
- To maximize autonomy, prefer host tests with a mocked bus, or a simulator (Renode/QEMU/Wokwi),
  so "build and test" gets far before it needs me.

## Web / grounding
- Web search / URL lookup: use the `local-tools` `web_search` / `ingest_url` tools, NOT the built-in
  WebSearch/WebFetch (those need Anthropic and don't work against local Ollama). For grounding,
  `web_search` to find, then `ingest_url` to fetch + persist into the RAG.

## Working agreement
- Verify every hardware constant against the datasheets first; cite it. Missing info is a question.
- After each change: build + host tests. Don't say "done" until they pass. Keep changes small.

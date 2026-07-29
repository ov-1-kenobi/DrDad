# Stack profile: embedded / IoT (C / C++)
<!-- A FRAGMENT, not a CLAUDE.md. /forge copies these sections into the project's CLAUDE.md during the
     architecture step. Kit-owned sections come from templates/generic/CLAUDE.md - do not duplicate them. -->

## Hardware / stack
- Board / MCU: <ESP32-S3 | STM32 | RP2040 | ...>.
- Toolchain: <PlatformIO | CMake + arm-none-eabi | Arduino>. Language: C/C++.
- Pin the toolchain/framework versions in the project (`platformio.ini`, CMake toolchain file) rather than
  relying on whatever is installed - embedded builds are far more version-sensitive than desktop ones.
- Peripherals & pin map (the source of truth - keep accurate):
  - <BME280> on <I2C1 addr 0x76>
  - <status LED> on <GPIO17>

## Datasheet rule (stack-specific, keep this)
- ALWAYS confirm pin numbers, register addresses, timing and electrical specs via `search_datasheets` /
  the `doc-researcher` before using them. Cite the source. **Never guess a hardware constant.**

## Placeholder convention
- Abstract hardware behind a HAL; provide mock I2C/SPI/GPIO for host tests. `// TODO` on stubs.

## Build / test
- Build: `pio run`                  (or your cmake/make command)
- Host tests: `pio test -e native`  (mocked bus - runs without the board)
- Flash: `pio run -t upload`

## Project hygiene
- **No absolute paths** in `platformio.ini`, CMakeLists or linker scripts - use relative paths and
  toolchain variables so a clean checkout builds.
- **Clean-machine rule:** a fresh clone + the documented toolchain must build and run host tests with no
  manual setup.

## Human-in-loop (hardware)
- Anything needing the board: implement + host-test, then STOP and ask me to flash and report the
  serial/LED/scope result. I am the hardware in the loop. Mark such items **(HW)** in the design doc.
- To maximize autonomy, prefer host tests with a mocked bus, or a simulator (Renode/QEMU/Wokwi), so
  "build and test" gets far before it needs me.

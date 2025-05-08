---
title: Next Steps
description: Immediate priorities and status for Raxol Terminal Emulator development
date: 2025-05-08
author: Raxol Team
section: roadmap
tags: [roadmap, next steps, planning, status]
---

# Raxol: Next Steps

## Current Status (As of 2025-05-08 - Please Update Regularly)

- **Test Suite:** The project now compiles successfully after resolving issues with Mox setup, test helper loading, dependency compilation, and extensive test suite debugging. The full suite reports **0 failures** (down from 240+) and **24 skipped tests** overall (no change).
- **Mox Compilation Blocker:** A critical compilation error (`Mox.__using__/1 is undefined or private`) has emerged, preventing the use of `Mox`. This issue occurs even in minimal test files and persists despite several troubleshooting attempts (simplifying `test_helper.exs`, trying Mox v1.2.0 and v1.1.0, checking Elixir/OTP versions).
- **`:meck` cleanup (Complete):** The systematic transition from `:meck` to `Mox` for all core runtime and plugins test files listed in `TODO.md` is complete.
- **Primary Focus:** The primary focus is now to resolve the critical `Mox.__using__/1 is undefined or private` compilation error. Addressing the remaining 24 skipped tests will follow once Mox is functional.
- **Functionality:** Core systems are largely in place.
- **Compiler Warnings:** Numerous warnings remain and require investigation.
- **Sixel Graphics Tests:** Verified correct Sixel string terminator sequences (`\e\\`) in `test/terminal/ansi/sixel_graphics_test.exs`, with all tests passing.

## Immediate Priorities / Tactical Plan

1. **Resolve Mox Compilation Error:** Continue troubleshooting the `Mox.__using__/1` issue. Next attempt: full project clean (`mix deps.clean --all`, `mix clean`, `rm -rf _build`) followed by fresh `deps.get`, `compile`, and test of `test/minimal_mox_test.exs`.
2. **Address Remaining Skipped Tests:** Investigate and fix the remaining **24 skipped tests** (currently blocked by the Mox issue). This is the primary immediate priority once Mox is working.
3. **(Potentially) Identify Further `:meck` Usage:** Perform a codebase search for any remaining `:meck` usage that might have been missed.
4. **Run Full Test Suite:** Regularly run `mix test` to monitor progress and catch regressions.
5. **Update Documentation:** Keep `TODO.md`, `CHANGELOG.md`, and this file current with accurate test counts and task status.
6. **(Once Skipped/Mox Issues Addressed):** Begin comprehensive cross-platform testing.
7. **(Once Tests Stabilize):** Re-run performance benchmarks.
8. **(Optional/Later):** Revisit the skipped test in `AccessibilityTest` regarding setting unknown options.

---

_(Older sections detailing specific test fixes, long-term plans, contribution areas, timelines, etc., have been removed to keep this document focused. Refer to `TODO.md` and `CHANGELOG.md` for more detail.)_

---
title: Handoff Prompt
description: Documentation for handoff prompts in Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: planning
tags: [planning, handoff, prompts]
---

# Handoff: Example Investigation & Runtime Debugging

**Context:**
Previous steps involved documentation cleanup. Attempted to verify the status of examples in `lib/raxol/examples` after recent refactoring.

**Current Status:**
Following the refactoring of examples to use `Raxol.start_link/1`, investigation into a runtime hang revealed build/compatibility issues with the `:rrex_termbox` dependency (v1.1.0).

The `:rrex_termbox` dependency has now been successfully integrated using its Elixir Port-based API, replacing the previous NIF-based approach. This involved:

- Refactoring `Raxol.Terminal.Driver` to communicate with the `:rrex_termbox` port process and handle its event messages (placeholder translation added).
- Refactoring `Raxol.Terminal.TerminalUtils` to remove dependency on `:rrex_termbox` for dimensions.
- Applying a local patch to the `:rrex_termbox` Makefile to fix build issues.

The project now compiles successfully. Most previous compiler warnings have been addressed, although a few persist (e.g., regarding unused variables in `sixel_graphics.ex` under specific conditions, and a potentially spurious duplicate `@doc` warning in `accessibility.ex`).

The original runtime hang observed when launching examples via `Raxol.start_link/1` has not yet been re-tested after these changes.

**Immediate Next Steps:**

1. **Test Runtime & Implement Event Translation:** Launch an example (e.g., using `bin/demo.exs`) to:
   - Verify if the original runtime hang is resolved.
   - Observe the `{:termbox_event, event_map}` messages received by `Raxol.Terminal.Driver`.
   - Implement the `translate_termbox_event/1` function in `Raxol.Terminal.Driver` to correctly map `rrex_termbox` events to `Raxol.Core.Events.Event` structs.
2. **Address Remaining Warnings:** Investigate and fix the persistent compiler warnings if necessary.

Once the examples can successfully launch and basic input is functional:

1. **Refactor/Fix Examples:** Fully adapt the example modules (like `IntegratedAccessibilityDemo`) to the `Application` behaviour, implementing proper state management and view logic using `Raxol.View.Elements`.
2. **Enhance Component Showcase:** Resume work on `docs/guides/examples/showcase/component_showcase.exs`.
3. **Tackle Roadmap Items:** Consult `docs/development/planning/roadmap/Roadmap.md` or `TODO.md`.

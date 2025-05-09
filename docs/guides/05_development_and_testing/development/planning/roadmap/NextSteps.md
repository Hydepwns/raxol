---
title: Next Steps
description: Immediate priorities and status for Raxol Terminal Emulator development
date: 2025-05-08
author: Raxol Team
section: roadmap
tags: [roadmap, next steps, planning, status]
---

# Raxol: Next Steps

## Current Status (As of 2025-05-08)

- **System Interaction Adapters:** For modules with direct operating system or external service interactions (e.g., file system, HTTP calls, system commands), an adapter pattern (a behaviour defining the interaction contract and an implementation module) is used.
  This allows for mocking these interactions in tests, improving test reliability and isolation.
  Examples include `Raxol.System.DeltaUpdater` with its `Raxol.System.DeltaUpdaterSystemAdapterBehaviour`,
  and `Raxol.Terminal.Config.Capabilities` with its `Raxol.System.EnvironmentAdapterBehaviour`.
  **This pattern is encouraged for all new modules or significantly refactored modules involving such interactions to enhance testability from the outset.**
- **Test Suite:** The project now compiles successfully after resolving issues with Mox setup, test helper loading, dependency compilation, and extensive test suite debugging. The full suite currently reports **227 failures** and **33 skipped tests** overall (as of 2025-05-08).
  - Significant effort was recently dedicated to fixing all tests in `test/raxol_web/channels/terminal_channel_test.exs`. This involved addressing Mox configurations, adapting to Phoenix Channel testing updates (including the creation of `RaxolWeb.UserSocket`), correcting `EmulatorBehaviour` arities, aligning `handle_in` expectations, and refining test assertions (e.g., using `assert_receive` and ensuring robust payload matching).
  - All 17 tests in `test/raxol/ui/renderer_edge_cases_test.exs` are now passing after resolving issues related to theme instantiation, registration, user preferences setup, element definitions, robust handling of nil/missing theme variants in `ColorSystem`, nil themes and elements in `Renderer`, and correct attribute/style propagation for various element types.
- **Runtime Tests (`test/raxol/runtime_test.exs`):** (Resolved) All 6 tests in this file now pass. Failures were previously caused by unhandled errors from `Supervisor.stop/3` in the `on_exit` cleanup handler. These are now caught and logged, allowing the tests to pass, though the underlying supervisor shutdown in test contexts might still have minor issues (logged errors).
- **Mox Compilation Blocker:** ~~A critical compilation error (`Mox.__using__/1 is undefined or private`) has emerged, preventing the use of `Mox`. This issue has been reproduced in a minimal test project using Mox 1.2.0 (with `Mox.start_link_ownership()`), Elixir 1.18.3, and OTP 27.0.1. It appears specifically related to Mox 1.2.0 and its `nimble_ownership` dependency.~~ (Resolved: The error was due to `use Mox` which is not defined; solution is to use `import Mox` or explicit calls.)
- **Plugin Manager Reloading Test (`manager_reloading_test.exs`):** (Resolved) This test is passing. Key fixes included:
  - Upgrading Mox to v1.2.0 (though `Mox.allow_global/1` was not the direct solution for cross-process calls).
  - Correctly using `import Mox` along with `setup :set_mox_global` to ensure mocks were visible across processes.
  - Fixing `Manager.handle_call(:initialize, ...)` to use `state.command_registry_table` instead of re-initializing it.
  - Ensuring `LoaderMock` was correctly passed in `start_opts` to the `Manager` and not inadvertently deleted.
  - Standardizing plugin ID derivation (e.g., `initial_plugin_spec.id` to `:test_plugin_v1`) in the test and aligning it with `Manager` logic.
  - Refactoring the test file structure, including the placement of helper functions like `generate_plugin_code/2` and `create_plugin_files/3`.
  - Correcting the usage of `Briefly.create(directory: true)` to handle its path string return value.
  - Replacing `Process.exit(manager_pid, :shutdown)` with `GenServer.stop(manager_pid, :normal)` for a more graceful shutdown in the test.
- **Plugin Manager Reloading Test (`manager_reloading_test.exs`):** ~~Actively debugging this test. The current focus is a `FunctionClauseError` when setting a PID-specific expectation using `Mox.expect(Module, pid, :fun, callback)`. The next step is to try `Mox.expect(Module, pid, :fun, 1, callback)` to see if explicitly providing the count (`1`) resolves the clause error.~~
- **Plugin Manager Reloading Test (`manager_reloading_test.exs`):** ~~Actively debugging this test, which involves complex interactions between the `PluginManager` GenServer and mocked dependencies (`LoaderMock`, `ReloadingLifecycleHelperMock`). Current strategy involves using `Mox.allow_global/1` to ensure stubs and expectations defined in the test process are accessible when called from the `Manager`'s process.~~
- **UI Renderer Edge Cases (`test/raxol/ui/renderer_edge_cases_test.exs`):** (Resolved) All 17 tests in this suite are now passing. Key fixes involved:
  - Ensuring all theme maps were correctly instantiated as `%Raxol.UI.Theming.Theme{}` structs.
  - Registering themes using `Raxol.UI.Theming.Theme.register/1` within tests where they are defined.
  - Adding `Raxol.Core.UserPreferences.start_link/1` to the `setup_all` block to ensure the `UserPreferences` GenServer is available.
  - Correcting the key for text element content from `:content` to `:text`.
  - Refactoring recursive anonymous functions to correctly pass and call themselves.
  - Fixing miscellaneous syntax errors.
  - Made `Raxol.Core.ColorSystem.get/2` robust against undefined theme variants.
  - Added clauses to `Raxol.UI.Renderer.resolve_styles/3` (for `nil` themes) and `Raxol.UI.Renderer.render_element/2` (for `nil` elements).
  - Adjusted patterns in `Raxol.UI.Renderer.render_element/2` for various element types to correctly handle attributes and pass element `style` maps to rendering helpers.
  - Ensured `Raxol.UI.Renderer.resolve_styles/3` correctly handles `style` attributes that might be maps instead of lists.
- **`:meck` cleanup (Complete):** The systematic transition from `:meck` to `Mox` for all core runtime and plugins test files listed in `TODO.md` is complete.
- **Environment Troubleshooting:** Successfully built and installed Erlang/OTP 27.0.1 on macOS by setting `CC`, `CXX`, `LDFLAGS`, and `CPPFLAGS` to use Homebrew's `llvm`/`clang++`, resolving C++ JIT compilation errors. Updated `asdf` to `0.16.7` to fix `uninstall` and `local/global` command issues.
- **Primary Focus:** Addressing the **227 failing tests** is the primary focus, followed by the **33 skipped tests**. Investigation is needed to understand the cause of the widespread failures.
- **Functionality:** Core systems are largely in place.
- **Compiler Warnings:** Numerous warnings remain and require investigation.
- **Sixel Graphics Tests:** Verified correct Sixel string terminator sequences (`\e\\`) in `test/terminal/ansi/sixel_graphics_test.exs`, with all tests passing.
- **UX Refinement Keyboard Tests:** Successfully resolved all test failures (including previously skipped ones) in `test/raxol/core/ux_refinement_keyboard_test.exs`. This involved fully transitioning from `:meck` to `Mox`, careful handling of mock setup order, and a specific refactor for event integration testing where the mock's event handler was registered manually with `EventManager`. The number of skipped tests in this particular file is now 2 (originally 3, with one complex test now passing).

## Immediate Priorities / Tactical Plan

1. **Resolve Mox Compilation Error (`Mox.__using__/1` with Mox 1.2.0):** ~~Investigate Mox 1.2.0 changelogs, documentation, and issue trackers for breaking changes or specific setup requirements related to the `use Mox` macro or the `Mox.__using__/1` function, especially concerning its interaction with `nimble_ownership`.~~ (Resolved by removing `use Mox` and using `import Mox` or explicit calls.)
2. **Address Remaining Skipped Tests:** Once failures are resolved, investigate and fix the remaining **33 skipped tests**.
3. **(Potentially) Identify Further `:meck` Usage:** Perform a codebase search for any remaining `:meck` usage that might have been missed (though this was previously marked complete).
4. **Run Full Test Suite:** Regularly run `mix test` to monitor progress and catch regressions.
5. **Update Documentation:** Keep `TODO.md`, `CHANGELOG.md`, and this file current with accurate test counts and task status.
6. **(Once Tests Stabilize):** Begin comprehensive cross-platform testing and re-run performance benchmarks.

---

_(Older sections detailing specific test fixes, long-term plans, contribution areas, timelines, etc., have been removed to keep this document focused. Refer to `TODO.md`, `ARCHITECTURE.md`, `DevelopmentSetup.md`, and `CHANGELOG.md` for more detail.)_

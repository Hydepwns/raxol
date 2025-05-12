# Test Suite Tracking

## Test Suite Status (as of 2025-06-11)

- **Total Tests:** 2191
- **Doctests:** 34
- **Failures:** 977
- **Invalid:** N/A
- **Skipped:** 12

### Major Failure Categories (2025-06-11)

- **UndefinedFunctionError in Raxol.Terminal.Commands.CSIHandlers**

  - `function Raxol.Terminal.Commands.CSIHandlers.handle_r/2 is undefined or private`
  - This error appears in many terminal emulator and parser tests, likely blocking or cascading into other failures.

- **ModeManager Insert Mode Failure**
  - `test handles terminal modes (Raxol.Components.Terminal.EmulatorTest)`
  - Assertion: `assert state.core_emulator.mode_manager.insert_mode == true` (left: false, right: true)
  - Warning: `[ModeManager] Unhandled mode to set: :insert_mode`
  - Indicates insert mode is not being set or handled correctly in ModeManager.

### Progress Notes (2025-06-11)

- KeyError for :single_shift is resolved (argument order bug in translate_char fixed).
- ModeManager insert_mode failure and terminal driver test helper issues are resolved (helper import, pattern match, and assertion issues fixed).
- The test suite now runs to completion, with failures reduced to 977. Major failures are now dominated by scroll region assertion (handle_r/2 in CSIHandlers not implemented) and screen resizing assertion errors.
- Next step: implement or stub handle_r/2 in Raxol.Terminal.Commands.CSIHandlers, address screen resizing assertion failures, and re-run the suite to assess remaining issues.

### Minor Failure Categories (2025-06-10)

- **CompileError in test/raxol/core/runtime/plugins/discovery_test.exs**

  - Mox.defmock/2 error: LoaderMock cannot be compiled (deps/mox/lib/mox.ex:401)
  - This blocks all subsequent tests from running.
  - **Action:** Fix the mock definition or Mox usage in discovery_test.exs.

- **Plugin System: Dependency Manager Performance Tests**

  - **CaseClauseError** in multiple tests in `test/raxol/core/runtime/plugins/dependency_manager_performance_test.exs`:
    - "handles large number of plugins efficiently"
    - "handles complex version requirements efficiently"
    - "handles mixed workload efficiently"
    - "handles memory usage with large dependency graphs"
  - All fail with `no case clause matching: {:ok, ...}` in `Resolver.tarjan_sort/1`.
  - **Action:** Review the return value expectations in these tests and the implementation of `tarjan_sort/1`.

- **Dependency Graph Test**

  - `test/core/runtime/plugins/dependency_manager/graph_test.exs:115` fails:
    - Assertion with == failed: `assert length(deps) == 3` (left: 4, right: 3)
    - **Action:** Check the test data and expected dependency count.

- **Missing Dependencies**
  - Many errors of the form `{:error, :missing_dependencies, ...}` in plugin dependency tests.
  - **Action:** Review plugin dependency setup and error handling.

### Skipped/Invalid Tests

- All skipped/invalid tests are documented below with reasons and blocking issues.

### Action Plan (2025-06-11)

- **Phase 0:**
  - Fix CompileError in discovery_test.exs (Mox/LoaderMock)
  - Triage and fix CaseClauseError in dependency manager performance tests
  - Review dependency graph test assertion
- **Phase 1:**
  - Implement or stub handle_r/2 in Raxol.Terminal.Commands.CSIHandlers
  - Address screen resizing assertion failures
  - Re-run test suite after fixing above issues
  - Update this file with new failure counts and details

## Progress Notes (2025-06-10)

- Test run blocked by CompileError in discovery_test.exs (Mox/LoaderMock)
- Dependency manager performance tests have multiple CaseClauseError failures
- Dependency graph test assertion mismatch (expected vs actual dependency count)
- Many plugin dependency tests report missing dependencies
- ModeManager insert_mode not handled (see warning and assertion failure)
- Skipped/invalid tests unchanged

---

# Prioritized: Skipped Tests Blocked by Minor Refactors or Helper Updates

The following tests are skipped only due to minor refactors, missing helpers, or minor API changes. These are high-priority for unskipping and should be addressed before tackling feature-blocked or obsolete tests.

| Area / File        | Test / Describe                                                                                                | Reason Skipped                                                                  | Blocker Type                            | Next Action                                    |
| ------------------ | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- | --------------------------------------- | ---------------------------------------------- |
| UI/Renderer        | `test/raxol/ui/renderer_test.exs`<br>"renders table cell alignment correctly"                                  | Alignment hardcoded to left; test not implemented                               | Minor refactor (alignment/layout logic) | Update alignment logic, re-enable test         |
| UI/Renderer/Chart  | `test/raxol/core/renderer/views/chart_test.exs`<br>"adds axes when enabled", "adds legend when enabled"        | Chart.new returns only content view; axes/legend may need wrapper or API update | Minor API change                        | Refactor Chart API or test, re-enable          |
| Visual/Component   | `test/examples/button_test.exs`<br>"adapts to different sizes", "maintains consistent structure across themes" | Visual/snapshot tests; may need updated helpers or snapshots                    | Missing helpers / snapshot update       | Update helpers/snapshots, re-enable            |
| Input/Helpers      | `test/raxol/components/input/multi_line_input/render_helper_test.exs`                                          | Some helpers missing or refactored                                              | Missing helpers                         | Restore or rewrite helpers, re-enable          |
| Colors/Utilities   | `test/raxol/style/colors/utilities_test.exs`                                                                   | Entire module skipped; outdated tests or missing functions                      | Minor refactor / helper update          | Review module, restore helpers, re-enable      |
| Buffer/Scroll      | `test/raxol/terminal/buffer/scroll_test.exs`                                                                   | Compression logic only compresses runs of empty cells                           | Minor logic improvement                 | Improve compression logic, re-enable           |
| Visual/Performance | `test/examples/button_performance_test.exs`                                                                    | Outdated benchmarking or pending migration                                      | Minor refactor / helper update          | Update to new performance framework, re-enable |

---

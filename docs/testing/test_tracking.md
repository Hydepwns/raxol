# Test Suite Tracking

## Test Suite Status (as of 2025-06-11, post-TextField fix)

- **Total Tests:** (see below, suite did not complete due to CompileError)
- **Doctests:** (unknown)
- **Failures:** (suite halted on CompileError)
- **Invalid:** N/A
- **Skipped:** (unknown)

### Major Failure Categories (2025-06-11, post-TextField fix)

- **CompileError in test/core/runtime/plugins/dependency_manager/core_test.exs**

  - Module redefinition: `Raxol.Core.Runtime.Plugins.DependencyManager.CoreTest` is being defined multiple times.
  - This blocks the suite from running to completion.

- **UndefinedFunctionError in MultiLineInput.EventHandler tests**

  - Several tests in `test/raxol/components/input/multi_line_input/event_handler_test.exs` fail due to missing `handle_event/2` implementation.

- **Assertion failures in ApplicationTest**
  - Some tests in `test/raxol/core/runtime/application_test.exs` fail due to mismatched command lists and missing view helpers.

### Progress Notes (2025-06-11, post-TextField fix)

- TextField component and tests are now passing.
- The suite compiles and runs, but is blocked by a module redefinition CompileError in dependency_manager/core_test.exs.
- Several MultiLineInput.EventHandler tests fail due to missing implementation.
- Some ApplicationTest tests fail due to assertion mismatches and missing helpers.
- Next step: fix the module redefinition in core_test.exs to allow the suite to run to completion, then address the remaining high-frequency errors.

### New: Error Frequency Summary (2025-06-11)

A condensed error log from the latest test run shows the most frequent issues:

- `[error] [Elixir.Raxol.Core.Runtime.Plugins.Manager] :runtime_pid is missing or invalid in init opts: []` (63x)
- `{:error, :missing_dependencies, ["plugin_b"], ["plugin_a"]}` (45x)
- `UndefinedFunctionError: Raxol.Terminal.Cursor.Manager.move_to/3 is undefined or private` (25x)
- `UndefinedFunctionError: StateManager.new/0 is undefined` (23x)
- `UndefinedFunctionError: Raxol.DataCase.setup/1 is undefined or private` (21x)
- `UndefinedFunctionError: Raxol.UI.Theming.Theme.component_style/2 is undefined or private` (17x)
- `FunctionClauseError: no function clause matching in Raxol.Core.UserPreferences.handle_info/2` (17x)
- `UndefinedFunctionError: :erlang.trace_receive/1 is undefined or private` (16x)
- ...and many more (see tmp/test_errors_summary.txt for full list).

#### Immediate Next Focus

- **Top priority:** Implement or stub `move_to/3` in `Raxol.Terminal.Cursor.Manager` to address 25+ test failures and unblock further progress.
- After that, address other high-frequency undefined functions and missing helpers.

### Action Plan (2025-06-11)

- [x] Fix ArgumentError in file_watcher/events_test.exs (`:infinity` in `Process.send_after`)
- [x] Centralize ManagerMock definition to resolve duplicate mock errors
- [ ] Implement or stub `move_to/3` in `Raxol.Terminal.Cursor.Manager`
- [ ] Re-run test suite and update this file with new failure counts and details
- [ ] Continue triaging by error frequency and impact

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

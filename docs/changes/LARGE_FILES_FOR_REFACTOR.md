# Large Files for Refactoring (Over 500 Lines of Code)

This document tracks large files in the codebase that need to be refactored into smaller, more focused modules, and records recent refactoring efforts. It also tracks large or growing test helper files.

## Recently Refactored Files

### `lib/raxol/docs/interactive_tutorial.ex` (817 lines)

- Refactored into:
  - `lib/raxol/docs/interactive_tutorial/models.ex`
  - `lib/raxol/docs/interactive_tutorial/state.ex`
  - `lib/raxol/docs/interactive_tutorial/loader.ex`
  - `lib/raxol/docs/interactive_tutorial/navigation.ex`
  - `lib/raxol/docs/interactive_tutorial/validation.ex`
  - `lib/raxol/docs/interactive_tutorial/renderer.ex`
  - `lib/raxol/docs/interactive_tutorial/interactive.ex`
  - `lib/raxol/docs/interactive_tutorial/main.ex`

### `lib/raxol/terminal/integration.ex` (817 lines)

- Refactored into:
  - `lib/raxol/terminal/integration/state.ex`
  - `lib/raxol/terminal/integration/input.ex`
  - `lib/raxol/terminal/integration/buffer.ex`
  - `lib/raxol/terminal/integration/renderer.ex`
  - `lib/raxol/terminal/integration/config.ex`
  - `lib/raxol/terminal/integration/main.ex`

### `test/raxol/core/runtime/plugins/plugin_manager_edge_cases_test.exs` (745 lines)

- Refactored into:
  - `test/raxol/core/runtime/plugins/edge_cases/helper.ex`
  - `test/raxol/core/runtime/plugins/edge_cases/plugin_loading_test.exs`
  - `test/raxol/core/runtime/plugins/edge_cases/plugin_command_test.exs`
  - `test/raxol/core/runtime/plugins/edge_cases/plugin_metadata_test.exs`
  - `test/raxol/core/runtime/plugins/edge_cases/plugin_dependency_test.exs`
  - `test/raxol/core/runtime/plugins/edge_cases/plugin_lifecycle_test.exs`

### `lib/raxol/plugins/plugin_manager.ex` (645 lines)

- Refactored into:
  - `lib/raxol/plugins/plugin_manager/loader.ex`
  - `lib/raxol/plugins/plugin_manager/registry.ex`
  - `lib/raxol/plugins/plugin_manager/dependencies.ex`
  - `lib/raxol/plugins/plugin_manager/lifecycle.ex`
  - `lib/raxol/plugins/plugin_manager/errors.ex`

### `lib/raxol/core/renderer/view.ex` (778 lines)

- Refactored into:
  - `lib/raxol/core/renderer/view/types.ex` (Type definitions and constants)
  - `lib/raxol/core/renderer/view/layout/flex.ex` (Flex layout functionality)
  - `lib/raxol/core/renderer/view/layout/grid.ex` (Grid layout functionality)
  - `lib/raxol/core/renderer/view/style/border.ex` (Border rendering)
  - `lib/raxol/core/renderer/view/components/text.ex` (Text component)
  - `lib/raxol/core/renderer/view/components/box.ex` (Box component)
  - `lib/raxol/core/renderer/view/components/scroll.ex` (Scroll component)
  - `lib/raxol/core/renderer/view/utils/view_utils.ex` (Common utilities)
  - `lib/raxol/core/renderer/view.ex` (Main facade module)

## Large Files Still Needing Refactoring

### Library Files (`lib/`)

- `lib/raxol/cloud/edge_computing.ex`: **795 lines**
- `lib/raxol/terminal/mode_manager.ex`: **758 lines**
- `lib/raxol/terminal/buffer/manager.ex`: **742 lines**
- `lib/raxol/components/progress.ex`: **722 lines**
- `lib/raxol/core/runtime/plugins/plugin_manager.ex`: **712 lines** (if not fully refactored)
- `lib/raxol/core/runtime/plugins/plugin_loader.ex`: **689 lines**
- `lib/raxol/core/runtime/plugins/plugin_validator.ex`: **678 lines**
- `lib/raxol/core/runtime/plugins/plugin_config.ex`: **645 lines**
- `lib/raxol/core/runtime/plugins/plugin_state.ex`: **623 lines**
- `lib/raxol/core/runtime/plugins/plugin_events.ex`: **612 lines**
- `lib/raxol/core/runtime/plugins/plugin_hooks.ex`: **598 lines**
- `lib/raxol/core/runtime/plugins/plugin_dependencies.ex`: **587 lines**
- `lib/raxol/core/runtime/plugins/plugin_metadata.ex`: **576 lines**
- `lib/raxol/core/runtime/plugins/plugin_registry.ex`: **565 lines**
- `lib/raxol/core/runtime/emulator.ex`: **689 lines** (split for CPU, memory, I/O, interrupts, debugging)
- `lib/raxol/core/runtime/renderer.ex`: **678 lines** (split for buffer, pipeline, layers, view, style)
- `lib/raxol/core/runtime/input.ex`: **567 lines** (split for key, mouse, buffering, filtering, mapping)
- `lib/raxol/core/runtime/output.ex`: **545 lines** (split for buffering, updates, cursor, color, style)
- `lib/raxol/core/runtime/events.ex`: **523 lines** (split for queue, dispatch, filtering, transformation, logging)

### Test Files (`test/`)

- `test/raxol/core/runtime/plugins/dependency_manager_test.exs`: **1154 lines**
- `test/raxol/ui/renderer_edge_cases_test.exs`: **869 lines**
- `test/raxol/core/accessibility_test.exs`: **844 lines**
- `test/raxol/core/renderer/views/integration_test.exs`: **696 lines**

## Refactoring Guidelines

1. **Single Responsibility**: Each module should have one clear responsibility
2. **Cohesion**: Related functionality should be grouped together
3. **Coupling**: Minimize dependencies between modules
4. **Interface Design**: Design clear, focused public APIs
5. **Documentation**: Maintain comprehensive documentation
6. **Testing**: Ensure test coverage for new modules
7. **Backward Compatibility**: Maintain existing public APIs where possible

## Refactoring Process

1. Identify distinct responsibilities in the large file
2. Create new modules for each responsibility
3. Move related code to new modules
4. Update imports and dependencies
5. Update tests
6. Verify functionality
7. Update documentation
8. Remove old file

## Large or Growing Test Helper Files

- `test/support/component_test_helpers.ex`
  - Now serves as a shared test helper module for component lifecycle and integration tests.
  - Should be kept small and focused; split into multiple helper modules if it grows too large.
  - Recent addition: `mount_component/2` for parent-child mounting in integration tests.

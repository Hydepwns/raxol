# Master Plan: Test Suite Recovery Strategy

## Current Status

- **Total Tests**: 3392
- **Failures**: 1807
- **Passing**: 1585
- **Invalid**: 13
- **Skipped**: 1
- **Exit Code**: 0 (tests complete but with failures)

## Priority Order for Fixes

### Phase 1: Critical Infrastructure (High Impact, Low Risk)

**Goal**: Fix core structural issues that are causing cascading failures

#### 1.1 Fix Cursor Manager Struct Issues

**Impact**: ~400+ failures directly related to cursor operations
**Files to Fix**:

- `lib/raxol/terminal/cursor/style.ex`
- `lib/raxol/terminal/cursor/manager.ex`

**Issues**:

- Missing fields: `:state`, `:position`, `:blink` in `Raxol.Terminal.Cursor.Manager`
- `@impl true` annotations without corresponding `@behaviour`
- Function signature mismatches

**Action Plan**:

1. Add missing fields to the cursor struct
2. Implement proper behavior module for cursor operations
3. Fix function signatures to match test expectations
4. Update cursor-related functions to use correct field names

**Code Examples**:

```elixir
# In lib/raxol/terminal/cursor/manager.ex
defmodule Raxol.Terminal.Cursor.Manager do
  defstruct [
    :state,      # Add this field
    :position,   # Add this field
    :blink,      # Add this field
    :x, :y, :visible, :blinking, :style, :color,
    :saved_x, :saved_y, :saved_style, :saved_visible, :saved_blinking, :saved_color,
    :top_margin, :bottom_margin, :blink_timer
  ]

  # Add behavior definition
  @callback set_block(cursor :: t()) :: t()
  @callback set_underline(cursor :: t()) :: t()
  @callback set_bar(cursor :: t()) :: t()
  @callback set_custom(cursor :: t(), shape :: atom(), dimensions :: map()) :: t()
  @callback show(cursor :: t()) :: t()
  @callback hide(cursor :: t()) :: t()
  @callback toggle_visibility(cursor :: t()) :: t()
  @callback toggle_blink(cursor :: t()) :: t()
  @callback set_blink_rate(cursor :: t(), rate :: integer()) :: t()
  @callback update_blink(cursor :: t()) :: t()
  @callback get_state(cursor :: t()) :: atom()
  @callback get_blink(cursor :: t()) :: boolean()

  @type t :: %__MODULE__{}
end
```

```elixir
# In lib/raxol/terminal/cursor/style.ex
defmodule Raxol.Terminal.Cursor.Style do
  @behaviour Raxol.Terminal.Cursor.Manager

  # Fix function signatures to match behavior
  @impl true
  def set_block(%Manager{} = cursor) do
    %{cursor | style: :block}
  end

  @impl true
  def set_underline(%Manager{} = cursor) do
    %{cursor | style: :underline}
  end

  # Add missing state field access
  def get_state(%Manager{} = cursor) do
    cursor.state || :normal
  end

  def get_blink(%Manager{} = cursor) do
    cursor.blink || cursor.blinking
  end
end
```

#### 1.2 Fix Input Handler Module

**Impact**: ~200+ failures related to input processing
**Files to Fix**:

- `lib/raxol/terminal/input/input_handler.ex` (likely missing or incomplete)

**Issues**:

- Module `Raxol.Terminal.Input.InputHandler` appears to be missing
- Functions like `new/0`, `process_keyboard/2`, `get_buffer_contents/1` are undefined

**Action Plan**:

1. Create or complete the InputHandler module
2. Implement all required functions with correct signatures
3. Ensure proper state management for input buffering

**Code Example**:

```elixir
# Create lib/raxol/terminal/input/input_handler.ex
defmodule Raxol.Terminal.Input.InputHandler do
  defstruct [
    buffer: "",
    mode: :normal,
    modifiers: %{},
    mouse_enabled: false,
    history: [],
    history_index: -1
  ]

  @type t :: %__MODULE__{}

  def new() do
    %__MODULE__{}
  end

  def process_keyboard(%__MODULE__{} = handler, key) when is_binary(key) do
    case handler.mode do
      :normal -> %{handler | buffer: handler.buffer <> key}
      :insert -> %{handler | buffer: handler.buffer <> key}
    end
  end

  def process_special_key(%__MODULE__{} = handler, key) do
    case key do
      :up -> %{handler | buffer: get_history_entry(handler, handler.history_index - 1)}
      :down -> %{handler | buffer: get_history_entry(handler, handler.history_index + 1)}
      :left -> handler
      :right -> handler
      :home -> handler
      :end -> handler
      :page_up -> handler
      :page_down -> handler
      :f1 -> handler
      :f2 -> handler
      :f3 -> handler
      :f4 -> handler
      :f5 -> handler
      :f6 -> handler
      :f7 -> handler
      :f8 -> handler
      :f9 -> handler
      :f10 -> handler
      :f11 -> handler
      :f12 -> handler
      _ -> handler
    end
  end

  def process_key_with_modifiers(%__MODULE__{} = handler, key) do
    # Handle modifier keys (ctrl, alt, shift)
    handler
  end

  def process_mouse(%__MODULE__{} = handler, _event) do
    # Handle mouse events
    handler
  end

  def set_mouse_enabled(%__MODULE__{} = handler, enabled) do
    %{handler | mouse_enabled: enabled}
  end

  def set_mode(%__MODULE__{} = handler, mode) do
    %{handler | mode: mode}
  end

  def get_mode(%__MODULE__{} = handler) do
    handler.mode
  end

  def update_modifier(%__MODULE__{} = handler, modifier, state) do
    modifiers = Map.put(handler.modifiers, modifier, state)
    %{handler | modifiers: modifiers}
  end

  def add_to_history(%__MODULE__{} = handler) do
    if handler.buffer != "" do
      history = [handler.buffer | handler.history]
      %{handler | history: history, history_index: -1}
    else
      handler
    end
  end

  def get_history_entry(%__MODULE__{} = handler, index) do
    if index >= 0 and index < length(handler.history) do
      entry = Enum.at(handler.history, index)
      %{handler | buffer: entry, history_index: index}
    else
      handler
    end
  end

  def next_history_entry(%__MODULE__{} = handler) do
    if handler.history_index < length(handler.history) - 1 do
      %{handler | history_index: handler.history_index + 1}
    else
      handler
    end
  end

  def previous_history_entry(%__MODULE__{} = handler) do
    if handler.history_index > 0 do
      %{handler | history_index: handler.history_index - 1}
    else
      handler
    end
  end

  def clear_buffer(%__MODULE__{} = handler) do
    %{handler | buffer: ""}
  end

  def buffer_empty?(%__MODULE__{} = handler) do
    handler.buffer == ""
  end

  def get_buffer_contents(%__MODULE__{} = handler) do
    handler.buffer
  end
end
```

#### 1.3 Fix Terminal Operations

**Impact**: ~150+ failures in screen and buffer operations
**Files to Fix**:

- `lib/raxol/terminal/operations/screen_operations.ex`
- `lib/raxol/terminal/operations/selection_operations.ex`

**Issues**:

- Function signature mismatches (e.g., `clear_line/1` vs `clear_line/2`)
- Missing functions like `write_string/5`, `get_content/1`

**Action Plan**:

1. Standardize function signatures across operations modules
2. Add missing functions with correct implementations
3. Ensure consistent parameter ordering

**Code Examples**:

```elixir
# In lib/raxol/terminal/operations/screen_operations.ex
defmodule Raxol.Terminal.Operations.ScreenOperations do
  # Fix function signatures to match test expectations
  def clear_screen(emulator, _opts \\ %{}) do
    # Implementation
    emulator
  end

  def clear_line(emulator, _opts \\ %{}) do
    # Implementation
    emulator
  end

  def erase_display(emulator, _opts \\ %{}) do
    # Implementation
    emulator
  end

  def erase_in_display(emulator, _opts \\ %{}) do
    # Implementation
    emulator
  end

  def erase_line(emulator, _opts \\ %{}) do
    # Implementation
    emulator
  end

  def erase_in_line(emulator, _opts \\ %{}) do
    # Implementation
    emulator
  end

  def write_string(emulator, x, y, string, _opts \\ %{}) do
    # Implementation
    emulator
  end

  def get_content(emulator) do
    # Implementation
    ""
  end

  def get_line(emulator, line) do
    # Implementation
    ""
  end

  def set_cursor_position(emulator, x, y) do
    # Implementation
    emulator
  end

  # Add other missing functions...
end
```

### Phase 2: Configuration and Deprecation Warnings (Medium Impact, Low Risk)

**Goal**: Clean up warnings and modernize configuration

#### 2.1 Update Mix.Config to Config

**Impact**: ~50+ deprecation warnings
**Files to Fix**:

- `config/config.exs`
- Any other config files using `Mix.Config`

**Action Plan**:

1. Replace `use Mix.Config` with `import Config`
2. Update all `Mix.Config` function calls to use `Config`
3. Test configuration loading after changes

**Code Example**:

```elixir
# In config/config.exs
# Change from:
# use Mix.Config
# config :raxol, ...

# To:
import Config
config :raxol, ...
```

#### 2.2 Fix Behavior Implementation Warnings

**Impact**: ~100+ warnings about missing behavior implementations
**Files to Fix**:

- `lib/raxol/terminal/cursor/style.ex`
- Various mock implementations

**Action Plan**:

1. Add proper `@behaviour` modules where missing
2. Implement all required callbacks
3. Remove incorrect `@impl true` annotations

### Phase 3: Mock and Test Infrastructure (Medium Impact, Medium Risk)

**Goal**: Fix test infrastructure and mock implementations

#### 3.1 Fix Mock Implementations

**Impact**: ~300+ unused variable warnings
**Files to Fix**:

- `test/support/mock_implementations.ex`

**Action Plan**:

1. Add underscore prefixes to unused variables
2. Implement missing mock functions
3. Ensure mocks return appropriate test data

**Code Example**:

```elixir
# In test/support/mock_implementations.ex
# Change from:
def load_plugin(plugin_id_or_module, config, plugins, metadata, plugin_states, load_order, command_table, plugin_config) do

# To:
def load_plugin(_plugin_id_or_module, _config, _plugins, _metadata, _plugin_states, _load_order, _command_table, _plugin_config) do
```

#### 3.2 Fix Missing Test Helper Functions

**Impact**: ~50+ failures due to missing test helpers
**Files to Fix**:

- `test/support/` directory
- Various test helper modules

**Action Plan**:

1. Create missing test helper modules
2. Implement helper functions like `DriverTestHelper`
3. Ensure consistent test setup/teardown

**Code Example**:

```elixir
# Create test/support/driver_test_helper.ex
defmodule Raxol.Terminal.DriverTestHelper do
  def setup_terminal() do
    # Setup terminal for testing
    :ok
  end

  def start_driver(test_pid) do
    # Start driver process
    spawn(fn -> driver_loop(test_pid) end)
  end

  def wait_for_driver_ready(driver_pid) do
    # Wait for driver to be ready
    :ok
  end

  def consume_initial_resize() do
    # Consume initial resize event
    :ok
  end

  def simulate_key_event(driver_pid, key) do
    # Simulate key event
    send(driver_pid, {:key, key})
  end

  def simulate_key_event(driver_pid, modifier, key) do
    # Simulate key event with modifier
    send(driver_pid, {:key, modifier, key})
  end

  def assert_key_event(expected_key) do
    # Assert key event
    assert_receive {:key, ^expected_key}
  end

  def assert_key_event(expected_modifier, expected_key) do
    # Assert key event with modifier
    assert_receive {:key, ^expected_modifier, ^expected_key}
  end

  defp driver_loop(test_pid) do
    receive do
      {:key, key} ->
        send(test_pid, {:key, key})
        driver_loop(test_pid)
      {:key, modifier, key} ->
        send(test_pid, {:key, modifier, key})
        driver_loop(test_pid)
    end
  end
end
```

### Phase 4: Plugin System and Advanced Features (Low Impact, High Risk)

**Goal**: Complete plugin system and advanced terminal features

#### 4.1 Fix Plugin System

**Impact**: ~100+ failures in plugin-related tests
**Files to Fix**:

- `lib/raxol/plugins/` directory
- Plugin lifecycle management

**Action Plan**:

1. Complete plugin loading/unloading logic
2. Fix plugin state management
3. Implement missing plugin callbacks

#### 4.2 Fix Advanced Terminal Features

**Impact**: ~200+ failures in advanced terminal operations
**Files to Fix**:

- Various terminal operation modules
- Buffer management
- Screen management

**Action Plan**:

1. Complete advanced terminal operations
2. Fix buffer state management
3. Implement missing screen operations

## Implementation Strategy

### For Each Phase

1. **Analyze**: Run tests to identify specific failures
2. **Prioritize**: Focus on highest impact fixes first
3. **Implement**: Make changes incrementally
4. **Test**: Run tests after each significant change
5. **Document**: Update documentation as needed

### Testing Approach

1. **Start with**: `mix test --max-failures=10` to see immediate impact
2. **Progress to**: `mix test` to see full test suite status
3. **Use**: `mix test --trace` for detailed failure information when needed

### Risk Mitigation

1. **Backup**: Commit current state before major changes
2. **Incremental**: Make small, testable changes
3. **Isolation**: Fix one module/feature at a time
4. **Validation**: Ensure fixes don't break existing functionality

## Troubleshooting Guide

### Common Error Patterns and Solutions

#### KeyError: key :state not found

**Cause**: Missing struct field
**Solution**: Add field to struct definition

```elixir
defstruct [:state, :position, :blink, ...]
```

#### UndefinedFunctionError: function Module.function/arity is undefined

**Cause**: Missing function implementation
**Solution**: Create function with correct signature

```elixir
def function_name(arg1, arg2) do
  # Implementation
end
```

#### @impl true without @behaviour

**Cause**: Missing behavior definition
**Solution**: Add behavior or remove @impl

```elixir
@behaviour MyBehaviour
@impl true
def callback_function(arg) do
  # Implementation
end
```

#### FunctionClauseError: no function clause matching

**Cause**: Function signature mismatch
**Solution**: Fix function signature to match test expectations

```elixir
# Change from:
def my_function(arg1), do: ...

# To:
def my_function(arg1, opts \\ %{}), do: ...
```

### Debugging Commands

```bash
# Check specific test file
mix test test/path/to/specific_test.exs

# Run with detailed output
mix test --trace

# Check compilation warnings
mix compile --warnings-as-errors

# Check specific module compilation
mix compile lib/raxol/terminal/cursor/style.ex

# Run tests with specific pattern
mix test --only test_name_pattern
```

## Success Metrics

### Phase 1 Success

- Cursor-related failures reduced by 80%
- Input handler failures eliminated
- Terminal operations failures reduced by 70%

### Phase 2 Success

- Deprecation warnings eliminated
- Behavior implementation warnings reduced by 90%

### Phase 3 Success

- Mock implementation warnings eliminated
- Test helper failures resolved

### Overall Success

- **Target**: <100 test failures (95%+ pass rate)
- **Stretch Goal**: <50 test failures (98%+ pass rate)

## Files Requiring Immediate Attention

### High Priority

1. `lib/raxol/terminal/cursor/style.ex`
2. `lib/raxol/terminal/cursor/manager.ex`
3. `lib/raxol/terminal/input/input_handler.ex`
4. `lib/raxol/terminal/operations/screen_operations.ex`
5. `config/config.exs`

### Medium Priority

1. `test/support/mock_implementations.ex`
2. `lib/raxol/plugins/` directory
3. Various test helper modules

### Low Priority

1. Advanced terminal features
2. Performance optimizations
3. Documentation updates

## Notes for Next AI Agent

1. **Start with Phase 1**: The cursor and input handler fixes will have the biggest impact
2. **Test frequently**: Run tests after each significant change
3. **Focus on function signatures**: Many failures are due to mismatched function signatures
4. **Check for missing modules**: Several modules appear to be missing entirely
5. **Use the test output**: The detailed error messages provide specific guidance on what needs to be fixed
6. **Maintain backward compatibility**: Ensure fixes don't break existing functionality
7. **Document changes**: Update any relevant documentation as you make changes
8. **Use the troubleshooting guide**: Reference the common error patterns section
9. **Make incremental commits**: Commit after each major fix to track progress
10. **Ask for help**: If stuck on a specific error, the troubleshooting section should help

## Expected Timeline

- **Phase 1**: 2-3 days (highest impact)
- **Phase 2**: 1-2 days (cleanup)
- **Phase 3**: 2-3 days (test infrastructure)
- **Phase 4**: 3-5 days (advanced features)

**Total Estimated Time**: 8-13 days to reach <100 failures

## Quick Start Commands

```bash
# Check current status
mix test --max-failures=10

# Run specific test files to focus on one area
mix test test/raxol/terminal/cursor_test.exs

# Check for compilation warnings
mix compile --warnings-as-errors

# Run tests with detailed output
mix test --trace

# Focus on cursor tests specifically
mix test test/raxol/terminal/cursor_test.exs --trace

# Check input handler tests
mix test test/raxol/terminal/input/input_handler_test.exs --trace
```

## Progress Tracking

Keep track of your progress by running these commands regularly:

```bash
# Before starting
mix test 2>&1 | grep -E "tests,.*failures" | tail -1

# After each major fix
mix test --max-failures=10

# Daily progress check
mix test 2>&1 | grep -E "tests,.*failures" | tail -1
```

**Remember**: The goal is to get from 1807 failures to under 100 failures. Focus on Phase 1 first - it will have the biggest impact!

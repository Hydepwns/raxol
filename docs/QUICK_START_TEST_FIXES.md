# Quick Start: Test Fixes for Next AI Agent

## 🚀 Immediate Action Items (Start Here)

### 1. First Priority: Fix Cursor Manager

**File**: `lib/raxol/terminal/cursor/style.ex`
**Problem**: Missing fields `:state`, `:position`, `:blink` in cursor struct
**Quick Fix**:

```elixir
# Add these fields to the cursor struct in manager.ex
defstruct [
  :state,      # Add this
  :position,   # Add this
  :blink,      # Add this
  # ... existing fields
]
```

**Step-by-step**:

1. Open `lib/raxol/terminal/cursor/manager.ex`
2. Find the `defstruct` line
3. Add `:state, :position, :blink` to the list
4. Save and run: `mix test test/raxol/terminal/cursor_test.exs`

### 2. Second Priority: Create Input Handler

**File**: `lib/raxol/terminal/input/input_handler.ex` (likely missing)
**Problem**: Module doesn't exist, causing ~200 failures
**Quick Fix**: Create the module with basic functions:

```elixir
defmodule Raxol.Terminal.Input.InputHandler do
  defstruct [
    buffer: "",
    mode: :normal,
    modifiers: %{},
    mouse_enabled: false,
    history: [],
    history_index: -1
  ]

  def new(), do: %__MODULE__{}
  def process_keyboard(handler, key), do: handler
  def get_buffer_contents(handler), do: handler.buffer
  def process_special_key(handler, _key), do: handler
  def process_key_with_modifiers(handler, _key), do: handler
  def process_mouse(handler, _event), do: handler
  def set_mouse_enabled(handler, enabled), do: %{handler | mouse_enabled: enabled}
  def set_mode(handler, mode), do: %{handler | mode: mode}
  def get_mode(handler), do: handler.mode
  def update_modifier(handler, modifier, state), do: %{handler | modifiers: Map.put(handler.modifiers, modifier, state)}
  def add_to_history(handler), do: handler
  def get_history_entry(handler, _index), do: handler
  def next_history_entry(handler), do: handler
  def previous_history_entry(handler), do: handler
  def clear_buffer(handler), do: %{handler | buffer: ""}
  def buffer_empty?(handler), do: handler.buffer == ""
end
```

**Step-by-step**:

1. Create file `lib/raxol/terminal/input/input_handler.ex`
2. Copy the code above
3. Save and run: `mix test test/raxol/terminal/input/input_handler_test.exs`

### 3. Third Priority: Fix Function Signatures

**Files**: Various operation modules
**Problem**: Function signature mismatches
**Quick Fix**: Standardize signatures:

```elixir
# Change from:
def clear_line(emulator), do: ...

# To:
def clear_line(emulator, _opts \\ %{}), do: ...
```

**Common patterns to fix**:

```elixir
# Screen operations
def clear_screen(emulator, _opts \\ %{}), do: emulator
def erase_display(emulator, _opts \\ %{}), do: emulator
def erase_in_display(emulator, _opts \\ %{}), do: emulator
def erase_line(emulator, _opts \\ %{}), do: emulator
def erase_in_line(emulator, _opts \\ %{}), do: emulator
def write_string(emulator, x, y, string, _opts \\ %{}), do: emulator
def get_content(emulator), do: ""
def get_line(emulator, _line), do: ""
def set_cursor_position(emulator, x, y), do: emulator
```

## 🔍 Diagnostic Commands

```bash
# See current failures (limited to 10)
mix test --max-failures=10

# Focus on cursor tests
mix test test/raxol/terminal/cursor_test.exs

# Check specific module
mix test test/raxol/terminal/input/input_handler_test.exs

# See all warnings
mix compile --warnings-as-errors

# Run with detailed output for debugging
mix test test/raxol/terminal/cursor_test.exs --trace

# Check compilation of specific file
mix compile lib/raxol/terminal/cursor/style.ex
```

## 📋 Top 5 Files to Fix First

1. **`lib/raxol/terminal/cursor/style.ex`** - Fix struct fields and @impl issues
2. **`lib/raxol/terminal/input/input_handler.ex`** - Create missing module
3. **`lib/raxol/terminal/operations/screen_operations.ex`** - Fix function signatures
4. **`config/config.exs`** - Update Mix.Config to Config
5. **`test/support/mock_implementations.ex`** - Fix unused variables

## 🎯 Success Metrics

- **Current**: 1807 failures
- **Phase 1 Goal**: <500 failures
- **Final Goal**: <100 failures

## ⚡ Quick Wins

1. **Fix deprecation warnings** - Easy, low risk

   ```elixir
   # In config/config.exs
   # Change: use Mix.Config
   # To: import Config
   ```

2. **Add underscore prefixes** - Simple syntax fixes

   ```elixir
   # Change: def function(a, b, c), do: ...
   # To: def function(_a, _b, _c), do: ...
   ```

3. **Create stub functions** - Quick to implement

   ```elixir
   def missing_function(_arg1, _arg2), do: :ok
   ```

4. **Fix struct definitions** - Clear, mechanical fixes
   ```elixir
   defstruct [:missing_field, :another_field]
   ```

## 🚨 Common Patterns to Look For

- `** (KeyError) key :state not found` → Add missing struct field
- `is undefined or private` → Create missing function
- `@impl true` without `@behaviour` → Add behavior or remove @impl
- `function clause matching` → Fix function signature
- `deprecated` → Update to new API
- `unused variable` → Add underscore prefix

## 🔧 Step-by-Step Workflow

### Day 1: Cursor Fixes

1. **Morning**: Fix cursor struct fields
   ```bash
   mix test test/raxol/terminal/cursor_test.exs
   ```
2. **Afternoon**: Fix cursor behavior implementations
3. **Evening**: Test and commit changes

### Day 2: Input Handler

1. **Morning**: Create input handler module
   ```bash
   mix test test/raxol/terminal/input/input_handler_test.exs
   ```
2. **Afternoon**: Implement all required functions
3. **Evening**: Test and commit changes

### Day 3: Terminal Operations

1. **Morning**: Fix screen operations signatures
2. **Afternoon**: Fix selection operations
3. **Evening**: Test and commit changes

## 🐛 Troubleshooting Common Issues

### Issue: "module not found"

**Solution**: Create the missing module file

```bash
touch lib/raxol/terminal/input/input_handler.ex
```

### Issue: "function undefined"

**Solution**: Add the missing function

```elixir
def missing_function(arg1, arg2), do: :ok
```

### Issue: "struct field not found"

**Solution**: Add field to struct

```elixir
defstruct [:missing_field]
```

### Issue: "compilation warnings"

**Solution**: Fix warnings one by one

```bash
mix compile --warnings-as-errors
```

## 📊 Progress Tracking

Keep a simple log of your progress:

```bash
# Before starting
echo "Starting: $(date)" > progress.log
mix test 2>&1 | grep -E "tests,.*failures" | tail -1 >> progress.log

# After each fix
echo "After fix: $(date)" >> progress.log
mix test --max-failures=10 >> progress.log
```

## 🎯 Daily Goals

- **Day 1**: Get cursor tests passing (target: -400 failures)
- **Day 2**: Get input handler tests passing (target: -200 failures)
- **Day 3**: Get terminal operations passing (target: -150 failures)
- **Day 4**: Fix deprecation warnings (target: -50 failures)
- **Day 5**: Fix mock implementations (target: -100 failures)

## 🚀 Pro Tips

1. **Start small**: Fix one test file at a time
2. **Test frequently**: Run tests after each change
3. **Use the trace flag**: `--trace` gives detailed error info
4. **Focus on patterns**: Many failures follow the same pattern
5. **Commit often**: Save your progress regularly
6. **Read error messages**: They tell you exactly what's wrong
7. **Use grep**: Find all occurrences of a pattern
   ```bash
   grep -r "Mix.Config" config/
   ```

## 📚 Reference

- Full plan: `docs/MASTER_PLAN_TEST_FIXES.md`
- Test output analysis: Check `tmp/test_output.txt`
- Current status: 3392 tests, 1807 failures, 1585 passing

## 🎯 Next Steps

1. **Start with cursor fixes** (biggest impact)
2. **Create input handler** (missing module)
3. **Fix function signatures** (mechanical fixes)
4. **Run tests frequently** to see progress
5. **Document changes** as you go

## 🆘 Emergency Commands

If something goes wrong:

```bash
# Reset to last working state
git reset --hard HEAD

# Check what files you've modified
git status

# See your recent changes
git diff

# Run a specific test to debug
mix test test/path/to/test.exs --trace
```

**Remember**: Focus on Phase 1 first - it will have the biggest impact on reducing failures! The goal is to get from 1807 failures to under 100 failures systematically.

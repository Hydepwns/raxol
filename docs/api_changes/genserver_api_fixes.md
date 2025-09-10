# GenServer API Fixes - FocusManager and KeyboardShortcuts

**Version:** v1.2.0  
**Date:** 2025-01-09  
**Affects:** Sprint 23+ fixes for FocusManager and KeyboardShortcuts modules

## Overview

During Sprint 23+ development, critical API issues were discovered and fixed in the FocusManager and KeyboardShortcuts modules. These modules use a delegating architecture where the public API delegates to GenServer implementations, but the parameter passing was incorrect.

## The Problem

Both `Raxol.Core.FocusManager` and `Raxol.Core.KeyboardShortcuts` act as public API wrappers that delegate to their respective GenServer implementations:

- `FocusManager` → `FocusManager.FocusServer`
- `KeyboardShortcuts` → `KeyboardShortcuts.ShortcutsServer`

However, the wrapper functions were not passing the required `server` parameter to the GenServer functions, causing the first actual parameter to be misinterpreted as the server name.

### Example of the Issue

**Before (Broken):**
```elixir
# In Raxol.Core.FocusManager
def register_focusable(component_id, tab_index, opts \\ []) do
  ensure_started()
  Server.register_focusable(component_id, tab_index, opts)  # ❌ Missing server parameter
end
```

**Expected GenServer signature:**
```elixir
# In FocusServer
def register_focusable(server \\ __MODULE__, component_id, tab_index, opts \\ []) do
  GenServer.call(server, {:register_focusable, component_id, tab_index, opts})
end
```

**Result:** `component_id` was being passed as the `server` parameter, causing `GenServer.whereis/1` errors.

## The Fix

All wrapper functions were updated to correctly pass the server parameter:

**After (Fixed):**
```elixir
# In Raxol.Core.FocusManager
def register_focusable(component_id, tab_index, opts \\ []) do
  ensure_started()
  Server.register_focusable(Server, component_id, tab_index, opts)  # ✅ Correct server parameter
end
```

## Affected Functions

### FocusManager Functions Fixed

All functions in `Raxol.Core.FocusManager` were updated to pass the `Server` parameter:

1. **`register_focusable/3`**
   - **Before:** `Server.register_focusable(component_id, tab_index, opts)`
   - **After:** `Server.register_focusable(Server, component_id, tab_index, opts)`

2. **`unregister_focusable/1`**
   - **Before:** `Server.unregister_focusable(component_id)`
   - **After:** `Server.unregister_focusable(Server, component_id)`

3. **`set_initial_focus/1`**
   - **Before:** `Server.set_initial_focus(component_id)`
   - **After:** `Server.set_initial_focus(Server, component_id)`

4. **`set_focus/1`**
   - **Before:** `Server.set_focus(component_id)`
   - **After:** `Server.set_focus(Server, component_id)`

5. **`focus_next/1`**
   - **Before:** `Server.focus_next(opts)`
   - **After:** `Server.focus_next(Server, opts)`

6. **`focus_previous/1`**
   - **Before:** `Server.focus_previous(opts)`
   - **After:** `Server.focus_previous(Server, opts)`

7. **`get_focused_element/0`**
   - **Before:** `Server.get_focused_element()`
   - **After:** `Server.get_focused_element(Server)`

8. **`get_focus_history/0`**
   - **Before:** `Server.get_focus_history()`
   - **After:** `Server.get_focus_history(Server)`

9. **`get_next_focusable/1`**
   - **Before:** `Server.get_next_focusable(current_focus_id)`
   - **After:** `Server.get_next_focusable(Server, current_focus_id)`

10. **`get_previous_focusable/1`**
    - **Before:** `Server.get_previous_focusable(current_focus_id)`
    - **After:** `Server.get_previous_focusable(Server, current_focus_id)`

11. **`has_focus?/1`**
    - **Before:** `Server.has_focus?(component_id)`
    - **After:** `Server.has_focus?(Server, component_id)`

12. **`return_to_previous/0`**
    - **Before:** `Server.return_to_previous()`
    - **After:** `Server.return_to_previous(Server)`

13. **`enable_component/1`**
    - **Before:** `Server.enable_component(component_id)`
    - **After:** `Server.enable_component(Server, component_id)`

14. **`disable_component/1`**
    - **Before:** `Server.disable_component(component_id)`
    - **After:** `Server.disable_component(Server, component_id)`

15. **`register_focus_change_handler/1`**
    - **Before:** `Server.register_focus_change_handler(handler_fun)`
    - **After:** `Server.register_focus_change_handler(Server, handler_fun)`

16. **`unregister_focus_change_handler/1`**
    - **Before:** `Server.unregister_focus_change_handler(handler_fun)`
    - **After:** `Server.unregister_focus_change_handler(Server, handler_fun)`

### KeyboardShortcuts Functions Fixed

All functions in `Raxol.Core.KeyboardShortcuts` were updated to pass the `Server` parameter:

1. **`init_shortcuts/0`**
   - **Before:** `Server.init_shortcuts()`
   - **After:** `Server.init_shortcuts(Server)`

2. **`register_shortcut/4`**
   - **Before:** `Server.register_shortcut(shortcut, name, callback, opts)`
   - **After:** `Server.register_shortcut(Server, shortcut, name, callback, opts)`

3. **`unregister_shortcut/2`**
   - **Before:** `Server.unregister_shortcut(shortcut, context)`
   - **After:** `Server.unregister_shortcut(Server, shortcut, context)`

4. **`set_active_context/1`**
   - **Before:** `Server.set_active_context(context)`
   - **After:** `Server.set_active_context(Server, context)`

5. **`get_shortcuts_for_context/1`**
   - **Before:** `Server.get_shortcuts_for_context(context)`
   - **After:** `Server.get_shortcuts_for_context(Server, context)`

6. **`handle_keyboard_event/1`**
   - **Before:** `Server.handle_keyboard_event(event)`
   - **After:** `Server.handle_keyboard_event(Server, event)`

7. **`get_active_context/0`**
   - **Before:** `Server.get_active_context()`
   - **After:** `Server.get_active_context(Server)`

8. **`get_available_shortcuts/0`**
   - **Before:** `Server.get_available_shortcuts()`
   - **After:** `Server.get_available_shortcuts(Server)`

9. **`generate_shortcuts_help/0`**
   - **Before:** `Server.generate_shortcuts_help()`
   - **After:** `Server.generate_shortcuts_help(Server)`

10. **`set_enabled/1`**
    - **Before:** `Server.set_enabled(enabled)`
    - **After:** `Server.set_enabled(Server, enabled)`

11. **`enabled?/0`**
    - **Before:** `Server.enabled?()`
    - **After:** `Server.enabled?(Server)`

12. **`set_conflict_resolution/1`**
    - **Before:** `Server.set_conflict_resolution(strategy)`
    - **After:** `Server.set_conflict_resolution(Server, strategy)`

13. **`clear_all/0`** (both occurrences)
    - **Before:** `Server.clear_all()`
    - **After:** `Server.clear_all(Server)`

14. **`clear_context/1`**
    - **Before:** `Server.clear_context(context)`
    - **After:** `Server.clear_context(Server, context)`

## Error Symptoms

Before the fix, you would see errors like:

```elixir
** (FunctionClauseError) no function clause matching in GenServer.whereis/1

The following arguments were given to GenServer.whereis/1:
    # 1
    "search_button_focus"  # This should have been the component_id, not server name

Attempted function clauses (showing 6 out of 6):
    def whereis(pid) when -is_pid(pid)-
    def whereis(name) when -is_atom(name)-  # Expected atom server name
    # ... other clauses
```

## Impact on Applications

### Breaking Changes
**None** - This was a bug fix that restored the intended behavior. The public API signatures remain unchanged.

### Testing Impact
- Tests that were failing due to GenServer parameter issues now pass
- Real implementation tests (non-mocked) now work correctly
- UX refinement tests that use actual KeyboardShortcuts and FocusManager now function properly

### Configuration Impact
Applications using configuration overrides for testing (e.g., setting `:focus_manager_impl` or `:keyboard_shortcuts_impl`) now work correctly with both mocked and real implementations.

## Migration Guide

### For Application Developers
**No action required** - This was a bug fix. Your existing code should continue to work as expected, but may work better if it was previously experiencing issues.

### For Test Writers
If you were experiencing test failures related to GenServer parameter errors when using real implementations instead of mocks, these should now be resolved.

**Example test pattern that now works:**
```elixir
test "real implementation test" do
  # Override config to use real implementations
  Application.put_env(:raxol, :focus_manager_impl, Raxol.Core.FocusManager)
  Application.put_env(:raxol, :keyboard_shortcuts_impl, Raxol.Core.KeyboardShortcuts)
  
  # This now works correctly
  FocusManager.register_focusable("my_component", 1)
  KeyboardShortcuts.register_shortcut("Ctrl+S", :save, &my_callback/0)
end
```

## Technical Details

### Architecture Pattern
Both modules follow this pattern:
1. **Public API Module** (`FocusManager`, `KeyboardShortcuts`) - Provides clean, documented interface
2. **GenServer Implementation** (`FocusServer`, `ShortcutsServer`) - Handles state and supervision  
3. **Delegation** - Public API delegates to GenServer with proper parameter passing

### Default Server Names
- `FocusServer` registers itself as `Raxol.Core.FocusManager.FocusServer`
- `ShortcutsServer` registers itself as `Raxol.Core.KeyboardShortcuts.ShortcutsServer`

### Process Supervision
Both servers are supervised and can be restarted if they crash, maintaining system reliability.

## Files Changed

- `lib/raxol/core/focus_manager.ex` - Fixed all delegation calls
- `lib/raxol/core/keyboard_shortcuts.ex` - Fixed all delegation calls  
- `test/raxol/core/ux_refinement_keyboard_test.exs` - Updated to use real implementations

## Verification

You can verify these fixes work by running:

```bash
# Test FocusManager functionality
iex> alias Raxol.Core.FocusManager
iex> FocusManager.register_focusable("test_component", 1)
:ok

# Test KeyboardShortcuts functionality  
iex> alias Raxol.Core.KeyboardShortcuts
iex> KeyboardShortcuts.register_shortcut("Ctrl+T", :test, fn -> IO.puts("Test!") end)
:ok
```

## Related Issues

This fix resolves:
- GenServer parameter mismatching errors
- Test failures when using real implementations
- UX refinement integration issues
- Focus management not working in production scenarios
- Keyboard shortcuts not registering correctly

## Future Considerations

1. **Pattern Consistency** - Ensure all future GenServer delegation follows this pattern
2. **Testing Strategy** - Prefer real implementation tests over mocks where possible
3. **Documentation** - Keep GenServer interface documentation in sync with wrapper modules
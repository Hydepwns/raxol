# **Plan for Next AI Agent: Fix Remaining 10 Test Failures**

## **Current Status**

- ✅ **Successfully Fixed:** Component hierarchy integration, plugin dependency resolution, terminal state management, buffer cache system, terminal channel mocks, **plugin system (all tests passing)**
- ❌ **Remaining:** 10 specific test failures across different components

## **Detailed Failure Analysis & Fix Plan**

### **1. Button Component Event Handling Failures (3 tests)**

**Files:**

- `test/examples/button_test.exs:36` - Unit test click events
- `test/examples/button_test.exs:161` - Integration test button in form interaction
- `test/examples/button_test.exs:185` - Integration test validation errors

**Errors:**

- `** (FunctionClauseError) no function clause matching in Raxol.UI.Components.Input.Button.handle_event/3`
- Button validation errors not being detected properly

**Root Cause:** The Button component's `handle_event/3` function doesn't have a clause for `:click` events with data, only for `:click` events without data.

**Fix Strategy:**

1. Update `Button.handle_event/3` to handle `:click` events with data
2. Fix validation error detection for invalid button roles
3. Ensure click events work in both unit and integration tests

**Files to examine:**

- `lib/raxol/ui/components/input/button.ex`
- `test/examples/button_test.exs`

---

### **2. Column Width Mode Test Failure**

**File:** `test/raxol/terminal/commands/mode_handlers_test.exs:127`
**Error:** `assert res_set_132.mode_manager.column_width_mode == :wide` (getting `:normal` instead of `:wide`)

**Root Cause:** The column width mode is not being set correctly when calling `ModeHandlers.handle_h_or_l/4` with mode `3` and `?h`.

**Fix Strategy:**

1. Check `ModeHandlers.handle_h_or_l/4` implementation
2. Verify the mode mapping from `3` to `:deccolm_132`
3. Ensure `ModeManager.set_mode/3` correctly updates `column_width_mode` field
4. Check if the mode handler is being called in the correct order

**Files to examine:**

- `lib/raxol/terminal/commands/mode_handlers.ex`
- `lib/raxol/terminal/mode_manager.ex`
- `lib/raxol/terminal/modes/handlers/dec_private_handler.ex`

---

### **3. Cursor Management Test Failures (2 tests)**

**Files:**

- `test/raxol/terminal/emulator/cursor_management_test.exs:14`
- `test/raxol/terminal/emulator/cursor_management_test.exs:39`

**Errors:**

- `key :style not found in: #PID<0.7433.0>`
- `key :state not found in: #PID<0.7424.0>`

**Root Cause:** Tests are expecting cursor to be a struct with `:style` and `:state` fields, but it's a PID (process).

**Fix Strategy:**

1. Check `Emulator.set_cursor_style/2` and `Emulator.set_cursor_visible/2` implementations
2. Determine if cursor should be a struct or a process
3. Update tests to match the actual implementation
4. Check if cursor manager is being initialized correctly

**Files to examine:**

- `lib/raxol/terminal/emulator.ex`
- `lib/raxol/terminal/cursor/manager.ex`
- `test/raxol/terminal/emulator/cursor_management_test.exs`

---

### **4. EventSource Test Failures (3 tests)**

**File:** `test/raxol/core/runtime/event_source_test.exs`

**Errors:**

- Start/stop behavior issues
- Return value mismatches (`:ok` vs `{:ok, pid}`)
- Initialization failures

**Root Cause:** EventSource behaviour implementation doesn't match test expectations.

**Fix Strategy:**

1. Review `Raxol.Core.Runtime.EventSource` behaviour definition
2. Check `TestEventSource` implementation
3. Ensure start_link returns `{:ok, pid}` not `:ok`
4. Fix initialization and termination callbacks
5. Verify event sending mechanism

**Files to examine:**

- `lib/raxol/core/runtime/event_source.ex`
- `test/raxol/core/runtime/event_source_test.exs`

---

### **5. Driver Resize Event Test Failures (2 tests)**

**File:** `test/raxol/terminal/driver/resize_event_test.exs`

**Errors:**

- `assert_receive {:resize, _expected_width, _expected_height}` failing
- No resize messages being sent

**Root Cause:** Resize event handling in driver is not working correctly.

**Fix Strategy:**

1. Check `Raxol.Terminal.Driver` resize event handling
2. Verify termbox event parsing for resize events
3. Ensure resize messages are being sent to the correct process
4. Check if driver is properly initialized in tests

**Files to examine:**

- `lib/raxol/terminal/driver.ex`
- `test/raxol/terminal/driver/resize_event_test.exs`
- `test/support/driver_test_helper.ex`

---

## **Recommended Approach**

### **Priority Order:**

1. **High Priority:** Button component event handling (affects UI functionality)
2. **High Priority:** Column width mode test (affects terminal functionality)
3. **Medium Priority:** Cursor management tests (affects user experience)
4. **Medium Priority:** EventSource tests (affects core runtime)
5. **Lower Priority:** Driver resize tests (affects window management)

### **Testing Strategy:**

1. Run individual failing tests to isolate issues
2. Use `--trace` flag for detailed error information
3. Add debug output to understand data flow
4. Fix one category at a time and re-run full suite

### **Common Patterns to Look For:**

- **Event handling mismatches:** Button component expects different event formats
- **Struct vs Process mismatches:** Cursor tests expecting structs but getting PIDs
- **Return value inconsistencies:** Functions returning `:ok` instead of `{:ok, result}`
- **Mode/state synchronization:** Column width mode not propagating correctly
- **Event handling:** Messages not being sent or received properly

### **Success Criteria:**

- All 10 failing tests pass
- No regressions in previously fixed tests (especially plugin system)
- Full test suite passes with `mix test`

---

## **Quick Commands for Next Agent:**

```bash
# Run specific failing tests
mix test test/examples/button_test.exs --trace
mix test test/raxol/terminal/commands/mode_handlers_test.exs:127 --trace
mix test test/raxol/terminal/emulator/cursor_management_test.exs --trace
mix test test/raxol/core/runtime/event_source_test.exs --trace
mix test test/raxol/terminal/driver/resize_event_test.exs --trace

# Check current status
mix test --max-failures=10

# Run full suite after fixes
mix test
```

## **Key Files to Focus On:**

### **Button Component:**

- `lib/raxol/ui/components/input/button.ex`
- `test/examples/button_test.exs`

### **Mode Handlers:**

- `lib/raxol/terminal/commands/mode_handlers.ex`
- `lib/raxol/terminal/mode_manager.ex`

### **Cursor Management:**

- `lib/raxol/terminal/emulator.ex`
- `lib/raxol/terminal/cursor/manager.ex`
- `test/raxol/terminal/emulator/cursor_management_test.exs`

### **EventSource:**

- `lib/raxol/core/runtime/event_source.ex`
- `test/raxol/core/runtime/event_source_test.exs`

### **Driver:**

- `lib/raxol/terminal/driver.ex`
- `test/raxol/terminal/driver/resize_event_test.exs`

---

## **Expected Outcomes:**

After implementing these fixes, the next AI agent should achieve:

1. **Button component working correctly** - Click events and validation work in both unit and integration tests
2. **Column width mode working correctly** - Terminal properly switches between 80/132 column modes
3. **Cursor management functioning** - Cursor style and visibility changes work as expected
4. **EventSource behavior consistent** - Start/stop and event sending work properly
5. **Driver resize events working** - Window resize events are properly handled and dispatched

## **Major Achievement:**

✅ **Plugin System Completely Fixed** - All plugin tests are now passing (67 tests), including:

- Plugin lifecycle (init, cleanup, enable/disable)
- Plugin output transformation (hyperlink plugin transforms URLs correctly)
- Plugin input processing
- Plugin dependencies
- Theme, Search, Image, and Hyperlink plugins all working correctly

This plan provides a clear roadmap for the next AI agent to systematically address the remaining 10 test failures while maintaining the stability we've achieved, especially the fully functional plugin system.

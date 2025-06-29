# Raxol Compilation Error Resolution Plan

## 📊 Current State Analysis (Latest Run)

- **Total Compilation Warnings**: 576
- **Undefined Functions**: 91
- **Missing @impl Annotations**: 63
- **Unused Variables**: 141
- **Other Issues**: ~281 (duplicate definitions, unused aliases, etc.)

## 🎯 Priority Order for Resolution

### **Phase 1: Critical Behaviour/Implementation Issues (63 issues)**

#### **1.1 Fix Raxol.Terminal.Cursor.Style Behaviour**

**Issue**: Module defines itself as behaviour but missing callbacks for `blink/1` and `get_style/1`

**Files to Fix**:

- `lib/raxol/terminal/cursor/style.ex`

**Action**: Add missing callbacks to behaviour definition:

```elixir
@callback blink(cursor :: Raxol.Terminal.Cursor.Manager.t()) ::
            Raxol.Terminal.Cursor.Manager.t()
@callback get_style(cursor :: Raxol.Terminal.Cursor.Manager.t()) :: atom()
```

#### **1.2 Fix ScreenBufferBehaviour @impl Issues**

**Issue**: 63 missing `@impl` annotations in ScreenBuffer module

**Files to Fix**:

- `lib/raxol/terminal/screen_buffer.ex`

**Action**: Add `@impl Raxol.Terminal.ScreenBufferBehaviour` before each callback function

**Functions needing @impl**:

- `apply_single_shift/2`
- `attribute_set?/2`
- `clear_line/2`
- `clear_scroll_region/1`
- `designate_charset/3`
- `empty?/1`
- `erase_all/1`
- `erase_from_cursor_to_end/1`
- `get_background/1`
- `get_cell/3`
- `get_char/3`
- `get_current_g_set/1`
- `get_designated_charset/2`
- `get_dimensions/1`
- `get_foreground/1`
- `get_height/1`
- `get_scroll_position/1`
- `get_scroll_region_boundaries/1`
- `get_set_attributes/1`
- `get_single_shift/1`
- `get_style/1`
- `get_width/1`
- `invoke_g_set/2`
- `new/2`
- `reset_all_attributes/1`
- `reset_attribute/2`
- `scroll_down/2`
- `scroll_up/2`
- `set_attribute/2`
- `set_background/2`
- `set_foreground/2`
- `set_scroll_region/3`
- `update_style/2`
- `write_char/5`
- `write_string/5`

### **Phase 2: Undefined Functions (91 issues)**

#### **2.1 Terminal Commands System**

**Files to Fix**:

- `lib/raxol/terminal/commands/executor.ex`
- `lib/raxol/terminal/commands/parser.ex`

**Missing Functions**:

- `Raxol.Terminal.Commands.Executor.execute_dcs_command/5`
- `Raxol.Terminal.Commands.Executor.execute_dcs_command/3`
- `Raxol.Terminal.Commands.Executor.execute_osc_command/3`
- `Raxol.Terminal.Commands.Parser.parse/1`

#### **2.2 Terminal Emulator Functions**

**Files to Fix**:

- `lib/raxol/terminal/emulator.ex`

**Missing Functions**:

- `Raxol.Terminal.Emulator.clear_scrollback/1`
- `Raxol.Terminal.Emulator.set_attribute/2`

#### **2.3 Buffer Operations**

**Files to Fix**:

- `lib/raxol/terminal/buffer/line_operations.ex`
- `lib/raxol/terminal/buffer/operations.ex`
- `lib/raxol/terminal/buffer/scroll_region.ex`

**Missing Functions**:

- `Raxol.Terminal.Buffer.LineOperations.delete_chars/2`
- `Raxol.Terminal.Buffer.LineOperations.insert_chars/2`
- `Raxol.Terminal.Buffer.Operations.delete_lines/5`
- `Raxol.Terminal.Buffer.Operations.insert_lines/5`
- `Raxol.Terminal.Buffer.ScrollRegion.get_scroll_bottom/1`
- `Raxol.Terminal.Buffer.ScrollRegion.get_scroll_top/1`

#### **2.4 Screen Buffer Core**

**Files to Fix**:

- `lib/raxol/terminal/screen_buffer/core.ex`

**Missing Functions**:

- `Raxol.Terminal.ScreenBuffer.Core.clear_damaged_regions/1`
- `Raxol.Terminal.ScreenBuffer.Core.delete_chars/4`
- `Raxol.Terminal.ScreenBuffer.Core.erase_display/5`
- `Raxol.Terminal.ScreenBuffer.Core.erase_line/5`
- `Raxol.Terminal.ScreenBuffer.Core.get_damaged_regions/1`
- `Raxol.Terminal.ScreenBuffer.Core.get_scrollback/1`
- `Raxol.Terminal.ScreenBuffer.Core.insert_chars/4`
- `Raxol.Terminal.ScreenBuffer.Core.mark_damaged/6`
- `Raxol.Terminal.ScreenBuffer.Core.set_dimensions/3`
- `Raxol.Terminal.ScreenBuffer.Core.set_scrollback/2`

#### **2.5 Test Support Functions**

**Files to Fix**:

- `test/support/test_helper.ex`

**Missing Functions**:

- `Raxol.Test.Support.TestHelper.cleanup_test_env/1`
- `Raxol.Test.Support.TestHelper.create_test_emulator/0`
- `Raxol.Test.Support.TestHelper.create_test_plugin/2`
- `Raxol.Test.Support.TestHelper.create_test_plugin_module/2`
- `Raxol.Test.Support.TestHelper.setup_common_mocks/0`

#### **2.6 Other System Functions**

**Files to Fix**:

- `lib/raxol/core/user_preferences.ex`
- `lib/raxol/system/updater.ex`

**Missing Functions**:

- `Raxol.Core.UserPreferences.set_preferences/1`
- `Raxol.System.Updater.default_update_settings/0`

### **Phase 3: Unused Variables (141 issues)**

#### **3.1 Systematic Variable Cleanup**

**Pattern**: Prefix unused variables with underscore (`_variable`)

**Common Patterns to Fix**:

- `variable "count" is unused`
- `variable "config" is unused`
- `variable "window_config" is unused`
- `variable "tab_config" is unused`

**Files to Check**:

- All files with unused variable warnings

### **Phase 4: Duplicate Function Definitions**

#### **4.1 Fix Duplicate Function Clauses**

**Files to Fix**:

- `lib/raxol/terminal/buffer/char_editor.ex`
- `lib/raxol/test/unit.ex`

**Issues**:

- `def insert_chars/4` - multiple definitions
- `def delete_chars/4` - multiple definitions
- `def erase_chars/4` - multiple definitions
- `def erase_chars/5` - multiple definitions
- `def simulate_event/2` - multiple definitions

**Action**: Group function clauses together or remove duplicates

### **Phase 5: Unused Aliases and Imports**

#### **5.1 Remove Unused Aliases**

**Common Issues**:

- `unused alias Application`
- `unused alias Operations`
- `unused alias Theme`
- `unused alias EmulatorStruct`

**Action**: Remove unused aliases or use them

#### **5.2 Fix Unused Imports**

**Issues**:

- `unused import Raxol.Guards`

**Action**: Remove unused imports

### **Phase 6: Behaviour Conflicts**

#### **6.1 Fix GenServer Behaviour Conflicts**

**Files to Fix**:

- `lib/raxol/terminal/graphics/unified_graphics.ex`

**Issue**: `the behaviour GenServer has been declared twice`

**Action**: Remove duplicate `use GenServer` or `@behaviour GenServer` declarations

## 🔧 Implementation Strategy

### **Step 1: Start with Behaviour Issues**

1. Fix `Raxol.Terminal.Cursor.Style` missing callbacks
2. Add all missing `@impl` annotations to ScreenBuffer
3. Verify behaviour implementations are complete

### **Step 2: Implement Missing Functions**

1. Start with most critical functions (terminal commands)
2. Implement test support functions
3. Add buffer operation functions
4. Complete screen buffer core functions

### **Step 3: Clean Up Variables and Imports**

1. Prefix unused variables with underscore
2. Remove unused aliases and imports
3. Fix duplicate function definitions

### **Step 4: Verify and Test**

1. Run `mix compile` after each batch
2. Run tests to ensure no regressions
3. Document any new patterns discovered

## 📝 Success Metrics

**Target Goals**:

- **Phase 1**: Reduce missing @impl from 63 to 0
- **Phase 2**: Reduce undefined functions from 91 to <20
- **Phase 3**: Reduce unused variables from 141 to <30
- **Phase 4**: Eliminate all duplicate function definitions
- **Phase 5**: Remove all unused aliases and imports
- **Phase 6**: Fix all behaviour conflicts

**Overall Target**: Reduce total compilation warnings from 576 to <100

## 🛠️ Tools and Commands

### **Analysis Commands**:

```bash
# Get current warning count
mix compile 2>&1 | grep -c "warning:"

# Count specific issue types
mix compile 2>&1 | grep -c "is undefined or private"
mix compile 2>&1 | grep -c "module attribute @impl was not set"
mix compile 2>&1 | grep -c "variable.*is unused"

# Get specific error details
mix compile 2>&1 | grep "is undefined or private" | head -20
```

### **Testing Commands**:

```bash
# Test compilation
mix compile

# Run tests after fixes
mix test --max-failures=0
```

## 🚨 Critical Notes

1. **Start with Phase 1** - Behaviour issues are foundational
2. **Fix incrementally** - Don't try to fix all 576 warnings at once
3. **Test after each batch** - Ensure no regressions
4. **Document patterns** - Note common fixes for similar issues
5. **Preserve functionality** - Don't remove code that might be needed

## 📋 Next Agent Checklist

- [ ] Run `mix compile` to get current state
- [ ] Start with Phase 1 (Behaviour issues)
- [ ] Fix `Raxol.Terminal.Cursor.Style` missing callbacks
- [ ] Add missing `@impl` annotations to ScreenBuffer
- [ ] Implement critical missing functions
- [ ] Clean up unused variables systematically
- [ ] Fix duplicate function definitions
- [ ] Remove unused aliases and imports
- [ ] Test after each phase
- [ ] Document progress and any new patterns discovered

This plan provides a systematic approach to reducing compilation errors while maintaining code quality and functionality.

# Next AI Agent Plan - Remaining Test Failures Resolution

## **Current Status Summary (Updated July 2025)**

### **✅ COMPLETED WORK:**

- **✅ Large File Refactoring**: All 18 large files successfully refactored (100% completion)
- **✅ Coordinate System Standardization**: All 30 cursor-related test failures resolved (100% completion)
- **✅ Test Success Rate**: Improved from 70 to 10 test failures (85.7% improvement)

### **Current Test Status:**

- **Overall**: 10 test failures out of 1670 tests (99.4% passing)
- **Goal**: Achieve 100% test success rate

## **🔴 REMAINING: Test Failures to Address (10 failures)**

### **Priority 1: Sixel Graphics State Missing (HIGH PRIORITY)**

**File**: `lib/raxol/terminal/commands/dcs_handlers.ex:223`
**Test**: `test handle_dcs/5 - Sixel Graphics processes a simple Sixel sequence`
**Issue**: `** (KeyError) key :sixel not found`

**Action Plan**:

1. Check emulator initialization for sixel state
2. Ensure sixel state is properly initialized in `DCSHandlers.handle_dcs/5`
3. Verify sixel state is maintained throughout the emulator lifecycle

### **Priority 2: Buffer Server Process Management (HIGH PRIORITY)**

**Test 1**: `test error handling handles server shutdown gracefully`
**Issue**: `** (EXIT) no process: the process is not alive or there's no process currently associated with the given name`

**Test 2**: `test get_cell/3 returns cached cell after set`
**Issue**: Cell style mismatch - expected `nil` but got `%Raxol.Terminal.ANSI.TextFormatting.Core{}`

**Action Plan**:

1. Fix buffer server process lifecycle management
2. Ensure proper process cleanup on shutdown
3. Fix cell style initialization and caching logic

### **Priority 3: Cache System TTL Logic (MEDIUM PRIORITY)**

**Test**: `test TTL operations expired entry`
**Issue**: Expected `{:error, :expired}` but got `{:ok, "test_value"}`

**Action Plan**:

1. Review cache TTL implementation
2. Fix expiration logic in cache system
3. Ensure proper time-based cleanup

### **Priority 4: Auto-repeat Mode Management (MEDIUM PRIORITY)**

**Test**: `test auto-repeat mode auto-repeat mode is saved and restored when switching screen modes`
**Issue**: Mode state not properly maintained during screen mode switches

**Action Plan**:

1. Fix mode manager state preservation
2. Ensure auto-repeat mode is properly saved/restored
3. Verify mode transitions maintain state correctly

### **Priority 5: Cursor Movement Tab Stops (MEDIUM PRIORITY)**

**Test**: `test Cursor Movement move_to_prev_tab moves cursor to previous tab stop`
**Issue**: Expected `{8, 0}` but got `{0, 10}` - still has coordinate system issue

**Action Plan**:

1. Check if this test was missed in coordinate system fixes
2. Verify tab stop logic uses correct coordinate format
3. Update test or fix implementation as needed

### **Priority 6: Column Width Mode Changes (MEDIUM PRIORITY)**

**Test 1**: `test column width changes switching to 132-column mode`
**Test 2**: `test column width changes switching back to 80-column mode`
**Test 3**: `test column width changes screen clearing on column width change`

**Issues**: Screen buffer width not updating correctly, screen not clearing properly

**Action Plan**:

1. Fix column width mode switching logic
2. Ensure screen buffer resizes correctly
3. Fix screen clearing on mode changes

## **Next Agent Priority Order**

### **Phase 1: Critical Test Failures (HIGH PRIORITY)**

1. **CRITICAL**: Fix Sixel graphics state initialization

   - **Action**: Ensure sixel state is properly initialized in emulator
   - **Files**: `lib/raxol/terminal/commands/dcs_handlers.ex`, `lib/raxol/terminal/emulator.ex`
   - **Expected Impact**: Fix 1 test failure

2. **CRITICAL**: Fix buffer server process management
   - **Action**: Fix process lifecycle and cell caching issues
   - **Files**: `lib/raxol/terminal/buffer/buffer_server_refactored.ex`
   - **Expected Impact**: Fix 2 test failures

### **Phase 2: System Logic Fixes (MEDIUM PRIORITY)**

3. **MEDIUM**: Fix cache TTL logic

   - **Action**: Fix expiration logic in cache system
   - **Files**: Cache-related modules
   - **Expected Impact**: Fix 1 test failure

4. **MEDIUM**: Fix auto-repeat mode management

   - **Action**: Fix mode state preservation during screen switches
   - **Files**: Mode manager modules
   - **Expected Impact**: Fix 1 test failure

5. **MEDIUM**: Fix remaining cursor movement issue

   - **Action**: Check tab stop logic for coordinate system consistency
   - **Files**: Cursor movement modules
   - **Expected Impact**: Fix 1 test failure

6. **MEDIUM**: Fix column width mode changes
   - **Action**: Fix screen buffer resizing and clearing on mode changes
   - **Files**: Screen buffer and column width modules
   - **Expected Impact**: Fix 3 test failures

### **Phase 3: Code Quality Improvements (LOW PRIORITY)**

7. **LOW**: Clean up remaining undefined function warnings

   - **Action**: Implement missing functions or fix function references
   - **Files**: Various modules with undefined function warnings
   - **Expected Impact**: Fix 36 undefined function warnings

8. **LOW**: Clean up unused variables and imports
   - **Action**: Remove or prefix unused variables with underscore
   - **Files**: Various test and source files
   - **Expected Impact**: Fix 172 unused variable warnings

## **Success Metrics**

### **Target Goals:**

- **Test Success Rate**: 100% (0 failures out of 1670 tests)
- **Code Quality**: Eliminate all undefined function warnings
- **Maintainability**: Clean up unused variables and imports

### **Current Progress:**

- **Test Success Rate**: 99.4% (10 failures out of 1670 tests)
- **Improvement**: 60 test failures resolved (85.7% improvement)

## **Handoff to Next Agent**

The next agent should focus on systematically addressing the remaining 10 test failures in priority order:

1. **Start with Phase 1** (Critical failures) - Sixel graphics and buffer server issues
2. **Move to Phase 2** (System logic) - Cache TTL, mode management, column width
3. **Finish with Phase 3** (Code quality) - Clean up warnings and unused code

Each fix should be tested individually to ensure no regressions are introduced. The goal is to achieve 100% test success rate while maintaining code quality and performance.

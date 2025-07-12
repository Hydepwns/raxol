# Next AI Agent Plan - Test Failure Resolution

## **Current Status Summary**

- ✅ **Fixed**: MultiLineInput TextHelper (major text manipulation bugs)
- ✅ **Fixed**: Table column width calculation (empty data handling)
- ✅ **Fixed**: CursorHandlers coordinate system and movement
- ✅ **Fixed**: EraseHandlers (buffer operations and cursor position)
- ✅ **Fixed**: MultiLineInput NavigationHelper cursor movement

## **Remaining Test Failures (10 total)**

### **1. TreeDiffer Tests (4 failures) - HIGH PRIORITY**

**Location**: `test/raxol/core/tree_differ_test.exs`
**Issues**:

- Keyed tree diffing operations failing
- Order of operations in diff results incorrect
- Likely algorithmic issues in the diffing logic

**Action Plan**:

1. Review the failing TreeDiffer test cases
2. Examine the `TreeDiffer` implementation in `lib/raxol/core/tree_differ.ex`
3. Fix the diffing algorithm to handle keyed operations correctly
4. Ensure proper ordering of diff operations

### **2. Table Rendering Tests (2 failures) - MEDIUM PRIORITY**

**Location**: `test/raxol/ui/renderer_test.exs`
**Issues**:

- Table rendering returns empty or nil cells
- Theme styles not applied correctly to table headers and data rows

**Action Plan**:

1. Review the table rendering implementation
2. Check if the renderer is properly extracting data from table components
3. Fix theme application logic for table headers and data rows
4. Ensure proper cell content rendering

### **3. Graphics Manager Test (1 failure) - MEDIUM PRIORITY**

**Location**: `test/raxol/terminal/graphics/manager_test.exs`
**Issue**: KeyError with `:r` key in color maps

**Action Plan**:

1. Examine the Graphics Manager implementation
2. Check color map initialization and access patterns
3. Fix the missing `:r` key in color maps
4. Ensure proper color system initialization

### **4. Component Rendering Test (1 failure) - LOW PRIORITY**

**Location**: `test/raxol/ui/components/box_test.exs`
**Issue**: Box component rendering issue

**Action Plan**:

1. Review the Box component implementation
2. Check rendering logic and output format
3. Fix any rendering bugs in the Box component

### **5. MultiLineInput TextHelper Tests (2 failures) - LOW PRIORITY**

**Location**: `test/raxol/components/input/multi_line_input/text_helper_test.exs`
**Issues**: Remaining text replacement and deletion edge cases

**Action Plan**:

1. Review the specific failing test cases
2. Apply similar fixes as the previous TextHelper issues
3. Ensure multi-line text handling is fully correct

## **Recommended Approach for Next Agent**

### **Phase 1: TreeDiffer (Most Critical)**

1. Run `mix test test/raxol/core/tree_differ_test.exs` to see specific failures
2. Use `./scripts/summarize_test_errors.sh` to get detailed error information
3. Examine the TreeDiffer implementation and fix the diffing algorithm
4. This is likely the most complex remaining issue

### **Phase 2: Table Rendering**

1. Run `mix test test/raxol/ui/renderer_test.exs` to see table-specific failures
2. Review the renderer implementation for table handling
3. Fix data extraction and theme application issues

### **Phase 3: Graphics Manager**

1. Run `mix test test/raxol/terminal/graphics/manager_test.exs`
2. Fix the color map initialization issue
3. Ensure proper color system setup

### **Phase 4: Remaining Issues**

1. Address the Box component rendering issue
2. Fix any remaining TextHelper edge cases
3. Run full test suite to verify all fixes

## **Key Tools and Commands**

- `mix test` - Run full test suite
- `./scripts/summarize_test_errors.sh` - Get detailed error summary
- `mix test <specific_test_file> --trace` - Run specific tests with detailed output
- Use the existing debug patterns we established for troubleshooting

## **Debug Patterns Established**

- Add `require Logger` and `Logger.debug()` statements for diagnosing cursor movement issues
- Use `Map.get(state, :key, default)` vs `state.key || default` for proper nil handling
- Check both `state.lines` and `TextHelper.split_into_lines()` for line source of truth
- Verify coordinate systems (0-indexed vs 1-indexed) in test expectations

## **Success Criteria**

- All 636 tests passing
- No critical functionality broken
- Clean test output with no failures

## **Context from Previous Work**

The previous agent successfully fixed:

1. **TextHelper**: Fixed `replace_text_range/4` to use exclusive end positions for `replaced_text` calculation while keeping inclusive end positions for replacement logic
2. **NavigationHelper**: Fixed `desired_col` fallback logic from `Map.get(state, :desired_col, col)` to `state.desired_col || col` to properly handle nil values
3. **Cursor/Erase Handlers**: Fixed coordinate systems and buffer operations
4. **Table Column Width**: Fixed empty data handling in column width calculations

The next agent should start with the TreeDiffer tests as they appear to be the most complex remaining issue and likely require algorithmic fixes rather than simple coordinate or logic corrections.

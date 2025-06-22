# Raxol Testing Plan

## Test Environments

- **VS Code Extension Mode**: Using the extension in Debug mode
- **Native Terminal Mode**: Using `run_native_terminal.sh` script

## Test Assertions Framework

Each test should record:

- **Expected Behavior**: Clear statement of what should happen
- **Actual Behavior**: What actually happened
- **Pass/Fail Status**: Explicit marking
- **Severity**: For failures (Critical, Major, Minor)
- **Screenshots**: Where applicable

## Logging Configuration

### VS Code Extension Tests

```typescript
// Add to extension.ts
const LOG_LEVEL = "debug"; // Options: debug, info, warn, error
```

### Native Terminal Tests

```elixir
# Add to config/test.exs
config :raxol, :debug_mode, true
```

## Test Results Template

```
# Test Case: [ID] - [Short Description]
- **Environment**: [VS Code | Native Terminal]
- **Test Date**: YYYY-MM-DD
- **Tester**: [Name]

## Setup
[Describe any special setup required]

## Steps
1. [Step 1]
2. [Step 2]
...

## Expected Results
[What should happen]

## Actual Results
[What actually happened]

## Status
[PASS | FAIL]

## Notes
[Additional observations, performance metrics, etc.]

## Screenshots/Logs
[Attach or link relevant files]
```

## Test Categories

### Current Major Test Failures (as of 2025-04-19 - Please Update Date)

Based on the test run on [Insert Date Here], the following modules have significant failures:

- `Raxol.Style.Colors.UtilitiesTest` (Multiple failures, investigation details below):
  - **Doctest `UndefinedFunctionError`**: Likely due to missing `alias Raxol.Style.Colors.Utilities` _before_ examples in the main `@moduledoc` of `utilities.ex`. Attempted fix was unsuccessful due to apply errors (the automated edit tool had difficulty inserting the `alias` correctly within the multi-line `@moduledoc` block).
  - **`readable?/3` (vs `readable?`)**: The function is public and named `readable?`. The plan's note about potential privacy (`readable?`) was incorrect.
  - **`Accessibility.check_contrast`**: Was called with incorrect arity (2 vs 4, although defaults exist) in `darken/lighten_until_contrast` tests. Added missing `alias Raxol.Style.Colors.Accessibility` and corrected calls in `utilities_test.exs`.
  - \*\*Specific Test/Doctest Failures (9 total from `mix test test/raxol/style/colors/utilities_test.exs` run):
    - `lighten_until_contrast`: Fails to lighten color (returns original hex `#777777` instead of expected `#CCCCCC`), both in tests and doctest. Potentially due to stream/Enum.find logic needing adjustment (e.g., `Stream.drop(1)`).
    - `relative_luminance`: Fails for gray (`#808080`) due to minor floating-point differences. Suggest using `assert_in_delta`.
    - `contrast_ratio`: Doctest fails for `#777777`/`#999999` (expected `1.3`, got `~1.57`). Test for mixed types (`String`/`Color` struct) fails (expected `21.0`, got `1.0`), suggesting input normalization issue.
    - `darken_until_contrast`: Doctest fails (expected `"#595959"`, got `"#6D6D6D"`), indicating calculation might be slightly off.
    - `lighten/darken_until_contrast` (Return Type): Tests checking return type when contrast is already sufficient failed initially (expecting hex string, got `%Color{}` struct). Automated fixes _may_ have resolved this by adding `Color.to_hex()` calls, but subsequent compilation errors prevented confirmation.
  - **File State**: Encountered significant issues applying automated edits to `lib/raxol/style/colors/utilities.ex`. The file might be in an inconsistent state. Recommend `git restore` before resuming work on this module.
- `Raxol.ApplicationTest` (missing `put_env/3`, theme validation errors)

### 1. Basic Functionality Tests

- Application startup
- UI rendering
- Keyboard input processing
- Basic widget interaction
- Application termination

### 2. Visualization Component Tests

- Bar chart rendering
- Treemap rendering
- Color handling
- Label rendering
- Scaling/alignment

### 3. Layout Tests

- Widget positioning
- Layout persistence
- Layout loading
- Widget resizing

### 4. Edge Case Tests

- **Empty Data Sets**
  - Bar charts with no data
  - Treemaps with empty nodes
- **Large Data Sets**
  - Bar charts with 100+ items
  - Deeply nested treemaps (5+ levels)
- **Display Constraints**
  - Extremely small terminal (20x10)
  - Very large terminal (200x50)
  - Visualization in 1-line height widget
- **Dynamic Resizing**
  - Rapid window resizing
  - Resize during data loading
  - Resize during rendering

### 5. Data Variation Tests

- **Value Types**
  - Negative values in charts
  - Zero values in visualizations
  - Very large values (>1,000,000)
  - Very small values (<0.001)
- **Text Handling**
  - Long labels
  - Unicode/emoji in labels
  - Multi-line text

### 6. Cross-Environment Comparison

- **Visual Comparison**
  - Side-by-side screenshots of same view
  - Character/color alignment verification
- **Feature Parity**
  - Checklist of features working in both environments
  - Differences in behavior documented

### 7. Cleanup Verification

- **Resource Monitoring**
  - Memory usage before/after tests
  - File handle count before/after
  - Process count verification
- **Terminal State**
  - Terminal restoration after exit
  - Cursor position reset
  - Color attributes reset

### 8. Performance Tests

- **Render Timing**
  - Time to first meaningful render
  - Render time for complex visualizations
  - Refresh rate during data updates
- **Resource Usage**
  - CPU usage during operation
  - Memory consumption patterns
  - I/O operations during rendering

## Test Scripts

### VS Code Extension Test Script

```bash
#!/bin/bash
# vs_code_test.sh

echo "Starting VS Code Extension Test at $(date)"
echo "OS: $(uname -a)"

# Launch VS Code with extension in debug mode
code --extensionDevelopmentPath=/path/to/raxol/extensions/vscode .

# Tester manual checklist - verify these items
cat << EOF
Manual Test Checklist:
1. Extension activates without errors
2. Panel opens with raxol.showTerminal command
3. UI renders correctly
4. Input events processed correctly
5. Resizing updates UI properly
6. All visualizations display correctly
7. Application exits cleanly with Ctrl+C
EOF

# Timing template
echo "Test completed at $(date)"
echo "Results recorded in test_results/vscode_$(date +%Y%m%d_%H%M%S).md"
```

### Native Terminal Test Script

```bash
#!/bin/bash
# native_terminal_test.sh

echo "Starting Native Terminal Test at $(date)"
echo "OS: $(uname -a)"
echo "Terminal: $TERM"
echo "Dimensions: $(stty size)"

# Record memory usage before
echo "Memory before: $(ps -o rss= -p $$) KB"
```

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
config :logger,
  level: :debug,
  backends: [:console],
  compile_time_purge_matching: [
    [level_lower_than: :debug]
  ]
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

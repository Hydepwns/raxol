#!/bin/bash
# native_terminal_test.sh

echo "Starting Native Terminal Test at $(date)"
echo "OS: $(uname -a)"
echo "Terminal: $TERM"
echo "Dimensions: $(stty size)"

# Create results directory if it doesn't exist
mkdir -p test_results

# Generate results file
RESULTS_FILE="test_results/terminal_$(date +%Y%m%d_%H%M%S).md"

# Write header to results file
cat > "$RESULTS_FILE" << EOF
# Native Terminal Test Results
- **Test Date**: $(date +%Y-%m-%d)
- **OS**: $(uname -a)
- **Terminal**: $TERM
- **Dimensions**: $(stty size)

## Test Environment
- Native Terminal Mode
EOF

# Record memory usage before
MEMORY_BEFORE=$(ps -o rss= -p $$ 2>/dev/null || echo "N/A")
echo "Memory before: $MEMORY_BEFORE KB"
echo "- **Memory Before**: $MEMORY_BEFORE KB" >> "$RESULTS_FILE"

# Count open file descriptors before
FD_BEFORE=$(lsof -p $$ 2>/dev/null | wc -l || echo "N/A")
echo "File descriptors before: $FD_BEFORE"
echo "- **File Descriptors Before**: $FD_BEFORE" >> "$RESULTS_FILE"

# Launch application
echo "Launching application..."
START_TIME=$(date +%s)
./run_native_terminal.sh &
APP_PID=$!

# Write PID to results
echo "- **Application PID**: $APP_PID" >> "$RESULTS_FILE"

# Wait for startup
sleep 2

# Tester manual checklist
cat << EOF
Manual Test Checklist:
1. Application started without errors
2. UI renders correctly with proper dimensions
3. Input events processed correctly
4. All visualizations display properly
5. Application exits cleanly with Ctrl+C

When finished testing, please complete the results in:
$RESULTS_FILE
EOF

# Wait for tester to complete tests
read -p "Press enter when testing is complete..."

# Calculate runtime
END_TIME=$(date +%s)
RUNTIME=$((END_TIME - START_TIME))
echo "Runtime: $RUNTIME seconds"
echo "- **Runtime**: $RUNTIME seconds" >> "$RESULTS_FILE"

# Check if process is still running
if ps -p $APP_PID > /dev/null 2>&1; then
  echo "WARNING: Application still running. Killing process..."
  echo "- **Clean Exit**: No (process had to be killed)" >> "$RESULTS_FILE"
  kill $APP_PID
  sleep 1
  # Force kill if still running
  if ps -p $APP_PID > /dev/null 2>&1; then
    echo "WARNING: Process did not terminate with SIGTERM, using SIGKILL..."
    kill -9 $APP_PID
    echo "- **Force Kill Required**: Yes" >> "$RESULTS_FILE"
  fi
else
  echo "Application exited cleanly."
  echo "- **Clean Exit**: Yes" >> "$RESULTS_FILE"
fi

# Record memory usage after
MEMORY_AFTER=$(ps -o rss= -p $$ 2>/dev/null || echo "N/A")
echo "Memory after: $MEMORY_AFTER KB"
echo "- **Memory After**: $MEMORY_AFTER KB" >> "$RESULTS_FILE"

# Count open file descriptors after
FD_AFTER=$(lsof -p $$ 2>/dev/null | wc -l || echo "N/A")
echo "File descriptors after: $FD_AFTER"
echo "- **File Descriptors After**: $FD_AFTER" >> "$RESULTS_FILE"

# Memory difference
if [[ "$MEMORY_BEFORE" != "N/A" && "$MEMORY_AFTER" != "N/A" ]]; then
  MEMORY_DIFF=$((MEMORY_AFTER - MEMORY_BEFORE))
  echo "Memory difference: $MEMORY_DIFF KB"
  echo "- **Memory Difference**: $MEMORY_DIFF KB" >> "$RESULTS_FILE"
fi

# File descriptor difference
if [[ "$FD_BEFORE" != "N/A" && "$FD_AFTER" != "N/A" ]]; then
  FD_DIFF=$((FD_AFTER - FD_BEFORE))
  echo "File descriptor difference: $FD_DIFF"
  echo "- **File Descriptor Difference**: $FD_DIFF" >> "$RESULTS_FILE"
fi

echo "Test completed at $(date)"
echo "Results recorded in $RESULTS_FILE"

# Append completion information to results file
echo -e "\n## Test Completion\n- **Completed At**: $(date)" >> "$RESULTS_FILE"

# Make script executable
chmod +x "$0"

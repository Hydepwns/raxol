#!/bin/bash

# Run the dashboard layout integration test and log the output
# This script executes the Elixir test script and captures the results

# Set path variables
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TEST_SCRIPT="${SCRIPT_DIR}/test_dashboard_layout_integration.exs"
LOG_DIR="$HOME/.raxol"
LOG_FILE="${LOG_DIR}/dashboard_integration_test.log"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Print header
echo "========================================"
echo "Running Dashboard Layout Integration Test"
echo "========================================"
echo "Test script: $TEST_SCRIPT"
echo "Log file: $LOG_FILE"
echo "Started at: $(date)"
echo "========================================"

# Give executable permissions to the test script
chmod +x "$TEST_SCRIPT"

# Run the test script and capture output to both console and log file
"$TEST_SCRIPT" | tee "$LOG_FILE"

# Check exit status
if [ ${PIPESTATUS[0]} -eq 0 ]; then
  echo "========================================"
  echo "Test completed successfully!"
  echo "Check $LOG_FILE for detailed output"
  echo "========================================"
  exit 0
else
  echo "========================================"
  echo "Test failed! Check $LOG_FILE for details"
  echo "========================================"
  exit 1
fi

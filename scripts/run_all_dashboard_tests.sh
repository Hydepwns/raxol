#!/bin/bash

# Run all dashboard integration tests in sequence
# This script runs all the dashboard-related tests and collects their output

# Set path variables
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG_DIR="$HOME/.raxol"
SUMMARY_FILE="${LOG_DIR}/dashboard_tests_summary.log"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Print header
echo "==============================================="
echo "Running All Dashboard Integration Tests"
echo "==============================================="
echo "Started at: $(date)"
echo "Log directory: $LOG_DIR"
echo "Summary file: $SUMMARY_FILE"
echo "==============================================="

# Initialize summary file
cat > "$SUMMARY_FILE" << EOF
===============================================
DASHBOARD INTEGRATION TESTS SUMMARY
===============================================
Date: $(date)

EOF

# Function to run a test and report results
run_test() {
  test_name="$1"
  test_script="$2"

  echo -e "\n\n==============================================="
  echo "RUNNING TEST: $test_name"
  echo "==============================================="

  # Give executable permissions to the test script
  chmod +x "$test_script"

  # Run the test and capture exit code
  "$test_script"
  exit_code=$?

  # Report result
  if [ $exit_code -eq 0 ]; then
    result="PASSED"
  else
    result="FAILED (Exit code: $exit_code)"
  fi

  echo "==============================================="
  echo "TEST RESULT: $result"
  echo "==============================================="

  # Add to summary
  cat >> "$SUMMARY_FILE" << EOF
TEST: $test_name
RESULT: $result
---------------------------------------------
EOF

  return $exit_code
}

# Track overall success
all_tests_passed=true

# Run layout persistence test
echo -e "\n>>> Running Layout Persistence Test"
run_test "Layout Persistence" "${SCRIPT_DIR}/test_layout_persistence.exs"
if [ $? -ne 0 ]; then all_tests_passed=false; fi

# Run dashboard layout integration test
echo -e "\n>>> Running Dashboard Layout Integration Test"
run_test "Dashboard Layout Integration" "${SCRIPT_DIR}/test_dashboard_layout_integration.exs"
if [ $? -ne 0 ]; then all_tests_passed=false; fi

# Add visualization test
echo -e "\n>>> Running Visualization Test"
run_test "Visualization Components" "${SCRIPT_DIR}/test_visualization.exs"
if [ $? -ne 0 ]; then all_tests_passed=false; fi

# Add VS Code visualization test if it exists
if [ -f "${SCRIPT_DIR}/test_vscode_visualization.exs" ]; then
  echo -e "\n>>> Running VS Code Visualization Test"
  run_test "VS Code Visualization" "${SCRIPT_DIR}/test_vscode_visualization.exs"
  if [ $? -ne 0 ]; then all_tests_passed=false; fi
fi

# Generate final status
if [ "$all_tests_passed" = true ]; then
  final_status="ALL TESTS PASSED"
else
  final_status="SOME TESTS FAILED"
fi

# Add summary footer
cat >> "$SUMMARY_FILE" << EOF

===============================================
FINAL STATUS: $final_status
===============================================
EOF

# Print final status
echo -e "\n\n==============================================="
echo "TEST SUITE COMPLETED"
echo "FINAL STATUS: $final_status"
echo "Summary written to: $SUMMARY_FILE"
echo "==============================================="

# Return overall status
if [ "$all_tests_passed" = true ]; then
  exit 0
else
  exit 1
fi

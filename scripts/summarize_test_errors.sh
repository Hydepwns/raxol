#!/bin/bash
# Summarize test errors and warnings from a test run.
# Usage: ./scripts/summarize_test_errors.sh

# Directory for storing test output
TMP_DIR="tmp"
# File to store raw test output
INPUT_FILE="$TMP_DIR/test_output.txt"
# File to store the summarized errors
OUTPUT_FILE="$TMP_DIR/test_error_summary.txt"

# Ensure tmp directory exists
mkdir -p "$TMP_DIR"

# Run the test suite and capture all output directly for inspection
echo "Running mix test with --max-requires 1..."
if mix test --max-requires 1 > "$INPUT_FILE" 2>&1; then
  echo "mix test completed successfully." > "$OUTPUT_FILE"
else
  echo "mix test failed. Full output in $INPUT_FILE" > "$OUTPUT_FILE"
  echo "\n--- Error Summary ---" >> "$OUTPUT_FILE"

  error_patterns=(
    "UndefinedFunctionError"
    "KeyError"
    "FunctionClauseError"
    "ArgumentError"
    "MatchError"
    "Assertion failed"
    "failed"
    "error"
    "No such file or directory"
    "Compilaation error"
    "Mox.__using__/1"
  )

  for pattern in "${error_patterns[@]}"; do
    count=$(grep -c -i "$pattern" "$INPUT_FILE")
    if [ "$count" -gt 0 ]; then
      echo "\n=== $pattern (Count: $count) ===" >> "$OUTPUT_FILE"
      grep -m 5 -i "$pattern" "$INPUT_FILE" >> "$OUTPUT_FILE"
    fi
  done
fi

echo "\nFull summary in $OUTPUT_FILE"

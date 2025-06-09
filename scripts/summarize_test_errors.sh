#!/bin/bash
# Summarize real test failures from a test run.
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
echo "Running mix test..."
if mix test > "$INPUT_FILE" 2>&1; then
  echo "All tests passed!" > "$OUTPUT_FILE"
else
  echo "mix test failed. Full output in $INPUT_FILE" > "$OUTPUT_FILE"
  echo "--- Test Failure Summary ---" >> "$OUTPUT_FILE"

  # Extract all test failures
  grep -nE "^[[:space:]]*[0-9]+\\) test " "$INPUT_FILE" | while read -r line; do
    line_num=$(echo "$line" | cut -d: -f1)
    test_header=$(echo "$line" | cut -d: -f2-)

    # Determine the range of lines for the current test failure's context
    # Use awk to find the line number of the *next* test header
    next_test_header_line_num=$(awk -v start_line="$((line_num + 1))" 'NR >= start_line && /^[[:space:]]*[0-9]+\\) test / {print NR; exit}' "$INPUT_FILE")

    echo "$test_header" >> "$OUTPUT_FILE"
    if [ -z "$next_test_header_line_num" ]; then
      # No more test headers after this one, so print from the line after the current header to the end of the file
      awk -v l_num="$line_num" 'NR > l_num' "$INPUT_FILE" >> "$OUTPUT_FILE"
    else
      # Print lines from the line after the current header up to the line *before* the next test header
      awk -v l_num="$line_num" -v next_h_ln="$next_test_header_line_num" 'NR > l_num && NR < next_h_ln' "$INPUT_FILE" >> "$OUTPUT_FILE"
    fi
    echo "" >> "$OUTPUT_FILE"
  done

  # If no failures found by the general pattern, say so
  if ! grep -qE "^[[:space:]]*[0-9]+\) test " "$INPUT_FILE"; then
    echo "No test failures found in the output (or the pattern needs adjustment)." >> "$OUTPUT_FILE"
  fi
fi

echo "Full summary in $OUTPUT_FILE"
echo "Output file size: $(stat -f %z "$OUTPUT_FILE") bytes"
echo "Number of lines: $(wc -l < "$OUTPUT_FILE")"

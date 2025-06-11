#!/bin/bash
# Summarize real test failures from a test run.
# Usage: ./scripts/summarize_test_errors.sh

# Directory for storing test output
TMP_DIR="tmp"
# File to store raw test output
INPUT_FILE="$TMP_DIR/test_output.txt"
# File to store the summarized errors
OUTPUT_FILE="$TMP_DIR/test_error_summary.txt"
# Temporary files
COMPILATION_ISSUES_FILE="$TMP_DIR/test_compilation_issues.txt"
TEST_FAILURES_FILE="$TMP_DIR/test_failures.txt"

# Ensure tmp directory exists
mkdir -p "$TMP_DIR"

# Clean up previous summary files
true > "$OUTPUT_FILE"
true > "$COMPILATION_ISSUES_FILE"
true > "$TEST_FAILURES_FILE"

# Run the test suite and capture all output
echo "Running mix test..."
if mix test > "$INPUT_FILE" 2>&1; then
  echo "All tests passed!" > "$OUTPUT_FILE"
else
  # --- Extract Information ---

  # 1. Extract compilation warnings and errors
  # We look for lines containing 'warning:' or 'error:'.
  # This might include some lines from test failures, but it's a good starting point.
  grep -E "warning:|error:" "$INPUT_FILE" > "$COMPILATION_ISSUES_FILE"

  # 2. Extract full test failure blocks
  grep -nE "^[[:space:]]*[0-9]+\\) test " "$INPUT_FILE" | while read -r line; do
    line_num=$(echo "$line" | cut -d: -f1)
    test_header=$(echo "$line" | cut -d: -f2-)

    # Determine the range of lines for the current test failure's context
    # Use awk to find the line number of the *next* test header
    next_test_header_line_num=$(awk -v start_line="$((line_num + 1))" 'NR >= start_line && /^[[:space:]]*[0-9]+\\) test / {print NR; exit}' "$INPUT_FILE")

    echo "$test_header" >> "$TEST_FAILURES_FILE"
    if [ -z "$next_test_header_line_num" ]; then
      # No more test headers after this one, so print from the line after the current header to the end of the file
      awk -v l_num="$line_num" 'NR > l_num' "$INPUT_FILE" >> "$TEST_FAILURES_FILE"
    else
      # Print lines from the line after the current header up to the line *before* the next test header
      awk -v l_num="$line_num" -v next_h_ln="$next_test_header_line_num" 'NR > l_num && NR < next_h_ln' "$INPUT_FILE" >> "$TEST_FAILURES_FILE"
    fi
    echo "" >> "$TEST_FAILURES_FILE"
  done

  # --- Generate Summary Report ---
  # Check if there are actual test failures
  if [ -s "$TEST_FAILURES_FILE" ]; then
    {
      echo "mix test failed. Full output is in $INPUT_FILE"
      echo "---"

      # Summarize unique compilation issues if any were found
      if [ -s "$COMPILATION_ISSUES_FILE" ]; then
        echo "Summary of Unique Compilation Warnings and Errors:"
        # This sed command tries to remove file paths and line numbers to group similar errors
        # Example: "lib/foo.ex:123: warning: message" becomes "warning: message"
        sed -E 's/^[^:]+:[0-9]+:[[:space:]]*//' "$COMPILATION_ISSUES_FILE" \
          | sort | uniq -c | sort -nr
        echo "---"
      fi

      # Display full test failures
      echo "Test Failure Details:"
      cat "$TEST_FAILURES_FILE"
      echo "---"

      # If no specific issues were extracted, show a generic message
      if ! [ -s "$COMPILATION_ISSUES_FILE" ] && ! [ -s "$TEST_FAILURES_FILE" ]; then
        echo "No specific compilation issues or test failures were found by the script."
        echo "The test suite failed for another reason. Please check the full output."
      fi
    } > "$OUTPUT_FILE"
  else
    # No test failures, so it's a success, but there might be compilation warnings
    {
      echo "All tests passed!"
      if [ -s "$COMPILATION_ISSUES_FILE" ]; then
        echo "However, there are some compilation warnings:"
        echo "---"
        sed -E 's/^[^:]+:[0-9]+:[[:space:]]*//' "$COMPILATION_ISSUES_FILE" \
          | sort | uniq -c | sort -nr
      fi
    } > "$OUTPUT_FILE"
  fi
fi

echo "Summary written to $OUTPUT_FILE"
echo "Output file size: $(stat -f %z "$OUTPUT_FILE") bytes"
echo "Number of lines: $(wc -l < "$OUTPUT_FILE")"

# Clean up temporary files
rm -f "$COMPILATION_ISSUES_FILE" "$TEST_FAILURES_FILE"

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
STRUCT_ERRORS_FILE="$TMP_DIR/struct_errors.txt"
MODULE_REDEFINITIONS_FILE="$TMP_DIR/module_redefinitions.txt"
UNUSED_VARS_FILE="$TMP_DIR/unused_vars.txt"
UNDEFINED_FUNCTIONS_FILE="$TMP_DIR/undefined_functions.txt"
BEHAVIOR_IMPL_FILE="$TMP_DIR/behavior_impl.txt"
FUNCTION_CLAUSE_FILE="$TMP_DIR/function_clause.txt"
MODULE_ATTR_FILE="$TMP_DIR/module_attr.txt"
DEPRECATED_FILE="$TMP_DIR/deprecated.txt"
DOCUMENTATION_FILE="$TMP_DIR/documentation.txt"
TYPE_SPEC_FILE="$TMP_DIR/type_spec.txt"

# Ensure tmp directory exists
mkdir -p "$TMP_DIR"

# Clean up previous summary files
true > "$OUTPUT_FILE"
true > "$COMPILATION_ISSUES_FILE"
true > "$TEST_FAILURES_FILE"
true > "$STRUCT_ERRORS_FILE"
true > "$MODULE_REDEFINITIONS_FILE"
true > "$UNUSED_VARS_FILE"
true > "$UNDEFINED_FUNCTIONS_FILE"
true > "$BEHAVIOR_IMPL_FILE"
true > "$FUNCTION_CLAUSE_FILE"
true > "$MODULE_ATTR_FILE"
true > "$DEPRECATED_FILE"
true > "$DOCUMENTATION_FILE"
true > "$TYPE_SPEC_FILE"

# Run the test suite and capture all output
echo "Running mix test..."
if mix test > "$INPUT_FILE" 2>&1; then
  echo "All tests passed!" > "$OUTPUT_FILE"
else
  # --- Extract Information ---

  # 1. Extract compilation warnings and errors
  grep -E "warning:|error:" "$INPUT_FILE" > "$COMPILATION_ISSUES_FILE"

  # 2. Extract struct-related errors
  grep -E "key .* not found.*struct:|struct:.*not found" "$INPUT_FILE" > "$STRUCT_ERRORS_FILE"

  # 3. Extract module redefinitions
  grep -E "redefining module .* \(current version loaded from" "$INPUT_FILE" > "$MODULE_REDEFINITIONS_FILE"

  # 4. Extract unused variable warnings
  grep -E "variable .* is unused" "$INPUT_FILE" > "$UNUSED_VARS_FILE"

  # 5. Extract undefined/private function warnings
  grep -E "is undefined or private|is not available or is yet to be defined" "$INPUT_FILE" > "$UNDEFINED_FUNCTIONS_FILE"

  # 6. Extract behavior implementation warnings
  grep -E "@impl true.*without a corresponding behaviour|@behaviour.*not implemented" "$INPUT_FILE" > "$BEHAVIOR_IMPL_FILE"

  # 7. Extract function clause ordering warnings
  grep -E "this clause cannot match because a previous clause at line.*always matches" "$INPUT_FILE" > "$FUNCTION_CLAUSE_FILE"

  # 8. Extract module attribute warnings
  grep -E "@.*attribute.*not set|@.*attribute.*not found" "$INPUT_FILE" > "$MODULE_ATTR_FILE"

  # 9. Extract deprecated function warnings
  grep -E "deprecated|deprecation" "$INPUT_FILE" > "$DEPRECATED_FILE"

  # 10. Extract documentation warnings
  grep -E "missing documentation|@doc.*not found" "$INPUT_FILE" > "$DOCUMENTATION_FILE"

  # 11. Extract type spec warnings
  grep -E "@spec.*not found|@type.*not found|@opaque.*not found" "$INPUT_FILE" > "$TYPE_SPEC_FILE"

  # 12. Extract full test failure blocks
  grep -nE "^[[:space:]]*[0-9]+\\) test " "$INPUT_FILE" | while read -r line; do
    line_num=$(echo "$line" | cut -d: -f1)
    test_header=$(echo "$line" | cut -d: -f2-)

    # Determine the range of lines for the current test failure's context
    next_test_header_line_num=$(awk -v start_line="$((line_num + 1))" 'NR >= start_line && /^[[:space:]]*[0-9]+\\) test / {print NR; exit}' "$INPUT_FILE")

    echo "$test_header" >> "$TEST_FAILURES_FILE"
    if [ -z "$next_test_header_line_num" ]; then
      awk -v l_num="$line_num" 'NR > l_num' "$INPUT_FILE" >> "$TEST_FAILURES_FILE"
    else
      awk -v l_num="$line_num" -v next_h_ln="$next_test_header_line_num" 'NR > l_num && NR < next_h_ln' "$INPUT_FILE" >> "$TEST_FAILURES_FILE"
    fi
    echo "" >> "$TEST_FAILURES_FILE"
  done

  # --- Generate Summary Report ---
  {
    echo "mix test failed. Full output is in $INPUT_FILE"
    echo "---"

    # Display struct errors if any
    if [ -s "$STRUCT_ERRORS_FILE" ]; then
      echo "Struct-related Errors:"
      cat "$STRUCT_ERRORS_FILE"
      echo "---"
    fi

    # Display module redefinitions if any
    if [ -s "$MODULE_REDEFINITIONS_FILE" ]; then
      echo "Module Redefinitions:"
      cat "$MODULE_REDEFINITIONS_FILE"
      echo "---"
    fi

    # Display behavior implementation issues if any
    if [ -s "$BEHAVIOR_IMPL_FILE" ]; then
      echo "Behavior Implementation Issues:"
      cat "$BEHAVIOR_IMPL_FILE"
      echo "---"
    fi

    # Display function clause ordering issues if any
    if [ -s "$FUNCTION_CLAUSE_FILE" ]; then
      echo "Function Clause Ordering Issues:"
      cat "$FUNCTION_CLAUSE_FILE"
      echo "---"
    fi

    # Display module attribute issues if any
    if [ -s "$MODULE_ATTR_FILE" ]; then
      echo "Module Attribute Issues:"
      cat "$MODULE_ATTR_FILE"
      echo "---"
    fi

    # Display deprecated function warnings if any
    if [ -s "$DEPRECATED_FILE" ]; then
      echo "Deprecated Function Warnings:"
      cat "$DEPRECATED_FILE"
      echo "---"
    fi

    # Display documentation warnings if any
    if [ -s "$DOCUMENTATION_FILE" ]; then
      echo "Documentation Issues:"
      cat "$DOCUMENTATION_FILE"
      echo "---"
    fi

    # Display type spec warnings if any
    if [ -s "$TYPE_SPEC_FILE" ]; then
      echo "Type Specification Issues:"
      cat "$TYPE_SPEC_FILE"
      echo "---"
    fi

    # Display undefined/private functions if any
    if [ -s "$UNDEFINED_FUNCTIONS_FILE" ]; then
      echo "Undefined/Private Functions:"
      cat "$UNDEFINED_FUNCTIONS_FILE"
      echo "---"
    fi

    # Display unused variables if any
    if [ -s "$UNUSED_VARS_FILE" ]; then
      echo "Unused Variables:"
      cat "$UNUSED_VARS_FILE"
      echo "---"
    fi

    # Display other compilation issues
    if [ -s "$COMPILATION_ISSUES_FILE" ]; then
      echo "Other Compilation Warnings and Errors:"
      sed -E 's/^[^:]+:[0-9]+:[[:space:]]*//' "$COMPILATION_ISSUES_FILE" \
        | sort | uniq -c | sort -nr
      echo "---"
    fi

    # Display test failures
    if [ -s "$TEST_FAILURES_FILE" ]; then
      echo "Test Failure Details:"
      cat "$TEST_FAILURES_FILE"
      echo "---"
    fi

    # If no specific issues were extracted, show a generic message
    if ! [ -s "$COMPILATION_ISSUES_FILE" ] && ! [ -s "$TEST_FAILURES_FILE" ] && \
       ! [ -s "$STRUCT_ERRORS_FILE" ] && ! [ -s "$MODULE_REDEFINITIONS_FILE" ] && \
       ! [ -s "$UNUSED_VARS_FILE" ] && ! [ -s "$UNDEFINED_FUNCTIONS_FILE" ] && \
       ! [ -s "$BEHAVIOR_IMPL_FILE" ] && ! [ -s "$FUNCTION_CLAUSE_FILE" ] && \
       ! [ -s "$MODULE_ATTR_FILE" ] && ! [ -s "$DEPRECATED_FILE" ] && \
       ! [ -s "$DOCUMENTATION_FILE" ] && ! [ -s "$TYPE_SPEC_FILE" ]; then
      echo "No specific issues were found by the script."
      echo "The test suite failed for another reason. Please check the full output."
    fi
  } > "$OUTPUT_FILE"
fi

echo "Summary written to $OUTPUT_FILE"
echo "Output file size: $(stat -f %z "$OUTPUT_FILE") bytes"
echo "Number of lines: $(wc -l < "$OUTPUT_FILE")"

# Clean up temporary files
rm -f "$COMPILATION_ISSUES_FILE" "$TEST_FAILURES_FILE" "$STRUCT_ERRORS_FILE" \
      "$MODULE_REDEFINITIONS_FILE" "$UNUSED_VARS_FILE" "$UNDEFINED_FUNCTIONS_FILE" \
      "$BEHAVIOR_IMPL_FILE" "$FUNCTION_CLAUSE_FILE" "$MODULE_ATTR_FILE" \
      "$DEPRECATED_FILE" "$DOCUMENTATION_FILE" "$TYPE_SPEC_FILE"

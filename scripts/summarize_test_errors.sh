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
COMPILATION_FILE="$TMP_DIR/compilation_errors.txt"
STRUCT_FILE="$TMP_DIR/struct_errors.txt"
MODULE_REDEF_FILE="$TMP_DIR/module_redef_errors.txt"
TEST_FAILURES_FILE="$TMP_DIR/test_failures.txt"
MODULE_AVAILABILITY_FILE="$TMP_DIR/module_availability.txt"
BEHAVIOR_CALLBACK_FILE="$TMP_DIR/behavior_callback.txt"
UNDEFINED_FUNCTIONS_FILE="$TMP_DIR/undefined_functions.txt"
UNUSED_VARIABLES_FILE="$TMP_DIR/unused_variables.txt"
MODULE_ATTRIBUTE_FILE="$TMP_DIR/module_attribute.txt"
DEPRECATION_FILE="$TMP_DIR/deprecation.txt"
UNUSED_IMPORTS_ALIASES_FILE="$TMP_DIR/unused_imports_aliases.txt"
DOC_WARNINGS_FILE="$TMP_DIR/doc_warnings.txt"
TYPE_SPEC_FILE="$TMP_DIR/type_spec.txt"
FUNC_CLAUSE_FILE="$TMP_DIR/function_clause.txt"
ASSERTION_FAILURES_FILE="$TMP_DIR/assertion_failures.txt"

# Ensure tmp directory exists
mkdir -p "$TMP_DIR"

# Clean up previous summary files
true > "$OUTPUT_FILE"
true > "$COMPILATION_FILE"
true > "$STRUCT_FILE"
true > "$MODULE_REDEF_FILE"
true > "$TEST_FAILURES_FILE"
true > "$MODULE_AVAILABILITY_FILE"
true > "$BEHAVIOR_CALLBACK_FILE"
true > "$UNDEFINED_FUNCTIONS_FILE"
true > "$UNUSED_VARIABLES_FILE"
true > "$MODULE_ATTRIBUTE_FILE"
true > "$DEPRECATION_FILE"
true > "$UNUSED_IMPORTS_ALIASES_FILE"
true > "$DOC_WARNINGS_FILE"
true > "$TYPE_SPEC_FILE"
true > "$FUNC_CLAUSE_FILE"
true > "$ASSERTION_FAILURES_FILE"

# Run the test suite and capture all output
echo "Running mix test..."
if mix test > "$INPUT_FILE" 2>&1; then
  echo "All tests passed!" > "$OUTPUT_FILE"
else
  # --- Extract Information ---

  # 1. Extract compilation warnings and errors
  grep -E "warning:|error:" "$INPUT_FILE" | sort | uniq > "$COMPILATION_FILE"

  # 2. Extract struct-related errors
  grep -E "key .* not found.*struct:|struct:.*not found" "$INPUT_FILE" | sort | uniq > "$STRUCT_FILE"

  # 3. Extract module redefinitions
  grep -E "redefining module .* \(current version loaded from" "$INPUT_FILE" | sort | uniq > "$MODULE_REDEF_FILE"

  # 4. Extract unused variable warnings
  grep -E "variable .* is unused" "$INPUT_FILE" | sort | uniq > "$UNUSED_VARIABLES_FILE"

  # 5. Extract undefined/private function warnings
  grep -E "is undefined or private|is not available or is yet to be defined" "$INPUT_FILE" | sort | uniq > "$UNDEFINED_FUNCTIONS_FILE"

  # 6. Extract behavior implementation warnings
  grep -E "@impl true.*without a corresponding behaviour|@behaviour.*not implemented" "$INPUT_FILE" | sort | uniq > "$BEHAVIOR_CALLBACK_FILE"

  # 7. Extract function clause ordering warnings
  grep -E "this clause cannot match because a previous clause at line.*always matches" "$INPUT_FILE" | sort | uniq > "$MODULE_ATTRIBUTE_FILE"

  # 8. Extract module attribute warnings
  grep -E "@.*attribute.*not set|@.*attribute.*not found" "$INPUT_FILE" | sort | uniq > "$MODULE_ATTRIBUTE_FILE"

  # 9. Extract deprecated function warnings
  grep -E "deprecated|deprecation" "$INPUT_FILE" | sort | uniq > "$DEPRECATION_FILE"

  # 10. Extract documentation warnings
  grep -E "missing documentation|@doc.*not found" "$INPUT_FILE" | sort | uniq > "$DOC_WARNINGS_FILE"

  # 11. Extract type spec warnings
  grep -E "@spec.*not found|@type.*not found|@opaque.*not found" "$INPUT_FILE" | sort | uniq > "$TYPE_SPEC_FILE"

  # 12. Extract module availability warnings
  grep -E "module .* is not available or is yet to be defined" "$INPUT_FILE" | sort | uniq > "$MODULE_AVAILABILITY_FILE"

  # 13. Extract behavior callback warnings
  grep -E "got \"@impl true\" for function .* but no behaviour specifies such callback" "$INPUT_FILE" | sort | uniq > "$BEHAVIOR_CALLBACK_FILE"

  # 14. Extract full test failure blocks
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

    # Display behavior callback issues if any
    if [ -s "$BEHAVIOR_CALLBACK_FILE" ]; then
      echo "Behavior Callback Issues:"
      cat "$BEHAVIOR_CALLBACK_FILE"
      echo "---"
    fi

    # Display module availability issues if any
    if [ -s "$MODULE_AVAILABILITY_FILE" ]; then
      echo "Module Availability Issues:"
      cat "$MODULE_AVAILABILITY_FILE"
      echo "---"
    fi

    # Display struct errors if any
    if [ -s "$STRUCT_FILE" ]; then
      echo "Struct-related Errors:"
      cat "$STRUCT_FILE"
      echo "---"
    fi

    # Display module redefinitions if any
    if [ -s "$MODULE_REDEF_FILE" ]; then
      echo "Module Redefinitions:"
      cat "$MODULE_REDEF_FILE"
      echo "---"
    fi

    # Display behavior implementation issues if any
    if [ -s "$BEHAVIOR_CALLBACK_FILE" ]; then
      echo "Behavior Implementation Issues:"
      cat "$BEHAVIOR_CALLBACK_FILE"
      echo "---"
    fi

    # Display function clause ordering issues if any
    if [ -s "$MODULE_ATTRIBUTE_FILE" ]; then
      echo "Function Clause Ordering Issues:"
      cat "$MODULE_ATTRIBUTE_FILE"
      echo "---"
    fi

    # Display module attribute issues if any
    if [ -s "$MODULE_ATTRIBUTE_FILE" ]; then
      echo "Module Attribute Issues:"
      cat "$MODULE_ATTRIBUTE_FILE"
      echo "---"
    fi

    # Display deprecated function warnings if any
    if [ -s "$DEPRECATION_FILE" ]; then
      echo "Deprecation Warnings:"
      cat "$DEPRECATION_FILE"
      echo "---"
    fi

    # Display documentation warnings if any
    if [ -s "$DOC_WARNINGS_FILE" ]; then
      echo "Documentation Warnings:"
      cat "$DOC_WARNINGS_FILE"
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
    if [ -s "$UNUSED_VARIABLES_FILE" ]; then
      echo "Unused Variables:"
      cat "$UNUSED_VARIABLES_FILE"
      echo "---"
    fi

    # Display other compilation issues
    if [ -s "$COMPILATION_FILE" ]; then
      echo "Other Compilation Warnings and Errors:"
      sed -E 's/^[^:]+:[0-9]+:[[:space:]]*//' "$COMPILATION_FILE" \
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
    if ! [ -s "$COMPILATION_FILE" ] && ! [ -s "$TEST_FAILURES_FILE" ] && \
       ! [ -s "$STRUCT_FILE" ] && ! [ -s "$MODULE_REDEF_FILE" ] && \
       ! [ -s "$UNUSED_VARIABLES_FILE" ] && ! [ -s "$UNDEFINED_FUNCTIONS_FILE" ] && \
       ! [ -s "$BEHAVIOR_CALLBACK_FILE" ] && ! [ -s "$MODULE_ATTRIBUTE_FILE" ] && \
       ! [ -s "$DEPRECATION_FILE" ] && ! [ -s "$DOC_WARNINGS_FILE" ] && \
       ! [ -s "$TYPE_SPEC_FILE" ] && ! [ -s "$FUNC_CLAUSE_FILE" ] && \
       ! [ -s "$ASSERTION_FAILURES_FILE" ]; then
      echo "No specific issues were found by the script."
      echo "The test suite failed for another reason. Please check the full output."
    fi
  } > "$OUTPUT_FILE"
fi

echo "Summary written to $OUTPUT_FILE"
echo "Output file size: $(stat -f %z "$OUTPUT_FILE") bytes"
echo "Number of lines: $(wc -l < "$OUTPUT_FILE")"

# Clean up temporary files
rm -f "$COMPILATION_FILE" "$STRUCT_FILE" "$MODULE_REDEF_FILE" "$TEST_FAILURES_FILE" \
      "$MODULE_AVAILABILITY_FILE" "$BEHAVIOR_CALLBACK_FILE" "$UNDEFINED_FUNCTIONS_FILE" \
      "$UNUSED_VARIABLES_FILE" "$MODULE_ATTRIBUTE_FILE" "$DEPRECATION_FILE" \
      "$UNUSED_IMPORTS_ALIASES_FILE" "$DOC_WARNINGS_FILE" "$TYPE_SPEC_FILE" \
      "$FUNC_CLAUSE_FILE" "$ASSERTION_FAILURES_FILE"

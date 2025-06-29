#!/bin/bash
# Summarize real test failures from a test run with improved truncation and summarization.
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

# Configuration for truncation
MAX_LINES_PER_CATEGORY=20
MAX_TOTAL_LINES=500
SHOW_FREQUENCY_THRESHOLD=3

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

# Function to truncate and summarize content with frequency
truncate_with_frequency() {
    local input_file="$1"
    local max_lines="$2"
    local threshold="$3"

    if [ ! -s "$input_file" ]; then
        return
    fi

    # Count frequency and sort by count (descending)
    sort "$input_file" | uniq -c | sort -nr | while read -r count line; do
        if [ "$count" -ge "$threshold" ]; then
            echo "[$count times] $line"
        else
            echo "$line"
        fi
    done | head -n "$max_lines"

    # Show truncation message if needed
    local total_lines
    total_lines=$(wc -l < "$input_file")
    if [ "$total_lines" -gt "$max_lines" ]; then
        local remaining=$((total_lines - max_lines))
        echo "... and $remaining more similar warnings"
    fi
}

# Function to extract and summarize test failures
extract_test_failures() {
    local input_file="$1"
    local output_file="$2"
    local max_failures=10

    # Extract test failure headers
    grep -nE "^[[:space:]]*[0-9]+\\) test " "$input_file" | head -n "$max_failures" | while read -r line; do
        line_num=$(echo "$line" | cut -d: -f1)
        test_header=$(echo "$line" | cut -d: -f2- | sed 's/^[[:space:]]*//')

        # Get the next few lines for context (up to 5 lines)
        awk -v l_num="$line_num" -v max_context=5 '
            NR > l_num && NR <= l_num + max_context {
                if (/^[[:space:]]*[0-9]+\\) test /) exit
                print "  " $0
            }
        ' "$input_file" > /tmp/test_context.tmp

        echo "FAILED: $test_header" >> "$output_file"
        if [ -s /tmp/test_context.tmp ]; then
            cat /tmp/test_context.tmp >> "$output_file"
        fi
        echo "" >> "$output_file"
    done

    # Check if there are more failures
    local total_failures
    total_failures=$(grep -cE "^[[:space:]]*[0-9]+\\) test " "$input_file")
    if [ "$total_failures" -gt "$max_failures" ]; then
        local remaining=$((total_failures - max_failures))
        echo "... and $remaining more test failures" >> "$output_file"
    fi

    rm -f /tmp/test_context.tmp
}

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
  grep -E "this clause cannot match because a previous clause at line.*always matches" "$INPUT_FILE" | sort | uniq > "$FUNC_CLAUSE_FILE"

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

  # 14. Extract test failures with context
  extract_test_failures "$INPUT_FILE" "$TEST_FAILURES_FILE"

  # --- Generate Summary Report ---
  {
    echo "mix test failed. Full output is in $INPUT_FILE"
    echo "Summary generated at $(date)"
    echo "---"

    # Count total issues for overview
    total_issues=0
    issue_counts=()

    for file in "$COMPILATION_FILE" "$STRUCT_FILE" "$MODULE_REDEF_FILE" "$TEST_FAILURES_FILE" \
                "$MODULE_AVAILABILITY_FILE" "$BEHAVIOR_CALLBACK_FILE" "$UNDEFINED_FUNCTIONS_FILE" \
                "$UNUSED_VARIABLES_FILE" "$MODULE_ATTRIBUTE_FILE" "$DEPRECATION_FILE" \
                "$DOC_WARNINGS_FILE" "$TYPE_SPEC_FILE" "$FUNC_CLAUSE_FILE"; do
        if [ -s "$file" ]; then
            count=$(wc -l < "$file")
            total_issues=$((total_issues + count))
            issue_counts+=("$file:$count")
        fi
    done

    echo "OVERVIEW: $total_issues total issues found"
    echo "---"

    # Display test failures first (most important)
    if [ -s "$TEST_FAILURES_FILE" ]; then
        echo "TEST FAILURES (most critical):"
        cat "$TEST_FAILURES_FILE"
        echo "---"
    fi

    # Display behavior callback issues if any
    if [ -s "$BEHAVIOR_CALLBACK_FILE" ]; then
        echo "BEHAVIOR CALLBACK ISSUES:"
        truncate_with_frequency "$BEHAVIOR_CALLBACK_FILE" "$MAX_LINES_PER_CATEGORY" "$SHOW_FREQUENCY_THRESHOLD"
        echo "---"
    fi

    # Display module availability issues if any
    if [ -s "$MODULE_AVAILABILITY_FILE" ]; then
        echo "MODULE AVAILABILITY ISSUES:"
        truncate_with_frequency "$MODULE_AVAILABILITY_FILE" "$MAX_LINES_PER_CATEGORY" "$SHOW_FREQUENCY_THRESHOLD"
        echo "---"
    fi

    # Display struct errors if any
    if [ -s "$STRUCT_FILE" ]; then
        echo "STRUCT-RELATED ERRORS:"
        truncate_with_frequency "$STRUCT_FILE" "$MAX_LINES_PER_CATEGORY" "$SHOW_FREQUENCY_THRESHOLD"
        echo "---"
    fi

    # Display module redefinitions if any
    if [ -s "$MODULE_REDEF_FILE" ]; then
        echo "MODULE REDEFINITIONS:"
        truncate_with_frequency "$MODULE_REDEF_FILE" "$MAX_LINES_PER_CATEGORY" "$SHOW_FREQUENCY_THRESHOLD"
        echo "---"
    fi

    # Display undefined/private functions if any
    if [ -s "$UNDEFINED_FUNCTIONS_FILE" ]; then
        echo "UNDEFINED/PRIVATE FUNCTIONS:"
        truncate_with_frequency "$UNDEFINED_FUNCTIONS_FILE" "$MAX_LINES_PER_CATEGORY" "$SHOW_FREQUENCY_THRESHOLD"
        echo "---"
    fi

    # Display function clause ordering issues if any
    if [ -s "$FUNC_CLAUSE_FILE" ]; then
        echo "FUNCTION CLAUSE ORDERING ISSUES:"
        truncate_with_frequency "$FUNC_CLAUSE_FILE" "$MAX_LINES_PER_CATEGORY" "$SHOW_FREQUENCY_THRESHOLD"
        echo "---"
    fi

    # Display module attribute issues if any
    if [ -s "$MODULE_ATTRIBUTE_FILE" ]; then
        echo "MODULE ATTRIBUTE ISSUES:"
        truncate_with_frequency "$MODULE_ATTRIBUTE_FILE" "$MAX_LINES_PER_CATEGORY" "$SHOW_FREQUENCY_THRESHOLD"
        echo "---"
    fi

    # Display deprecated function warnings if any
    if [ -s "$DEPRECATION_FILE" ]; then
        echo "DEPRECATION WARNINGS:"
        truncate_with_frequency "$DEPRECATION_FILE" "$MAX_LINES_PER_CATEGORY" "$SHOW_FREQUENCY_THRESHOLD"
        echo "---"
    fi

    # Display documentation warnings if any
    if [ -s "$DOC_WARNINGS_FILE" ]; then
        echo "DOCUMENTATION WARNINGS:"
        truncate_with_frequency "$DOC_WARNINGS_FILE" "$MAX_LINES_PER_CATEGORY" "$SHOW_FREQUENCY_THRESHOLD"
        echo "---"
    fi

    # Display type spec warnings if any
    if [ -s "$TYPE_SPEC_FILE" ]; then
        echo "TYPE SPECIFICATION ISSUES:"
        truncate_with_frequency "$TYPE_SPEC_FILE" "$MAX_LINES_PER_CATEGORY" "$SHOW_FREQUENCY_THRESHOLD"
        echo "---"
    fi

    # Display unused variables if any
    if [ -s "$UNUSED_VARIABLES_FILE" ]; then
        echo "UNUSED VARIABLES:"
        truncate_with_frequency "$UNUSED_VARIABLES_FILE" "$MAX_LINES_PER_CATEGORY" "$SHOW_FREQUENCY_THRESHOLD"
        echo "---"
    fi

    # Display other compilation issues (summarized)
    if [ -s "$COMPILATION_FILE" ]; then
        echo "OTHER COMPILATION WARNINGS AND ERRORS:"
        # Remove file paths and line numbers for cleaner output
        sed -E 's/^[^:]+:[0-9]+:[[:space:]]*//' "$COMPILATION_FILE" \
            | sort | uniq -c | sort -nr | head -n "$MAX_LINES_PER_CATEGORY" \
            | sed 's/^[[:space:]]*\([0-9]*\)[[:space:]]*\(.*\)/[\\1 times] \\2/'

        total_compilation=$(wc -l < "$COMPILATION_FILE")
        if [ "$total_compilation" -gt "$MAX_LINES_PER_CATEGORY" ]; then
            remaining=$((total_compilation - MAX_LINES_PER_CATEGORY))
            echo "... and $remaining more compilation issues"
        fi
        echo "---"
    fi

    # If no specific issues were extracted, show a generic message
    if ! [ -s "$COMPILATION_FILE" ] && ! [ -s "$TEST_FAILURES_FILE" ] && \
       ! [ -s "$STRUCT_FILE" ] && ! [ -s "$MODULE_REDEF_FILE" ] && \
       ! [ -s "$UNUSED_VARIABLES_FILE" ] && ! [ -s "$UNDEFINED_FUNCTIONS_FILE" ] && \
       ! [ -s "$BEHAVIOR_CALLBACK_FILE" ] && ! [ -s "$MODULE_ATTRIBUTE_FILE" ] && \
       ! [ -s "$DEPRECATION_FILE" ] && ! [ -s "$DOC_WARNINGS_FILE" ] && \
       ! [ -s "$TYPE_SPEC_FILE" ] && ! [ -s "$FUNC_CLAUSE_FILE" ]; then
      echo "No specific issues were found by the script."
      echo "The test suite failed for another reason. Please check the full output."
    fi

    echo ""
    echo "SUMMARY STATISTICS:"
    for count_info in "${issue_counts[@]}"; do
        file=$(echo "$count_info" | cut -d: -f1)
        count=$(echo "$count_info" | cut -d: -f2)
        category=$(basename "$file" .txt | sed 's/_/ /g' | tr '[:lower:]' '[:upper:]')
        echo "  $category: $count issues"
    done

  } > "$OUTPUT_FILE"
fi

# Truncate the final output if it's too long
if [ -f "$OUTPUT_FILE" ]; then
    output_lines=$(wc -l < "$OUTPUT_FILE")
    if [ "$output_lines" -gt "$MAX_TOTAL_LINES" ]; then
        echo "" >> "$OUTPUT_FILE"
        echo "NOTE: Output truncated to $MAX_TOTAL_LINES lines for readability."
        echo "See $INPUT_FILE for complete details."

        # Keep only the first MAX_TOTAL_LINES
        head -n "$MAX_TOTAL_LINES" "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp"
        mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
    fi
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

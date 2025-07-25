#!/usr/bin/env nu

# Summarize test failures and warnings from mix test output
# Usage: 
#   ./scripts/summarize_test_errors.nu
#   ./scripts/summarize_test_errors.nu --test-file <path>

def main [
    --test-file: string = ""  # Optional test file to use instead of running mix test
] {
    # Configuration
    let tmp_dir = "tmp"
    let input_file = $"($tmp_dir)/test_output.txt"
    let output_file = $"($tmp_dir)/test_error_summary.txt"
    let max_lines_per_category = 20
    let max_total_lines = 500
    let show_frequency_threshold = 3

    # Ensure tmp directory exists
    mkdir $tmp_dir

    # Get test output
    let test_output = if $test_file != "" {
        # Use provided test file
        print $"Using test file: ($test_file)"
        open $test_file
    } else {
        # Run mix test and capture output
        print "Running mix test..."
        let test_result = (do { mix test } | complete)
        let output = $"($test_result.stdout)\n($test_result.stderr)"
        $output | save -f $input_file
        if $test_result.exit_code == 0 {
            "All tests passed!" | save -f $output_file
            print $"Summary written to ($output_file)"
            let file_size = (ls $output_file | get size | first)
            let line_count = (open $output_file | lines | length)
            print $"Output file size: ($file_size)"
            print $"Number of lines: ($line_count)"
            return
        }
        $output
    }

    # Process the test output
    process_test_output $test_output $input_file $output_file $max_lines_per_category $max_total_lines $show_frequency_threshold
}

# Function to truncate and summarize content with frequency
def truncate_with_frequency [
    lines: list<string>
    max_lines: int
    threshold: int
] {
    # Group by unique values and count occurrences
    let grouped = ($lines | group-by | items { |key, value| 
        {key: $key, count: ($value | length)} 
    })
    let sorted = ($grouped | sort-by count --reverse)
    
    let output = ($sorted | take $max_lines | each { |item|
        if $item.count >= $threshold {
            $"[($item.count) times] ($item.key)"
        } else {
            $item.key
        }
    })
    
    let total_lines = ($lines | length)
    if $total_lines > $max_lines {
        let remaining = $total_lines - $max_lines
        $output | append $"... and ($remaining) more similar warnings"
    } else {
        $output
    }
}

# Function to extract test failures with context
def extract_test_failures [input: string] {
    let lines = ($input | lines)
    let test_failures = []
    let max_failures = 10
    
    # Find test failure lines
    let failure_indices = ($lines | enumerate | where { |it| 
        $it.item =~ '^\s*\d+\) test '
    } | take $max_failures)
    
    let failures = ($failure_indices | each { |failure|
        let test_header = ($failure.item | str trim)
        let context_start = $failure.index + 1
        let context_end = $failure.index + 6
        
        # Get context lines (up to 5 lines after the failure)
        let context = if $context_end < ($lines | length) {
            $lines | skip $context_start | take 5 | each { |line|
                # Stop if we hit another test
                if ($line =~ '^\s*\d+\) test ') {
                    null
                } else {
                    $"  ($line)"
                }
            } | compact
        } else {
            []
        }
        
        let failure_text = ([$"FAILED: ($test_header)"] | append $context | append [""])
        $failure_text
    } | flatten)
    
    # Check for more failures
    let total_failures = ($lines | where { |it| $it =~ '^\s*\d+\) test ' } | length)
    if $total_failures > $max_failures {
        let remaining = $total_failures - $max_failures
        $failures | append $"... and ($remaining) more test failures"
    } else {
        $failures
    }
}

def process_test_output [
    test_output: string
    input_file: string
    output_file: string
    max_lines_per_category: int
    max_total_lines: int
    show_frequency_threshold: int
] {
    # Extract different categories of issues
    let all_lines = ($test_output | lines)
    
    # Extract various issue types
    let compilation_issues = ($all_lines | where { |it| $it =~ 'warning:|error:' })
    let struct_errors = ($all_lines | where { |it| $it =~ 'key .* not found.*struct:|struct:.*not found' })
    let module_redefs = ($all_lines | where { |it| $it =~ 'redefining module .* \(current version loaded from' })
    let unused_vars = ($all_lines | where { |it| $it =~ 'variable .* is unused' })
    let undefined_funcs = ($all_lines | where { |it| $it =~ 'is undefined or private|is not available or is yet to be defined' })
    let behavior_callbacks = ($all_lines | where { |it| $it =~ '@impl true.*without a corresponding behaviour|@behaviour.*not implemented' })
    let func_clauses = ($all_lines | where { |it| $it =~ 'this clause cannot match because a previous clause at line.*always matches' })
    let module_attrs = ($all_lines | where { |it| $it =~ '@.*attribute.*not set|@.*attribute.*not found' })
    let deprecations = ($all_lines | where { |it| $it =~ 'deprecated|deprecation' })
    let doc_warnings = ($all_lines | where { |it| $it =~ 'missing documentation|@doc.*not found' })
    let type_specs = ($all_lines | where { |it| $it =~ '@spec.*not found|@type.*not found|@opaque.*not found' })
    let module_availability = ($all_lines | where { |it| $it =~ 'module .* is not available or is yet to be defined' })
    let test_failures = (extract_test_failures $test_output)
    
    # Build summary report
    mut summary_lines = []
    $summary_lines = ($summary_lines | append $"mix test failed. Full output is in ($input_file)")
    $summary_lines = ($summary_lines | append $"Summary generated at (date now | format date '%Y-%m-%d %H:%M:%S')")
    $summary_lines = ($summary_lines | append "---")
    
    # Count total issues
    let categories = [
        ["name", "data"];
        ["TEST FAILURES", $test_failures]
        ["BEHAVIOR CALLBACK ISSUES", $behavior_callbacks]
        ["MODULE AVAILABILITY ISSUES", $module_availability]
        ["STRUCT-RELATED ERRORS", $struct_errors]
        ["MODULE REDEFINITIONS", $module_redefs]
        ["UNDEFINED/PRIVATE FUNCTIONS", $undefined_funcs]
        ["FUNCTION CLAUSE ORDERING ISSUES", $func_clauses]
        ["MODULE ATTRIBUTE ISSUES", $module_attrs]
        ["DEPRECATION WARNINGS", $deprecations]
        ["DOCUMENTATION WARNINGS", $doc_warnings]
        ["TYPE SPECIFICATION ISSUES", $type_specs]
        ["UNUSED VARIABLES", $unused_vars]
        ["OTHER COMPILATION WARNINGS AND ERRORS", $compilation_issues]
    ]
    
    let issue_counts = ($categories | each { |cat|
        let count = if ($cat.data | is-empty) { 0 } else { ($cat.data | length) }
        {name: $cat.name, count: $count}
    })
    
    let total_issues = ($issue_counts | get count | math sum)
    
    $summary_lines = ($summary_lines | append $"OVERVIEW: ($total_issues) total issues found")
    $summary_lines = ($summary_lines | append "---")
    
    # Add each category to summary
    for cat in $categories {
        if not ($cat.data | is-empty) {
            $summary_lines = ($summary_lines | append $"($cat.name):")
            
            if $cat.name == "TEST FAILURES" {
                # Test failures are already formatted
                $summary_lines = ($summary_lines | append $cat.data)
            } else {
                # Apply frequency truncation to other categories
                let truncated = (truncate_with_frequency $cat.data $max_lines_per_category $show_frequency_threshold)
                $summary_lines = ($summary_lines | append $truncated)
            }
            
            $summary_lines = ($summary_lines | append "---")
        }
    }
    
    # Add summary statistics
    $summary_lines = ($summary_lines | append "")
    $summary_lines = ($summary_lines | append "SUMMARY STATISTICS:")
    $summary_lines = ($summary_lines | append ($issue_counts | where count > 0 | each { |stat|
        $"  ($stat.name): ($stat.count) issues"
    }))
    
    # Save summary
    $summary_lines | str join "\n" | save -f $output_file
    
    # Truncate if too long
    let output_lines = (open $output_file | lines | length)
    if $output_lines > $max_total_lines {
        let truncated = (open $output_file | lines | take $max_total_lines)
        let truncated = ($truncated | append ["", $"NOTE: Output truncated to ($max_total_lines) lines for readability.", $"See ($input_file) for complete details."])
        $truncated | str join "\n" | save -f $output_file
    }
    
    # Print summary info
    print $"Summary written to ($output_file)"
    let file_size = (ls $output_file | get size | first)
    let line_count = (open $output_file | lines | length)
    print $"Output file size: ($file_size)"
    print $"Number of lines: ($line_count)"
}
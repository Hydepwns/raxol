#!/bin/bash
# vs_code_test.sh

echo "Starting VS Code Extension Test at $(date)"
echo "OS: $(uname -a)"

# Create results directory if it doesn't exist
mkdir -p test_results

# Generate results file
RESULTS_FILE="test_results/vscode_$(date +%Y%m%d_%H%M%S).md"

# Write header to results file
cat > "$RESULTS_FILE" << EOF
# VS Code Extension Test Results
- **Test Date**: $(date +%Y-%m-%d)
- **OS**: $(uname -a)
- **VS Code Version**: $(code --version | head -n 1)

## Test Environment
- VS Code Extension Debug Mode
EOF

# Launch VS Code with extension in debug mode
code --extensionDevelopmentPath="$(pwd)/extensions/vscode" .

# Tester manual checklist - verify these items
cat << EOF
Manual Test Checklist:
1. Extension activates without errors
2. Panel opens with raxol.showTerminal command
3. UI renders correctly
4. Input events processed correctly
5. Resizing updates UI properly
6. All visualizations display correctly
7. Application exits cleanly with Ctrl+C

When finished testing, please complete the results in:
$RESULTS_FILE
EOF

# Timing template
echo "Test completed at $(date)"
echo "Results recorded in $RESULTS_FILE"

# Make script executable
chmod +x "$0"

#!/bin/bash
# build_and_test.sh
# Runs build, test, and greps for errors, piping output to tmp/

set -e

# Ensure tmp directory exists
mkdir -p tmp

# Run build and compile, tee output
echo "Running mix deps.get and mix compile..."
mix deps.get | tee tmp/build_and_compile.log
mix compile | tee -a tmp/build_and_compile.log

echo "Build complete. Output saved to tmp/build_and_compile.log"

# Check for zero warnings
echo "Checking for compilation warnings..."
mix compile --warnings-as-errors 2>&1 | tee tmp/warnings_check.log
if [ $? -eq 0 ]; then
    echo "✅ Zero warnings - compilation check passed!"
else
    echo "❌ Compilation warnings detected - see tmp/warnings_check.log"
    exit 1
fi

# Run tests, tee output
echo "Running mix test..."
mix test | tee tmp/test_output.log

echo "Test run complete. Output saved to tmp/test_output.log"

# Grep for errors in build and test logs

grep -i error tmp/build_and_compile.log > tmp/build_errors.log || true
grep -i error tmp/test_output.log > tmp/test_errors.log || true

echo "Error grep complete."
echo "- Build errors: tmp/build_errors.log"
echo "- Test errors: tmp/test_errors.log"

printf "\nSummary:\n"
echo "  Build log: tmp/build_and_compile.log"
echo "  Test log:  tmp/test_output.log"
echo "  Build errors: tmp/build_errors.log"
echo "  Test errors:  tmp/test_errors.log"

#!/bin/bash

# Fix termbox2 compilation issues by setting proper TMPDIR
export TMPDIR=/tmp

# Run tests with environment variables to skip problematic tests
# and exclude integration/slow tests
env SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test \
  --exclude integration \
  --exclude slow \
  --exclude performance \
  --max-failures 5 \
  "$@"
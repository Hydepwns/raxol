#!/bin/bash

# Script to run tests directly locally without GitHub Actions
# This is a simpler alternative to using act which has port conflicts

echo "==== Running Local Tests ===="
echo "Environment: test"

# Export necessary environment variables
export MIX_ENV=test
export RAXOL_ENV=test
export RAXOL_HEADLESS=true
export RAXOL_USE_MOCK_TERMBOX=true
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=postgres
export POSTGRES_DB=raxol_test
export TERM=xterm-256color
export COLORTERM=truecolor

# Ensure dependencies are up to date
echo "Installing dependencies..."
mix deps.get
echo "Explicitly compiling ranch with --force..."
mix deps.compile ranch --force
echo "Compiling all dependencies..."
mix deps.compile

# Run the tests
echo "Running tests..."
mix test --cover --slowest 10

# Check formatting
echo "Checking formatting..."
mix format --check-formatted

echo "==== Tests Completed ===="

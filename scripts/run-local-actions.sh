#!/bin/bash

# Script to run GitHub Actions locally using act
# Especially useful for debugging on macOS with ARM chips using Orbstack

# Set default values
WORKFLOW="ci.yml"
JOB="test"
DEBUG=false
DRY_RUN=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -w|--workflow)
      WORKFLOW="$2"
      shift 2
      ;;
    -j|--job)
      JOB="$2"
      shift 2
      ;;
    -d|--debug)
      DEBUG=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  -w, --workflow WORKFLOW    Specify the workflow file (default: ci.yml)"
      echo "  -j, --job JOB              Specify the job to run (default: test)"
      echo "  -d, --debug                Enable verbose debugging"
      echo "  --dry-run                  Show command without running it"
      echo "  -h, --help                 Show this help message"
      echo ""
      echo "Example:"
      echo "  $0 -w cross_platform_tests.yml -j test -d"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use -h or --help for usage information"
      exit 1
      ;;
  esac
done

# Check if act is installed
if ! command -v act &> /dev/null; then
    echo "Error: 'act' is not installed or not in your PATH"
    echo "Please install it with: brew install act"
    exit 1
fi

# Check if Docker/Orbstack is running
if ! docker info &> /dev/null; then
    echo "Error: Docker/Orbstack is not running"
    echo "Please start Docker or Orbstack first"
    exit 1
fi

# Set environment variables for act
export GITHUB_TOKEN=${GITHUB_TOKEN:-dummy_token}
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5433
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=postgres
export POSTGRES_DB=raxol_test
export MIX_ENV=test
export RAXOL_ENV=test
export RAXOL_HEADLESS=true
export RAXOL_USE_MOCK_TERMBOX=true
export TERM=xterm-256color
export COLORTERM=truecolor
export PLATFORM=macos
export ACT=true

# Build the command
CMD="act -W .github/workflows/$WORKFLOW"

if [ "$JOB" != "all" ]; then
  CMD="$CMD -j $JOB"
fi

# Add matrix specification to only run on ubuntu-latest
CMD="$CMD --matrix os:ubuntu-latest"

if [ "$DEBUG" = true ]; then
  CMD="$CMD --verbose"
fi

# Print what we're about to do
echo "==== Running Local GitHub Action ===="
echo "Workflow: $WORKFLOW"
echo "Job: $JOB"
echo "Debug mode: $DEBUG"
echo "Command: $CMD"
echo "====================================="

# Run the command or just display it
if [ "$DRY_RUN" = true ]; then
  echo "Dry run mode - command not executed"
else
  echo "Starting local GitHub Action run..."
  eval $CMD
fi

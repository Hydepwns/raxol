#!/bin/bash
# Script to run Raxol in native terminal mode
# Usage: ./run_native_terminal.sh

# Set correct environment variables
export RAXOL_ENV=dev
export RAXOL_MODE=native

# Navigate to the project root
cd "$(dirname "$0")/.."

# Check if MIX_ENV is set, default to dev
MIX_ENV=${MIX_ENV:-dev}

echo "Starting Raxol in native terminal mode (MIX_ENV=$MIX_ENV)..."

# Ensure compilation is up to date
mix compile

# Run the application
mix run -e "Raxol.CLI.main([])"

# Check exit code and provide message
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo "Raxol exited with code $EXIT_CODE"

  # Provide advice if BEAM VM hang occurs
  if [ $EXIT_CODE -eq 143 ] || [ $EXIT_CODE -eq 137 ]; then
    echo "NOTICE: The application may have terminated abnormally (likely BEAM VM hang)."
    echo "If you used Ctrl+C, this is expected. Check terminal.ex's terminate handler."
  fi
fi

exit $EXIT_CODE

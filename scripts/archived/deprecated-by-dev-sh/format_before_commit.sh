#!/bin/bash

# This script formats all Elixir files in the project
# It can be run manually before committing or as part of a CI workflow

echo "Formatting all Elixir files in the project..."

# Run formatter on all files
mix format

echo "All files formatted successfully!"

# You can commit now with confidence that your code is properly formatted
echo "You can now commit your changes with confidence."

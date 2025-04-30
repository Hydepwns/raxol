#!/bin/sh

# This script installs the pre-commit hook for the Raxol project.
# It copies the pre-commit hook to the .git/hooks directory.

echo "Installing pre-commit hook..."

# Create the pre-commit hook
cat > .git/hooks/pre-commit << 'EOL'
#!/bin/sh

echo "Running mix format on staged Elixir files..."

# Get list of staged Elixir files
STAGED_FILES=$(git diff --name-only --cached --diff-filter=ACMR -- "*.ex" "*.exs")

if [ -n "$STAGED_FILES" ]; then
  # Format each staged file
  echo "$STAGED_FILES" | while read -r file; do
    echo "Formatting $file"
    mix format "$file"
    git add "$file"
  done
  echo "Formatted and staged changes."
else
  echo "No Elixir files to format."
fi

# Run the pre-commit checks
echo "Running Raxol pre-commit checks..."
elixir scripts/pre_commit_check.exs

# If the pre-commit checks fail, exit with a non-zero status
if [ $? -ne 0 ]; then
  echo "Pre-commit checks failed. Please fix the issues before committing."
  exit 1
fi

echo "Pre-commit checks passed!"
exit 0
EOL

# Make the pre-commit hook executable
chmod +x .git/hooks/pre-commit

echo "Pre-commit hook installed successfully!"

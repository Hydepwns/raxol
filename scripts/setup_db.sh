#!/bin/bash

# Exit on error
set -e

echo "===== Raxol Database Setup ====="

# Check if PostgreSQL is running
if ! pg_isready -q; then
  echo "Error: PostgreSQL is not running."
  echo "Please start PostgreSQL and try again."
  echo "Suggestion: brew services start postgresql"
  exit 1
fi

# Database configuration (from config/dev.exs)
DB_NAME="raxol_dev"
DB_USER="postgres"
DB_PASS="postgres"
DB_HOST="localhost"

# Override with environment variables if set
[ -n "$RAXOL_DB_NAME" ] && DB_NAME="$RAXOL_DB_NAME"
[ -n "$RAXOL_DB_USER" ] && DB_USER="$RAXOL_DB_USER"
[ -n "$RAXOL_DB_PASS" ] && DB_PASS="$RAXOL_DB_PASS"
[ -n "$RAXOL_DB_HOST" ] && DB_HOST="$RAXOL_DB_HOST"

echo "Using database configuration:"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo "  Host: $DB_HOST"
echo ""

# Check if the user wants to reset the database
if [ "$1" == "--reset" ]; then
  echo "Dropping database $DB_NAME if it exists..."
  PGPASSWORD=$DB_PASS dropdb -h $DB_HOST -U $DB_USER $DB_NAME --if-exists
  echo "Database dropped."
fi

# Create the database if it doesn't exist
echo "Creating database $DB_NAME if it doesn't exist..."
PGPASSWORD=$DB_PASS createdb -h $DB_HOST -U $DB_USER $DB_NAME -O $DB_USER 2>/dev/null || echo "Database already exists."

# Check if we can connect to the database
echo "Verifying database connection..."
if PGPASSWORD=$DB_PASS psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT 1" > /dev/null 2>&1; then
  echo "✅ Database connection verified"
else
  echo "❌ Could not connect to database. Please check your credentials and ensure PostgreSQL is running properly."
  exit 1
fi

# Run migrations
echo "Running migrations..."
cd "$(dirname "$0")/.." && mix ecto.migrate

# Run a simple diagnostic test
echo "Running final database checks..."
elixir scripts/check_db.exs

echo "Database setup complete."
echo ""
echo "You can now run the application with:"
echo "  mix run --no-halt"
echo ""
echo "To reset the database, run:"
echo "  scripts/setup_db.sh --reset"

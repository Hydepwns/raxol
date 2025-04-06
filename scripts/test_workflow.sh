#!/bin/bash

# Enable debug mode if DEBUG environment variable is set
if [ -n "$DEBUG" ]; then
    set -x
fi

# Exit on error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print error messages
error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# Function to print warning messages
warn() {
    echo -e "${YELLOW}Warning: $1${NC}" >&2
}

# Function to print success messages
success() {
    echo -e "${GREEN}$1${NC}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to check PostgreSQL connection
check_postgres() {
    local port=$1
    local max_attempts=5
    local attempt=1

    # Start PostgreSQL container if not running
    if ! docker ps | grep -q "postgres:14"; then
        echo "Starting PostgreSQL container..."
        docker run -d \
            --name raxol-postgres \
            -e POSTGRES_PASSWORD=postgres \
            -e POSTGRES_USER=postgres \
            -e POSTGRES_DB=raxol_test \
            -p ${port}:5432 \
            postgres:14
    fi

    while [ $attempt -le $max_attempts ]; do
        if pg_isready -h localhost -p $port -U postgres > /dev/null 2>&1; then
            echo "PostgreSQL is ready on port $port"
            return 0
        fi
        echo "Warning: PostgreSQL not ready on port $port, attempt $attempt of $max_attempts"
        sleep 2
        attempt=$((attempt + 1))
    done

    echo "Error: PostgreSQL failed to start on port $port after $max_attempts attempts"
    return 1
}

# Function to check Docker status
check_docker() {
    echo "Checking Docker status..."
    if ! orb status | grep -q "Running"; then
        error "OrbStack is not running. Please start OrbStack and try again."
        exit 1
    fi
    docker info > /dev/null 2>&1 || {
        error "Docker is not responding. Please check OrbStack status and try again."
        exit 1
    }
}

# Print system information
echo "System Information:"
echo "OS: $(uname)"
echo "Architecture: $(uname -m)"
echo "User: $(whoami)"
echo "Working directory: $(pwd)"
echo

# Check if running with sudo
if [ "$EUID" -eq 0 ]; then
    error "Please run this script without sudo. It will request elevated privileges only when needed."
fi

# Check for required commands
echo "Checking required dependencies..."

# Check if Docker is installed
if ! command_exists docker; then
    error "Docker is not installed. Please install Docker Desktop from https://www.docker.com/products/docker-desktop"
fi

# Check if act is installed
if ! command_exists act; then
    echo "act is not installed. Installing..."
    if ! command_exists brew; then
        error "Homebrew is not installed. Please install Homebrew first: https://brew.sh"
    fi
    brew install act || error "Failed to install act"
fi

# Check if Docker is running
check_docker

# Ensure script directory exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Create .secrets file if it doesn't exist
SECRETS_FILE="$PROJECT_ROOT/.secrets"
if [ ! -f "$SECRETS_FILE" ]; then
    echo "Creating .secrets file..."
    cat > "$SECRETS_FILE" << EOL
POSTGRES_PASSWORD=postgres
POSTGRES_USER=postgres
POSTGRES_DB=raxol_test
EOL
    chmod 600 "$SECRETS_FILE" || error "Failed to set permissions on .secrets file"
    success "Created .secrets file successfully"
fi

# Check PostgreSQL
echo "Checking PostgreSQL status..."
if ! command_exists pg_isready; then
    warn "pg_isready command not found. Installing PostgreSQL client..."
    if command_exists brew; then
        brew install postgresql || warn "Failed to install PostgreSQL client. Continuing anyway..."
    else
        warn "Homebrew not found. Skipping PostgreSQL client installation..."
    fi
fi

# Ensure PostgreSQL is running on port 5433
echo "Ensuring PostgreSQL is running on port 5433..."
check_postgres 5433 || exit 1

# Run the workflow
echo "Running CI workflow locally..."
cd "$PROJECT_ROOT" || error "Failed to change to project directory"

echo "Using act with the following configuration:"
echo "- Project root: $PROJECT_ROOT"
echo "- Secrets file: $SECRETS_FILE"
echo "- Environment: test"

# Run act with matrix testing
for elixir in "1.14" "1.15"; do
    for otp in "25.0" "26.0"; do
        echo "Testing with Elixir $elixir and OTP $otp..."
        act -P ubuntu-20.04=catthehacker/ubuntu:act-20.04 \
            --secret-file "$SECRETS_FILE" \
            --env MIX_ENV=test \
            --env POSTGRES_HOST=host.docker.internal \
            --env POSTGRES_PORT=5433 \
            --env POSTGRES_USER=postgres \
            --env POSTGRES_PASSWORD=postgres \
            --env POSTGRES_DB=raxol_test \
            --env ASDF_DIR=/root/.asdf \
            --env ELIXIR_VERSION=$elixir \
            --env OTP_VERSION=$otp \
            -v \
            push || error "Workflow execution failed for Elixir $elixir and OTP $otp"
    done
done

success "All workflow matrix combinations completed successfully!"

# Print helpful next steps
echo
echo "Next steps:"
echo "1. Check the output above for any warnings or errors"
echo "2. If you see any issues, try running with DEBUG=1 ./scripts/test_workflow.sh"
echo "3. Make sure Docker Desktop is running"
echo "4. Ensure PostgreSQL is running and accessible on port 5433"

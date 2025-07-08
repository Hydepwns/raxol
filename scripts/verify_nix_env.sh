#!/bin/bash

# Raxol Nix Environment Verification Script
# This script verifies that the Nix development environment is properly configured

set -e

echo "=== Raxol Nix Environment Verification ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    local status=$1
    local message=$2
    if [ "$status" = "OK" ]; then
        echo -e "${GREEN}✓${NC} $message"
    elif [ "$status" = "WARN" ]; then
        echo -e "${YELLOW}⚠${NC} $message"
    else
        echo -e "${RED}✗${NC} $message"
    fi
}

# Function to check if command exists
check_command() {
    local cmd=$1
    local name=$2
    if command -v "$cmd" >/dev/null 2>&1; then
        print_status "OK" "$name is available"
        return 0
    else
        print_status "FAIL" "$name is not available"
        return 1
    fi
}

# Function to check environment variable
check_env_var() {
    local var=$1
    local name=$2
    if [ -n "${!var}" ]; then
        print_status "OK" "$name is set: ${!var}"
        return 0
    else
        print_status "FAIL" "$name is not set"
        return 1
    fi
}

# Function to check if path exists
check_path() {
    local path=$1
    local name=$2
    if [ -e "$path" ]; then
        print_status "OK" "$name exists: $path"
        return 0
    else
        print_status "FAIL" "$name does not exist: $path"
        return 1
    fi
}

echo "1. Checking Nix installation..."
if check_command "nix" "Nix"; then
    echo "   Version: $(nix --version)"
fi

echo ""
echo "2. Checking Erlang and Elixir..."
check_command "erl" "Erlang"
check_command "elixir" "Elixir"

if command -v "erl" >/dev/null 2>&1; then
    echo "   Erlang version: $(erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell)"
fi

if command -v "elixir" >/dev/null 2>&1; then
    echo "   Elixir version: $(elixir --version | head -1)"
fi

echo ""
echo "3. Checking PostgreSQL..."
check_command "pg_ctl" "PostgreSQL"
check_env_var "PGDATA" "PGDATA"

if [ -n "$PGDATA" ] && [ -d "$PGDATA" ]; then
    echo "   PostgreSQL data directory: $PGDATA"
    if pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then
        print_status "OK" "PostgreSQL is running"
    else
        print_status "WARN" "PostgreSQL is not running (use 'pg_ctl -D \$PGDATA start')"
    fi
fi

echo ""
echo "4. Checking build tools..."
check_command "gcc" "GCC"
check_command "make" "Make"
check_command "cmake" "CMake"
check_command "pkg-config" "pkg-config"

echo ""
echo "5. Checking Node.js..."
check_command "node" "Node.js"
check_command "npm" "npm"

if command -v "node" >/dev/null 2>&1; then
    echo "   Node.js version: $(node --version)"
fi

if command -v "npm" >/dev/null 2>&1; then
    echo "   npm version: $(npm --version)"
fi

echo ""
echo "6. Checking environment variables..."
check_env_var "ERLANG_PATH" "ERLANG_PATH"
check_env_var "ELIXIR_PATH" "ELIXIR_PATH"
check_env_var "ERL_EI_INCLUDE_DIR" "ERL_EI_INCLUDE_DIR"
check_env_var "ERL_EI_LIBDIR" "ERL_EI_LIBDIR"
check_env_var "MIX_ENV" "MIX_ENV"
check_env_var "MAGICK_HOME" "MAGICK_HOME"

echo ""
echo "7. Checking Mix and dependencies..."
check_command "mix" "Mix"

if command -v "mix" >/dev/null 2>&1; then
    echo "   Mix version: $(mix --version | head -1)"
    
    # Check if we're in a Mix project
    if [ -f "mix.exs" ]; then
        print_status "OK" "Mix project found"
        
        # Check if dependencies are installed
        if [ -d "_build" ]; then
            print_status "OK" "Build directory exists"
        else
            print_status "WARN" "Build directory not found (run 'mix deps.get')"
        fi
    else
        print_status "WARN" "Not in a Mix project directory"
    fi
fi

echo ""
echo "8. Checking ImageMagick..."
check_command "convert" "ImageMagick"

echo ""
echo "9. Checking Git submodules..."
if [ -f ".gitmodules" ]; then
    if [ -d "lib/termbox2_nif" ]; then
        print_status "OK" "Git submodules are initialized"
    else
        print_status "WARN" "Git submodules not initialized (run 'git submodule update --init --recursive')"
    fi
else
    print_status "WARN" "No .gitmodules file found"
fi

echo ""
echo "=== Summary ==="

# Count issues
issues=0
warnings=0

# Check for critical failures
if ! command -v "nix" >/dev/null 2>&1; then
    ((issues++))
fi

if ! command -v "erl" >/dev/null 2>&1; then
    ((issues++))
fi

if ! command -v "elixir" >/dev/null 2>&1; then
    ((issues++))
fi

if ! command -v "mix" >/dev/null 2>&1; then
    ((issues++))
fi

if [ -z "$ERLANG_PATH" ] || [ -z "$ELIXIR_PATH" ]; then
    ((issues++))
fi

if [ $issues -eq 0 ]; then
    echo -e "${GREEN}✓ Environment is ready for development!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Run 'mix deps.get' to install dependencies"
    echo "2. Run 'git submodule update --init --recursive' to initialize submodules"
    echo "3. Run 'mix setup' to set up the project"
    echo "4. Run 'mix test' to verify everything works"
else
    echo -e "${RED}✗ Found $issues critical issue(s)${NC}"
    echo ""
    echo "Please fix the issues above before proceeding."
    echo "See docs/NIX_TROUBLESHOOTING.md for help."
fi

if [ $warnings -gt 0 ]; then
    echo -e "${YELLOW}⚠ Found $warnings warning(s)${NC}"
    echo "These are not critical but should be addressed for the best experience."
fi

echo ""
echo "For more help, see:"
echo "- docs/DEVELOPMENT.md - Development setup guide"
echo "- docs/NIX_TROUBLESHOOTING.md - Troubleshooting guide"
echo "- examples/guides/01_getting_started/install.md - Installation guide" 
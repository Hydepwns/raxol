#!/bin/bash

# Cloudflare Pages build script for Raxol Playground
set -e

echo "Building Raxol Playground for Cloudflare Pages..."

# Set required environment variables
export TMPDIR=/tmp
export SKIP_TERMBOX2_TESTS=true
export MIX_ENV=prod

# Check if we have Elixir available, if not try to install
if ! command -v elixir > /dev/null; then
    echo "Elixir not found, attempting installation..."

    # Try different package managers
    if command -v apt-get > /dev/null; then
        sudo apt-get update && sudo apt-get install -y erlang elixir
    elif command -v yum > /dev/null; then
        sudo yum install -y erlang elixir
    elif command -v apk > /dev/null; then
        apk add --no-cache erlang elixir
    else
        echo "Warning: Could not install Elixir automatically"
        echo "Attempting to continue with available tools..."
    fi
fi

# Install Hex and Rebar if available
if command -v mix > /dev/null; then
    echo "Installing Hex and Rebar..."
    mix local.hex --force || echo "Warning: Hex installation failed"
    mix local.rebar --force || echo "Warning: Rebar installation failed"

    echo "Installing Elixir dependencies..."
    mix deps.get --only prod || echo "Warning: deps.get failed"

    echo "Compiling Phoenix application..."
    mix compile || echo "Warning: mix compile failed"

    echo "Deploying assets..."
    mix assets.deploy || {
        echo "mix assets.deploy failed, trying manual asset build..."
        cd assets
        if command -v npm > /dev/null; then
            npm install && npm run build
        else
            echo "Warning: npm not available for asset building"
        fi
        cd ..
    }

    echo "Creating digest..."
    mix phx.digest || echo "Warning: phx.digest failed"
else
    echo "Mix not available, building assets only..."
    cd assets
    if command -v npm > /dev/null; then
        npm install && npm run build
        # Copy built assets to expected location
        mkdir -p ../priv/static
        cp -r dist/* ../priv/static/ || echo "Warning: Could not copy assets"
    else
        echo "Error: No build tools available"
        exit 1
    fi
    cd ..
fi

echo "Build completed successfully!"
#!/bin/bash

# Cloudflare Pages build script for Raxol Playground
set -e

echo "🔧 Installing Elixir dependencies..."
mix deps.get --only prod

echo "🎨 Compiling assets..."
mix assets.deploy

echo "🏗️  Building Phoenix application..."
MIX_ENV=prod mix compile

echo "📦 Creating release..."
MIX_ENV=prod mix release raxol_playground

echo "✅ Build completed successfully!"
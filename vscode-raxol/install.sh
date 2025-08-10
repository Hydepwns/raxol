#!/bin/bash

# Raxol VSCode Extension Installation Script

set -e

echo "🎨 Installing Raxol VSCode Extension..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js 18+ and try again."
    exit 1
fi

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed. Please install npm and try again."
    exit 1
fi

# Check if vsce is installed
if ! command -v vsce &> /dev/null; then
    echo "📦 Installing vsce (Visual Studio Code Extension Manager)..."
    npm install -g vsce
fi

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Install dev dependencies
echo "🛠️  Installing development dependencies..."
npm install --save-dev @types/vscode@^1.80.0 @types/node@^18.x typescript@^5.1.6

# Compile TypeScript
echo "🔨 Compiling TypeScript..."
npx tsc -p ./

# Package the extension
echo "📦 Packaging extension..."
vsce package

# Find the generated .vsix file
VSIX_FILE=$(ls *.vsix | head -n 1)

if [ -z "$VSIX_FILE" ]; then
    echo "❌ Failed to create .vsix package"
    exit 1
fi

echo "✅ Extension packaged as: $VSIX_FILE"

# Install the extension
echo "🚀 Installing extension to VSCode..."
code --install-extension "$VSIX_FILE" --force

echo ""
echo "🎉 Raxol VSCode Extension installed successfully!"
echo ""
echo "To get started:"
echo "1. Open VSCode"
echo "2. Open or create a Raxol project"
echo "3. Use Cmd+Shift+P (Ctrl+Shift+P) and type 'Raxol' to see available commands"
echo ""
echo "Available commands:"
echo "- Raxol: New Project"
echo "- Raxol: Start Playground" 
echo "- Raxol: Start Tutorial"
echo "- Raxol: Preview Component"
echo ""
echo "Happy coding! 🎨✨"
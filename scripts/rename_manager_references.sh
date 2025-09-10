#!/bin/bash

# Script to update all module references after renaming manager files
# Phase 1: Core module managers

echo "Updating module references for renamed manager files..."

# Core Config Manager
echo "Updating Raxol.Core.Config.Manager references..."
find . -type f \( -name "*.ex" -o -name "*.exs" \) -exec sed -i '' 's/Raxol\.Core\.Config\.Manager/Raxol.Core.Config.ConfigManager/g' {} \;

# Core Events Manager  
echo "Updating Raxol.Core.Events.Manager references..."
find . -type f \( -name "*.ex" -o -name "*.exs" \) -exec sed -i '' 's/Raxol\.Core\.Events\.Manager/Raxol.Core.Events.EventManager/g' {} \;
find . -type f \( -name "*.ex" -o -name "*.exs" \) -exec sed -i '' 's/Events\.Manager/Events.EventManager/g' {} \;
find . -type f \( -name "*.ex" -o -name "*.exs" \) -exec sed -i '' 's/alias Raxol\.Core\.Events\.EventManager, as: EventManager/alias Raxol.Core.Events.EventManager/g' {} \;

# Core Renderer Manager
echo "Updating Raxol.Core.Renderer.Manager references..."
find . -type f \( -name "*.ex" -o -name "*.exs" \) -exec sed -i '' 's/Raxol\.Core\.Renderer\.Manager/Raxol.Core.Renderer.RendererManager/g' {} \;

# Core Runtime Plugins Manager
echo "Updating Raxol.Core.Runtime.Plugins.Manager references..."
find . -type f \( -name "*.ex" -o -name "*.exs" \) -exec sed -i '' 's/Raxol\.Core\.Runtime\.Plugins\.Manager/Raxol.Core.Runtime.Plugins.PluginManager/g' {} \;

echo "Phase 1 reference updates complete!"
echo ""
echo "Next steps:"
echo "1. Run: mix compile"
echo "2. Run: mix test"
echo "3. Fix any remaining issues"
#!/bin/bash

# Fix Phase 1 module references

echo "Fixing Phase 1 module references..."

# Fix all references in Elixir files
find lib test -type f \( -name "*.ex" -o -name "*.exs" \) | while read file; do
  # Core.Config.Manager -> Core.Config.ConfigManager
  perl -pi -e 's/Raxol\.Core\.Config\.Manager/Raxol.Core.Config.ConfigManager/g' "$file"
  
  # Core.Events.Manager -> Core.Events.EventManager
  perl -pi -e 's/Raxol\.Core\.Events\.Manager/Raxol.Core.Events.EventManager/g' "$file"
  
  # Core.Renderer.Manager -> Core.Renderer.RendererManager
  perl -pi -e 's/Raxol\.Core\.Renderer\.Manager/Raxol.Core.Renderer.RendererManager/g' "$file"
  
  # Core.Runtime.Plugins.Manager -> Core.Runtime.Plugins.PluginManager
  perl -pi -e 's/Raxol\.Core\.Runtime\.Plugins\.Manager/Raxol.Core.Runtime.Plugins.PluginManager/g' "$file"
  
  # Also fix short-form references
  perl -pi -e 's/Core\.Config\.Manager/Core.Config.ConfigManager/g' "$file"
  perl -pi -e 's/Core\.Events\.Manager/Core.Events.EventManager/g' "$file"
  perl -pi -e 's/Core\.Renderer\.Manager/Core.Renderer.RendererManager/g' "$file"
  perl -pi -e 's/Runtime\.Plugins\.Manager/Runtime.Plugins.PluginManager/g' "$file"
  
  # Fix alias statements
  perl -pi -e 's/alias\s+Raxol\.Core\.Config\.Manager/alias Raxol.Core.Config.ConfigManager/g' "$file"
  perl -pi -e 's/alias\s+Raxol\.Core\.Events\.Manager/alias Raxol.Core.Events.EventManager/g' "$file"
  perl -pi -e 's/alias\s+Raxol\.Core\.Renderer\.Manager/alias Raxol.Core.Renderer.RendererManager/g' "$file"
  perl -pi -e 's/alias\s+Raxol\.Core\.Runtime\.Plugins\.Manager/alias Raxol.Core.Runtime.Plugins.PluginManager/g' "$file"
done

echo "Phase 1 references fixed!"
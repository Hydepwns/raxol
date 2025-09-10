#!/bin/bash

# Update all module references for the renamed manager files
echo "Updating manager module references..."

# Find all Elixir files and update them
find . -name "*.ex" -o -name "*.exs" | grep -v scripts/rename_manager_references.sh | xargs grep -l "Raxol\.Core\.Events\.Manager" | while read file; do
    echo "Updating Events.Manager references in: $file"
    # Use perl for more reliable regex replacement
    perl -pi -e 's/Raxol\.Core\.Events\.Manager(?!\.)/Raxol.Core.Events.EventManager/g' "$file"
done

find . -name "*.ex" -o -name "*.exs" | grep -v scripts/rename_manager_references.sh | xargs grep -l "Raxol\.Core\.Config\.Manager" | while read file; do
    echo "Updating Config.Manager references in: $file"
    perl -pi -e 's/Raxol\.Core\.Config\.Manager(?!\.)/Raxol.Core.Config.ConfigManager/g' "$file"
done

find . -name "*.ex" -o -name "*.exs" | grep -v scripts/rename_manager_references.sh | xargs grep -l "Raxol\.Core\.Renderer\.Manager" | while read file; do
    echo "Updating Renderer.Manager references in: $file"
    perl -pi -e 's/Raxol\.Core\.Renderer\.Manager(?!\.)/Raxol.Core.Renderer.RendererManager/g' "$file"
done

find . -name "*.ex" -o -name "*.exs" | grep -v scripts/rename_manager_references.sh | xargs grep -l "Raxol\.Core\.Runtime\.Plugins\.Manager" | while read file; do
    echo "Updating Runtime.Plugins.Manager references in: $file"
    perl -pi -e 's/Raxol\.Core\.Runtime\.Plugins\.Manager(?!\.)/Raxol.Core.Runtime.Plugins.PluginManager/g' "$file"
done

echo "Manager reference updates completed!"
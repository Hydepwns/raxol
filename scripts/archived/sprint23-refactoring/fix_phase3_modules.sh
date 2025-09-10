#!/bin/bash

# Fix module definitions for all renamed files from Phase 3

echo "Fixing module definitions for renamed files..."
echo "=============================================="

# Function to update module definition in a file
fix_module() {
    local file=$1
    local old_module=$2
    local new_module=$3
    
    echo "  Fixing: $file"
    echo "    $old_module -> $new_module"
    
    # Update the defmodule line
    sed -i '' "s/defmodule $old_module/defmodule $new_module/g" "$file" 2>/dev/null || true
}

# Function to update references
update_refs() {
    local old_module=$1
    local new_module=$2
    
    echo "  Updating references: $old_module -> $new_module"
    
    # Update in all Elixir files
    find lib test -name "*.ex" -o -name "*.exs" | while read -r file; do
        # Update alias statements
        sed -i '' "s/alias $old_module/alias $new_module/g" "$file" 2>/dev/null || true
        # Update direct references (be careful with partial matches)
        sed -i '' "s/\b$old_module\b/$new_module/g" "$file" 2>/dev/null || true
    done
}

echo ""
echo "Fixing state.ex files..."
echo "------------------------"

# Fix modal_state.ex
fix_module "lib/raxol/ui/components/modal/modal_state.ex" \
    "Raxol.UI.Components.Modal.State" \
    "Raxol.UI.Components.Modal.ModalState"

# Fix pipeline_state.ex
fix_module "lib/raxol/ui/rendering/pipeline/pipeline_state.ex" \
    "Raxol.UI.Rendering.Pipeline.State" \
    "Raxol.UI.Rendering.Pipeline.PipelineState"

# Fix cursor_state.ex
fix_module "lib/raxol/terminal/cursor/cursor_state.ex" \
    "Raxol.Terminal.Cursor.State" \
    "Raxol.Terminal.Cursor.CursorState"

# Fix parser_state.ex
fix_module "lib/raxol/terminal/parser/parser_state.ex" \
    "Raxol.Terminal.Parser.State" \
    "Raxol.Terminal.Parser.ParserState"

# Fix terminal_state.ex files
fix_module "lib/raxol/terminal/terminal_state.ex" \
    "Raxol.Terminal.State" \
    "Raxol.Terminal.TerminalState"

fix_module "lib/raxol/core/terminal/terminal_state.ex" \
    "Raxol.Core.Terminal.State" \
    "Raxol.Core.Terminal.TerminalState"

# Fix emulator_state.ex
fix_module "lib/raxol/terminal/emulator/emulator_state.ex" \
    "Raxol.Terminal.Emulator.State" \
    "Raxol.Terminal.Emulator.EmulatorState"

# Fix buffer_state.ex
fix_module "lib/raxol/terminal/buffer/buffer_state.ex" \
    "Raxol.Terminal.Buffer.State" \
    "Raxol.Terminal.Buffer.BufferState"

# Fix plugins_state.ex
fix_module "lib/raxol/core/runtime/plugins/plugins_state.ex" \
    "Raxol.Core.Runtime.Plugins.State" \
    "Raxol.Core.Runtime.Plugins.PluginsState"

# Fix playground_state.ex
fix_module "lib/raxol/playground/playground_state.ex" \
    "Raxol.Playground.State" \
    "Raxol.Playground.PlaygroundState"

# Fix updater_state.ex
fix_module "lib/raxol/system/updater/updater_state.ex" \
    "Raxol.System.Updater.State" \
    "Raxol.System.Updater.UpdaterState"

echo ""
echo "Fixing handler.ex files..."
echo "--------------------------"

# Fix events_handler.ex
fix_module "lib/raxol/core/runtime/events/events_handler.ex" \
    "Raxol.Core.Runtime.Events.Handler" \
    "Raxol.Core.Runtime.Events.EventsHandler"

# Fix character_sets_handler.ex
fix_module "lib/raxol/terminal/ansi/character_sets/character_sets_handler.ex" \
    "Raxol.Terminal.ANSI.CharacterSets.Handler" \
    "Raxol.Terminal.ANSI.CharacterSets.CharacterSetsHandler"

# Fix escape_handler.ex
fix_module "lib/raxol/terminal/ansi/escape_handler.ex" \
    "Raxol.Terminal.ANSI.Handler" \
    "Raxol.Terminal.ANSI.EscapeHandler"

# Fix osc_handler.ex
fix_module "lib/raxol/terminal/commands/osc_handler.ex" \
    "Raxol.Terminal.Commands.Handler" \
    "Raxol.Terminal.Commands.OscHandler"

# Fix mouse_handler.ex
fix_module "lib/raxol/terminal/mouse/mouse_handler.ex" \
    "Raxol.Terminal.Mouse.Handler" \
    "Raxol.Terminal.Mouse.MouseHandler"

echo ""
echo "Fixing core.ex files..."
echo "------------------------"

# Fix various core files (skip main core.ex)
for file in $(find lib/raxol -name "*_core.ex"); do
    dir=$(dirname "$file")
    module_path=$(echo "$dir" | sed 's|lib/raxol/||' | sed 's|/|.|g' | awk -F. '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) substr($i,2)}}1' | sed 's/ /./g')
    base_name=$(basename "$file" .ex | sed 's/_core/Core/')
    
    if [[ "$file" != "lib/raxol/core/core.ex" ]]; then
        old_module="Raxol.$module_path.Core"
        new_module="Raxol.$module_path.${base_name//_/.}"
        new_module=$(echo "$new_module" | sed 's/\.\././g' | awk -F. '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) substr($i,2)}}1' | sed 's/ /./g')
        
        fix_module "$file" "$old_module" "$new_module"
    fi
done

echo ""
echo "Fixing renderer.ex files..."
echo "---------------------------"

# List of renderer files to fix
fix_module "lib/raxol/terminal/terminal_renderer.ex" \
    "Raxol.Terminal.Renderer" \
    "Raxol.Terminal.TerminalRenderer"

fix_module "lib/raxol/ui/ui_renderer.ex" \
    "Raxol.UI.Renderer" \
    "Raxol.UI.UiRenderer"

fix_module "lib/raxol/react/react_renderer.ex" \
    "Raxol.React.Renderer" \
    "Raxol.React.ReactRenderer"

fix_module "lib/raxol/svelte/svelte_renderer.ex" \
    "Raxol.Svelte.Renderer" \
    "Raxol.Svelte.SvelteRenderer"

echo ""
echo "Fixing supervisor.ex files..."
echo "-----------------------------"

# Fix supervisor files
fix_module "lib/raxol/core/core_supervisor.ex" \
    "Raxol.Core.Supervisor" \
    "Raxol.Core.CoreSupervisor"

fix_module "lib/raxol/runtime/runtime_supervisor.ex" \
    "Raxol.Runtime.Supervisor" \
    "Raxol.Runtime.RuntimeSupervisor"

fix_module "lib/raxol/terminal/terminal_supervisor.ex" \
    "Raxol.Terminal.Supervisor" \
    "Raxol.Terminal.TerminalSupervisor"

echo ""
echo "Fixing buffer.ex files..."
echo "-------------------------"

# Fix buffer files
fix_module "lib/raxol/terminal/buffer/buffer_core.ex" \
    "Raxol.Terminal.Buffer.Core" \
    "Raxol.Terminal.Buffer.BufferCore"

fix_module "lib/raxol/ui/components/list/list_buffer.ex" \
    "Raxol.UI.Components.List.Buffer" \
    "Raxol.UI.Components.List.ListBuffer"

echo ""
echo "Fixing config.ex files..."
echo "-------------------------"

fix_module "lib/raxol/raxol_config.ex" \
    "Raxol.Config" \
    "Raxol.RaxolConfig"

fix_module "lib/raxol/terminal/terminal_config.ex" \
    "Raxol.Terminal.Config" \
    "Raxol.Terminal.TerminalConfig"

fix_module "lib/raxol/cloud/cloud_config.ex" \
    "Raxol.Cloud.Config" \
    "Raxol.Cloud.CloudConfig"

echo ""
echo "Fixing validation.ex files..."
echo "-----------------------------"

# Fix validation files
for file in $(find lib/raxol -name "*_validation.ex"); do
    dir=$(dirname "$file")
    module_path=$(echo "$dir" | sed 's|lib/raxol/||' | sed 's|/|.|g' | awk -F. '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) substr($i,2)}}1' | sed 's/ /./g')
    base_name=$(basename "$file" .ex | sed 's/_validation/Validation/')
    
    old_module="Raxol.$module_path.Validation"
    new_module="Raxol.$module_path.${base_name//_/.}"
    new_module=$(echo "$new_module" | sed 's/\.\././g' | awk -F. '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) substr($i,2)}}1' | sed 's/ /./g')
    
    fix_module "$file" "$old_module" "$new_module"
done

echo ""
echo "Fixing types.ex files..."
echo "------------------------"

# Fix types files
for file in $(find lib/raxol -name "*_types.ex"); do
    dir=$(dirname "$file")
    module_path=$(echo "$dir" | sed 's|lib/raxol/||' | sed 's|/|.|g' | awk -F. '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) substr($i,2)}}1' | sed 's/ /./g')
    base_name=$(basename "$file" .ex | sed 's/_types/Types/')
    
    old_module="Raxol.$module_path.Types"
    new_module="Raxol.$module_path.${base_name//_/.}"
    new_module=$(echo "$new_module" | sed 's/\.\././g' | awk -F. '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) substr($i,2)}}1' | sed 's/ /./g')
    
    fix_module "$file" "$old_module" "$new_module"
done

echo ""
echo "Phase 3 Module Fixes Complete!"
echo "=============================="
echo ""
echo "Next steps:"
echo "1. Run 'mix compile' to verify all modules are fixed"
echo "2. Update references throughout the codebase"
echo "3. Run tests to ensure everything works"
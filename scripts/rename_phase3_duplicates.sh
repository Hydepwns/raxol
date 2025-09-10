#!/bin/bash

# Phase 3: Rename remaining duplicate files
# This script renames all duplicate file names to follow the pattern: <domain>_<function>.ex

echo "Phase 3: Renaming remaining duplicate files"
echo "==========================================="

# Function to rename a file and update its module name
rename_file_and_module() {
    local old_path=$1
    local new_name=$2
    local new_path=$(dirname "$old_path")/"$new_name"
    
    if [ -f "$old_path" ]; then
        echo "Renaming: $old_path -> $new_path"
        
        # Extract the module name components
        local dir_path=$(dirname "$old_path" | sed 's|lib/raxol/||' | sed 's|/|.|g' | sed 's|\.|\\.|g')
        local old_module_name=$(basename "$old_path" .ex | sed 's/_/./g' | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}' | sed 's/\.//')
        local new_module_name=$(basename "$new_name" .ex | sed 's/_/\./g' | awk -F. '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) tolower(substr($i,2))}}1' | sed 's/ //g')
        
        # Move the file
        git mv "$old_path" "$new_path" 2>/dev/null || mv "$old_path" "$new_path"
        
        # Update the module definition in the file
        if [ -f "$new_path" ]; then
            # Update defmodule line
            sed -i '' "s/defmodule.*${old_module_name}/defmodule Raxol.${dir_path}.${new_module_name}/" "$new_path" 2>/dev/null || true
        fi
    fi
}

# Function to update references across the codebase
update_references() {
    local old_module=$1
    local new_module=$2
    
    echo "  Updating references: $old_module -> $new_module"
    
    # Update in all Elixir files
    find lib test -name "*.ex" -o -name "*.exs" | while read -r file; do
        # Update alias statements
        sed -i '' "s/alias $old_module/alias $new_module/g" "$file" 2>/dev/null || true
        # Update direct references
        sed -i '' "s/$old_module/$new_module/g" "$file" 2>/dev/null || true
    done
}

echo ""
echo "Step 1: Renaming server.ex files (19 files)"
echo "--------------------------------------------"

# Rename server.ex files
rename_file_and_module "lib/raxol/ai/performance_optimization/server.ex" "optimization_server.ex"
rename_file_and_module "lib/raxol/animation/gestures/server.ex" "gesture_server.ex"
rename_file_and_module "lib/raxol/cloud/edge_computing/server.ex" "edge_server.ex"
rename_file_and_module "lib/raxol/cloud/monitoring/server.ex" "monitoring_server.ex"
rename_file_and_module "lib/raxol/core/accessibility/server.ex" "accessibility_server.ex"
rename_file_and_module "lib/raxol/core/events/manager/server.ex" "event_manager_server.ex"
rename_file_and_module "lib/raxol/core/focus_manager/server.ex" "focus_server.ex"
rename_file_and_module "lib/raxol/core/i18n/server.ex" "i18n_server.ex"
rename_file_and_module "lib/raxol/core/keyboard_navigator/server.ex" "navigator_server.ex"
rename_file_and_module "lib/raxol/core/keyboard_shortcuts/server.ex" "shortcuts_server.ex"
rename_file_and_module "lib/raxol/core/performance/memoization/server.ex" "memoization_server.ex"
rename_file_and_module "lib/raxol/core/ux_refinement/server.ex" "ux_server.ex"
rename_file_and_module "lib/raxol/security/user_context/server.ex" "context_server.ex"
rename_file_and_module "lib/raxol/style/colors/system/server.ex" "color_system_server.ex"
rename_file_and_module "lib/raxol/svelte/component_state/server.ex" "svelte_state_server.ex"
rename_file_and_module "lib/raxol/system/updater/state/server.ex" "updater_server.ex"
rename_file_and_module "lib/raxol/terminal/emulator/server.ex" "emulator_server.ex"
rename_file_and_module "lib/raxol/terminal/window/manager/server.ex" "window_manager_server.ex"
rename_file_and_module "lib/raxol/ui/state/management/server.ex" "state_management_server.ex"

echo ""
echo "Step 2: Renaming state.ex files (18 files)"
echo "-------------------------------------------"

# Find and rename state.ex files
find lib/raxol -name "state.ex" -type f | while read -r file; do
    dir=$(dirname "$file")
    parent_dir=$(basename "$dir")
    
    # Create descriptive name based on parent directory
    case "$parent_dir" in
        "ansi") new_name="ansi_state.ex" ;;
        "buffer") new_name="buffer_state.ex" ;;
        "cursor") new_name="cursor_state.ex" ;;
        "emulator") new_name="emulator_state.ex" ;;
        "parser") new_name="parser_state.ex" ;;
        "screen") new_name="screen_state.ex" ;;
        "selection") new_name="selection_state.ex" ;;
        "session") new_name="session_state.ex" ;;
        "terminal") new_name="terminal_state.ex" ;;
        "window") new_name="window_state.ex" ;;
        "clipboard") new_name="clipboard_state.ex" ;;
        "scroll") new_name="scroll_state.ex" ;;
        "tab") new_name="tab_state.ex" ;;
        "mouse") new_name="mouse_state.ex" ;;
        "input") new_name="input_state.ex" ;;
        "mode") new_name="mode_state.ex" ;;
        "theme") new_name="theme_state.ex" ;;
        *) new_name="${parent_dir}_state.ex" ;;
    esac
    
    rename_file_and_module "$file" "$new_name"
done

echo ""
echo "Step 3: Renaming handler.ex files (5 files)"
echo "--------------------------------------------"

# Find and rename handler.ex files
find lib/raxol -name "handler.ex" -type f | while read -r file; do
    dir=$(dirname "$file")
    parent_dir=$(basename "$dir")
    
    case "$parent_dir" in
        "error") new_name="error_handler.ex" ;;
        "event") new_name="event_handler.ex" ;;
        "command") new_name="command_handler.ex" ;;
        "message") new_name="message_handler.ex" ;;
        "request") new_name="request_handler.ex" ;;
        *) new_name="${parent_dir}_handler.ex" ;;
    esac
    
    rename_file_and_module "$file" "$new_name"
done

echo ""
echo "Step 4: Renaming buffer.ex files (7 files)"
echo "-------------------------------------------"

# Find and rename buffer.ex files
find lib/raxol -name "buffer.ex" -type f | while read -r file; do
    dir=$(dirname "$file")
    parent_dir=$(basename "$dir")
    grandparent_dir=$(basename "$(dirname "$dir")")
    
    if [ "$parent_dir" == "buffer" ]; then
        # Main buffer file in buffer directory
        new_name="buffer_core.ex"
    elif [ "$grandparent_dir" == "buffer" ]; then
        # Subdirectory of buffer
        new_name="${parent_dir}_buffer.ex"
    else
        # Buffer file in other locations
        new_name="${parent_dir}_buffer.ex"
    fi
    
    rename_file_and_module "$file" "$new_name"
done

echo ""
echo "Step 5: Renaming renderer.ex files (8 files)"
echo "----------------------------------------------"

# Find and rename renderer.ex files
find lib/raxol -name "renderer.ex" -type f | while read -r file; do
    dir=$(dirname "$file")
    parent_dir=$(basename "$dir")
    
    case "$parent_dir" in
        "renderer") new_name="renderer_core.ex" ;;
        "terminal") new_name="terminal_renderer.ex" ;;
        "ui") new_name="ui_renderer.ex" ;;
        "component") new_name="component_renderer.ex" ;;
        "react") new_name="react_renderer.ex" ;;
        "svelte") new_name="svelte_renderer.ex" ;;
        "live_view") new_name="liveview_renderer.ex" ;;
        *) new_name="${parent_dir}_renderer.ex" ;;
    esac
    
    rename_file_and_module "$file" "$new_name"
done

echo ""
echo "Step 6: Renaming core.ex files (13 files)"
echo "------------------------------------------"

# Find and rename core.ex files
find lib/raxol -name "core.ex" -type f | while read -r file; do
    dir=$(dirname "$file")
    parent_dir=$(basename "$dir")
    
    # Skip the main core.ex file
    if [ "$dir" == "lib/raxol/core" ]; then
        continue
    fi
    
    case "$parent_dir" in
        "animation") new_name="animation_core.ex" ;;
        "ui") new_name="ui_core.ex" ;;
        "terminal") new_name="terminal_core.ex" ;;
        "runtime") new_name="runtime_core.ex" ;;
        "system") new_name="system_core.ex" ;;
        "style") new_name="style_core.ex" ;;
        *) new_name="${parent_dir}_core.ex" ;;
    esac
    
    rename_file_and_module "$file" "$new_name"
done

echo ""
echo "Step 7: Renaming supervisor.ex files (6 files)"
echo "-----------------------------------------------"

# Find and rename supervisor.ex files
find lib/raxol -name "supervisor.ex" -type f | while read -r file; do
    dir=$(dirname "$file")
    parent_dir=$(basename "$dir")
    
    case "$parent_dir" in
        "core") new_name="core_supervisor.ex" ;;
        "runtime") new_name="runtime_supervisor.ex" ;;
        "terminal") new_name="terminal_supervisor.ex" ;;
        "ui") new_name="ui_supervisor.ex" ;;
        "web") new_name="web_supervisor.ex" ;;
        *) new_name="${parent_dir}_supervisor.ex" ;;
    esac
    
    rename_file_and_module "$file" "$new_name"
done

echo ""
echo "Step 8: Renaming types.ex files (4 files)"
echo "------------------------------------------"

# Find and rename types.ex files
find lib/raxol -name "types.ex" -type f | while read -r file; do
    dir=$(dirname "$file")
    parent_dir=$(basename "$dir")
    
    new_name="${parent_dir}_types.ex"
    rename_file_and_module "$file" "$new_name"
done

echo ""
echo "Step 9: Renaming validation.ex files (8 files)"
echo "-----------------------------------------------"

# Find and rename validation.ex files
find lib/raxol -name "validation.ex" -type f | while read -r file; do
    dir=$(dirname "$file")
    parent_dir=$(basename "$dir")
    
    new_name="${parent_dir}_validation.ex"
    rename_file_and_module "$file" "$new_name"
done

echo ""
echo "Step 10: Renaming config.ex files (6 files)"
echo "--------------------------------------------"

# Find and rename config.ex files
find lib/raxol -name "config.ex" -type f | while read -r file; do
    dir=$(dirname "$file")
    parent_dir=$(basename "$dir")
    
    new_name="${parent_dir}_config.ex"
    rename_file_and_module "$file" "$new_name"
done

echo ""
echo "Phase 3 Complete!"
echo "=================="
echo ""
echo "Summary:"
echo "- Renamed server.ex files (19)"
echo "- Renamed state.ex files (18)"  
echo "- Renamed handler.ex files (5)"
echo "- Renamed buffer.ex files (7)"
echo "- Renamed renderer.ex files (8)"
echo "- Renamed core.ex files (13)"
echo "- Renamed supervisor.ex files (6)"
echo "- Renamed types.ex files (4)"
echo "- Renamed validation.ex files (8)"
echo "- Renamed config.ex files (6)"
echo ""
echo "Next steps:"
echo "1. Run 'mix compile' to check for compilation errors"
echo "2. Run tests to verify everything works"
echo "3. Update any remaining broken references"
#!/bin/bash

# Phase 2: Rename terminal managers
# This script renames all manager.ex files in lib/raxol/terminal/ to follow the naming convention

set -e

echo "Phase 2: Renaming terminal managers..."

# Function to rename a manager file
rename_manager() {
  local old_path="$1"
  local new_name="$2"
  local dir=$(dirname "$old_path")
  local new_path="$dir/$new_name"
  
  if [ -f "$old_path" ]; then
    echo "Renaming $old_path -> $new_path"
    git mv "$old_path" "$new_path" || mv "$old_path" "$new_path"
    return 0
  fi
  return 1
}

# Rename each manager file
rename_manager "lib/raxol/terminal/buffer/manager.ex" "buffer_manager.ex"
rename_manager "lib/raxol/terminal/capabilities/manager.ex" "capabilities_manager.ex"
rename_manager "lib/raxol/terminal/charset/manager.ex" "charset_manager.ex"
rename_manager "lib/raxol/terminal/clipboard/manager.ex" "clipboard_manager.ex"
rename_manager "lib/raxol/terminal/color/manager.ex" "color_manager.ex"
rename_manager "lib/raxol/terminal/command/manager.ex" "command_manager.ex"
rename_manager "lib/raxol/terminal/config/manager.ex" "terminal_config_manager.ex"
rename_manager "lib/raxol/terminal/cursor/manager.ex" "cursor_manager.ex"
rename_manager "lib/raxol/terminal/extension/manager.ex" "extension_manager.ex"
rename_manager "lib/raxol/terminal/font/manager.ex" "font_manager.ex"
rename_manager "lib/raxol/terminal/formatting/manager.ex" "formatting_manager.ex"
rename_manager "lib/raxol/terminal/graphics/manager.ex" "graphics_manager.ex"
rename_manager "lib/raxol/terminal/hyperlink/manager.ex" "hyperlink_manager.ex"
rename_manager "lib/raxol/terminal/input/manager.ex" "input_manager.ex"
rename_manager "lib/raxol/terminal/manager.ex" "terminal_manager.ex"
rename_manager "lib/raxol/terminal/metrics/manager.ex" "metrics_manager.ex"
rename_manager "lib/raxol/terminal/mode/manager.ex" "mode_manager.ex"
rename_manager "lib/raxol/terminal/mouse/manager.ex" "mouse_manager.ex"
rename_manager "lib/raxol/terminal/output/manager.ex" "output_manager.ex"
rename_manager "lib/raxol/terminal/parser/state/manager.ex" "parser_state_manager.ex"
rename_manager "lib/raxol/terminal/plugin/manager.ex" "terminal_plugin_manager.ex"
rename_manager "lib/raxol/terminal/screen/manager.ex" "screen_manager.ex"
rename_manager "lib/raxol/terminal/scroll/manager.ex" "scroll_manager.ex"
rename_manager "lib/raxol/terminal/scrollback/manager.ex" "scrollback_manager.ex"
rename_manager "lib/raxol/terminal/selection/manager.ex" "selection_manager.ex"
rename_manager "lib/raxol/terminal/split/manager.ex" "split_manager.ex"
rename_manager "lib/raxol/terminal/state/manager.ex" "state_manager.ex"
rename_manager "lib/raxol/terminal/style/manager.ex" "style_manager.ex"
rename_manager "lib/raxol/terminal/sync/manager.ex" "sync_manager.ex"
rename_manager "lib/raxol/terminal/tab/manager.ex" "tab_manager.ex"
rename_manager "lib/raxol/terminal/terminal_state/manager.ex" "terminal_state_manager.ex"
rename_manager "lib/raxol/terminal/theme/manager.ex" "theme_manager.ex"
rename_manager "lib/raxol/terminal/window/manager.ex" "window_manager.ex"

echo "Phase 2 complete: All terminal managers renamed"
echo "Next step: Update module definitions and references"
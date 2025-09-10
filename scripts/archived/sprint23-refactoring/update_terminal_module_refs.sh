#!/bin/bash

# Update module definitions and references for renamed terminal managers

set -e

echo "Updating module definitions and references for terminal managers..."

# Step 1: Update module definitions in the renamed files
echo "Step 1: Updating module definitions..."

# Buffer
if [ -f "lib/raxol/terminal/buffer/buffer_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Buffer\.Manager/defmodule Raxol.Terminal.Buffer.BufferManager/g' lib/raxol/terminal/buffer/buffer_manager.ex
fi

# Capabilities
if [ -f "lib/raxol/terminal/capabilities/capabilities_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Capabilities\.Manager/defmodule Raxol.Terminal.Capabilities.CapabilitiesManager/g' lib/raxol/terminal/capabilities/capabilities_manager.ex
fi

# Charset
if [ -f "lib/raxol/terminal/charset/charset_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Charset\.Manager/defmodule Raxol.Terminal.Charset.CharsetManager/g' lib/raxol/terminal/charset/charset_manager.ex
fi

# Clipboard
if [ -f "lib/raxol/terminal/clipboard/clipboard_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Clipboard\.Manager/defmodule Raxol.Terminal.Clipboard.ClipboardManager/g' lib/raxol/terminal/clipboard/clipboard_manager.ex
fi

# Color
if [ -f "lib/raxol/terminal/color/color_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Color\.Manager/defmodule Raxol.Terminal.Color.ColorManager/g' lib/raxol/terminal/color/color_manager.ex
fi

# Command
if [ -f "lib/raxol/terminal/command/command_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Command\.Manager/defmodule Raxol.Terminal.Command.CommandManager/g' lib/raxol/terminal/command/command_manager.ex
fi

# Config
if [ -f "lib/raxol/terminal/config/terminal_config_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Config\.Manager/defmodule Raxol.Terminal.Config.TerminalConfigManager/g' lib/raxol/terminal/config/terminal_config_manager.ex
fi

# Cursor
if [ -f "lib/raxol/terminal/cursor/cursor_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Cursor\.Manager/defmodule Raxol.Terminal.Cursor.CursorManager/g' lib/raxol/terminal/cursor/cursor_manager.ex
fi

# Extension
if [ -f "lib/raxol/terminal/extension/extension_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Extension\.Manager/defmodule Raxol.Terminal.Extension.ExtensionManager/g' lib/raxol/terminal/extension/extension_manager.ex
fi

# Font
if [ -f "lib/raxol/terminal/font/font_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Font\.Manager/defmodule Raxol.Terminal.Font.FontManager/g' lib/raxol/terminal/font/font_manager.ex
fi

# Formatting
if [ -f "lib/raxol/terminal/formatting/formatting_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Formatting\.Manager/defmodule Raxol.Terminal.Formatting.FormattingManager/g' lib/raxol/terminal/formatting/formatting_manager.ex
fi

# Graphics
if [ -f "lib/raxol/terminal/graphics/graphics_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Graphics\.Manager/defmodule Raxol.Terminal.Graphics.GraphicsManager/g' lib/raxol/terminal/graphics/graphics_manager.ex
fi

# Hyperlink
if [ -f "lib/raxol/terminal/hyperlink/hyperlink_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Hyperlink\.Manager/defmodule Raxol.Terminal.Hyperlink.HyperlinkManager/g' lib/raxol/terminal/hyperlink/hyperlink_manager.ex
fi

# Input
if [ -f "lib/raxol/terminal/input/input_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Input\.Manager/defmodule Raxol.Terminal.Input.InputManager/g' lib/raxol/terminal/input/input_manager.ex
fi

# Terminal (root)
if [ -f "lib/raxol/terminal/terminal_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Manager/defmodule Raxol.Terminal.TerminalManager/g' lib/raxol/terminal/terminal_manager.ex
fi

# Metrics
if [ -f "lib/raxol/terminal/metrics/metrics_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Metrics\.Manager/defmodule Raxol.Terminal.Metrics.MetricsManager/g' lib/raxol/terminal/metrics/metrics_manager.ex
fi

# Mode
if [ -f "lib/raxol/terminal/mode/mode_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Mode\.Manager/defmodule Raxol.Terminal.Mode.ModeManager/g' lib/raxol/terminal/mode/mode_manager.ex
fi

# Mouse
if [ -f "lib/raxol/terminal/mouse/mouse_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Mouse\.Manager/defmodule Raxol.Terminal.Mouse.MouseManager/g' lib/raxol/terminal/mouse/mouse_manager.ex
fi

# Output
if [ -f "lib/raxol/terminal/output/output_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Output\.Manager/defmodule Raxol.Terminal.Output.OutputManager/g' lib/raxol/terminal/output/output_manager.ex
fi

# Parser State
if [ -f "lib/raxol/terminal/parser/state/parser_state_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Parser\.State\.Manager/defmodule Raxol.Terminal.Parser.State.ParserStateManager/g' lib/raxol/terminal/parser/state/parser_state_manager.ex
fi

# Plugin
if [ -f "lib/raxol/terminal/plugin/terminal_plugin_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Plugin\.Manager/defmodule Raxol.Terminal.Plugin.TerminalPluginManager/g' lib/raxol/terminal/plugin/terminal_plugin_manager.ex
fi

# Screen
if [ -f "lib/raxol/terminal/screen/screen_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Screen\.Manager/defmodule Raxol.Terminal.Screen.ScreenManager/g' lib/raxol/terminal/screen/screen_manager.ex
fi

# Scroll
if [ -f "lib/raxol/terminal/scroll/scroll_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Scroll\.Manager/defmodule Raxol.Terminal.Scroll.ScrollManager/g' lib/raxol/terminal/scroll/scroll_manager.ex
fi

# Scrollback
if [ -f "lib/raxol/terminal/scrollback/scrollback_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Scrollback\.Manager/defmodule Raxol.Terminal.Scrollback.ScrollbackManager/g' lib/raxol/terminal/scrollback/scrollback_manager.ex
fi

# Selection
if [ -f "lib/raxol/terminal/selection/selection_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Selection\.Manager/defmodule Raxol.Terminal.Selection.SelectionManager/g' lib/raxol/terminal/selection/selection_manager.ex
fi

# Split
if [ -f "lib/raxol/terminal/split/split_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Split\.Manager/defmodule Raxol.Terminal.Split.SplitManager/g' lib/raxol/terminal/split/split_manager.ex
fi

# State
if [ -f "lib/raxol/terminal/state/state_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.State\.Manager/defmodule Raxol.Terminal.State.StateManager/g' lib/raxol/terminal/state/state_manager.ex
fi

# Style
if [ -f "lib/raxol/terminal/style/style_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Style\.Manager/defmodule Raxol.Terminal.Style.StyleManager/g' lib/raxol/terminal/style/style_manager.ex
fi

# Sync
if [ -f "lib/raxol/terminal/sync/sync_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Sync\.Manager/defmodule Raxol.Terminal.Sync.SyncManager/g' lib/raxol/terminal/sync/sync_manager.ex
fi

# Tab
if [ -f "lib/raxol/terminal/tab/tab_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Tab\.Manager/defmodule Raxol.Terminal.Tab.TabManager/g' lib/raxol/terminal/tab/tab_manager.ex
fi

# Terminal State
if [ -f "lib/raxol/terminal/terminal_state/terminal_state_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.TerminalState\.Manager/defmodule Raxol.Terminal.TerminalState.TerminalStateManager/g' lib/raxol/terminal/terminal_state/terminal_state_manager.ex
fi

# Theme
if [ -f "lib/raxol/terminal/theme/theme_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Theme\.Manager/defmodule Raxol.Terminal.Theme.ThemeManager/g' lib/raxol/terminal/theme/theme_manager.ex
fi

# Window
if [ -f "lib/raxol/terminal/window/window_manager.ex" ]; then
  sed -i '' 's/defmodule Raxol\.Terminal\.Window\.Manager/defmodule Raxol.Terminal.Window.WindowManager/g' lib/raxol/terminal/window/window_manager.ex
fi

echo "Step 1 complete: Module definitions updated"

# Step 2: Update all references across the codebase
echo "Step 2: Updating references across codebase..."

# Update alias statements
find lib test -name "*.ex" -o -name "*.exs" | while read file; do
  # Buffer
  sed -i '' 's/alias Raxol\.Terminal\.Buffer\.Manager/alias Raxol.Terminal.Buffer.BufferManager/' "$file"
  sed -i '' 's/Terminal\.Buffer\.Manager/Terminal.Buffer.BufferManager/g' "$file"
  
  # Capabilities
  sed -i '' 's/alias Raxol\.Terminal\.Capabilities\.Manager/alias Raxol.Terminal.Capabilities.CapabilitiesManager/' "$file"
  sed -i '' 's/Terminal\.Capabilities\.Manager/Terminal.Capabilities.CapabilitiesManager/g' "$file"
  
  # Charset
  sed -i '' 's/alias Raxol\.Terminal\.Charset\.Manager/alias Raxol.Terminal.Charset.CharsetManager/' "$file"
  sed -i '' 's/Terminal\.Charset\.Manager/Terminal.Charset.CharsetManager/g' "$file"
  
  # Clipboard
  sed -i '' 's/alias Raxol\.Terminal\.Clipboard\.Manager/alias Raxol.Terminal.Clipboard.ClipboardManager/' "$file"
  sed -i '' 's/Terminal\.Clipboard\.Manager/Terminal.Clipboard.ClipboardManager/g' "$file"
  
  # Color
  sed -i '' 's/alias Raxol\.Terminal\.Color\.Manager/alias Raxol.Terminal.Color.ColorManager/' "$file"
  sed -i '' 's/Terminal\.Color\.Manager/Terminal.Color.ColorManager/g' "$file"
  
  # Command
  sed -i '' 's/alias Raxol\.Terminal\.Command\.Manager/alias Raxol.Terminal.Command.CommandManager/' "$file"
  sed -i '' 's/Terminal\.Command\.Manager/Terminal.Command.CommandManager/g' "$file"
  
  # Config
  sed -i '' 's/alias Raxol\.Terminal\.Config\.Manager/alias Raxol.Terminal.Config.TerminalConfigManager/' "$file"
  sed -i '' 's/Terminal\.Config\.Manager/Terminal.Config.TerminalConfigManager/g' "$file"
  
  # Cursor
  sed -i '' 's/alias Raxol\.Terminal\.Cursor\.Manager/alias Raxol.Terminal.Cursor.CursorManager/' "$file"
  sed -i '' 's/Terminal\.Cursor\.Manager/Terminal.Cursor.CursorManager/g' "$file"
  
  # Extension
  sed -i '' 's/alias Raxol\.Terminal\.Extension\.Manager/alias Raxol.Terminal.Extension.ExtensionManager/' "$file"
  sed -i '' 's/Terminal\.Extension\.Manager/Terminal.Extension.ExtensionManager/g' "$file"
  
  # Font
  sed -i '' 's/alias Raxol\.Terminal\.Font\.Manager/alias Raxol.Terminal.Font.FontManager/' "$file"
  sed -i '' 's/Terminal\.Font\.Manager/Terminal.Font.FontManager/g' "$file"
  
  # Formatting
  sed -i '' 's/alias Raxol\.Terminal\.Formatting\.Manager/alias Raxol.Terminal.Formatting.FormattingManager/' "$file"
  sed -i '' 's/Terminal\.Formatting\.Manager/Terminal.Formatting.FormattingManager/g' "$file"
  
  # Graphics
  sed -i '' 's/alias Raxol\.Terminal\.Graphics\.Manager/alias Raxol.Terminal.Graphics.GraphicsManager/' "$file"
  sed -i '' 's/Terminal\.Graphics\.Manager/Terminal.Graphics.GraphicsManager/g' "$file"
  
  # Hyperlink
  sed -i '' 's/alias Raxol\.Terminal\.Hyperlink\.Manager/alias Raxol.Terminal.Hyperlink.HyperlinkManager/' "$file"
  sed -i '' 's/Terminal\.Hyperlink\.Manager/Terminal.Hyperlink.HyperlinkManager/g' "$file"
  
  # Input
  sed -i '' 's/alias Raxol\.Terminal\.Input\.Manager/alias Raxol.Terminal.Input.InputManager/' "$file"
  sed -i '' 's/Terminal\.Input\.Manager/Terminal.Input.InputManager/g' "$file"
  
  # Terminal (root)
  sed -i '' 's/alias Raxol\.Terminal\.Manager/alias Raxol.Terminal.TerminalManager/' "$file"
  # Be careful with this one to avoid double replacements
  sed -i '' 's/\([^.]\)Terminal\.Manager/\1Terminal.TerminalManager/g' "$file"
  
  # Metrics
  sed -i '' 's/alias Raxol\.Terminal\.Metrics\.Manager/alias Raxol.Terminal.Metrics.MetricsManager/' "$file"
  sed -i '' 's/Terminal\.Metrics\.Manager/Terminal.Metrics.MetricsManager/g' "$file"
  
  # Mode
  sed -i '' 's/alias Raxol\.Terminal\.Mode\.Manager/alias Raxol.Terminal.Mode.ModeManager/' "$file"
  sed -i '' 's/Terminal\.Mode\.Manager/Terminal.Mode.ModeManager/g' "$file"
  
  # Mouse
  sed -i '' 's/alias Raxol\.Terminal\.Mouse\.Manager/alias Raxol.Terminal.Mouse.MouseManager/' "$file"
  sed -i '' 's/Terminal\.Mouse\.Manager/Terminal.Mouse.MouseManager/g' "$file"
  
  # Output
  sed -i '' 's/alias Raxol\.Terminal\.Output\.Manager/alias Raxol.Terminal.Output.OutputManager/' "$file"
  sed -i '' 's/Terminal\.Output\.Manager/Terminal.Output.OutputManager/g' "$file"
  
  # Parser State
  sed -i '' 's/alias Raxol\.Terminal\.Parser\.State\.Manager/alias Raxol.Terminal.Parser.State.ParserStateManager/' "$file"
  sed -i '' 's/Parser\.State\.Manager/Parser.State.ParserStateManager/g' "$file"
  
  # Plugin
  sed -i '' 's/alias Raxol\.Terminal\.Plugin\.Manager/alias Raxol.Terminal.Plugin.TerminalPluginManager/' "$file"
  sed -i '' 's/Terminal\.Plugin\.Manager/Terminal.Plugin.TerminalPluginManager/g' "$file"
  
  # Screen
  sed -i '' 's/alias Raxol\.Terminal\.Screen\.Manager/alias Raxol.Terminal.Screen.ScreenManager/' "$file"
  sed -i '' 's/Terminal\.Screen\.Manager/Terminal.Screen.ScreenManager/g' "$file"
  
  # Scroll
  sed -i '' 's/alias Raxol\.Terminal\.Scroll\.Manager/alias Raxol.Terminal.Scroll.ScrollManager/' "$file"
  sed -i '' 's/Terminal\.Scroll\.Manager/Terminal.Scroll.ScrollManager/g' "$file"
  
  # Scrollback
  sed -i '' 's/alias Raxol\.Terminal\.Scrollback\.Manager/alias Raxol.Terminal.Scrollback.ScrollbackManager/' "$file"
  sed -i '' 's/Terminal\.Scrollback\.Manager/Terminal.Scrollback.ScrollbackManager/g' "$file"
  
  # Selection
  sed -i '' 's/alias Raxol\.Terminal\.Selection\.Manager/alias Raxol.Terminal.Selection.SelectionManager/' "$file"
  sed -i '' 's/Terminal\.Selection\.Manager/Terminal.Selection.SelectionManager/g' "$file"
  
  # Split
  sed -i '' 's/alias Raxol\.Terminal\.Split\.Manager/alias Raxol.Terminal.Split.SplitManager/' "$file"
  sed -i '' 's/Terminal\.Split\.Manager/Terminal.Split.SplitManager/g' "$file"
  
  # State
  sed -i '' 's/alias Raxol\.Terminal\.State\.Manager/alias Raxol.Terminal.State.StateManager/' "$file"
  sed -i '' 's/Terminal\.State\.Manager/Terminal.State.StateManager/g' "$file"
  
  # Style
  sed -i '' 's/alias Raxol\.Terminal\.Style\.Manager/alias Raxol.Terminal.Style.StyleManager/' "$file"
  sed -i '' 's/Terminal\.Style\.Manager/Terminal.Style.StyleManager/g' "$file"
  
  # Sync
  sed -i '' 's/alias Raxol\.Terminal\.Sync\.Manager/alias Raxol.Terminal.Sync.SyncManager/' "$file"
  sed -i '' 's/Terminal\.Sync\.Manager/Terminal.Sync.SyncManager/g' "$file"
  
  # Tab
  sed -i '' 's/alias Raxol\.Terminal\.Tab\.Manager/alias Raxol.Terminal.Tab.TabManager/' "$file"
  sed -i '' 's/Terminal\.Tab\.Manager/Terminal.Tab.TabManager/g' "$file"
  
  # Terminal State
  sed -i '' 's/alias Raxol\.Terminal\.TerminalState\.Manager/alias Raxol.Terminal.TerminalState.TerminalStateManager/' "$file"
  sed -i '' 's/Terminal\.TerminalState\.Manager/Terminal.TerminalState.TerminalStateManager/g' "$file"
  
  # Theme
  sed -i '' 's/alias Raxol\.Terminal\.Theme\.Manager/alias Raxol.Terminal.Theme.ThemeManager/' "$file"
  sed -i '' 's/Terminal\.Theme\.Manager/Terminal.Theme.ThemeManager/g' "$file"
  
  # Window
  sed -i '' 's/alias Raxol\.Terminal\.Window\.Manager/alias Raxol.Terminal.Window.WindowManager/' "$file"
  sed -i '' 's/Terminal\.Window\.Manager/Terminal.Window.WindowManager/g' "$file"
done

echo "Step 2 complete: References updated"
echo "Phase 2 Terminal Manager rename complete!"
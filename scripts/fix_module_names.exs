#!/usr/bin/env elixir

files_to_fix = [
  "lib/raxol/core/focus_manager.ex",
  "lib/raxol/core/keyboard_navigator.ex", 
  "lib/raxol/core/keyboard_shortcuts.ex",
  "lib/raxol/core/ux_refinement.ex",
  "lib/raxol/ui/state/store.ex",
  "lib/raxol/ui/state/hooks.ex",
  "lib/raxol/animation/state_manager.ex"
]

# Fixes for module names  
fixes = [
  {"defmodule Raxol.Core.FocusManager", "defmodule Raxol.Core.FocusManager"},
  {"defmodule Raxol.Core.KeyboardNavigator", "defmodule Raxol.Core.KeyboardNavigator"},  
  {"defmodule Raxol.Core.KeyboardShortcuts", "defmodule Raxol.Core.KeyboardShortcuts"},
  {"defmodule Raxol.Core.UXRefinement", "defmodule Raxol.Core.UXRefinement"},
  {"defmodule Raxol.UI.State.Store", "defmodule Raxol.UI.State.Store"},
  {"defmodule Raxol.UI.State.Hooks", "defmodule Raxol.UI.State.Hooks"},
  {"defmodule Raxol.Animation.StateManager", "defmodule Raxol.Animation.StateManager"}
]

Enum.each(files_to_fix, fn file ->
  if File.exists?(file) do
    content = File.read!(file)
    
    new_content = Enum.reduce(fixes, content, fn {old, new}, acc ->
      String.replace(acc, old, new)
    end)
    
    if new_content != content do
      File.write!(file, new_content) 
      IO.puts("✅ Fixed module name in #{file}")
    end
  end
end)

IO.puts("✅ Module name fixes complete!")
#!/usr/bin/env elixir

defmodule MigrateToRefactored do
  @moduledoc """
  Script to migrate from Process dictionary-based modules to GenServer-based refactored versions.
  """
  
  @migrations %{
    # Core modules
    "Raxol.Core.UXRefinement" => "Raxol.Core.UXRefinementRefactored",
    "Raxol.Core.I18n" => "Raxol.Core.I18nRefactored",
    "Raxol.Core.FocusManager" => "Raxol.Core.FocusManagerRefactored",
    "Raxol.Core.Accessibility" => "Raxol.Core.AccessibilityRefactored",
    "Raxol.Core.KeyboardNavigator" => "Raxol.Core.KeyboardNavigatorRefactored",
    "Raxol.Core.KeyboardShortcuts" => "Raxol.Core.KeyboardShortcutsRefactored",
    "Raxol.Core.Events.EventManager" => "Raxol.Core.Events.EventManagerRefactored",
    "Raxol.Core.Performance.Optimizer" => "Raxol.Core.Performance.OptimizerRefactored",
    
    # UI modules
    "Raxol.UI.State.Store" => "Raxol.UI.State.StoreRefactored",
    "Raxol.UI.State.Hooks" => "Raxol.UI.State.HooksRefactored",
    
    # Animation modules
    "Raxol.Animation.StateManager" => "Raxol.Animation.StateManagerRefactored",
    "Raxol.Animation.Gestures" => "Raxol.Animation.GesturesRefactored",
    
    # Terminal modules
    "Raxol.Terminal.Window.Manager" => "Raxol.Terminal.Window.ManagerRefactored",
    
    # Svelte modules
    "Raxol.Svelte.Slots" => "Raxol.Svelte.SlotsRefactored",
    
    # Security modules
    "Raxol.Security.UserContext" => "Raxol.Security.UserContextRefactored",
    
    # Aliases - replace with as: aliasing to maintain compatibility
    "alias Raxol.Core.UXRefinement" => "alias Raxol.Core.UXRefinementRefactored, as: UXRefinement",
    "alias Raxol.Core.I18n" => "alias Raxol.Core.I18nRefactored, as: I18n",
    "alias Raxol.Core.FocusManager" => "alias Raxol.Core.FocusManagerRefactored, as: FocusManager",
    "alias Raxol.Core.Accessibility" => "alias Raxol.Core.AccessibilityRefactored, as: Accessibility",
    "alias Raxol.Core.KeyboardNavigator" => "alias Raxol.Core.KeyboardNavigatorRefactored, as: KeyboardNavigator",
    "alias Raxol.Core.KeyboardShortcuts" => "alias Raxol.Core.KeyboardShortcutsRefactored, as: KeyboardShortcuts",
    "alias Raxol.Core.Events.EventManager" => "alias Raxol.Core.Events.EventManagerRefactored, as: Manager",
    "alias Raxol.Core.Performance.Optimizer" => "alias Raxol.Core.Performance.OptimizerRefactored, as: Optimizer",
    "alias Raxol.UI.State.Store" => "alias Raxol.UI.State.StoreRefactored, as: Store",
    "alias Raxol.UI.State.Hooks" => "alias Raxol.UI.State.HooksRefactored, as: Hooks",
    "alias Raxol.Animation.StateManager" => "alias Raxol.Animation.StateManagerRefactored, as: StateManager",
    "alias Raxol.Animation.Gestures" => "alias Raxol.Animation.GesturesRefactored, as: Gestures",
    "alias Raxol.Terminal.Window.Manager" => "alias Raxol.Terminal.Window.ManagerRefactored, as: Manager",
    "alias Raxol.Svelte.Slots" => "alias Raxol.Svelte.SlotsRefactored, as: Slots",
    "alias Raxol.Security.UserContext" => "alias Raxol.Security.UserContextRefactored, as: UserContext"
  }
  
  def run(mode \\ :dry_run) do
    IO.puts("\n🔄 Migration to Refactored Modules")
    IO.puts("=" |> String.duplicate(50))
    
    files = find_files_to_migrate()
    
    IO.puts("\n📊 Files to migrate: #{length(files)}")
    
    case mode do
      :dry_run ->
        IO.puts("\n🔍 DRY RUN - No files will be modified")
        Enum.each(files, &analyze_file/1)
        
      :apply ->
        IO.puts("\n⚠️  APPLYING MIGRATIONS - Files will be modified!")
        IO.puts("Press Enter to continue or Ctrl+C to abort...")
        IO.gets("")
        
        Enum.each(files, &migrate_file/1)
        
        IO.puts("\n✅ Migration complete!")
        IO.puts("\nNext steps:")
        IO.puts("1. All GenServers should already be added to the RefactoredSupervisor")
        IO.puts("2. Run tests to verify everything works: mix test")
        IO.puts("3. Check Process dictionary usage: rg 'Process\\.(get|put)' lib/")
        IO.puts("4. Remove old modules when confident (they're backed up as .backup files)")
        IO.puts("\nGenServers that should be running:")
        IO.puts("   - Raxol.Core.UXRefinement.Server")
        IO.puts("   - Raxol.Core.I18n.Server") 
        IO.puts("   - Raxol.Core.FocusManager.Server")
        IO.puts("   - Raxol.Core.Accessibility.Server")
        IO.puts("   - Raxol.Core.KeyboardNavigator.Server")
        IO.puts("   - Raxol.Core.KeyboardShortcuts.Server")
        IO.puts("   - And 8 more servers...")
    end
  end
  
  defp find_files_to_migrate do
    Path.wildcard("{lib,test,docs}/**/*.{ex,exs}")
    |> Enum.reject(&String.contains?(&1, "_build"))
    |> Enum.reject(&String.contains?(&1, "deps"))
    |> Enum.reject(&String.contains?(&1, "_refactored"))
    |> Enum.reject(&String.contains?(&1, "/server.ex"))
    |> Enum.filter(&file_needs_migration?/1)
  end
  
  defp file_needs_migration?(file) do
    content = File.read!(file)
    
    Enum.any?(@migrations, fn {pattern, _} ->
      String.contains?(content, pattern)
    end)
  end
  
  defp analyze_file(file) do
    content = File.read!(file)
    
    migrations_needed = 
      @migrations
      |> Enum.filter(fn {pattern, _} ->
        String.contains?(content, pattern)
      end)
      |> Enum.map(fn {pattern, _} ->
        count = content |> String.split(pattern) |> length() |> Kernel.-(1)
        {pattern, count}
      end)
    
    if length(migrations_needed) > 0 do
      IO.puts("\n📄 #{file}")
      Enum.each(migrations_needed, fn {pattern, count} ->
        IO.puts("   #{count}x #{pattern}")
      end)
    end
  end
  
  defp migrate_file(file) do
    original_content = File.read!(file)
    
    new_content = 
      Enum.reduce(@migrations, original_content, fn {pattern, replacement}, content ->
        String.replace(content, pattern, replacement)
      end)
    
    if new_content != original_content do
      # Backup original
      File.write!("#{file}.backup", original_content)
      
      # Write migrated version
      File.write!(file, new_content)
      
      IO.puts("✅ Migrated: #{file}")
      IO.puts("   Backup: #{file}.backup")
    end
  end
end

# Parse command line arguments
mode = case System.argv() do
  ["apply"] -> :apply
  ["--apply"] -> :apply
  _ -> :dry_run
end

MigrateToRefactored.run(mode)
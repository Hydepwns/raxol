#!/usr/bin/env elixir

# Script to refactor module names for consistency
# Usage: elixir scripts/refactor_module_names.exs [--dry-run]

defmodule ModuleRefactor do
  @handlers_to_handler [
    # Terminal Commands
    {"Raxol.Terminal.Commands.CSIHandlers",
     "Raxol.Terminal.Commands.CSIHandler"},
    {"Raxol.Terminal.Commands.BufferHandlers",
     "Raxol.Terminal.Commands.BufferHandler"},
    {"Raxol.Terminal.Commands.WindowHandlers",
     "Raxol.Terminal.Commands.WindowHandler"},
    {"Raxol.Terminal.Commands.EraseHandlers",
     "Raxol.Terminal.Commands.EraseHandler"},
    {"Raxol.Terminal.Commands.OSCHandlers",
     "Raxol.Terminal.Commands.OSCHandler"},
    {"Raxol.Terminal.Commands.DCSHandlers",
     "Raxol.Terminal.Commands.DCSHandler"},
    {"Raxol.Terminal.Commands.CursorHandlers",
     "Raxol.Terminal.Commands.CursorHandler"},
    {"Raxol.Terminal.Commands.DeviceHandlers",
     "Raxol.Terminal.Commands.DeviceHandler"},
    {"Raxol.Terminal.Commands.ModeHandlers",
     "Raxol.Terminal.Commands.ModeHandler"},

    # Terminal Events
    {"Raxol.Terminal.Events.Handlers", "Raxol.Terminal.Events.Handler"},
    {"Raxol.Terminal.CursorHandlers", "Raxol.Terminal.CursorHandler"},
    {"Raxol.Terminal.ModeHandlers", "Raxol.Terminal.ModeHandler"},
    {"Raxol.Terminal.Buffer.Handlers", "Raxol.Terminal.Buffer.Handler"},
    {"Raxol.Terminal.ANSI.SequenceHandlers",
     "Raxol.Terminal.ANSI.SequenceHandler"},
    {"Raxol.Terminal.Emulator.CommandHandlers",
     "Raxol.Terminal.Emulator.CommandHandler"},

    # Core
    {"Raxol.Core.Accessibility.EventHandlers",
     "Raxol.Core.Accessibility.EventHandler"},
    {"Raxol.Core.Runtime.Events.Handlers", "Raxol.Core.Runtime.Events.Handler"},
    {"Raxol.Core.Runtime.Plugins.Manager.EventHandlers",
     "Raxol.Core.Runtime.Plugins.Manager.EventHandler"},

    # CSI Handlers submodules
    {"Raxol.Terminal.Commands.CSIHandlers.WindowHandlers",
     "Raxol.Terminal.Commands.CSIHandler.WindowHandler"},
    {"Raxol.Terminal.Commands.CSIHandlers.ModeHandlers",
     "Raxol.Terminal.Commands.CSIHandler.ModeHandler"},
    {"Raxol.Terminal.Commands.CSIHandlers.CharsetHandlers",
     "Raxol.Terminal.Commands.CSIHandler.CharsetHandler"},
    {"Raxol.Terminal.Commands.CSIHandlers.TextHandlers",
     "Raxol.Terminal.Commands.CSIHandler.TextHandler"},
    {"Raxol.Terminal.Commands.CSIHandlers.SGRHandler",
     "Raxol.Terminal.Commands.CSIHandler.SGRHandler"},
    {"Raxol.Terminal.Commands.CSIHandlers.ScreenHandlers",
     "Raxol.Terminal.Commands.CSIHandler.ScreenHandler"},
    {"Raxol.Terminal.Commands.CSIHandlers.DeviceHandlers",
     "Raxol.Terminal.Commands.CSIHandler.DeviceHandler"},
    {"Raxol.Terminal.Commands.CSIHandlers.ApplyHandlers",
     "Raxol.Terminal.Commands.CSIHandler.ApplyHandler"},

    # OSC Handlers submodules
    {"Raxol.Terminal.Commands.OSCHandlers.Window",
     "Raxol.Terminal.Commands.OSCHandler.Window"},
    {"Raxol.Terminal.Commands.OSCHandlers.Cursor",
     "Raxol.Terminal.Commands.OSCHandler.Cursor"},
    {"Raxol.Terminal.Commands.OSCHandlers.SelectionParser",
     "Raxol.Terminal.Commands.OSCHandler.SelectionParser"},
    {"Raxol.Terminal.Commands.OSCHandlers.FontParser",
     "Raxol.Terminal.Commands.OSCHandler.FontParser"},
    {"Raxol.Terminal.Commands.OSCHandlers.ColorParser",
     "Raxol.Terminal.Commands.OSCHandler.ColorParser"},
    {"Raxol.Terminal.Commands.OSCHandlers.HyperlinkParser",
     "Raxol.Terminal.Commands.OSCHandler.HyperlinkParser"},
    {"Raxol.Terminal.Commands.OSCHandlers.ColorPalette",
     "Raxol.Terminal.Commands.OSCHandler.ColorPalette"},
    {"Raxol.Terminal.Commands.OSCHandlers.Clipboard",
     "Raxol.Terminal.Commands.OSCHandler.Clipboard"},
    {"Raxol.Terminal.Commands.OSCHandlers.Selection",
     "Raxol.Terminal.Commands.OSCHandler.Selection"},
    {"Raxol.Terminal.Commands.OSCHandlers.Color",
     "Raxol.Terminal.Commands.OSCHandler.Color"},

    # Modes Handlers
    {"Raxol.Terminal.Modes.Handlers.MouseHandler",
     "Raxol.Terminal.Modes.Handler.MouseHandler"},
    {"Raxol.Terminal.Modes.Handlers.StandardHandler",
     "Raxol.Terminal.Modes.Handler.StandardHandler"},
    {"Raxol.Terminal.Modes.Handlers.ScreenBufferHandler",
     "Raxol.Terminal.Modes.Handler.ScreenBufferHandler"},
    {"Raxol.Terminal.Modes.Handlers.DECPrivateHandler",
     "Raxol.Terminal.Modes.Handler.DECPrivateHandler"}
  ]

  @helpers_to_helper [
    {"Raxol.Terminal.Buffer.Helpers", "Raxol.Terminal.Buffer.Helper"},
    {"Raxol.Terminal.Emulator.Helpers", "Raxol.Terminal.Emulator.Helper"},
    {"Raxol.Terminal.Buffer.GenServerHelpers",
     "Raxol.Terminal.Buffer.GenServerHelper"},
    {"Raxol.Terminal.Cache.EvictionHelpers",
     "Raxol.Terminal.Cache.EvictionHelper"},
    {"RaxolWeb.ErrorHelpers", "RaxolWeb.ErrorHelper"},
    {"Raxol.AccessibilityTestHelpers", "Raxol.AccessibilityTestHelper"},
    {"Raxol.ComponentTestHelpers", "Raxol.ComponentTestHelper"},
    {"Raxol.I18nTestHelpers", "Raxol.I18nTestHelper"},
    {"Raxol.Test.EventHelpers", "Raxol.Test.EventHelper"},
    {"Raxol.Test.AssertionHelpers", "Raxol.Test.AssertionHelper"},
    {"Raxol.Test.EmulatorHelpers", "Raxol.Test.EmulatorHelper"}
  ]

  def run(args) do
    dry_run = "--dry-run" in args

    IO.puts(
      "Starting module refactoring#{if dry_run, do: " (DRY RUN)", else: ""}..."
    )

    IO.puts("")

    # Combine all renamings
    all_renamings = @handlers_to_handler ++ @helpers_to_helper

    # Process each renaming
    Enum.each(all_renamings, fn {old_name, new_name} ->
      process_renaming(old_name, new_name, dry_run)
    end)

    # Fix missing namespace
    fix_missing_namespace(dry_run)

    IO.puts("\nRefactoring complete!")

    unless dry_run do
      IO.puts("\nIMPORTANT: Please run the following commands:")
      IO.puts("  mix compile --force")
      IO.puts("  mix test")
    end
  end

  defp process_renaming(old_module, new_module, dry_run) do
    old_path = module_to_path(old_module)
    new_path = module_to_path(new_module)

    # Check if old file exists
    if File.exists?(old_path) do
      IO.puts("Processing: #{old_module} -> #{new_module}")

      unless dry_run do
        # Read the file
        content = File.read!(old_path)

        # Replace module declaration
        updated_content =
          String.replace(
            content,
            "defmodule #{old_module}",
            "defmodule #{new_module}"
          )

        # Create new directory if needed
        new_dir = Path.dirname(new_path)
        File.mkdir_p!(new_dir)

        # Write to new file
        File.write!(new_path, updated_content)

        # Delete old file if it's different from new path
        if old_path != new_path do
          File.rm!(old_path)
          IO.puts("  ✓ Renamed file: #{old_path} -> #{new_path}")
        else
          IO.puts("  ✓ Updated module name in: #{old_path}")
        end

        # Update all references in the codebase
        update_references(old_module, new_module)
      else
        IO.puts("  Would rename: #{old_path} -> #{new_path}")
      end
    else
      IO.puts("  ⚠ File not found: #{old_path}")
    end
  end

  defp fix_missing_namespace(dry_run) do
    path = "lib/raxol/terminal/event_handlers.ex"

    if File.exists?(path) do
      IO.puts("\nFixing missing namespace in #{path}")

      unless dry_run do
        content = File.read!(path)

        updated_content =
          String.replace(
            content,
            "defmodule EventHandlers",
            "defmodule Raxol.Terminal.EventHandlers"
          )

        File.write!(path, updated_content)

        # Update references from EventHandlers to Raxol.Terminal.EventHandlers
        update_references("EventHandlers", "Raxol.Terminal.EventHandlers")
        IO.puts("  ✓ Fixed namespace")
      else
        IO.puts(
          "  Would fix namespace: EventHandlers -> Raxol.Terminal.EventHandlers"
        )
      end
    end
  end

  defp update_references(old_module, new_module) do
    # Get all Elixir files
    files =
      Path.wildcard("lib/**/*.ex") ++
        Path.wildcard("lib/**/*.exs") ++
        Path.wildcard("test/**/*.ex") ++ Path.wildcard("test/**/*.exs")

    Enum.each(files, fn file ->
      content = File.read!(file)

      # Check if file contains reference to old module
      if String.contains?(content, old_module) do
        # Replace module references
        updated =
          content
          |> String.replace("alias #{old_module}", "alias #{new_module}")
          |> String.replace("#{old_module}.", "#{new_module}.")
          |> String.replace("&#{old_module}.", "&#{new_module}.")
          |> String.replace(
            "@behaviour #{old_module}",
            "@behaviour #{new_module}"
          )
          |> String.replace("use #{old_module}", "use #{new_module}")
          |> String.replace("import #{old_module}", "import #{new_module}")

        if updated != content do
          File.write!(file, updated)
          IO.puts("    Updated references in: #{file}")
        end
      end
    end)
  end

  defp module_to_path(module_name) do
    # Convert module name to file path
    # Raxol.Terminal.Commands.CSIHandlers -> lib/raxol/terminal/commands/csi_handlers.ex

    parts = String.split(module_name, ".")

    path =
      case parts do
        ["Raxol" | rest] ->
          "lib/raxol/" <> Enum.map_join(rest, "/", &Macro.underscore/1)

        ["RaxolWeb" | rest] ->
          "lib/raxol_web/" <> Enum.map_join(rest, "/", &Macro.underscore/1)

        _ ->
          Enum.map_join(parts, "/", &Macro.underscore/1)
      end

    path <> ".ex"
  end
end

# Run the script
ModuleRefactor.run(System.argv())

#!/usr/bin/env elixir

# Script to fix remaining references after module renaming

defmodule FixReferences do
  @replacements [
    # Main modules
    {"Raxol.Terminal.Commands.CSIHandlers",
     "Raxol.Terminal.Commands.CSIHandler"},
    {"Raxol.Terminal.Commands.OSCHandlers",
     "Raxol.Terminal.Commands.OSCHandler"},
    {"Raxol.Terminal.Commands.DCSHandlers",
     "Raxol.Terminal.Commands.DCSHandler"},
    {"Raxol.Terminal.Commands.BufferHandlers",
     "Raxol.Terminal.Commands.BufferHandler"},
    {"Raxol.Terminal.Commands.WindowHandlers",
     "Raxol.Terminal.Commands.WindowHandler"},
    {"Raxol.Terminal.Commands.CursorHandlers",
     "Raxol.Terminal.Commands.CursorHandler"},
    {"Raxol.Terminal.Commands.EraseHandlers",
     "Raxol.Terminal.Commands.EraseHandler"},
    {"Raxol.Terminal.Commands.DeviceHandlers",
     "Raxol.Terminal.Commands.DeviceHandler"},
    {"Raxol.Terminal.Commands.ModeHandlers",
     "Raxol.Terminal.Commands.ModeHandler"},
    {"Raxol.Terminal.Events.Handlers", "Raxol.Terminal.Events.Handler"},
    {"Raxol.Terminal.Buffer.Handlers", "Raxol.Terminal.Buffer.Handler"},
    {"Raxol.Terminal.ANSI.SequenceHandlers",
     "Raxol.Terminal.ANSI.SequenceHandler"},
    {"Raxol.Terminal.Emulator.CommandHandlers",
     "Raxol.Terminal.Emulator.CommandHandler"},
    {"Raxol.Core.Runtime.Plugins.Manager.EventHandlers",
     "Raxol.Core.Runtime.Plugins.Manager.EventHandler"},
    {"Raxol.Core.Accessibility.EventHandlers",
     "Raxol.Core.Accessibility.EventHandler"},
    {"Raxol.Core.Runtime.Events.Handlers", "Raxol.Core.Runtime.Events.Handler"},

    # Helpers
    {"Raxol.Terminal.Buffer.Helpers", "Raxol.Terminal.Buffer.Helper"},
    {"RaxolWeb.ErrorHelpers", "RaxolWeb.ErrorHelper"},

    # Short references that might appear
    {"CSIHandlers.", "CSIHandler."},
    {"OSCHandlers.", "OSCHandler."},
    {"DCSHandlers.", "DCSHandler."},
    {"BufferHandlers.", "BufferHandler."},
    {"WindowHandlers.", "WindowHandler."},
    {"CursorHandlers.", "CursorHandler."},
    {"EventHandlers.", "EventHandler."},
    {"SequenceHandlers.", "SequenceHandler."},
    {"CommandHandlers.", "CommandHandler."},

    # Alias statements
    {"alias CSIHandlers", "alias CSIHandler"},
    {"alias OSCHandlers", "alias OSCHandler"},
    {"alias Handlers", "alias Handler"},

    # Import statements
    {"import CSIHandlers", "import CSIHandler"},
    {"import OSCHandlers", "import OSCHandler"},
    {"import Handlers", "import Handler"}
  ]

  def run() do
    IO.puts("Fixing remaining references...")

    # Get all Elixir files
    files =
      Path.wildcard("lib/**/*.ex") ++
        Path.wildcard("lib/**/*.exs") ++
        Path.wildcard("test/**/*.ex") ++
        Path.wildcard("test/**/*.exs")

    Enum.each(files, &fix_file/1)

    IO.puts("\nDone! Fixed references in #{length(files)} files.")
  end

  defp fix_file(file) do
    content = File.read!(file)
    original = content

    updated =
      Enum.reduce(@replacements, content, fn {old, new}, acc ->
        String.replace(acc, old, new)
      end)

    if updated != original do
      File.write!(file, updated)
      IO.puts("  Fixed: #{file}")
    end
  end
end

FixReferences.run()

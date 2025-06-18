defmodule Raxol.Terminal.Commands.OSCHandlers do
  @moduledoc '''
  Handles Operating System Command (OSC) sequences.

  This module dispatches OSC commands to their respective handlers based on the command number.
  Each handler is responsible for a specific set of related commands.

  ## Supported Commands

  - Window Operations (OSC 0, 1, 2, 7, 8, 1337)
  - Color Palette (OSC 4)
  - Clipboard Operations (OSC 9, 52)
  - Color Management (OSC 10, 11, 12, 17, 19)
  - Cursor and Font (OSC 12, 50, 112)
  - Selection (OSC 51)
  '''

  alias Raxol.Terminal.{Emulator, Commands.OSCHandlers}
  require Raxol.Core.Runtime.Log

  @doc '''
  Handles an OSC command by dispatching it to the appropriate handler.

  ## Parameters

  - `emulator` - The terminal emulator state
  - `command` - The OSC command number
  - `data` - The command data

  ## Returns

  - `{:ok, emulator}` - Command handled successfully
  - `{:error, reason, emulator}` - Command failed with reason
  '''
  @spec handle(Emulator.t(), non_neg_integer(), String.t()) ::
          {:ok, Emulator.t()} | {:error, term(), Emulator.t()}
  def handle(emulator, command, data) do
    case get_command_group(command) do
      {:window, cmd} ->
        handle_window_ops(emulator, cmd, data)

      {:clipboard, cmd} ->
        handle_clipboard_ops(emulator, cmd, data)

      {:color, cmd} ->
        handle_color_ops(emulator, cmd, data)

      {:cursor, cmd} ->
        handle_cursor_ops(emulator, cmd, data)

      {:standalone, cmd} ->
        handle_standalone_ops(emulator, cmd, data)

      :unsupported ->
        Raxol.Core.Runtime.Log.warning("Unsupported OSC command: #{command}")
        {:error, :unsupported_command, emulator}
    end
  end

  defp get_command_group(command) do
    cond do
      command in [0, 1, 2, 7, 8, 1337] -> {:window, command}
      command in [9, 52] -> {:clipboard, command}
      command in [10, 11, 17, 19] -> {:color, command}
      command in [12, 50, 112] -> {:cursor, command}
      command in [4, 51] -> {:standalone, command}
      true -> :unsupported
    end
  end

  defp handle_standalone_ops(emulator, command, data) do
    case command do
      4 -> OSCHandlers.ColorPalette.handle_4(emulator, data)
      51 -> OSCHandlers.Selection.handle_51(emulator, data)
    end
  end

  defp handle_window_ops(emulator, command, data) do
    case command do
      0 -> OSCHandlers.Window.handle_0(emulator, data)
      1 -> OSCHandlers.Window.handle_1(emulator, data)
      2 -> OSCHandlers.Window.handle_2(emulator, data)
      7 -> OSCHandlers.Window.handle_7(emulator, data)
      8 -> OSCHandlers.Window.handle_8(emulator, data)
      1337 -> OSCHandlers.Window.handle_1337(emulator, data)
    end
  end

  defp handle_clipboard_ops(emulator, command, data) do
    case command do
      9 -> OSCHandlers.Clipboard.handle_9(emulator, data)
      52 -> OSCHandlers.Clipboard.handle_52(emulator, data)
    end
  end

  defp handle_color_ops(emulator, command, data) do
    case command do
      10 -> OSCHandlers.Color.handle_10(emulator, data)
      11 -> OSCHandlers.Color.handle_11(emulator, data)
      17 -> OSCHandlers.Color.handle_17(emulator, data)
      19 -> OSCHandlers.Color.handle_19(emulator, data)
    end
  end

  defp handle_cursor_ops(emulator, command, data) do
    case command do
      12 -> OSCHandlers.Cursor.handle_12(emulator, data)
      50 -> OSCHandlers.Cursor.handle_50(emulator, data)
      112 -> OSCHandlers.Cursor.handle_112(emulator, data)
    end
  end
end

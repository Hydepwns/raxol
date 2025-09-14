defmodule Raxol.Terminal.Commands.EraseHandler do
  @moduledoc """
  @deprecated "Use Raxol.Terminal.Commands.UnifiedCommandHandler instead"

  This module has been consolidated into the unified command handling system.
  For new code, use:

      # Instead of EraseHandler.handle_erase(emulator, type, param, pos)
      UnifiedCommandHandler.handle_csi(emulator, command, [param])
      # where command is "J" for screen, "K" for line, "X" for character
  """

  alias Raxol.Terminal.Commands.UnifiedCommandHandler
  require Raxol.Core.Runtime.Log

  @deprecated "Use UnifiedCommandHandler.handle_csi/3 instead"
  def handle_erase(emulator, type, erase_param, _pos) do
    IO.puts(
      :stderr,
      "Warning: EraseHandler.handle_erase/4 is deprecated. Use UnifiedCommandHandler instead."
    )

    command =
      case type do
        :screen -> "J"
        :line -> "K"
        :character -> "X"
        # Default fallback
        _ -> "J"
      end

    UnifiedCommandHandler.handle_csi(emulator, command, [erase_param])
  end

  # Keep the old helper function for backward compatibility
  def get_buffer_state(emulator) do
    IO.puts(:stderr, "Warning: EraseHandler.get_buffer_state/1 is deprecated.")

    active_buffer =
      case emulator do
        %{main_screen_buffer: buffer} -> buffer
        # Fallback
        _ -> %{cells: [], width: 80, height: 24}
      end

    cursor_pos =
      case emulator.cursor do
        pid when is_pid(pid) ->
          case Raxol.Terminal.Cursor.Manager.get_position(pid) do
            {:ok, pos} -> pos
            pos when is_tuple(pos) -> pos
            _ -> {0, 0}
          end

        %{position: pos} when is_tuple(pos) ->
          pos

        %{row: row, col: col} ->
          {row, col}

        _ ->
          {0, 0}
      end

    blank_style = Raxol.Terminal.ANSI.TextFormatting.new()
    {active_buffer, cursor_pos, blank_style}
  end
end

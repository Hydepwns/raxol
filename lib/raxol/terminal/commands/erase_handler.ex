defmodule Raxol.Terminal.Commands.EraseHandler do
  @moduledoc """
  Handles terminal erase commands like Erase in Display (ED) and Erase in Line (EL).
  This module provides simple fallback implementations.
  """

  @doc """
  Handles erase operations for display, line, or character.

  Modes:
  - :screen (ED): Erase in Display
  - :line (EL): Erase in Line
  - :character (ECH): Erase Characters

  Parameters:
  - mode: 0 = from cursor to end, 1 = from start to cursor, 2 = entire area
  - position: {row, col} cursor position
  """
  def handle_erase(emulator, scope, mode, position) do
    case scope do
      :screen ->
        # ED - Erase in Display
        handle_erase_display(emulator, mode, position)

      :line ->
        # EL - Erase in Line
        handle_erase_line(emulator, mode, position)

      :character ->
        # ECH - Erase Characters
        handle_erase_characters(emulator, mode, position)

      _ ->
        {:error, :invalid_erase_scope, emulator}
    end
  end

  defp handle_erase_display(emulator, mode, _position) do
    # Delegate to CSIHandler's erase display implementation
    updated_emulator =
      Raxol.Terminal.Commands.CSIHandler.handle_erase_display(emulator, mode)

    {:ok, updated_emulator}
  end

  defp handle_erase_line(emulator, mode, _position) do
    # Delegate to CSIHandler's erase line implementation
    updated_emulator =
      Raxol.Terminal.Commands.CSIHandler.handle_erase_line(emulator, mode)

    {:ok, updated_emulator}
  end

  defp handle_erase_characters(emulator, count, _position) do
    # ECH - Erase Characters at cursor position
    # Delegates to ScreenOperations for actual buffer manipulation
    updated_emulator =
      Raxol.Terminal.Operations.ScreenOperations.erase_chars(emulator, count)

    {:ok, updated_emulator}
  end
end

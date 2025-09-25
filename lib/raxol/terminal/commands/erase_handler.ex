defmodule Raxol.Terminal.Commands.EraseHandler do
  @moduledoc """
  Handles terminal erase commands like Erase in Display (ED) and Erase in Line (EL).
  This module delegates to UnifiedCommandHandler for actual implementation.
  """

  alias Raxol.Terminal.Commands.UnifiedCommandHandler

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
    case UnifiedCommandHandler.handle_csi(emulator, "J", [mode], "") do
      {:ok, updated_emulator} -> {:ok, updated_emulator}
      {:error, _reason, updated_emulator} -> {:ok, updated_emulator}
      result -> result
    end
  end

  defp handle_erase_line(emulator, mode, _position) do
    case UnifiedCommandHandler.handle_csi(emulator, "K", [mode], "") do
      {:ok, updated_emulator} -> {:ok, updated_emulator}
      {:error, _reason, updated_emulator} -> {:ok, updated_emulator}
      result -> result
    end
  end

  defp handle_erase_characters(emulator, count, _position) do
    case UnifiedCommandHandler.handle_csi(emulator, "X", [count], "") do
      {:ok, updated_emulator} -> {:ok, updated_emulator}
      {:error, _reason, updated_emulator} -> {:ok, updated_emulator}
      result -> result
    end
  end
end
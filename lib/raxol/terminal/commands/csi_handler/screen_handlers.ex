defmodule Raxol.Terminal.Commands.CSIHandler.ScreenHandlers do
  @moduledoc """
  Screen handling utilities for CSI commands.
  """

  # Simple implementations without BufferManager dependency

  @doc """
  Handles erase display operations.
  """
  @spec handle_erase_display(term(), non_neg_integer()) :: {:ok, term()}
  def handle_erase_display(emulator, mode) do
    alias Raxol.Terminal.Commands.Screen

    updated_emulator = Screen.clear_screen(emulator, mode)
    {:ok, updated_emulator}
  end

  @doc """
  Handles erase line operations.
  """
  @spec handle_erase_line(term(), non_neg_integer()) :: {:ok, term()}
  def handle_erase_line(emulator, mode) do
    alias Raxol.Terminal.Commands.Screen

    updated_emulator = Screen.clear_line(emulator, mode)
    {:ok, updated_emulator}
  end
end

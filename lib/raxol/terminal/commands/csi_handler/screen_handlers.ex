defmodule Raxol.Terminal.Commands.CSIHandler.ScreenHandlers do
  @moduledoc """
  Screen handling utilities for CSI commands.
  """

  # Simple implementations without BufferManager dependency

  @doc """
  Handles erase display operations.
  """
  @spec handle_erase_display(Raxol.Terminal.Emulator.t(), integer()) ::
          {:ok, Raxol.Terminal.Emulator.t()}
  def handle_erase_display(emulator, mode) do
    alias Raxol.Terminal.Commands.Screen

    {:ok, Screen.clear_screen(emulator, mode)}
  end

  @doc """
  Handles erase line operations.
  """
  @spec handle_erase_line(Raxol.Terminal.Emulator.t(), integer()) ::
          {:ok, Raxol.Terminal.Emulator.t()}
  def handle_erase_line(emulator, mode) do
    alias Raxol.Terminal.Commands.Screen

    {:ok, Screen.clear_line(emulator, mode)}
  end
end

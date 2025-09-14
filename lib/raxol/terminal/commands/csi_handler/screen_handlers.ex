defmodule Raxol.Terminal.Commands.CSIHandler.ScreenHandlers do
  @moduledoc """
  Screen handling utilities for CSI commands.
  """

  alias Raxol.Terminal.Commands.UnifiedCommandHandler

  @doc """
  Handles erase display operations.
  """
  @spec handle_erase_display(term(), non_neg_integer()) :: {:ok, term()}
  def handle_erase_display(emulator, mode) do
    # Delegate to UnifiedCommandHandler for actual implementation
    case UnifiedCommandHandler.handle_csi(emulator, "J", [mode]) do
      {:ok, updated_emulator} -> {:ok, updated_emulator}
      {:error, _, updated_emulator} -> {:ok, updated_emulator}
      updated_emulator -> {:ok, updated_emulator}
    end
  end

  @doc """
  Handles erase line operations.
  """
  @spec handle_erase_line(term(), non_neg_integer()) :: {:ok, term()}
  def handle_erase_line(emulator, mode) do
    # Delegate to UnifiedCommandHandler for actual implementation
    case UnifiedCommandHandler.handle_csi(emulator, "K", [mode]) do
      {:ok, updated_emulator} -> {:ok, updated_emulator}
      {:error, _, updated_emulator} -> {:ok, updated_emulator}
      updated_emulator -> {:ok, updated_emulator}
    end
  end
end

defmodule Raxol.Terminal.Commands.CSIHandler.TextHandlers do
  @moduledoc """
  Handlers for text attributes and save/restore cursor CSI commands.
  """

  alias Raxol.Terminal.Commands.CSIHandler.Basic

  @doc """
  Handles text attributes command.
  """
  def handle_text_attributes(emulator, params) do
    case Basic.handle_command(
           emulator,
           params,
           ?m
         ) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, _} -> emulator
      updated_emulator when is_map(updated_emulator) -> updated_emulator
      _ -> emulator
    end
  end

  @doc """
  Handles save cursor command.
  """
  def handle_save_cursor(emulator, _params) do
    # Save cursor position
    case Basic.handle_command(
           emulator,
           [],
           ?s
         ) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, _} -> emulator
      updated_emulator -> updated_emulator
    end
  end

  @doc """
  Handles restore cursor command.
  """
  def handle_restore_cursor(emulator, _params) do
    # Restore cursor position
    case Basic.handle_command(
           emulator,
           [],
           ?u
         ) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, _} -> emulator
      updated_emulator -> updated_emulator
    end
  end

  @doc """
  Handles save/restore cursor command.
  """
  def handle_save_restore_cursor(emulator, params) do
    # This function is called for both save (?s) and restore (?u) commands
    # We need to determine which command based on the context
    # For now, we'll use the Basic handler which should handle both cases
    case Basic.handle_command(
           emulator,
           params,
           ?s
         ) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, _} -> emulator
      updated_emulator -> updated_emulator
    end
  end

  @doc """
  Handles save cursor alias.
  """
  def handle_s(emulator, params) do
    Basic.handle_command(emulator, params, ?s)
  end

  @doc """
  Handles restore cursor alias.
  """
  def handle_u(emulator, params) do
    Basic.handle_command(emulator, params, ?u)
  end
end

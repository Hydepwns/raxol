defmodule Raxol.Terminal.Mode.Manager do
  @moduledoc """
  Manages terminal modes for the terminal emulator.
  """

  defstruct [:modes]

  @type t :: %__MODULE__{
          modes: %{atom() => boolean()}
        }

  @doc """
  Creates a new mode manager.
  """
  def new do
    %__MODULE__{
      modes: %{}
    }
  end

  @doc """
  Gets the mode manager from an emulator.
  """
  def get_manager(emulator) do
    emulator.mode_manager
  end

  @doc """
  Updates the mode manager in an emulator.
  """
  def update_manager(emulator, manager) do
    %{emulator | mode_manager: manager}
  end

  @doc """
  Sets a mode in the mode manager.
  """
  def set_mode(manager, mode, value) do
    %{manager | modes: Map.put(manager.modes, mode, value)}
  end

  @doc """
  Resets a mode in the mode manager.
  """
  def reset_mode(manager, mode) do
    %{manager | modes: Map.delete(manager.modes, mode)}
  end

  @doc """
  Checks if a mode is set.
  """
  def mode_set?(manager, mode) do
    Map.get(manager.modes, mode, false)
  end

  @doc """
  Gets all set modes.
  """
  def get_set_modes(manager) do
    manager.modes
    |> Enum.filter(fn {_mode, value} -> value end)
    |> Enum.map(fn {mode, _} -> mode end)
  end

  @doc """
  Resets all modes.
  """
  def reset_all_modes(manager) do
    %{manager | modes: %{}}
  end

  @doc """
  Saves the current modes.
  """
  def save_modes(manager) do
    manager
  end

  @doc """
  Restores previously saved modes.
  """
  def restore_modes(manager) do
    manager
  end
end

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
  @spec new() :: t()
  def new do
    %__MODULE__{
      modes: %{}
    }
  end

  @doc """
  Gets the mode manager from an emulator.
  """
  @spec get_manager(Raxol.Terminal.Emulator.t()) :: t()
  def get_manager(emulator) do
    emulator.mode_manager
  end

  @doc """
  Updates the mode manager in an emulator.
  """
  @spec update_manager(Raxol.Terminal.Emulator.t(), t()) ::
          Raxol.Terminal.Emulator.t()
  def update_manager(emulator, manager) do
    %{emulator | mode_manager: manager}
  end

  @doc """
  Sets a mode in the mode manager.
  """
  @spec set_mode(t(), atom(), boolean()) :: t()
  def set_mode(manager, mode, value) do
    %{manager | modes: Map.put(manager.modes, mode, value)}
  end

  @doc """
  Resets a mode in the mode manager.
  """
  @spec reset_mode(t(), atom()) :: t()
  def reset_mode(manager, mode) do
    %{manager | modes: Map.delete(manager.modes, mode)}
  end

  @doc """
  Checks if a mode is set.
  """
  @spec mode_set?(t(), atom()) :: boolean()
  def mode_set?(manager, mode) do
    Map.get(manager.modes, mode, false)
  end

  @doc """
  Gets all set modes.
  """
  @spec get_set_modes(t()) :: [atom()]
  def get_set_modes(manager) do
    manager.modes
    |> Enum.filter(fn {_mode, value} -> value end)
    |> Enum.map(fn {mode, _} -> mode end)
  end

  @doc """
  Resets all modes.
  """
  @spec reset_all_modes(t()) :: t()
  def reset_all_modes(manager) do
    %{manager | modes: %{}}
  end

  @doc """
  Saves the current modes.
  """
  @spec save_modes(t()) :: t()
  def save_modes(manager) do
    manager
  end

  @doc """
  Restores previously saved modes.
  """
  @spec restore_modes(t()) :: t()
  def restore_modes(manager) do
    manager
  end
end

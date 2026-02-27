defmodule Raxol.Terminal.Modes.ModeStateManager do
  @moduledoc """
  Deprecated: Use `Raxol.Terminal.ModeManager` instead.

  This module was a GenServer variant for mode state management with validation.
  The validation logic has been consolidated into `Raxol.Terminal.ModeManager`.

  This module is maintained for backward compatibility only.
  """

  # Note: This module previously used BaseManager behavior.
  # For new code, use Raxol.Terminal.ModeManager directly.

  alias Raxol.Terminal.Modes.Types.ModeTypes

  defstruct modes: %{}

  @type t :: %__MODULE__{}

  @doc """
  Creates a new mode state with default values.

  Deprecated: Use `Raxol.Terminal.ModeManager.new/0` instead.
  """
  def new do
    %__MODULE__{
      modes: initialize_default_modes()
    }
  end

  @doc """
  Sets a mode to a specific value.

  Deprecated: Use `Raxol.Terminal.ModeManager.set_mode/3` instead.
  """
  def set_mode(state, mode_name, value) do
    with {:ok, mode_def} <- validate_mode(mode_name),
         :ok <- validate_dependencies(state, mode_def),
         :ok <- validate_conflicts(state, mode_def) do
      new_state = put_in(state.modes[mode_name], value)
      {:ok, new_state}
    end
  end

  @doc """
  Resets a mode to its default value.

  Deprecated: Use `Raxol.Terminal.ModeManager.reset_mode/3` instead.
  """
  def reset_mode(state, mode_name) do
    with {:ok, mode_def} <- validate_mode(mode_name) do
      new_state = put_in(state.modes[mode_name], mode_def.default_value)
      {:ok, new_state}
    end
  end

  @doc """
  Checks if a mode is enabled.

  Deprecated: Use `Raxol.Terminal.ModeManager.mode_enabled?/2` instead.
  """
  def mode_enabled?(state, mode_name) do
    case Map.get(state.modes, mode_name) do
      nil -> false
      value -> value == true or value == :enabled
    end
  end

  # Private functions for validation

  defp initialize_default_modes do
    ModeTypes.get_all_modes()
    |> Map.values()
    |> Enum.map(fn mode_def -> {mode_def.name, mode_def.default_value} end)
    |> Map.new()
  end

  defp validate_mode(mode_name) do
    case find_mode_definition(mode_name) do
      nil -> {:error, :invalid_mode}
      mode_def -> {:ok, mode_def}
    end
  end

  defp find_mode_definition(mode_name) do
    ModeTypes.get_all_modes()
    |> Map.values()
    |> Enum.find(&(&1.name == mode_name))
  end

  defp validate_dependencies(state, mode_def) do
    case check_dependencies(state, mode_def.dependencies) do
      :ok -> :ok
      {:error, missing} -> {:error, {:missing_dependencies, missing}}
    end
  end

  defp check_dependencies(_state, []), do: :ok

  defp check_dependencies(state, [dep | rest]) do
    case mode_enabled?(state, dep) do
      true -> check_dependencies(state, rest)
      false -> {:error, [dep]}
    end
  end

  defp validate_conflicts(state, mode_def) do
    case check_conflicts(state, mode_def.conflicts) do
      :ok -> :ok
      {:error, conflicts} -> {:error, {:conflicting_modes, conflicts}}
    end
  end

  defp check_conflicts(_state, []), do: :ok

  defp check_conflicts(state, [conflict | rest]) do
    case mode_enabled?(state, conflict) do
      true -> {:error, [conflict]}
      false -> check_conflicts(state, rest)
    end
  end
end

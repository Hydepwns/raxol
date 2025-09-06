defmodule Raxol.Terminal.Modes.ModeStateManager do
  @moduledoc """
  Manages the state of terminal modes, including transitions and validation.
  Handles mode dependencies, conflicts, and state persistence.
  """

  use GenServer
  require Logger

  alias Raxol.Terminal.Modes.Types.ModeTypes
  require Raxol.Core.Runtime.Log

  defstruct modes: %{}

  @type t :: %__MODULE__{}

  # Client API

  @doc """
  Starts the ModeStateManager process.
  """
  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @doc """
  Creates a new mode state with default values.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      modes: initialize_default_modes()
    }
  end

  @doc """
  Sets a mode to a specific value.
  """
  @spec set_mode(t(), atom(), ModeTypes.mode_value()) ::
          {:ok, t()} | {:error, term()}
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
  """
  @spec reset_mode(t(), atom()) :: {:ok, t()} | {:error, term()}
  def reset_mode(state, mode_name) do
    with {:ok, mode_def} <- validate_mode(mode_name) do
      new_state = put_in(state.modes[mode_name], mode_def.default_value)
      {:ok, new_state}
    end
  end

  @doc """
  Checks if a mode is enabled.
  """
  @spec mode_enabled?(t(), atom()) :: boolean()
  def mode_enabled?(state, mode_name) do
    case Map.get(state.modes, mode_name) do
      nil -> false
      value -> value == true or value == :enabled
    end
  end

  # Server Callbacks

  @impl GenServer
  def init(_init_arg) do
    {:ok, new()}
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl GenServer
  def handle_call({:set_mode, mode_name, value}, _from, state) do
    case set_mode(state, mode_name, value) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:reset_mode, mode_name}, _from, state) do
    case reset_mode(state, mode_name) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_mode, mode_name}, _from, state) do
    value = mode_enabled?(state, mode_name)
    {:reply, value, state}
  end

  # Private Functions

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

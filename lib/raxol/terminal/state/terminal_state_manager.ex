defmodule Raxol.Terminal.State.TerminalStateManager do
  @moduledoc """
  Manages terminal state including modes, attributes, and state transitions.
  This module is responsible for maintaining and updating the terminal's state.
  """

  use Raxol.Core.Behaviours.BaseManager


  alias Raxol.Terminal.{Emulator, State}
  require Raxol.Core.Runtime.Log

  # Client API

  @doc """
  Starts the state manager.
  """
  # BaseManager provides start_link/1 and start_link/2 automatically

  # Server Callbacks

  @impl true
  def init_manager(_opts) do
    {:ok, new()}
  end

  @impl true
  def handle_manager_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_manager_call({:set_state, new_state}, _from, _state) do
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call({:get_mode, mode}, _from, state) do
    {:reply, get_in(state.modes, [mode]), state}
  end

  @impl true
  def handle_manager_call({:set_mode, mode, value}, _from, state) do
    new_state = %{state | modes: Map.put(state.modes, mode, value)}
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_manager_call({:get_attribute, attribute}, _from, state) do
    {:reply, get_in(state.attributes, [attribute]), state}
  end

  @impl true
  def handle_manager_call({:set_attribute, attribute, value}, _from, state) do
    new_state = %{
      state
      | attributes: Map.put(state.attributes, attribute, value)
    }

    {:reply, new_state, new_state}
  end

  @impl true
  def handle_manager_call(:push_state, _from, state) do
    new_state = %{state | state_stack: [state | state.state_stack]}
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_manager_call(:pop_state, _from, state) do
    case state.state_stack do
      [popped_state | rest] ->
        new_state = %{state | state_stack: rest}
        {:reply, popped_state, new_state}

      [] ->
        {:reply, nil, state}
    end
  end

  @impl true
  def handle_manager_call(:get_state_stack, _from, state) do
    {:reply, state.state_stack, state}
  end

  @impl true
  def handle_manager_call(:clear_state_stack, _from, state) do
    new_state = %{state | state_stack: []}
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_manager_call(:reset_state, _from, _state) do
    new_state = new()
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_manager_cast({:update_state, update_fun}, state)
      when is_function(update_fun) do
    {:noreply, update_fun.(state)}
  end

  @impl true
  def handle_manager_info(_msg, state) do
    {:noreply, state}
  end

  @doc """
  Creates a new state manager.
  """
  @spec new() :: State.t()
  def new do
    %{
      modes: %{},
      attributes: %{},
      state_stack: []
    }
  end

  @doc """
  Gets a mode value.
  Returns the mode value or nil.
  """
  @spec get_mode(Emulator.t(), atom()) :: any()
  def get_mode(emulator, mode) do
    case emulator do
      %{state: state} when is_map(state) ->
        # Handle map-based emulator
        get_in(state.modes, [mode])

      %{state: state_pid} when is_pid(state_pid) ->
        # Handle PID-based state - delegate to the state PID
        GenServer.call(state_pid, {:get_mode, mode})

      _ ->
        # Fallback for other cases
        nil
    end
  end

  @doc """
  Sets a mode value.
  Returns the updated emulator.
  """
  @spec set_mode(Emulator.t(), atom(), any()) :: Emulator.t()
  def set_mode(emulator, mode, value) do
    case emulator do
      %{state: state} when is_map(state) ->
        # Handle map-based emulator
        modes = Map.put(state.modes, mode, value)
        %{emulator | state: %{state | modes: modes}}

      %{state: state_pid} when is_pid(state_pid) ->
        # Handle PID-based state - delegate to the state PID and return emulator
        _ = GenServer.call(state_pid, {:set_mode, mode, value})
        emulator

      _ ->
        # Fallback for other cases
        emulator
    end
  end

  @doc """
  Gets an attribute value.
  Returns the attribute value or nil.
  """
  @spec get_attribute(Emulator.t(), atom()) :: any()
  def get_attribute(emulator, attribute) do
    case emulator do
      %{state: state} when is_map(state) ->
        # Handle map-based emulator
        get_in(state.attributes, [attribute])

      %{state: state_pid} when is_pid(state_pid) ->
        # Handle PID-based state - delegate to the state PID
        GenServer.call(state_pid, {:get_attribute, attribute})

      _ ->
        # Fallback for other cases
        nil
    end
  end

  @doc """
  Sets an attribute value.
  Returns the updated emulator.
  """
  @spec set_attribute(Emulator.t(), atom(), any()) :: Emulator.t()
  def set_attribute(emulator, attribute, value) do
    case emulator do
      %{state: state} when is_map(state) ->
        # Handle map-based emulator
        attributes = Map.put(state.attributes, attribute, value)
        %{emulator | state: %{state | attributes: attributes}}

      %{state: state_pid} when is_pid(state_pid) ->
        # Handle PID-based state - delegate to the state PID
        _ = GenServer.call(state_pid, {:set_attribute, attribute, value})
        emulator

      _ ->
        # Fallback for other cases
        emulator
    end
  end

  @doc """
  Pushes the current state onto the stack.
  Returns the updated emulator.
  """
  @spec push_state(Emulator.t()) :: Emulator.t()
  def push_state(emulator) do
    case emulator do
      %{state: state} when is_map(state) ->
        # Handle map-based emulator
        state_stack = [state | state.state_stack]
        %{emulator | state: %{state | state_stack: state_stack}}

      %{state: state_pid} when is_pid(state_pid) ->
        # Handle PID-based state - delegate to the state PID
        _ = GenServer.call(state_pid, :push_state)
        emulator

      _ ->
        # Fallback for other cases
        emulator
    end
  end

  @doc """
  Pops a state from the stack.
  Returns {emulator, state} or {emulator, nil} if stack is empty.
  """
  @spec pop_state(Emulator.t()) :: {Emulator.t(), State.t() | nil}
  def pop_state(emulator) do
    case emulator do
      %{state: state} when is_map(state) ->
        # Handle map-based emulator
        case state.state_stack do
          [popped_state | rest] ->
            new_emulator = %{
              emulator
              | state: %{state | state_stack: rest}
            }

            {new_emulator, popped_state}

          [] ->
            {emulator, nil}
        end

      %{state: state_pid} when is_pid(state_pid) ->
        # Handle PID-based state - delegate to the state PID
        result = GenServer.call(state_pid, :pop_state)
        {emulator, result}

      _ ->
        # Fallback for other cases
        {emulator, nil}
    end
  end

  @doc """
  Gets the current state stack.
  Returns the list of states.
  """
  @spec get_state_stack(Emulator.t()) :: [State.t()]
  def get_state_stack(emulator) do
    case emulator do
      %{state: state} when is_map(state) ->
        # Handle map-based emulator
        state.state_stack

      %{state: state_pid} when is_pid(state_pid) ->
        # Handle PID-based state - delegate to the state PID
        GenServer.call(state_pid, :get_state_stack)

      _ ->
        # Fallback for other cases
        []
    end
  end

  @doc """
  Clears the state stack.
  Returns the updated emulator.
  """
  @spec clear_state_stack(Emulator.t()) :: Emulator.t()
  def clear_state_stack(emulator) do
    case emulator do
      %{state: state} when is_map(state) ->
        # Handle map-based emulator
        %{emulator | state: %{state | state_stack: []}}

      %{state: state_pid} when is_pid(state_pid) ->
        # Handle PID-based state - delegate to the state PID
        _ = GenServer.call(state_pid, :clear_state_stack)
        emulator

      _ ->
        # Fallback for other cases
        emulator
    end
  end

  @doc """
  Resets the state to its initial values.
  Returns the updated emulator.
  """
  @spec reset_state(Emulator.t()) :: Emulator.t()
  def reset_state(emulator) do
    case emulator do
      %{state: state} when is_map(state) ->
        # Handle map-based emulator
        %{emulator | state: new()}

      %{state: state_pid} when is_pid(state_pid) ->
        # Handle PID-based state - delegate to the state PID
        _ = GenServer.call(state_pid, :reset_state)
        emulator

      _ ->
        # Fallback for other cases
        emulator
    end
  end
end

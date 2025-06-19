defmodule Raxol.Terminal.State.Manager do
  @moduledoc """
  Manages terminal state including modes, attributes, and state transitions.
  This module is responsible for maintaining and updating the terminal's state.
  """

  alias Raxol.Terminal.{Emulator, State}
  require Raxol.Core.Runtime.Log

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
    get_in(emulator.state.modes, [mode])
  end

  @doc """
  Sets a mode value.
  Returns the updated emulator.
  """
  @spec set_mode(Emulator.t(), atom(), any()) :: Emulator.t()
  def set_mode(emulator, mode, value) do
    modes = Map.put(emulator.state.modes, mode, value)
    %{emulator | state: %{emulator.state | modes: modes}}
  end

  @doc """
  Gets an attribute value.
  Returns the attribute value or nil.
  """
  @spec get_attribute(Emulator.t(), atom()) :: any()
  def get_attribute(emulator, attribute) do
    get_in(emulator.state.attributes, [attribute])
  end

  @doc """
  Sets an attribute value.
  Returns the updated emulator.
  """
  @spec set_attribute(Emulator.t(), atom(), any()) :: Emulator.t()
  def set_attribute(emulator, attribute, value) do
    attributes = Map.put(emulator.state.attributes, attribute, value)
    %{emulator | state: %{emulator.state | attributes: attributes}}
  end

  @doc """
  Pushes the current state onto the stack.
  Returns the updated emulator.
  """
  @spec push_state(Emulator.t()) :: Emulator.t()
  def push_state(emulator) do
    state_stack = [emulator.state | emulator.state.state_stack]
    %{emulator | state: %{emulator.state | state_stack: state_stack}}
  end

  @doc """
  Pops a state from the stack.
  Returns {emulator, state} or {emulator, nil} if stack is empty.
  """
  @spec pop_state(Emulator.t()) :: {Emulator.t(), State.t() | nil}
  def pop_state(emulator) do
    case emulator.state.state_stack do
      [state | rest] ->
        new_emulator = %{emulator | state: %{emulator.state | state_stack: rest}}
        {new_emulator, state}
      [] ->
        {emulator, nil}
    end
  end

  @doc """
  Gets the current state stack.
  Returns the list of states.
  """
  @spec get_state_stack(Emulator.t()) :: [State.t()]
  def get_state_stack(emulator) do
    emulator.state.state_stack
  end

  @doc """
  Clears the state stack.
  Returns the updated emulator.
  """
  @spec clear_state_stack(Emulator.t()) :: Emulator.t()
  def clear_state_stack(emulator) do
    %{emulator | state: %{emulator.state | state_stack: []}}
  end

  @doc """
  Resets the state to its initial values.
  Returns the updated emulator.
  """
  @spec reset_state(Emulator.t()) :: Emulator.t()
  def reset_state(emulator) do
    %{emulator | state: new()}
  end
end

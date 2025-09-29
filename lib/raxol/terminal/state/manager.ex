defmodule Raxol.Terminal.State.Manager do
  @moduledoc """
  State manager for terminal emulator state.
  Provides functions for managing modes, attributes, and state stack.

  This is a compatibility wrapper that delegates to the actual StateManager
  implementation while maintaining the expected API for tests.
  """

  @doc """
  Creates a new state manager instance.
  """
  def new do
    %{
      modes: %{},
      attributes: %{},
      state_stack: []
    }
  end

  @doc """
  Gets a mode value from the emulator state.
  """
  def get_mode(emulator, mode_key) do
    emulator.state.modes[mode_key]
  end

  @doc """
  Sets a mode value in the emulator state.
  """
  def set_mode(emulator, mode_key, value) do
    updated_modes = Map.put(emulator.state.modes, mode_key, value)
    updated_state = %{emulator.state | modes: updated_modes}
    %{emulator | state: updated_state}
  end

  @doc """
  Gets an attribute value from the emulator state.
  """
  def get_attribute(emulator, attr_key) do
    emulator.state.attributes[attr_key]
  end

  @doc """
  Sets an attribute value in the emulator state.
  """
  def set_attribute(emulator, attr_key, value) do
    updated_attributes = Map.put(emulator.state.attributes, attr_key, value)
    updated_state = %{emulator.state | attributes: updated_attributes}
    %{emulator | state: updated_state}
  end

  @doc """
  Pushes current state onto the state stack.
  """
  def push_state(emulator) do
    current_state = emulator.state
    state_copy = Map.take(current_state, [:modes, :attributes])

    updated_stack = [state_copy | current_state.state_stack || []]
    updated_state = %{current_state | state_stack: updated_stack}
    %{emulator | state: updated_state}
  end

  @doc """
  Pops state from the state stack.
  """
  def pop_state(emulator) do
    case emulator.state.state_stack do
      [saved_state | rest] ->
        # Only remove from stack, don't restore the state
        updated_state = %{emulator.state | state_stack: rest}
        updated_emulator = %{emulator | state: updated_state}
        {updated_emulator, saved_state}

      _ ->
        {emulator, nil}
    end
  end

  @doc """
  Gets the state stack.
  """
  def get_state_stack(emulator) do
    emulator.state.state_stack || []
  end

  @doc """
  Clears the state stack.
  """
  def clear_state_stack(emulator) do
    updated_state = %{emulator.state | state_stack: []}
    %{emulator | state: updated_state}
  end

  @doc """
  Resets state to initial values.
  """
  def reset_state(emulator) do
    %{emulator | state: new()}
  end
end

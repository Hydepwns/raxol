defmodule Raxol.Terminal.TerminalState.Manager do
  @moduledoc """
  Manages terminal state operations for the terminal emulator.
  This module handles the state stack, saved states, and state transitions.
  """

  alias Raxol.Terminal.ANSI.TerminalState

  @doc """
  Creates a new terminal state.
  """
  def new do
    TerminalState.new()
  end

  @doc """
  Gets the current state stack.
  """
  def get_state_stack(emulator) do
    emulator.state_stack
  end

  @doc """
  Updates the state stack.
  """
  def update_state_stack(emulator, state_stack) do
    %{emulator | state_stack: state_stack}
  end

  @doc """
  Saves the current state.
  """
  def save_state(emulator) do
    new_stack = TerminalState.save(emulator.state_stack)
    update_state_stack(emulator, new_stack)
  end

  @doc """
  Restores the last saved state.
  """
  def restore_state(emulator) do
    new_stack = TerminalState.restore(emulator.state_stack)
    update_state_stack(emulator, new_stack)
  end

  @doc """
  Checks if there are saved states.
  """
  def has_saved_states?(emulator) do
    TerminalState.has_saved_states?(emulator.state_stack)
  end

  @doc """
  Gets the number of saved states.
  """
  def get_saved_states_count(emulator) do
    TerminalState.get_saved_states_count(emulator.state_stack)
  end

  @doc """
  Clears all saved states.
  """
  def clear_saved_states(emulator) do
    new_stack = TerminalState.clear(emulator.state_stack)
    update_state_stack(emulator, new_stack)
  end

  @doc """
  Gets the current state.
  """
  def get_current_state(emulator) do
    TerminalState.get_current_state(emulator.state_stack)
  end

  @doc """
  Updates the current state.
  """
  def update_current_state(emulator, state) do
    new_stack = TerminalState.update_current_state(emulator.state_stack, state)
    update_state_stack(emulator, new_stack)
  end
end

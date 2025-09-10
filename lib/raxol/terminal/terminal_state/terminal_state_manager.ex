defmodule Raxol.Terminal.TerminalState.Manager do
  @moduledoc """
  Manages terminal state operations for the terminal emulator.
  This module handles the state stack, saved states, and state transitions.
  """

  alias Raxol.Terminal.ANSI.TerminalState

  @doc """
  Creates a new terminal state.
  """
  @spec new() :: TerminalState.t()
  def new do
    TerminalState.new()
  end

  @doc """
  Gets the current state stack.
  """
  @spec get_state_stack(Raxol.Terminal.Emulator.t()) :: TerminalState.t()
  def get_state_stack(emulator) do
    emulator.state_stack
  end

  @doc """
  Updates the state stack.
  """
  @spec update_state_stack(Raxol.Terminal.Emulator.t(), TerminalState.t()) ::
          Raxol.Terminal.Emulator.t()
  def update_state_stack(emulator, state_stack) do
    %{emulator | state_stack: state_stack}
  end

  @doc """
  Saves the current state.
  """
  @spec save_state(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def save_state(emulator) do
    new_stack = TerminalState.save(emulator.state_stack)
    update_state_stack(emulator, new_stack)
  end

  @doc """
  Restores the last saved state.
  """
  @spec restore_state(Raxol.Terminal.Emulator.t()) ::
          Raxol.Terminal.Emulator.t()
  def restore_state(emulator) do
    new_stack = TerminalState.restore(emulator.state_stack)
    update_state_stack(emulator, new_stack)
  end

  @doc """
  Checks if there are saved states.
  """
  @spec has_saved_states?(Raxol.Terminal.Emulator.t()) :: boolean()
  def has_saved_states?(emulator) do
    TerminalState.has_saved_states?(emulator.state_stack)
  end

  @doc """
  Gets the number of saved states.
  """
  @spec get_saved_states_count(Raxol.Terminal.Emulator.t()) :: non_neg_integer()
  def get_saved_states_count(emulator) do
    TerminalState.get_saved_states_count(emulator.state_stack)
  end

  @doc """
  Clears all saved states.
  """
  @spec clear_saved_states(Raxol.Terminal.Emulator.t()) ::
          Raxol.Terminal.Emulator.t()
  def clear_saved_states(emulator) do
    new_stack = TerminalState.clear(emulator.state_stack)
    update_state_stack(emulator, new_stack)
  end

  @doc """
  Gets the current state.
  """
  @spec get_current_state(Raxol.Terminal.Emulator.t()) :: map()
  def get_current_state(emulator) do
    TerminalState.get_current_state(emulator.state_stack)
  end

  @doc """
  Updates the current state.
  """
  @spec update_current_state(Raxol.Terminal.Emulator.t(), map()) ::
          Raxol.Terminal.Emulator.t()
  def update_current_state(emulator, state) do
    new_stack = TerminalState.update_current_state(emulator.state_stack, state)
    update_state_stack(emulator, new_stack)
  end
end

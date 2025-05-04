defmodule Raxol.Terminal.ANSI.TerminalState do
  @moduledoc """
  Manages terminal state for the terminal emulator.
  Handles saving and restoring terminal state, including cursor position,
  attributes, character sets, and screen modes.
  """

  require Logger
  alias Raxol.Terminal.ANSI.{CharacterSets, ScreenModes}

  @type saved_state :: %{
          cursor: {non_neg_integer(), non_neg_integer()},
          attributes: map(),
          charset_state: CharacterSets.charset_state(),
          mode_state: ScreenModes.screen_state(),
          scroll_region: {non_neg_integer(), non_neg_integer()} | nil
        }

  @type state_stack :: [saved_state()]

  @doc """
  Creates a new terminal state stack.
  """
  @spec new() :: state_stack()
  def new do
    []
  end

  @doc """
  Saves the current terminal state to the stack.
  """
  @spec save_state(state_stack(), map()) :: state_stack()
  def save_state(stack, state) do
    saved_state = %{
      cursor: state.cursor,
      style: state.style,
      charset_state: state.charset_state,
      mode_state: state.mode_state,
      scroll_region: state.scroll_region
    }

    [saved_state | stack]
  end

  @doc """
  Restores the most recently saved terminal state from the stack.
  Returns the updated stack and the restored state.
  """
  @spec restore_state(state_stack()) :: {state_stack(), map() | nil}
  def restore_state([]) do
    {[], nil}
  end

  def restore_state([state | rest]) do
    {rest, state}
  end

  @doc """
  Clears the terminal state stack.
  """
  @spec clear_state(state_stack()) :: state_stack()
  def clear_state(_stack) do
    []
  end

  @doc """
  Gets the current terminal state stack.
  """
  @spec get_state_stack(state_stack()) :: state_stack()
  def get_state_stack(stack) do
    stack
  end

  @doc """
  Checks if the terminal state stack is empty.
  """
  @spec empty?(state_stack()) :: boolean()
  def empty?(stack) do
    stack == []
  end

  @doc """
  Gets the number of saved states in the stack.
  """
  @spec count(state_stack()) :: non_neg_integer()
  def count(stack) do
    length(stack)
  end

  @doc """
  Applies specified fields from restored data onto the current emulator state.
  """
  @spec apply_restored_data(map(), map() | nil, list(atom())) :: map()
  def apply_restored_data(emulator, nil, _fields_to_restore) do
    # No data to restore, return emulator unchanged
    Logger.debug("[ApplyRestore] No data to restore.") # Log
    emulator
  end

  def apply_restored_data(emulator, restored_data, fields_to_restore) do
    Logger.debug("[ApplyRestore] Restoring fields: #{inspect(fields_to_restore)} from data: #{inspect(restored_data)}") # Log
    Enum.reduce(fields_to_restore, emulator, fn field, acc_emulator ->
      if Map.has_key?(restored_data, field) do
        Logger.debug("[ApplyRestore] Applying field: #{field} with value: #{inspect(Map.get(restored_data, field))}") # Log
        Map.put(acc_emulator, field, Map.get(restored_data, field))
      else
        acc_emulator
      end
    end)
  end
end

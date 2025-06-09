defmodule Raxol.Terminal.ANSI.TerminalState do
  @moduledoc """
  Manages the terminal state including cursor position, attributes, and modes.
  Handles saving and restoring terminal state, including cursor position,
  attributes, character sets, and screen modes.
  """

  @behaviour Raxol.Terminal.ANSI.TerminalStateBehaviour

  require Raxol.Core.Runtime.Log

  @type saved_state :: %{
          cursor: {non_neg_integer(), non_neg_integer()},
          attributes: map(),
          style: map(),
          charset_state: CharacterSets.charset_state(),
          mode_manager: Raxol.Terminal.ModeManager.t(),
          scroll_region: {non_neg_integer(), non_neg_integer()} | nil,
          cursor_style: atom()
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
  @impl Raxol.Terminal.ANSI.TerminalStateBehaviour
  def save_state(stack, state) do
    saved_state = %{
      cursor: Map.get(state, :cursor),
      style: Map.get(state, :style),
      charset_state: Map.get(state, :charset_state),
      mode_manager: Map.get(state, :mode_manager),
      scroll_region: Map.get(state, :scroll_region),
      cursor_style: Map.get(state, :cursor_style)
    }

    [saved_state | stack]
  end

  @doc """
  Restores the most recently saved terminal state from the stack.
  Returns the updated stack and the restored state.
  """
  @spec restore_state(state_stack()) :: {state_stack(), map() | nil}
  @impl Raxol.Terminal.ANSI.TerminalStateBehaviour
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
  @impl Raxol.Terminal.ANSI.TerminalStateBehaviour
  def apply_restored_data(emulator, nil, _fields_to_restore) do
    # No data to restore, return emulator unchanged
    Raxol.Core.Runtime.Log.debug("[ApplyRestore] No data to restore.")
    emulator
  end

  def apply_restored_data(emulator, restored_data, fields_to_restore) do
    Raxol.Core.Runtime.Log.debug(
      "[ApplyRestore] Restoring fields: #{inspect(fields_to_restore)} from data: #{inspect(restored_data)}"
    )

    Enum.reduce(fields_to_restore, emulator, fn field, acc_emulator ->
      if Map.has_key?(restored_data, field) do
        Raxol.Core.Runtime.Log.debug(
          "[ApplyRestore] Applying field: #{field} with value: #{inspect(Map.get(restored_data, field))}"
        )

        Map.put(acc_emulator, field, Map.get(restored_data, field))
      else
        acc_emulator
      end
    end)
  end

  @doc """
  Pushes a state onto the stack.
  Returns {:ok, updated_stack} or {:error, reason}.
  """
  @spec push(state_stack()) :: {:ok, state_stack()} | {:error, String.t()}
  def push(stack) do
    {:ok, stack}
  end

  @doc """
  Pops a state from the stack.
  Returns {:ok, {updated_stack, state}} or {:error, reason}.
  """
  @spec pop(state_stack()) ::
          {:ok, {state_stack(), saved_state()}} | {:error, String.t()}
  def pop([]) do
    {:error, "Stack is empty"}
  end

  def pop([state | rest]) do
    {:ok, {rest, state}}
  end

  @doc """
  Gets the current state from the stack.
  Returns the current state or nil if stack is empty.
  """
  @spec current(state_stack()) :: saved_state() | nil
  def current([]), do: nil
  def current([state | _]), do: state
end

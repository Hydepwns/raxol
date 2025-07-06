defmodule Raxol.Terminal.ANSI.TerminalState do
  import Raxol.Guards

  @moduledoc """
  Manages terminal state operations for ANSI escape sequences.
  """

  defstruct [
    :state_stack,
    :current_state,
    :saved_states,
    :max_saved_states
  ]

  @type t :: %__MODULE__{
          state_stack: list(map()),
          current_state: map(),
          saved_states: list(map()),
          max_saved_states: integer()
        }

  @doc """
  Creates a new terminal state with default settings.
  """
  def new(opts \\ []) do
    %__MODULE__{
      state_stack: [],
      current_state: default_state(),
      saved_states: [],
      max_saved_states: Keyword.get(opts, :max_saved_states, 10)
    }
  end

  @doc """
  Gets the current state stack.
  """
  def get_state_stack(%__MODULE__{} = state) do
    state.state_stack
  end

  @doc """
  Updates the state stack.
  """
  def update_state_stack(%__MODULE__{} = state, new_stack)
      when list?(new_stack) do
    %{state | state_stack: new_stack}
  end

  @doc """
  Saves the current state.
  """
  def save(%__MODULE__{} = state) do
    saved_states = [state.current_state | state.saved_states]

    saved_states =
      if length(saved_states) > state.max_saved_states do
        Enum.take(saved_states, state.max_saved_states)
      else
        saved_states
      end

    %{state | saved_states: saved_states}
  end

  @doc """
  Restores the most recently saved state.
  """
  def restore(%__MODULE__{} = state) do
    case state.saved_states do
      [saved_state | remaining_states] ->
        %{state | current_state: saved_state, saved_states: remaining_states}

      [] ->
        state
    end
  end

  @doc """
  Checks if there are any saved states.
  """
  def has_saved_states?(%__MODULE__{} = state) do
    length(state.saved_states) > 0
  end

  @doc """
  Gets the number of saved states.
  """
  def get_saved_states_count(%__MODULE__{} = state) do
    length(state.saved_states)
  end

  @doc """
  Clears all saved states.
  """
  def clear(%__MODULE__{} = state) do
    %{state | saved_states: []}
  end

  @doc """
  Gets the current state.
  """
  def get_current_state(%__MODULE__{} = state) do
    state.current_state
  end

  @doc """
  Updates the current state.
  """
  def update_current_state(%__MODULE__{} = state, new_state)
      when map?(new_state) do
    %{state | current_state: new_state}
  end

  @doc """
  Pushes the current state onto the state stack.
  """
  def push(%__MODULE__{} = state) do
    new_stack = [state.current_state | state.state_stack]
    %{state | state_stack: new_stack}
  end

  @doc """
  Pops a state from the state stack.
  """
  def pop(%__MODULE__{} = state) do
    case state.state_stack do
      [popped_state | remaining_stack] ->
        {:ok,
         %{state | current_state: popped_state, state_stack: remaining_stack}}

      [] ->
        {:error, :empty_stack}
    end
  end

  @doc """
  Gets the current state from the state stack.
  """
  def current(%__MODULE__{} = state) do
    case state.state_stack do
      [current | _] -> current
      [] -> nil
    end
  end

  @doc """
  Saves the current terminal state to the state stack.
  """
  def save_state(stack, state) do
    [state | stack]
  end

  @doc """
  Restores the most recently saved terminal state from the state stack.
  Returns the restored state and the updated stack.
  """
  def restore_state([state | stack]), do: {state, stack}
  def restore_state([]), do: {nil, []}

  @doc """
  Gets the count of states in the state stack.
  """
  def count(stack) when list?(stack) do
    length(stack)
  end

  @doc """
  Checks if the state stack is empty.
  """
  def empty?(stack) when list?(stack) do
    stack == []
  end

  @doc """
  Clears the terminal state stack.
  """
  def clear_state(stack) when list?(stack) do
    []
  end

  @doc """
  Applies restored data to the emulator state.
  """
  def apply_restored_data(emulator, restored_state, fields_to_restore) do
    Enum.reduce(fields_to_restore, emulator, fn field, acc ->
      case field do
        :cursor when is_map(restored_state.cursor) ->
          %{acc | cursor: Map.merge(acc.cursor, restored_state.cursor)}

        :style when is_map(restored_state.style) ->
          %{acc | style: restored_state.style}

        :charset_state when is_map(restored_state.charset_state) ->
          %{acc | charset_state: restored_state.charset_state}

        :mode_manager when is_map(restored_state.mode_manager) ->
          %{
            acc
            | mode_manager:
                Map.merge(acc.mode_manager, restored_state.mode_manager)
          }

        :scroll_region ->
          %{acc | scroll_region: restored_state.scroll_region}

        :cursor_style ->
          %{acc | cursor_style: restored_state.cursor_style}

        _ ->
          acc
      end
    end)
  end

  defp default_state do
    %{
      cursor_visible: true,
      cursor_style: :block,
      cursor_blink: true,
      cursor_position: {0, 0},
      scroll_region: nil,
      origin_mode: false,
      auto_wrap: true,
      insert_mode: false,
      line_feed_mode: false,
      reverse_video: false,
      attributes: %{},
      colors: %{
        foreground: 7,
        background: 0
      }
    }
  end
end

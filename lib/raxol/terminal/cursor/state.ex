defmodule Raxol.Terminal.Cursor.State do
  @moduledoc """
  Handles cursor state management operations for the terminal cursor.
  Extracted from Raxol.Terminal.Cursor.Manager to reduce file size.
  """

  alias Raxol.Terminal.Cursor.Manager

  @doc """
  Saves the current cursor state.
  """
  def save_state(%Manager{} = state) do
    %{
      state
      | saved_row: state.row,
        saved_col: state.col,
        saved_style: state.style,
        saved_visible: state.visible,
        saved_blinking: state.blinking,
        saved_color: state.color,
        saved_position: {state.row, state.col}
    }
  end

  @doc """
  Restores the saved cursor state.
  """
  def restore_state(%Manager{} = state) do
    %{
      state
      | row: state.saved_row || state.row,
        col: state.saved_col || state.col,
        style: state.saved_style || state.style,
        visible: state.saved_visible || state.visible,
        blinking: state.saved_blinking || state.blinking,
        color: state.saved_color || state.color,
        position: state.saved_position || {state.row, state.col}
    }
  end

  @doc """
  Resets the cursor state to default values.
  """
  def reset(%Manager{} = state) do
    %{
      state
      | row: 0,
        col: 0,
        position: {0, 0},
        visible: true,
        blinking: true,
        style: :block,
        color: nil,
        saved_row: nil,
        saved_col: nil,
        saved_style: nil,
        saved_visible: nil,
        saved_blinking: nil,
        saved_color: nil
    }
  end

  @doc """
  Sets the cursor state based on a state atom.
  Supported states: :visible, :hidden, :blinking
  """
  def set_state(%Manager{} = state, state_atom),
    do: do_set_state(state, state_atom)

  defp do_set_state(state, :visible),
    do: %{state | visible: true, state: :visible}

  defp do_set_state(state, :hidden),
    do: %{state | visible: false, state: :hidden}

  defp do_set_state(state, :blinking),
    do: %{state | blinking: true, blink: true, state: :blinking}

  @doc """
  Saves the current cursor position.
  """
  def save_position(%Manager{} = state) do
    %{
      state
      | saved_row: state.row,
        saved_col: state.col,
        saved_position: {state.row, state.col}
    }
  end

  @doc """
  Restores the saved cursor position.
  """
  def restore_position(%Manager{} = state) do
    if state.saved_row && state.saved_col do
      %{
        state
        | row: state.saved_row,
          col: state.saved_col,
          position: {state.saved_row, state.saved_col}
      }
    else
      state
    end
  end

  @doc """
  Adds the current cursor state to history.
  """
  def add_to_history(%Manager{} = state) do
    history_entry = %{
      row: state.row,
      col: state.col,
      style: state.style,
      visible: state.visible,
      blinking: state.blinking,
      state: state.state,
      position: {state.row, state.col}
    }

    %{
      state
      | history: [history_entry | state.history],
        history_index: state.history_index + 1
    }
  end

  @doc """
  Restores cursor state from history.
  """
  def restore_from_history(%Manager{} = state) do
    case state.history do
      [entry | rest] ->
        %{
          state
          | row: entry.row,
            col: entry.col,
            style: entry.style,
            visible: entry.visible,
            blinking: entry.blinking,
            state: entry.state,
            position: {entry.row, entry.col},
            history: rest
        }

      [] ->
        state
    end
  end

  @doc """
  Gets the cursor state atom (:visible, :hidden, :blinking).
  """
  def get_state(%Manager{state: state}), do: state

  @doc """
  Sets the cursor margins.
  """
  def set_margins(cursor, top, bottom) do
    %{cursor | top_margin: top, bottom_margin: bottom}
  end

  @doc """
  Gets the cursor margins.
  """
  def get_margins(cursor) do
    {cursor.top_margin, cursor.bottom_margin}
  end

  @doc """
  Sets a custom cursor shape.
  """
  def set_custom_shape(%Manager{} = state, shape, params),
    do: %{
      state
      | style: :custom,
        custom_shape: shape,
        custom_dimensions: params,
        shape: params
    }

  @doc """
  Updates cursor position based on text input.
  """
  def update_position_from_text(%Manager{} = cursor, text)
      when is_binary(text) do
    # Calculate new position based on text length
    new_col = cursor.col + String.length(text)
    %{cursor | col: new_col, position: {cursor.row, new_col}}
  end

  @doc """
  Updates the cursor blink state.
  """
  def update_blink(%Manager{state: :visible} = state), do: {state, true}
  def update_blink(%Manager{state: :hidden} = state), do: {state, false}

  def update_blink(%Manager{state: :blinking, blink: blink} = state) do
    new_blink = !blink
    {%{state | blink: new_blink}, new_blink}
  end
end

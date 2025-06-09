defmodule Raxol.Terminal.Cursor.Manager do
  @moduledoc """
  Manages cursor state and operations.
  """

  require Raxol.Core.Runtime.Log

  defstruct position: {0, 0},
            style: :block,
            state: :visible,
            saved_position: nil,
            saved_style: nil,
            saved_state: nil,
            custom_shape: nil,
            custom_dimensions: nil,
            shape: {1, 1},
            blink_rate: 530,
            history: [],
            history_index: 0,
            history_limit: 100

  @type position :: {non_neg_integer(), non_neg_integer()}
  @type style :: :block | :underline | :bar | :custom
  @type state :: :visible | :hidden | :blinking
  @typedoc """
  Cursor struct representing position, style, state, and saved values.
  """
  @type t :: %__MODULE__{
          position: position(),
          style: style(),
          state: state(),
          saved_position: position() | nil,
          saved_style: style() | nil,
          saved_state: state() | nil,
          custom_shape: any() | nil,
          custom_dimensions: any() | nil,
          shape: {integer(), integer()},
          blink_rate: integer(),
          history: list(),
          history_index: integer(),
          history_limit: integer()
        }

  @doc """
  Creates a new cursor with default values.
  """
  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end

  @doc """
  Gets the cursor's current position.
  Accepts either an Emulator struct or a Cursor struct.
  """
  def get_position(%__MODULE__{} = cursor) do
    cursor.position
  end

  @doc """
  Moves the cursor to a new position (no clamping, arity 2).
  """
  def move_to(%__MODULE__{} = cursor, {x, y}) do
    %{cursor | position: {x, y}}
  end

  @doc """
  Moves the cursor to a new position (no clamping, arity 3 for compatibility).
  """
  def move_to(%__MODULE__{} = cursor, x, y) do
    move_to(cursor, {x, y})
  end

  @doc """
  Moves the cursor to a new position, clamped to the screen bounds.
  """
  def move_to(%__MODULE__{} = cursor, x, y, width, height) do
    move_to(cursor, {x, y}, width, height)
  end

  @doc """
  Moves the cursor to a new position (clamped to the screen bounds).
  """
  def move_to(%__MODULE__{} = cursor, {x, y}, width, height) do
    {clamped_x, clamped_y} = clamp_position({x, y}, width, height)
    %{cursor | position: {clamped_x, clamped_y}}
  end

  @doc """
  Saves the cursor's current position (only position, not style or state).
  """
  def save_position(%__MODULE__{} = cursor) do
    %{cursor | saved_position: cursor.position}
  end

  @doc """
  Saves the cursor's current state.
  """
  def save_state(cursor) do
    %{
      cursor
      | saved_position: cursor.position,
        saved_style: cursor.style,
        saved_state: cursor.state
    }
  end

  @doc """
  Restores the cursor's saved state.
  """
  def restore_state(cursor) do
    %{
      cursor
      | position: cursor.saved_position || cursor.position,
        style: cursor.saved_style || cursor.style,
        state: cursor.saved_state || cursor.state,
        saved_position: nil,
        saved_style: nil,
        saved_state: nil
    }
  end

  @doc """
  Gets the cursor's current style.
  """
  def get_style(cursor) do
    cursor.style
  end

  @doc """
  Sets the cursor's style.
  """
  def set_style(cursor, style) do
    %{cursor | style: style}
  end

  @doc """
  Gets the cursor's current state.
  """
  def get_state(cursor) do
    cursor.state
  end

  @doc """
  Sets the cursor's state.
  """
  def set_state(cursor, state) do
    %{cursor | state: state}
  end

  @doc """
  Updates the cursor's blink state and returns the updated cursor and visibility.
  """
  def update_blink(cursor) do
    case cursor.state do
      :blinking ->
        visible = cursor.style != :hidden

        new_cursor =
          case cursor.style do
            :visible -> %{cursor | style: :hidden}
            :hidden -> %{cursor | style: :visible}
            _ -> cursor
          end

        {new_cursor, visible}

      :visible ->
        {cursor, true}

      :hidden ->
        {cursor, false}

      _ ->
        {cursor, true}
    end
  end

  @doc """
  Gets whether the cursor is visible.
  """
  def is_visible?(%__MODULE__{} = cursor) do
    cursor.state == :visible
  end

  @doc """
  Sets the cursor visibility.
  """
  def set_visibility(%__MODULE__{} = cursor, visible)
      when is_boolean(visible) do
    state = if visible, do: :visible, else: :hidden
    %{cursor | state: state}
  end

  @doc """
  Moves the cursor to the next tab stop.
  """
  def move_to_next_tab(%__MODULE__{} = cursor, tab_stops, width) do
    {x, y} = cursor.position
    next_tab = find_next_tab(x, tab_stops, width)
    %{cursor | position: {next_tab, y}}
  end

  @doc """
  Moves the cursor to the previous tab stop.
  """
  def move_to_previous_tab(%__MODULE__{} = cursor, tab_stops) do
    {x, y} = cursor.position
    prev_tab = find_previous_tab(x, tab_stops)
    %{cursor | position: {prev_tab, y}}
  end

  @doc """
  Moves the cursor up by the specified number of lines, clamped to the screen bounds.
  """
  def move_up(%__MODULE__{} = cursor, lines, width, height) do
    {x, y} = cursor.position
    move_to(cursor, {x, y - lines}, width, height)
  end

  @doc """
  Moves the cursor down by the specified number of lines, clamped to the screen bounds.
  """
  def move_down(%__MODULE__{} = cursor, lines, width, height) do
    {x, y} = cursor.position
    move_to(cursor, {x, y + lines}, width, height)
  end

  @doc """
  Moves the cursor left by the specified number of columns, clamped to the screen bounds.
  """
  def move_left(%__MODULE__{} = cursor, columns, width, height) do
    {x, y} = cursor.position
    move_to(cursor, {x - columns, y}, width, height)
  end

  @doc """
  Moves the cursor right by the specified number of columns, clamped to the screen bounds.
  """
  def move_right(%__MODULE__{} = cursor, columns, width, height) do
    {x, y} = cursor.position
    move_to(cursor, {x + columns, y}, width, height)
  end

  @doc """
  Moves the cursor to the beginning of the line.
  """
  def move_to_line_start(%__MODULE__{} = cursor) do
    {_, y} = cursor.position
    %{cursor | position: {0, y}}
  end

  @doc """
  Moves the cursor to the specified column, clamped to the screen bounds.
  """
  def move_to_column(%__MODULE__{} = cursor, column, width, height) do
    {_, y} = cursor.position
    move_to(cursor, {column, y}, width, height)
  end

  @doc """
  Clamps a position to the screen bounds.
  """
  @spec clamp_position({integer(), integer()}, integer(), integer()) ::
          {integer(), integer()}
  def clamp_position({x, y}, width, height) do
    {
      min(max(x, 0), width - 1),
      min(max(y, 0), height - 1)
    }
  end

  @doc """
  Sets a custom cursor shape and dimensions.
  """
  def set_custom_shape(%__MODULE__{} = cursor, shape, dimensions) do
    %{
      cursor
      | style: :custom,
        custom_shape: shape,
        custom_dimensions: dimensions,
        shape: dimensions
    }
  end

  @doc """
  Restores the cursor's saved position (if any).
  """
  def restore_position(%__MODULE__{} = cursor) do
    %{cursor | position: cursor.saved_position || cursor.position}
  end

  @doc """
  Adds the current cursor state to history.
  """
  def add_to_history(%__MODULE__{} = cursor) do
    history =
      if length(cursor.history) >= cursor.history_limit do
        [cursor | Enum.take(cursor.history, cursor.history_limit - 1)]
      else
        [cursor | cursor.history]
      end

    %{cursor | history: history, history_index: length(history)}
  end

  @doc """
  Restores the cursor state from history.
  """
  def restore_from_history(%__MODULE__{} = cursor) do
    case cursor.history do
      [last | rest] ->
        %{
          last
          | history: rest,
            history_index: 0,
            history_limit: cursor.history_limit
        }

      _ ->
        cursor
    end
  end

  @doc """
  Resets the cursor position to the origin (0,0).
  """
  def reset_position(%__MODULE__{} = cursor) do
    %{cursor | position: {0, 0}}
  end

  @doc """
  Updates the cursor position based on the text content.
  """
  def update_position(%__MODULE__{} = cursor, text) do
    {x, y} = cursor.position
    new_x = x + String.length(text)
    %{cursor | position: {new_x, y}}
  end

  @doc """
  Gets the visible content from the buffer manager.
  """
  def get_visible_content(buffer_manager) do
    buffer_manager.visible_content
  end

  @doc """
  Gets the total number of lines in the buffer.
  """
  def get_total_lines(buffer_manager) do
    buffer_manager.total_lines
  end

  @doc """
  Gets the number of visible lines in the buffer.
  """
  def get_visible_lines(buffer_manager) do
    buffer_manager.visible_lines
  end

  @doc """
  Constrains the cursor position to the given width and height.
  """
  def constrain_position(%__MODULE__{} = cursor, width, height) do
    {x, y} = cursor.position
    clamped_x = min(max(x, 0), width - 1)
    clamped_y = min(max(y, 0), height - 1)
    %{cursor | position: {clamped_x, clamped_y}}
  end

  @doc """
  Writes text to the buffer at the cursor position.
  """
  def write(buffer_manager, _text) do
    # Implementation details...
    buffer_manager
  end

  @doc """
  Clears the buffer.
  """
  def clear(buffer_manager) do
    # Implementation details...
    {:ok, buffer_manager}
  end

  @doc """
  Updates the visible region of the buffer.
  """
  def update_visible_region(buffer_manager, _visible_region) do
    # Implementation details...
    buffer_manager
  end

  @doc """
  Resizes the buffer to the given dimensions.
  """
  def resize(buffer_manager, _width, _height) do
    # Implementation details...
    buffer_manager
  end

  # Private helper functions

  defp find_next_tab(current_x, tab_stops, width) do
    tab_stops
    |> Enum.sort()
    |> Enum.find(fn tab -> tab > current_x end)
    |> case do
      nil -> width - 1
      tab -> tab
    end
  end

  defp find_previous_tab(current_x, tab_stops) do
    tab_stops
    |> Enum.sort(:desc)
    |> Enum.find(fn tab -> tab < current_x end)
    |> case do
      nil -> 0
      tab -> tab
    end
  end
end

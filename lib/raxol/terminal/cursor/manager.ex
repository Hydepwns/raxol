defmodule Raxol.Terminal.Cursor.Manager do
  @moduledoc """
  Manages cursor state and operations.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Emulator
  require Logger

  defstruct position: {0, 0},
            style: :block,
            state: :visible,
            saved_position: nil,
            saved_style: nil,
            saved_state: nil,
            custom_shape: nil,
            custom_dimensions: nil

  @type position :: {non_neg_integer(), non_neg_integer()}
  @type style :: :block | :underline | :bar | :custom
  @type state :: :visible | :hidden | :blinking
  @type cursor :: %__MODULE__{
          position: position(),
          style: style(),
          state: state(),
          saved_position: position() | nil,
          saved_style: style() | nil,
          saved_state: state() | nil,
          custom_shape: any() | nil,
          custom_dimensions: any() | nil
        }

  @doc """
  Creates a new cursor with default values.
  """
  def new(_opts \\ []) do
    %__MODULE__{}
  end

  @doc """
  Gets the cursor's current position.
  """
  def get_position(cursor) do
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
  Updates the cursor's blink state.
  """
  def update_blink(cursor) do
    case cursor.state do
      :blinking ->
        case cursor.style do
          :visible -> %{cursor | style: :hidden}
          :hidden -> %{cursor | style: :visible}
          _ -> cursor
        end

      _ ->
        cursor
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
        custom_dimensions: dimensions
    }
  end

  @doc """
  Restores the cursor's saved position (if any).
  """
  def restore_position(%__MODULE__{} = cursor) do
    %{cursor | position: cursor.saved_position || cursor.position}
  end

  @doc """
  Adds the current cursor state to history (stub; not yet implemented).
  """
  def add_to_history(%__MODULE__{} = cursor), do: cursor

  @doc """
  Restores the cursor state from history (stub; not yet implemented).
  """
  def restore_from_history(%__MODULE__{} = cursor), do: cursor

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

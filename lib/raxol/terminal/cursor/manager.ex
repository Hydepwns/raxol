defmodule Raxol.Terminal.Cursor.Manager do
  @moduledoc """
  Terminal cursor manager module.

  This module handles the management of terminal cursors, including:
  - Multiple cursor styles
  - State persistence
  - Animation system
  - Position tracking
  """

  @type cursor_style :: :block | :underline | :bar | :custom
  @type cursor_state :: :visible | :hidden | :blinking
  # width, height
  @type cursor_shape :: {non_neg_integer(), non_neg_integer()}

  @type t :: %__MODULE__{
          position: {non_neg_integer(), non_neg_integer()},
          saved_position: {non_neg_integer(), non_neg_integer()} | nil,
          style: cursor_style,
          state: cursor_state,
          shape: cursor_shape,
          blink_rate: non_neg_integer(),
          last_blink: integer(),
          custom_shape: String.t() | nil,
          history: list(map()),
          history_index: non_neg_integer(),
          history_limit: non_neg_integer()
        }

  defstruct [
    :position,
    :saved_position,
    :style,
    :state,
    :shape,
    :blink_rate,
    :last_blink,
    :custom_shape,
    :history,
    :history_index,
    :history_limit
  ]

  @doc """
  Creates a new cursor manager.

  ## Examples

      iex> cursor = Cursor.Manager.new()
      iex> cursor.position
      {0, 0}
      iex> cursor.style
      :block
  """
  def new do
    %__MODULE__{
      position: {0, 0},
      saved_position: nil,
      style: :block,
      state: :visible,
      shape: {1, 1},
      # milliseconds
      blink_rate: 530,
      last_blink: System.system_time(:millisecond),
      custom_shape: nil,
      history: [],
      history_index: 0,
      history_limit: 100
    }
  end

  @doc """
  Moves the cursor to a new position.

  ## Examples

      iex> cursor = Cursor.Manager.new()
      iex> cursor = Cursor.Manager.move_to(cursor, 10, 5)
      iex> cursor.position
      {10, 5}
  """
  def move_to(%__MODULE__{} = cursor, x, y) do
    %{cursor | position: {x, y}}
  end

  @doc """
  Saves the current cursor position.

  ## Examples

      iex> cursor = Cursor.Manager.new()
      iex> cursor = Cursor.Manager.move_to(cursor, 10, 5)
      iex> cursor = Cursor.Manager.save_position(cursor)
      iex> cursor.saved_position
      {10, 5}
  """
  def save_position(%__MODULE__{} = cursor) do
    %{cursor | saved_position: cursor.position}
  end

  @doc """
  Restores the saved cursor position.

  ## Examples

      iex> cursor = Cursor.Manager.new()
      iex> cursor = Cursor.Manager.move_to(cursor, 10, 5)
      iex> cursor = Cursor.Manager.save_position(cursor)
      iex> cursor = Cursor.Manager.move_to(cursor, 0, 0)
      iex> cursor = Cursor.Manager.restore_position(cursor)
      iex> cursor.position
      {10, 5}
  """
  def restore_position(%__MODULE__{} = cursor) do
    case cursor.saved_position do
      nil -> cursor
      pos -> %{cursor | position: pos}
    end
  end

  @doc """
  Sets the cursor style.

  ## Examples

      iex> cursor = Cursor.Manager.new()
      iex> cursor = Cursor.Manager.set_style(cursor, :underline)
      iex> cursor.style
      :underline
  """
  def set_style(%__MODULE__{} = cursor, style)
      when style in [:block, :underline, :bar] do
    shape =
      case style do
        :block -> {1, 1}
        :underline -> {1, 1}
        :bar -> {1, 1}
      end

    %{cursor | style: style, shape: shape, custom_shape: nil}
  end

  @doc """
  Sets a custom cursor shape.

  ## Examples

      iex> cursor = Cursor.Manager.new()
      iex> cursor = Cursor.Manager.set_custom_shape(cursor, "█", {2, 1})
      iex> cursor.style
      :custom
      iex> cursor.custom_shape
      "█"
  """
  def set_custom_shape(%__MODULE__{} = cursor, shape, dimensions) do
    %{cursor | style: :custom, custom_shape: shape, shape: dimensions}
  end

  @doc """
  Sets the cursor state.

  ## Examples

      iex> cursor = Cursor.Manager.new()
      iex> cursor = Cursor.Manager.set_state(cursor, :hidden)
      iex> cursor.state
      :hidden
  """
  def set_state(%__MODULE__{} = cursor, state)
      when state in [:visible, :hidden, :blinking] do
    %{cursor | state: state}
  end

  @doc """
  Updates the cursor blink state.

  ## Examples

      iex> cursor = Cursor.Manager.new()
      iex> cursor = Cursor.Manager.set_state(cursor, :blinking)
      iex> {cursor, visible} = Cursor.Manager.update_blink(cursor)
      iex> is_boolean(visible)
      true
  """
  def update_blink(%__MODULE__{} = cursor) do
    case cursor.state do
      :blinking ->
        now = System.system_time(:millisecond)
        elapsed = now - cursor.last_blink
        visible = rem(div(elapsed, cursor.blink_rate), 2) == 0

        {%{cursor | last_blink: now}, visible}

      _ ->
        {cursor, cursor.state == :visible}
    end
  end

  @doc """
  Adds the current cursor state to history.

  ## Examples

      iex> cursor = Cursor.Manager.new()
      iex> cursor = Cursor.Manager.add_to_history(cursor)
      iex> length(cursor.history)
      1
  """
  def add_to_history(%__MODULE__{} = cursor) do
    state = %{
      position: cursor.position,
      style: cursor.style,
      state: cursor.state,
      shape: cursor.shape,
      custom_shape: cursor.custom_shape
    }

    history = [state | Enum.take(cursor.history, cursor.history_limit - 1)]

    %{
      cursor
      | history: history,
        history_index: min(cursor.history_index + 1, cursor.history_limit)
    }
  end

  @doc """
  Restores the cursor state from history.

  ## Examples

      iex> cursor = Cursor.Manager.new()
      iex> cursor = Cursor.Manager.add_to_history(cursor)
      iex> cursor = Cursor.Manager.move_to(cursor, 10, 5)
      iex> cursor = Cursor.Manager.restore_from_history(cursor)
      iex> cursor.position
      {0, 0}
  """
  def restore_from_history(%__MODULE__{} = cursor) do
    case Enum.at(cursor.history, cursor.history_index - 1) do
      nil ->
        cursor

      state ->
        %{
          cursor
          | position: state.position,
            style: state.style,
            state: state.state,
            shape: state.shape,
            custom_shape: state.custom_shape
        }
    end
  end
end

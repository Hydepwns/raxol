defmodule Raxol.UI.Components.Input.TextEditing do
  @moduledoc """
  Shared text editing operations for input components.

  Provides pure functions for insert, backspace, delete, and cursor
  movement that operate on `{value, cursor_pos}` tuples. Components
  map their own state structure to/from these tuples.
  """

  @type cursor_pos :: non_neg_integer()

  @doc """
  Inserts a character (or string) at the cursor position.

  Returns `{new_value, new_cursor_pos}`.
  """
  @spec insert_at(String.t(), cursor_pos(), String.t()) ::
          {String.t(), cursor_pos()}
  def insert_at(value, cursor_pos, char) do
    before = String.slice(value, 0, cursor_pos)
    after_cursor = String.slice(value, max(0, cursor_pos)..-1//1)
    new_value = before <> char <> after_cursor
    {new_value, cursor_pos + String.length(char)}
  end

  @doc """
  Deletes the character before the cursor (backspace).

  Returns `{new_value, new_cursor_pos}`. No-op if cursor is at position 0.
  """
  @spec backspace(String.t(), cursor_pos()) ::
          {String.t(), cursor_pos()} | {:noop, cursor_pos()}
  def backspace(_value, 0), do: {:noop, 0}

  def backspace(value, cursor_pos) do
    before = String.slice(value, 0, max(0, cursor_pos - 1))
    after_cursor = String.slice(value, max(0, cursor_pos)..-1//1)
    {before <> after_cursor, cursor_pos - 1}
  end

  @doc """
  Deletes the character at the cursor position (forward delete).

  Returns `{new_value, cursor_pos}`. No-op if cursor is at end.
  """
  @spec delete(String.t(), cursor_pos()) ::
          {String.t(), cursor_pos()} | {:noop, cursor_pos()}
  def delete(value, cursor_pos) do
    if cursor_pos >= String.length(value) do
      {:noop, cursor_pos}
    else
      before = String.slice(value, 0, cursor_pos)
      after_cursor = String.slice(value, max(0, cursor_pos + 1)..-1//1)
      {before <> after_cursor, cursor_pos}
    end
  end

  @doc """
  Moves the cursor by an offset, clamped to valid bounds.

  Returns the new cursor position.
  """
  @spec move_cursor(String.t(), cursor_pos(), integer()) :: cursor_pos()
  def move_cursor(value, cursor_pos, offset) do
    Raxol.Core.Utils.Math.clamp(
      cursor_pos + offset,
      0,
      String.length(value)
    )
  end

  @doc """
  Moves the cursor to an absolute position, clamped to valid bounds.
  """
  @spec move_cursor_to(String.t(), cursor_pos()) :: cursor_pos()
  def move_cursor_to(value, pos) do
    Raxol.Core.Utils.Math.clamp(pos, 0, String.length(value))
  end
end

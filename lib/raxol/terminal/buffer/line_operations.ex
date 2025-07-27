defmodule Raxol.Terminal.Buffer.LineOperations do
  @moduledoc """
  Provides line-level operations for the screen buffer.
  This module handles operations like inserting, deleting, and manipulating lines.
  """

  # Delegation to focused modules
  alias Raxol.Terminal.Buffer.LineOperations.{
    Insertion,
    Deletion,
    Management,
    CharOperations
  }

  # Delegate insertion operations
  defdelegate insert_lines(buffer, count), to: Insertion

  defdelegate insert_lines(
                buffer,
                count,
                cursor_y,
                cursor_x,
                scroll_top,
                scroll_bottom
              ),
              to: Insertion

  defdelegate do_insert_lines(buffer, cursor_y, count, bottom), to: Insertion

  defdelegate do_insert_lines_with_style(
                buffer,
                cursor_y,
                count,
                bottom,
                style
              ),
              to: Insertion

  defdelegate insert_lines(buffer, position, count), to: Insertion
  defdelegate insert_lines(buffer, position, count, style), to: Insertion
  defdelegate insert_lines(buffer, lines, y, top, bottom), to: Insertion

  # Delegate deletion operations
  defdelegate delete_lines(buffer, count), to: Deletion

  defdelegate delete_lines(
                buffer,
                count,
                cursor_y,
                cursor_x,
                scroll_top,
                scroll_bottom
              ),
              to: Deletion

  defdelegate delete_lines(buffer, position, count), to: Deletion
  defdelegate delete_lines(buffer, y, count, style, region), to: Deletion

  defdelegate delete_lines_in_region(buffer, lines, y, top, bottom),
    to: Deletion

  # Delegate management operations
  defdelegate prepend_lines(buffer, count), to: Management
  defdelegate pop_top_lines(buffer, count), to: Management
  defdelegate get_line(buffer, line_index), to: Management
  defdelegate update_line(buffer, line_index, new_line), to: Management
  defdelegate clear_line(buffer, line_index, style \\ nil), to: Management
  defdelegate set_line(buffer, position, new_line), to: Management
  defdelegate create_empty_lines(width, count), to: Management
  defdelegate create_empty_lines(width, count, style), to: Management
  defdelegate create_empty_line(width, style \\ nil), to: Management

  # Delegate character operations
  defdelegate erase_chars(buffer, row, col, count), to: CharOperations
  defdelegate delete_chars(buffer, count), to: CharOperations
  defdelegate delete_chars_at(buffer, row, col, count), to: CharOperations
  defdelegate insert_chars(buffer, count), to: CharOperations
  defdelegate insert_chars_at(buffer, row, col, count), to: CharOperations
end

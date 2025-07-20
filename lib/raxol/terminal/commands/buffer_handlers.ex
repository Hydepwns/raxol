defmodule Raxol.Terminal.Commands.BufferHandlers do
  @moduledoc false

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Commands.Editor

  def handle_l(emulator, count) do
    active_buffer = Emulator.get_active_buffer(emulator)
    {_x, y} = Emulator.get_cursor_position(emulator)

    style =
      active_buffer.default_style ||
        Raxol.Terminal.ANSI.TextFormatting.new()
        |> Map.from_struct()
        |> Map.put(:attributes, %{})

    updated_buffer = Editor.insert_lines(active_buffer, y, count, style)
    {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}
  end

  def handle_m(emulator, count) do
    active_buffer = Emulator.get_active_buffer(emulator)
    {_x, y} = Emulator.get_cursor_position(emulator)

    style =
      active_buffer.default_style ||
        Raxol.Terminal.ANSI.TextFormatting.new()
        |> Map.from_struct()
        |> Map.put(:attributes, %{})

    updated_buffer = Editor.delete_lines(active_buffer, y, count, style)
    {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}
  end

  def handle_x(emulator, count) do
    active_buffer = Emulator.get_active_buffer(emulator)
    {x, y} = Emulator.get_cursor_position(emulator)

    style =
      active_buffer.default_style ||
        Raxol.Terminal.ANSI.TextFormatting.new()
        |> Map.from_struct()
        |> Map.put(:attributes, %{})

    updated_buffer = Editor.erase_chars(active_buffer, y, x, count, style)
    {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}
  end

  def handle_L(emulator, count) do
    buffer = emulator.main_screen_buffer
    {_x, y} = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)

    n =
      case count do
        [n] -> n
        n when is_integer(n) -> n
        _ -> 1
      end

    style =
      buffer.default_style ||
        Raxol.Terminal.ANSI.TextFormatting.new()
        |> Map.from_struct()
        |> Map.put(:attributes, %{})

    # Check if we have a scroll region and if the cursor is within it
    case emulator.scroll_region do
      {scroll_top, scroll_bottom} when y >= scroll_top and y <= scroll_bottom ->
        # Insert lines within the scroll region
        Raxol.Core.Runtime.Log.debug(
          "handle_L: inserting #{n} lines within scroll region #{scroll_top}-#{scroll_bottom} at y=#{y}"
        )

        # Use scroll region-aware insertion
        updated_buffer = insert_lines_within_scroll_region(buffer, y, n, style, scroll_top, scroll_bottom)

        Raxol.Core.Runtime.Log.debug(
          "handle_L: scroll region insert returned: #{inspect(updated_buffer)}"
        )

        result = {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}
        Raxol.Core.Runtime.Log.debug("handle_L: returning: #{inspect(result)}")
        result

      _ ->
        # No scroll region or cursor outside scroll region, use normal insertion
    Raxol.Core.Runtime.Log.debug(
      "handle_L: calling Editor.insert_lines with buffer: #{inspect(buffer)}, y: #{y}, n: #{n}, style: #{inspect(style)}"
    )

    updated_buffer = Editor.insert_lines(buffer, y, n, style)

    Raxol.Core.Runtime.Log.debug(
      "handle_L: Editor.insert_lines returned: #{inspect(updated_buffer)}"
    )

    result = {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}
    Raxol.Core.Runtime.Log.debug("handle_L: returning: #{inspect(result)}")
    result
    end
  end

  # Helper function to insert lines within a scroll region
  defp insert_lines_within_scroll_region(buffer, y, count, style, scroll_top, scroll_bottom) do
    # Ensure y is within the scroll region
    y = max(scroll_top, min(y, scroll_bottom))

    # Create blank lines with the provided style
    blank_cell = %Raxol.Terminal.Cell{style: style}
    blank_line = List.duplicate(blank_cell, buffer.width)
    blank_lines_to_insert = List.duplicate(blank_line, count)

    # Split the buffer cells at the insertion row
    {top_part, bottom_part} = Enum.split(buffer.cells, y)

    # Take only the lines from the bottom part that will fit within the scroll region
    max_lines_in_region = scroll_bottom - scroll_top + 1
    lines_after_insertion = y - scroll_top + count
    lines_to_keep = max(0, max_lines_in_region - lines_after_insertion)

    # Keep lines from the bottom part that fit within the scroll region
    kept_bottom_part = Enum.take(bottom_part, lines_to_keep)

    # Add blank lines at the bottom of the scroll region if needed
    remaining_lines = max_lines_in_region - lines_after_insertion - lines_to_keep
    additional_blank_lines = if remaining_lines > 0 do
      List.duplicate(blank_line, remaining_lines)
    else
      []
    end

    # Combine the parts
    new_cells = top_part ++ blank_lines_to_insert ++ kept_bottom_part ++ additional_blank_lines

    # Ensure we don't exceed the buffer height
    final_cells = Enum.take(new_cells, buffer.height)

    %{buffer | cells: final_cells}
  end

  def handle_M(emulator, count) do
    buffer = emulator.main_screen_buffer
    {_x, y} = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)

    n =
      case count do
        [n] -> n
        n when is_integer(n) -> n
        _ -> 1
      end

    style =
      buffer.default_style ||
        Raxol.Terminal.ANSI.TextFormatting.new()
        |> Map.from_struct()
        |> Map.put(:attributes, %{})

    updated_buffer = Editor.delete_lines(buffer, y, n, style)
    {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}
  end

  def handle_P(emulator, count) do
    buffer = emulator.main_screen_buffer
    {x, y} = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)

    n =
      case count do
        [n] -> n
        n when is_integer(n) -> n
        _ -> 1
      end

    style =
      buffer.default_style ||
        Raxol.Terminal.ANSI.TextFormatting.new()
        |> Map.from_struct()
        |> Map.put(:attributes, %{})

    updated_buffer = Editor.delete_chars(buffer, y, x, n, style)
    {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}
  end

  def handle_X(emulator, count) do
    buffer = emulator.main_screen_buffer
    {x, y} = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)

    n =
      case count do
        [n] -> n
        n when is_integer(n) -> n
        _ -> 1
      end

    style =
      buffer.default_style ||
        Raxol.Terminal.ANSI.TextFormatting.new()
        |> Map.from_struct()
        |> Map.put(:attributes, %{})

    updated_buffer = Editor.erase_chars(buffer, y, x, n, style)
    {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}
  end

  def handle_at(emulator, count) do
    buffer = emulator.main_screen_buffer
    {x, y} = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)

    n =
      case count do
        [n] -> n
        n when is_integer(n) -> n
        _ -> 1
      end

    style =
      buffer.default_style ||
        Raxol.Terminal.ANSI.TextFormatting.new()
        |> Map.from_struct()
        |> Map.put(:attributes, %{})

    updated_buffer = Editor.insert_chars(buffer, y, x, n, style)
    {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}
  end
end

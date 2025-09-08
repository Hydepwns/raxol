defmodule Raxol.Terminal.Commands.BufferHandler do
  @moduledoc false

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Commands.Editor

  def handle_l(emulator, count) do
    active_buffer = Emulator.get_screen_buffer(emulator)
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
    active_buffer = Emulator.get_screen_buffer(emulator)
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
    active_buffer = Emulator.get_screen_buffer(emulator)
    {x, y} = Emulator.get_cursor_position(emulator)

    style =
      active_buffer.default_style ||
        Raxol.Terminal.ANSI.TextFormatting.new()
        |> Map.from_struct()
        |> Map.put(:attributes, %{})

    updated_buffer = Editor.erase_chars(active_buffer, y, x, count, style)
    {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}
  end

  def handle_l_alias(emulator, count) do
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
        updated_buffer =
          insert_lines_within_scroll_region(
            buffer,
            y,
            n,
            style,
            scroll_top,
            scroll_bottom
          )

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
  defp insert_lines_within_scroll_region(
         buffer,
         y,
         count,
         style,
         scroll_top,
         scroll_bottom
       ) do
    # Ensure y is within the scroll region
    y = max(scroll_top, min(y, scroll_bottom))

    # Create blank lines with the provided style
    blank_cell = %Raxol.Terminal.Cell{style: style}
    blank_line = List.duplicate(blank_cell, buffer.width)
    blank_lines_to_insert = List.duplicate(blank_line, count)

    # Split the buffer: lines before scroll region, scroll region, lines after scroll region
    {lines_before_scroll, rest} = Enum.split(buffer.cells, scroll_top)

    {scroll_region_lines, lines_after_scroll} =
      Enum.split(rest, scroll_bottom - scroll_top + 1)

    # Split the scroll region at the insertion point
    insertion_point_in_region = y - scroll_top

    {scroll_before_insertion, scroll_after_insertion} =
      Enum.split(scroll_region_lines, insertion_point_in_region)

    # Calculate how many lines from scroll_after_insertion can fit after inserting count lines
    max_lines_in_region = scroll_bottom - scroll_top + 1

    lines_after_insertion_count =
      max_lines_in_region - insertion_point_in_region - count

    kept_scroll_lines =
      case lines_after_insertion_count > 0 do
        true -> Enum.take(scroll_after_insertion, lines_after_insertion_count)
        false -> []
      end

    # Reconstruct the scroll region
    new_scroll_region =
      scroll_before_insertion ++ blank_lines_to_insert ++ kept_scroll_lines

    # Pad the scroll region to the correct size if needed
    padded_scroll_region =
      case length(new_scroll_region) < max_lines_in_region do
        true ->
          new_scroll_region ++
            List.duplicate(
              blank_line,
              max_lines_in_region - length(new_scroll_region)
            )

        false ->
          Enum.take(new_scroll_region, max_lines_in_region)
      end

    # Combine all parts: lines before + modified scroll region + lines after (unchanged)
    final_cells =
      lines_before_scroll ++ padded_scroll_region ++ lines_after_scroll

    %{buffer | cells: final_cells}
  end

  def handle_m_alias(emulator, count) do
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

  def handle_p_alias(emulator, count) do
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

  def handle_x_alias(emulator, count) do
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

  # Uppercase aliases for CSI command handlers
  def handle_L(emulator, count), do: handle_l_alias(emulator, count)
  def handle_M(emulator, count), do: handle_m_alias(emulator, count)
  def handle_P(emulator, count), do: handle_p_alias(emulator, count)
  def handle_X(emulator, count), do: handle_x_alias(emulator, count)
end

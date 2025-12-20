defmodule Raxol.Terminal.Commands.ScrollingTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.Commands.Scrolling
  alias Raxol.Terminal.ScreenBuffer

  setup do
    default_style = Raxol.Terminal.ANSI.TextFormatting.default_style()
    buffer_width = 10
    buffer_height = 5

    # Create a buffer with identifiable lines
    # Line 0: "0000000000"
    # Line 1: "1111111111"
    # ...
    # Line 4: "4444444444"
    initial_lines_content =
      Enum.map(0..(buffer_height - 1), fn i ->
        char = Integer.to_string(i)
        List.duplicate(Cell.new(char, default_style), buffer_width)
      end)

    buffer =
      ScreenBuffer.new(
        buffer_width,
        buffer_height
      )
      |> then(fn buf ->
        Enum.reduce(Enum.with_index(initial_lines_content), buf, fn {line, idx},
                                                                    acc ->
          ScreenBuffer.put_line(acc, idx, line)
        end)
      end)

    {:ok,
     buffer: buffer,
     default_style: default_style,
     buffer_width: buffer_width,
     buffer_height: buffer_height}
  end

  defp get_line_as_string(buffer, row_index) do
    ScreenBuffer.get_line(buffer, row_index)
    |> List.flatten()
    |> Enum.map_join("", fn cell -> cell.char end)
  end

  describe "scroll_up/4" do
    test "scrolls the entire buffer up by 1 line", %{
      buffer: buffer,
      default_style: default_style,
      buffer_width: buffer_width,
      buffer_height: buffer_height
    } do
      scrolled_buffer = Scrolling.scroll_up(buffer, 1, nil, default_style)

      assert get_line_as_string(scrolled_buffer, 0) == "1111111111"
      assert get_line_as_string(scrolled_buffer, 1) == "2222222222"
      assert get_line_as_string(scrolled_buffer, 2) == "3333333333"
      assert get_line_as_string(scrolled_buffer, 3) == "4444444444"
      # Blank line
      assert get_line_as_string(scrolled_buffer, 4) ==
               String.duplicate(" ", buffer_width)
    end

    test "scrolls the entire buffer up by multiple lines", %{
      buffer: buffer,
      default_style: default_style,
      buffer_width: buffer_width,
      buffer_height: buffer_height
    } do
      scrolled_buffer = Scrolling.scroll_up(buffer, 2, nil, default_style)

      assert get_line_as_string(scrolled_buffer, 0) == "2222222222"
      assert get_line_as_string(scrolled_buffer, 1) == "3333333333"
      assert get_line_as_string(scrolled_buffer, 2) == "4444444444"
      # Blank line
      assert get_line_as_string(scrolled_buffer, 3) ==
               String.duplicate(" ", buffer_width)

      # Blank line
      assert get_line_as_string(scrolled_buffer, 4) ==
               String.duplicate(" ", buffer_width)
    end

    test "scrolls a region up by 1 line", %{
      buffer: buffer,
      default_style: default_style,
      buffer_width: buffer_width
    } do
      # Scroll region from line 1 to 3 (0-indexed)
      scroll_region = {1, 3}

      scrolled_buffer =
        Scrolling.scroll_up(buffer, 1, scroll_region, default_style)

      # Unaffected
      assert get_line_as_string(scrolled_buffer, 0) == "0000000000"
      # Line 2 moves to 1
      assert get_line_as_string(scrolled_buffer, 1) == "2222222222"
      # Line 3 moves to 2
      assert get_line_as_string(scrolled_buffer, 2) == "3333333333"
      # Blank line in region
      assert get_line_as_string(scrolled_buffer, 3) ==
               String.duplicate(" ", buffer_width)

      # Unaffected
      assert get_line_as_string(scrolled_buffer, 4) == "4444444444"
    end

    test "scroll up by 0 lines does nothing", %{
      buffer: buffer,
      default_style: default_style
    } do
      scrolled_buffer = Scrolling.scroll_up(buffer, 0, nil, default_style)
      assert scrolled_buffer == buffer

      scrolled_buffer_region =
        Scrolling.scroll_up(buffer, 0, {1, 3}, default_style)

      assert scrolled_buffer_region == buffer
    end

    test "scroll up by more lines than buffer height fills with blank lines", %{
      buffer: buffer,
      default_style: default_style,
      buffer_width: buffer_width,
      buffer_height: buffer_height
    } do
      scrolled_buffer =
        Scrolling.scroll_up(buffer, buffer_height + 1, nil, default_style)

      for i <- 0..(buffer_height - 1) do
        assert get_line_as_string(scrolled_buffer, i) ==
                 String.duplicate(" ", buffer_width)
      end
    end

    test "scroll up in a region larger than region height fills region with blank lines",
         %{
           buffer: buffer,
           default_style: default_style,
           buffer_width: buffer_width
         } do
      # Region height 2
      scroll_region = {1, 2}

      scrolled_buffer =
        Scrolling.scroll_up(buffer, 3, scroll_region, default_style)

      # Unaffected
      assert get_line_as_string(scrolled_buffer, 0) == "0000000000"
      # Blank
      assert get_line_as_string(scrolled_buffer, 1) ==
               String.duplicate(" ", buffer_width)

      # Blank
      assert get_line_as_string(scrolled_buffer, 2) ==
               String.duplicate(" ", buffer_width)

      # Unaffected
      assert get_line_as_string(scrolled_buffer, 3) == "3333333333"
      # Unaffected
      assert get_line_as_string(scrolled_buffer, 4) == "4444444444"
    end

    test "scroll up with invalid region (top > bottom) does nothing", %{
      buffer: buffer,
      default_style: default_style
    } do
      scrolled_buffer = Scrolling.scroll_up(buffer, 1, {3, 1}, default_style)
      assert scrolled_buffer == buffer
    end

    test "scroll up ensures correct style for new lines", %{
      buffer: buffer,
      buffer_width: buffer_width
    } do
      # Red foreground
      custom_style =
        TextFormatting.new() |> Map.merge(%{foreground: {:rgb, 255, 0, 0}})

      scrolled_buffer = Scrolling.scroll_up(buffer, 1, nil, custom_style)

      # Check the style of the new blank line (last line)
      last_line_cells =
        ScreenBuffer.get_line(scrolled_buffer, buffer.height - 1)

      Enum.each(last_line_cells, fn cell ->
        assert cell.char == " "
        assert cell.style == custom_style
      end)
    end
  end

  describe "scroll_down/4" do
    test "scrolls the entire buffer down by 1 line", %{
      buffer: buffer,
      default_style: default_style,
      buffer_width: buffer_width
    } do
      scrolled_buffer = Scrolling.scroll_down(buffer, 1, nil, default_style)

      # Blank line
      assert get_line_as_string(scrolled_buffer, 0) ==
               String.duplicate(" ", buffer_width)

      assert get_line_as_string(scrolled_buffer, 1) == "0000000000"
      assert get_line_as_string(scrolled_buffer, 2) == "1111111111"
      assert get_line_as_string(scrolled_buffer, 3) == "2222222222"
      assert get_line_as_string(scrolled_buffer, 4) == "3333333333"
    end

    test "scrolls the entire buffer down by multiple lines", %{
      buffer: buffer,
      default_style: default_style,
      buffer_width: buffer_width
    } do
      scrolled_buffer = Scrolling.scroll_down(buffer, 2, nil, default_style)

      # Blank line
      assert get_line_as_string(scrolled_buffer, 0) ==
               String.duplicate(" ", buffer_width)

      # Blank line
      assert get_line_as_string(scrolled_buffer, 1) ==
               String.duplicate(" ", buffer_width)

      assert get_line_as_string(scrolled_buffer, 2) == "0000000000"
      assert get_line_as_string(scrolled_buffer, 3) == "1111111111"
      assert get_line_as_string(scrolled_buffer, 4) == "2222222222"
    end

    test "scrolls a region down by 1 line", %{
      buffer: buffer,
      default_style: default_style,
      buffer_width: buffer_width
    } do
      # Region from line 1 to 3
      scroll_region = {1, 3}

      scrolled_buffer =
        Scrolling.scroll_down(buffer, 1, scroll_region, default_style)

      # Unaffected
      assert get_line_as_string(scrolled_buffer, 0) == "0000000000"
      # Blank line in region
      assert get_line_as_string(scrolled_buffer, 1) ==
               String.duplicate(" ", buffer_width)

      # Line 1 moves to 2
      assert get_line_as_string(scrolled_buffer, 2) == "1111111111"
      # Line 2 moves to 3
      assert get_line_as_string(scrolled_buffer, 3) == "2222222222"
      # Unaffected
      assert get_line_as_string(scrolled_buffer, 4) == "4444444444"
    end

    test "scroll down by 0 lines does nothing", %{
      buffer: buffer,
      default_style: default_style
    } do
      scrolled_buffer = Scrolling.scroll_down(buffer, 0, nil, default_style)
      assert scrolled_buffer == buffer

      scrolled_buffer_region =
        Scrolling.scroll_down(buffer, 0, {1, 3}, default_style)

      assert scrolled_buffer_region == buffer
    end

    test "scroll down by more lines than buffer height fills with blank lines",
         %{
           buffer: buffer,
           default_style: default_style,
           buffer_width: buffer_width,
           buffer_height: buffer_height
         } do
      scrolled_buffer =
        Scrolling.scroll_down(buffer, buffer_height + 1, nil, default_style)

      for i <- 0..(buffer_height - 1) do
        assert get_line_as_string(scrolled_buffer, i) ==
                 String.duplicate(" ", buffer_width)
      end
    end

    test "scroll down in a region larger than region height fills region with blank lines",
         %{
           buffer: buffer,
           default_style: default_style,
           buffer_width: buffer_width
         } do
      # Region height 2
      scroll_region = {1, 2}

      scrolled_buffer =
        Scrolling.scroll_down(buffer, 3, scroll_region, default_style)

      # Unaffected
      assert get_line_as_string(scrolled_buffer, 0) == "0000000000"
      # Blank
      assert get_line_as_string(scrolled_buffer, 1) ==
               String.duplicate(" ", buffer_width)

      # Blank
      assert get_line_as_string(scrolled_buffer, 2) ==
               String.duplicate(" ", buffer_width)

      # Unaffected
      assert get_line_as_string(scrolled_buffer, 3) == "3333333333"
      # Unaffected
      assert get_line_as_string(scrolled_buffer, 4) == "4444444444"
    end

    test "scroll down with invalid region (top > bottom) does nothing", %{
      buffer: buffer,
      default_style: default_style
    } do
      scrolled_buffer = Scrolling.scroll_down(buffer, 1, {3, 1}, default_style)
      assert scrolled_buffer == buffer
    end

    test "scroll down ensures correct style for new lines", %{
      buffer: buffer,
      buffer_width: buffer_width
    } do
      # Blue foreground
      custom_style =
        TextFormatting.new() |> Map.merge(%{foreground: {:rgb, 0, 0, 255}})

      scrolled_buffer = Scrolling.scroll_down(buffer, 1, nil, custom_style)

      # Check the style of the new blank line (first line)
      first_line_cells = ScreenBuffer.get_line(scrolled_buffer, 0)

      Enum.each(first_line_cells, fn cell ->
        assert cell.char == " "
        assert cell.style == custom_style
      end)
    end
  end
end

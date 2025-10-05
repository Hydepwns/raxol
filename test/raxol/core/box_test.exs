defmodule Raxol.Core.BoxTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.{Buffer, Box}

  describe "draw_box/6" do
    test "draws a single-line box" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Box.draw_box(buffer, 5, 3, 20, 10, :single)

      # Check corners
      assert Buffer.get_cell(buffer, 5, 3).char == "┌"
      assert Buffer.get_cell(buffer, 24, 3).char == "┐"
      assert Buffer.get_cell(buffer, 5, 12).char == "└"
      assert Buffer.get_cell(buffer, 24, 12).char == "┘"

      # Check edges
      assert Buffer.get_cell(buffer, 6, 3).char == "─"
      assert Buffer.get_cell(buffer, 5, 4).char == "│"
    end

    test "draws a double-line box" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Box.draw_box(buffer, 5, 3, 20, 10, :double)

      # Check corners
      assert Buffer.get_cell(buffer, 5, 3).char == "╔"
      assert Buffer.get_cell(buffer, 24, 3).char == "╗"
      assert Buffer.get_cell(buffer, 5, 12).char == "╚"
      assert Buffer.get_cell(buffer, 24, 12).char == "╝"

      # Check edges
      assert Buffer.get_cell(buffer, 6, 3).char == "═"
      assert Buffer.get_cell(buffer, 5, 4).char == "║"
    end

    test "draws a rounded box" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Box.draw_box(buffer, 5, 3, 20, 10, :rounded)

      # Check corners
      assert Buffer.get_cell(buffer, 5, 3).char == "╭"
      assert Buffer.get_cell(buffer, 24, 3).char == "╮"
      assert Buffer.get_cell(buffer, 5, 12).char == "╰"
      assert Buffer.get_cell(buffer, 24, 12).char == "╯"

      # Check edges use standard lines
      assert Buffer.get_cell(buffer, 6, 3).char == "─"
      assert Buffer.get_cell(buffer, 5, 4).char == "│"
    end

    test "draws a heavy box" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Box.draw_box(buffer, 5, 3, 20, 10, :heavy)

      # Check corners
      assert Buffer.get_cell(buffer, 5, 3).char == "┏"
      assert Buffer.get_cell(buffer, 24, 3).char == "┓"
      assert Buffer.get_cell(buffer, 5, 12).char == "┗"
      assert Buffer.get_cell(buffer, 24, 12).char == "┛"

      # Check edges
      assert Buffer.get_cell(buffer, 6, 3).char == "━"
      assert Buffer.get_cell(buffer, 5, 4).char == "┃"
    end

    test "draws a dashed box" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Box.draw_box(buffer, 5, 3, 20, 10, :dashed)

      # Check corners
      assert Buffer.get_cell(buffer, 5, 3).char == "┌"
      assert Buffer.get_cell(buffer, 24, 3).char == "┐"

      # Check edges use dashed characters
      assert Buffer.get_cell(buffer, 6, 3).char == "╌"
      assert Buffer.get_cell(buffer, 5, 4).char == "╎"
    end

    test "defaults to single-line style" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Box.draw_box(buffer, 5, 3, 20, 10)

      assert Buffer.get_cell(buffer, 5, 3).char == "┌"
    end

    test "handles boxes at buffer edges" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Box.draw_box(buffer, 0, 0, 80, 24, :single)

      # Should not crash and should draw what fits
      assert buffer.width == 80
      assert buffer.height == 24
      assert Buffer.get_cell(buffer, 0, 0).char == "┌"
      assert Buffer.get_cell(buffer, 79, 0).char == "┐"
    end

    test "handles small boxes" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Box.draw_box(buffer, 10, 10, 3, 3, :single)

      # 3x3 box should have all corners
      assert Buffer.get_cell(buffer, 10, 10).char == "┌"
      assert Buffer.get_cell(buffer, 12, 10).char == "┐"
      assert Buffer.get_cell(buffer, 10, 12).char == "└"
      assert Buffer.get_cell(buffer, 12, 12).char == "┘"
    end
  end

  describe "draw_horizontal_line/5" do
    test "draws a horizontal line" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Box.draw_horizontal_line(buffer, 10, 5, 20)

      # Check first and last characters
      assert Buffer.get_cell(buffer, 10, 5).char == "-"
      assert Buffer.get_cell(buffer, 29, 5).char == "-"

      # Check middle character
      assert Buffer.get_cell(buffer, 15, 5).char == "-"
    end

    test "uses custom character" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Box.draw_horizontal_line(buffer, 10, 5, 20, "=")

      assert Buffer.get_cell(buffer, 10, 5).char == "="
      assert Buffer.get_cell(buffer, 20, 5).char == "="
    end

    test "defaults to dash character" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Box.draw_horizontal_line(buffer, 0, 0, 10)

      assert Buffer.get_cell(buffer, 0, 0).char == "-"
    end

    test "handles single character line" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Box.draw_horizontal_line(buffer, 5, 5, 1)

      assert Buffer.get_cell(buffer, 5, 5).char == "-"
    end
  end

  describe "draw_vertical_line/5" do
    test "draws a vertical line" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Box.draw_vertical_line(buffer, 10, 5, 10)

      # Check first and last characters
      assert Buffer.get_cell(buffer, 10, 5).char == "|"
      assert Buffer.get_cell(buffer, 10, 14).char == "|"

      # Check middle character
      assert Buffer.get_cell(buffer, 10, 10).char == "|"
    end

    test "uses custom character" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Box.draw_vertical_line(buffer, 10, 5, 10, "║")

      assert Buffer.get_cell(buffer, 10, 5).char == "║"
      assert Buffer.get_cell(buffer, 10, 10).char == "║"
    end

    test "defaults to pipe character" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Box.draw_vertical_line(buffer, 0, 0, 5)

      assert Buffer.get_cell(buffer, 0, 0).char == "|"
    end

    test "handles single character line" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Box.draw_vertical_line(buffer, 5, 5, 1)

      assert Buffer.get_cell(buffer, 5, 5).char == "|"
    end
  end

  describe "fill_area/7" do
    test "fills rectangular area with character" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Box.fill_area(buffer, 10, 5, 20, 10, "█")

      # Check corners of filled area
      assert Buffer.get_cell(buffer, 10, 5).char == "█"
      assert Buffer.get_cell(buffer, 29, 5).char == "█"
      assert Buffer.get_cell(buffer, 10, 14).char == "█"
      assert Buffer.get_cell(buffer, 29, 14).char == "█"

      # Check middle of filled area
      assert Buffer.get_cell(buffer, 15, 10).char == "█"
    end

    test "applies style to filled area" do
      buffer = Buffer.create_blank_buffer(80, 24)
      style = %{bg_color: :blue}
      buffer = Box.fill_area(buffer, 10, 5, 5, 5, " ", style)

      cell = Buffer.get_cell(buffer, 10, 5)
      assert cell.style == style

      # Check another cell in the area
      cell2 = Buffer.get_cell(buffer, 12, 7)
      assert cell2.style == style
    end

    test "defaults to empty style" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Box.fill_area(buffer, 0, 0, 5, 5, "X")

      cell = Buffer.get_cell(buffer, 0, 0)
      assert cell.style == %{}
    end

    test "handles single cell area" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Box.fill_area(buffer, 10, 10, 1, 1, "O")

      assert Buffer.get_cell(buffer, 10, 10).char == "O"
    end

    test "fills entire buffer" do
      buffer = Buffer.create_blank_buffer(10, 5)
      buffer = Box.fill_area(buffer, 0, 0, 10, 5, "#")

      # Check all corners
      assert Buffer.get_cell(buffer, 0, 0).char == "#"
      assert Buffer.get_cell(buffer, 9, 0).char == "#"
      assert Buffer.get_cell(buffer, 0, 4).char == "#"
      assert Buffer.get_cell(buffer, 9, 4).char == "#"
    end
  end

  describe "integration" do
    test "draws box with filled interior" do
      buffer = Buffer.create_blank_buffer(30, 15)
      buffer = Box.draw_box(buffer, 5, 3, 20, 10, :double)
      buffer = Box.fill_area(buffer, 6, 4, 18, 8, ".")

      # Box corners should remain
      assert Buffer.get_cell(buffer, 5, 3).char == "╔"
      assert Buffer.get_cell(buffer, 24, 3).char == "╗"

      # Interior should be filled
      assert Buffer.get_cell(buffer, 10, 7).char == "."
    end

    test "draws multiple boxes" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Box.draw_box(buffer, 5, 3, 20, 10, :single)
      buffer = Box.draw_box(buffer, 30, 8, 15, 8, :double)

      # First box corners
      assert Buffer.get_cell(buffer, 5, 3).char == "┌"

      # Second box corners
      assert Buffer.get_cell(buffer, 30, 8).char == "╔"
    end

    test "combines lines and boxes" do
      buffer = Buffer.create_blank_buffer(40, 20)
      buffer = Box.draw_box(buffer, 5, 5, 30, 10, :single)
      buffer = Box.draw_horizontal_line(buffer, 0, 10, 40, "=")
      buffer = Box.draw_vertical_line(buffer, 20, 0, 20, "║")

      # Verify box still intact at non-intersecting points
      assert Buffer.get_cell(buffer, 5, 5).char == "┌"

      # Verify lines drawn
      assert Buffer.get_cell(buffer, 0, 10).char == "="
      assert Buffer.get_cell(buffer, 20, 0).char == "║"
    end
  end
end

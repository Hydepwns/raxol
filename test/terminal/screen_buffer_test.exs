defmodule Raxol.Terminal.ScreenBufferTest do
  use ExUnit.Case
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell

  describe "initialization" do
    test "creates a new buffer with correct dimensions" do
      buffer = ScreenBuffer.new(10, 5)
      assert length(buffer.cells) == 5
      assert length(List.first(buffer.cells)) == 10
      assert buffer.width == 10
      assert buffer.height == 5
    end

    test "initializes with empty cells" do
      buffer = ScreenBuffer.new(10, 5)

      assert Enum.all?(buffer.cells, fn row ->
               Enum.all?(row, fn cell -> Cell.get_char(cell) == " " end)
             end)
    end
  end

  describe "character writing" do
    test "writes a single character" do
      buffer = ScreenBuffer.new(10, 5)
      buffer = ScreenBuffer.write_char(buffer, 0, 0, "A")
      assert Cell.get_char(Enum.at(buffer.cells, 0) |> Enum.at(0)) == "A"
    end

    test "writes a wide character" do
      buffer = ScreenBuffer.new(10, 5)
      buffer = ScreenBuffer.write_char(buffer, 0, 0, "中")
      assert Cell.get_char(Enum.at(buffer.cells, 0) |> Enum.at(0)) == "中"
      assert Cell.get_char(Enum.at(buffer.cells, 0) |> Enum.at(1)) == " "
    end

    test "writes a string" do
      buffer = ScreenBuffer.new(10, 5)
      buffer = ScreenBuffer.write_string(buffer, 0, 0, "Hello")
      first_row = Enum.at(buffer.cells, 0)

      assert Enum.map(Enum.take(first_row, 5), &Cell.get_char/1) == [
               "H",
               "e",
               "l",
               "l",
               "o"
             ]
    end

    test "writes a string with wide characters" do
      buffer = ScreenBuffer.new(10, 5)
      buffer = ScreenBuffer.write_string(buffer, 0, 0, "Hi 中国")
      first_row = Enum.at(buffer.cells, 0)

      assert Enum.map(Enum.take(first_row, 6), &Cell.get_char/1) == [
               "H",
               "i",
               " ",
               "中",
               "国",
               " "
             ]
    end
  end

  describe "scrolling" do
    test "scrolls up within scroll region" do
      buffer = ScreenBuffer.new(10, 5)
      buffer = ScreenBuffer.set_scroll_region(buffer, 1, 3)

      # Write test data
      buffer = ScreenBuffer.write_string(buffer, 0, 0, "Line 0")
      buffer = ScreenBuffer.write_string(buffer, 0, 1, "Line 1")
      buffer = ScreenBuffer.write_string(buffer, 0, 2, "Line 2")
      buffer = ScreenBuffer.write_string(buffer, 0, 3, "Line 3")
      buffer = ScreenBuffer.write_string(buffer, 0, 4, "Line 4")

      # Scroll up by 1 line
      buffer = ScreenBuffer.scroll_up(buffer, 1)

      # Verify that only the scroll region was affected
      rows =
        Enum.map(buffer.cells, fn row ->
          Enum.map(Enum.take(row, 6), &Cell.get_char/1) |> Enum.join("")
        end)

      assert Enum.at(rows, 0) == "Line 0"
      assert Enum.at(rows, 1) == "Line 2"
      assert Enum.at(rows, 2) == "Line 3"
      assert String.trim(Enum.at(rows, 3)) == ""
      assert Enum.at(rows, 4) == "Line 4"
    end

    test "scrolls down within scroll region" do
      buffer = ScreenBuffer.new(10, 5)
      buffer = ScreenBuffer.set_scroll_region(buffer, 1, 3)

      # Write test data
      buffer = ScreenBuffer.write_string(buffer, 0, 0, "Line 0")
      buffer = ScreenBuffer.write_string(buffer, 0, 1, "Line 1")
      buffer = ScreenBuffer.write_string(buffer, 0, 2, "Line 2")
      buffer = ScreenBuffer.write_string(buffer, 0, 3, "Line 3")
      buffer = ScreenBuffer.write_string(buffer, 0, 4, "Line 4")

      # First scroll up to populate scrollback buffer
      buffer = ScreenBuffer.scroll_up(buffer, 1)
      # Then scroll down
      buffer = ScreenBuffer.scroll_down(buffer, 1)

      # Verify the content
      rows =
        Enum.map(buffer.cells, fn row ->
          Enum.map(Enum.take(row, 6), &Cell.get_char/1) |> Enum.join("")
        end)

      assert Enum.at(rows, 0) == "Line 0"
      assert Enum.at(rows, 1) == "Line 1"
      assert Enum.at(rows, 2) == "Line 2"
      assert Enum.at(rows, 3) == "Line 3"
      assert Enum.at(rows, 4) == "Line 4"
    end
  end

  describe "selection" do
    test "starts and updates selection" do
      buffer = ScreenBuffer.new(10, 5)
      buffer = ScreenBuffer.start_selection(buffer, 1, 1)
      assert buffer.selection == {1, 1, 1, 1}

      buffer = ScreenBuffer.update_selection(buffer, 3, 2)
      assert buffer.selection == {1, 1, 3, 2}
    end

    test "gets selected text" do
      buffer = ScreenBuffer.new(10, 5)
      buffer = ScreenBuffer.write_string(buffer, 0, 0, "Hello")
      buffer = ScreenBuffer.write_string(buffer, 0, 1, "World")
      buffer = ScreenBuffer.start_selection(buffer, 0, 0)
      buffer = ScreenBuffer.update_selection(buffer, 4, 1)

      assert ScreenBuffer.get_selection(buffer) == "Hello\nWorld"
    end

    test "checks if position is in selection" do
      buffer = ScreenBuffer.new(10, 5)
      buffer = ScreenBuffer.start_selection(buffer, 1, 1)
      buffer = ScreenBuffer.update_selection(buffer, 3, 2)

      assert ScreenBuffer.is_in_selection?(buffer, 2, 1)
      assert ScreenBuffer.is_in_selection?(buffer, 1, 2)
      refute ScreenBuffer.is_in_selection?(buffer, 0, 0)
      refute ScreenBuffer.is_in_selection?(buffer, 4, 3)
    end

    test "gets selection boundaries" do
      buffer = ScreenBuffer.new(10, 5)
      buffer = ScreenBuffer.start_selection(buffer, 1, 1)
      buffer = ScreenBuffer.update_selection(buffer, 3, 2)

      assert ScreenBuffer.get_selection_boundaries(buffer) == {1, 1, 3, 2}
    end
  end

  describe "scroll region" do
    test "sets and clears scroll region" do
      buffer = ScreenBuffer.new(10, 5)
      buffer = ScreenBuffer.set_scroll_region(buffer, 1, 3)
      assert buffer.scroll_region == {1, 3}

      buffer = ScreenBuffer.clear_scroll_region(buffer)
      assert buffer.scroll_region == nil
    end

    test "gets scroll region boundaries" do
      buffer = ScreenBuffer.new(10, 5)
      assert ScreenBuffer.get_scroll_region_boundaries(buffer) == {0, 4}

      buffer = ScreenBuffer.set_scroll_region(buffer, 1, 3)
      assert ScreenBuffer.get_scroll_region_boundaries(buffer) == {1, 3}
    end
  end
end

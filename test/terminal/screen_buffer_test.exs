defmodule Raxol.Terminal.ScreenBufferTest do
  use ExUnit.Case
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell

  describe "new/3" do
    test "creates a new screen buffer with default dimensions" do
      buffer = ScreenBuffer.new(80, 24)
      assert buffer.width == 80
      assert buffer.height == 24
      assert length(buffer.buffer) == 24
      assert length(List.first(buffer.buffer)) == 80
      assert buffer.cursor == {0, 0}
      assert buffer.scrollback == []
      assert buffer.scrollback_height == 1000
    end

    test "creates a new screen buffer with custom scrollback height" do
      buffer = ScreenBuffer.new(80, 24, 500)
      assert buffer.scrollback_height == 500
    end
  end

  describe "resize/3" do
    test "resizes the buffer to larger dimensions" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.write_char(buffer, "A")
      buffer = ScreenBuffer.resize(buffer, 100, 30)
      
      assert buffer.width == 100
      assert buffer.height == 30
      assert length(buffer.buffer) == 30
      assert length(List.first(buffer.buffer)) == 100
      assert Cell.get_char(List.first(List.first(buffer.buffer))) == "A"
    end

    test "resizes the buffer to smaller dimensions" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.write_char(buffer, "A")
      buffer = ScreenBuffer.resize(buffer, 40, 12)
      
      assert buffer.width == 40
      assert buffer.height == 12
      assert length(buffer.buffer) == 12
      assert length(List.first(buffer.buffer)) == 40
      assert Cell.get_char(List.first(List.first(buffer.buffer))) == "A"
    end

    test "adjusts cursor position when resizing" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.move_cursor(buffer, 70, 20)
      buffer = ScreenBuffer.resize(buffer, 40, 12)
      
      assert buffer.cursor == {39, 11}
    end
  end

  describe "write_char/2" do
    test "writes a character at the current cursor position" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.write_char(buffer, "A")
      
      assert Cell.get_char(List.first(List.first(buffer.buffer))) == "A"
      assert buffer.cursor == {1, 0}
    end

    test "handles line wrap" do
      buffer = ScreenBuffer.new(5, 3)
      buffer = ScreenBuffer.move_cursor(buffer, 4, 0)
      buffer = ScreenBuffer.write_char(buffer, "A")
      
      assert buffer.cursor == {0, 1}
    end

    test "handles screen wrap" do
      buffer = ScreenBuffer.new(5, 3)
      buffer = ScreenBuffer.move_cursor(buffer, 4, 2)
      buffer = ScreenBuffer.write_char(buffer, "A")
      
      assert buffer.cursor == {0, 2}
      assert length(buffer.scrollback) == 1
    end
  end

  describe "cursor movement" do
    test "moves cursor to specified position" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.move_cursor(buffer, 10, 5)
      
      assert buffer.cursor == {10, 5}
    end

    test "constrains cursor to buffer boundaries" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.move_cursor(buffer, 100, 30)
      
      assert buffer.cursor == {79, 23}
    end

    test "moves cursor right" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.move_cursor_right(buffer, 5)
      
      assert buffer.cursor == {5, 0}
    end

    test "moves cursor left" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.move_cursor(buffer, 10, 0)
      buffer = ScreenBuffer.move_cursor_left(buffer, 5)
      
      assert buffer.cursor == {5, 0}
    end

    test "moves cursor up" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.move_cursor(buffer, 0, 5)
      buffer = ScreenBuffer.move_cursor_up(buffer, 3)
      
      assert buffer.cursor == {0, 2}
    end

    test "moves cursor down" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.move_cursor_down(buffer, 5)
      
      assert buffer.cursor == {0, 5}
    end
  end

  describe "cursor save/restore" do
    test "saves and restores cursor position" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.move_cursor(buffer, 10, 5)
      buffer = ScreenBuffer.save_cursor(buffer)
      buffer = ScreenBuffer.move_cursor(buffer, 0, 0)
      buffer = ScreenBuffer.restore_cursor(buffer)
      
      assert buffer.cursor == {10, 5}
    end

    test "handles restore with no saved position" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.move_cursor(buffer, 10, 5)
      buffer = ScreenBuffer.restore_cursor(buffer)
      
      assert buffer.cursor == {10, 5}
    end
  end

  describe "screen clearing" do
    test "clears screen from cursor to end" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.write_char(buffer, "A")
      buffer = ScreenBuffer.move_cursor(buffer, 0, 0)
      buffer = ScreenBuffer.clear_screen(buffer, :from_cursor)
      
      assert Cell.is_empty?(List.first(List.first(buffer.buffer)))
    end

    test "clears screen from beginning to cursor" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.write_char(buffer, "A")
      buffer = ScreenBuffer.move_cursor(buffer, 0, 0)
      buffer = ScreenBuffer.clear_screen(buffer, :to_cursor)
      
      assert Cell.is_empty?(List.first(List.first(buffer.buffer)))
    end

    test "clears entire screen" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.write_char(buffer, "A")
      buffer = ScreenBuffer.clear_screen(buffer, :all)
      
      assert Enum.all?(Enum.flat_map(buffer.buffer, &(&1)), &Cell.is_empty?/1)
    end
  end

  describe "line operations" do
    test "erases line from cursor to end" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.write_char(buffer, "A")
      buffer = ScreenBuffer.move_cursor(buffer, 0, 0)
      buffer = ScreenBuffer.erase_line(buffer, :from_cursor)
      
      assert Cell.is_empty?(List.first(List.first(buffer.buffer)))
    end

    test "erases line from beginning to cursor" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.write_char(buffer, "A")
      buffer = ScreenBuffer.move_cursor(buffer, 0, 0)
      buffer = ScreenBuffer.erase_line(buffer, :to_cursor)
      
      assert Cell.is_empty?(List.first(List.first(buffer.buffer)))
    end

    test "erases entire line" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.write_char(buffer, "A")
      buffer = ScreenBuffer.move_cursor(buffer, 0, 0)
      buffer = ScreenBuffer.erase_line(buffer, :all)
      
      assert Enum.all?(List.first(buffer.buffer), &Cell.is_empty?/1)
    end

    test "inserts line at cursor" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.move_cursor(buffer, 0, 5)
      buffer = ScreenBuffer.insert_line(buffer, 1)
      
      assert length(buffer.buffer) == 24
      assert Enum.all?(Enum.at(buffer.buffer, 5), &Cell.is_empty?/1)
    end

    test "deletes line at cursor" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.move_cursor(buffer, 0, 5)
      buffer = ScreenBuffer.delete_line(buffer, 1)
      
      assert length(buffer.buffer) == 24
      assert Enum.all?(Enum.at(buffer.buffer, 23), &Cell.is_empty?/1)
    end
  end

  describe "scrolling" do
    test "scrolls up" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.write_char(buffer, "A")
      buffer = ScreenBuffer.scroll_up(buffer, 1)
      
      assert length(buffer.scrollback) == 1
      assert Cell.get_char(List.first(List.first(buffer.scrollback))) == "A"
    end

    test "scrolls down" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.write_char(buffer, "A")
      buffer = ScreenBuffer.scroll_up(buffer, 1)
      buffer = ScreenBuffer.scroll_down(buffer, 1)
      
      assert length(buffer.scrollback) == 0
      assert Cell.get_char(List.first(List.first(buffer.buffer))) == "A"
    end

    test "respects scrollback height limit" do
      buffer = ScreenBuffer.new(80, 24, 2)
      buffer = ScreenBuffer.write_char(buffer, "A")
      buffer = ScreenBuffer.scroll_up(buffer, 3)
      
      assert length(buffer.scrollback) == 2
    end
  end

  describe "selection" do
    test "sets and clears selection" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.set_selection(buffer, 10, 5, 20, 10)
      
      assert buffer.selection == {10, 5, 20, 10}
      
      buffer = ScreenBuffer.clear_selection(buffer)
      assert buffer.selection == nil
    end

    test "gets selected text" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.write_char(buffer, "A")
      buffer = ScreenBuffer.set_selection(buffer, 0, 0, 0, 0)
      
      assert ScreenBuffer.get_selection(buffer) == "A"
    end
  end

  describe "history" do
    test "saves and restores history" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.write_char(buffer, "A")
      buffer = ScreenBuffer.save_history(buffer)
      buffer = ScreenBuffer.write_char(buffer, "B")
      buffer = ScreenBuffer.restore_history(buffer)
      
      assert Cell.get_char(List.first(List.first(buffer.buffer))) == "A"
    end

    test "respects history limit" do
      buffer = ScreenBuffer.new(80, 24)
      
      for i <- 1..150 do
        buffer = ScreenBuffer.write_char(buffer, Integer.to_string(i))
        buffer = ScreenBuffer.save_history(buffer)
      end
      
      assert length(buffer.history) == 100
    end
  end

  describe "text content" do
    test "gets text content" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.write_char(buffer, "A")
      buffer = ScreenBuffer.move_cursor(buffer, 0, 1)
      buffer = ScreenBuffer.write_char(buffer, "B")
      
      assert ScreenBuffer.get_text(buffer) == "A\nB"
    end
  end
end 
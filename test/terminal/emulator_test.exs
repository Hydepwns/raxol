defmodule Raxol.Terminal.EmulatorTest do
  use ExUnit.Case
  alias Raxol.Terminal.Emulator

  describe "new/2" do
    test "creates a new emulator with correct dimensions" do
      emulator = Emulator.new(80, 24)
      assert emulator.width == 80
      assert emulator.height == 24
      assert emulator.cursor_x == 0
      assert emulator.cursor_y == 0
      assert length(emulator.screen_buffer) == 24
      assert length(hd(emulator.screen_buffer)) == 80
    end
  end

  describe "write/2" do
    test "writes text to the current cursor position" do
      emulator = Emulator.new(80, 24)
      emulator = Emulator.write(emulator, "Hello")
      
      assert emulator.cursor_x == 5
      assert emulator.cursor_y == 0
      
      line = Enum.at(emulator.screen_buffer, 0)
      assert Enum.join(Enum.take(line, 5)) == "Hello"
    end

    test "handles line wrapping" do
      emulator = Emulator.new(5, 3)
      emulator = Emulator.write(emulator, "Hello World")
      
      assert emulator.cursor_x == 1
      assert emulator.cursor_y == 2
      
      assert Enum.join(Enum.at(emulator.screen_buffer, 0)) == "Hello"
      assert Enum.join(Enum.at(emulator.screen_buffer, 1)) == " Worl"
      assert Enum.join(Enum.at(emulator.screen_buffer, 2)) == "d    "
    end
  end

  describe "move_cursor/3" do
    test "moves cursor to specified position" do
      emulator = Emulator.new(80, 24)
      emulator = Emulator.move_cursor(emulator, 10, 5)
      
      assert emulator.cursor_x == 10
      assert emulator.cursor_y == 5
    end

    test "clamps cursor position to screen bounds" do
      emulator = Emulator.new(80, 24)
      emulator = Emulator.move_cursor(emulator, 100, 30)
      
      assert emulator.cursor_x == 79
      assert emulator.cursor_y == 23
    end
  end

  describe "clear_screen/1" do
    test "clears the screen buffer" do
      emulator = Emulator.new(80, 24)
      emulator = Emulator.write(emulator, "Hello")
      emulator = Emulator.clear_screen(emulator)
      
      assert emulator.cursor_x == 0
      assert emulator.cursor_y == 0
      
      line = Enum.at(emulator.screen_buffer, 0)
      assert Enum.all?(line, &(&1 == " "))
    end
  end

  describe "scroll_up/2" do
    test "scrolls the screen up" do
      emulator = Emulator.new(5, 3)
      emulator = Emulator.write(emulator, "Line 1\nLine 2\nLine 3")
      emulator = Emulator.scroll_up(emulator, 1)
      
      assert emulator.scroll_offset == 1
      assert Enum.join(Enum.at(emulator.screen_buffer, 0)) == "Line "
      assert Enum.join(Enum.at(emulator.screen_buffer, 1)) == "2    "
      assert Enum.join(Enum.at(emulator.screen_buffer, 2)) == "     "
    end
  end

  describe "to_string/1" do
    test "converts screen buffer to string" do
      emulator = Emulator.new(5, 3)
      emulator = Emulator.write(emulator, "Hello\nWorld")
      
      assert Emulator.to_string(emulator) == "Hello\nWorld \n     "
    end
  end
end 
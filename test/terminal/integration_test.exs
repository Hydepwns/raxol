defmodule Raxol.Terminal.IntegrationTest do
  use ExUnit.Case
  alias Raxol.Terminal.{Input, ScreenBuffer, ANSI}

  describe "input to screen buffer integration" do
    test "processes keyboard input and updates screen buffer" do
      input = Input.new()
      buffer = ScreenBuffer.new(80, 24)
      
      # Type some text
      input = Input.process_keyboard(input, "Hello")
      buffer = ScreenBuffer.write_char(buffer, Input.get_buffer(input))
      
      # Verify screen buffer content
      assert ScreenBuffer.get_text(buffer) == "Hello"
    end

    test "handles cursor movement with arrow keys" do
      input = Input.new()
      buffer = ScreenBuffer.new(80, 24)
      
      # Type text and move cursor
      input = Input.process_keyboard(input, "Hello")
      buffer = ScreenBuffer.write_char(buffer, Input.get_buffer(input))
      
      input = Input.process_keyboard(input, "\e[D") # Left arrow
      input = Input.process_keyboard(input, "\e[D") # Left arrow
      input = Input.process_keyboard(input, "\e[D") # Left arrow
      
      buffer = ScreenBuffer.move_cursor_left(buffer, 3)
      
      # Verify cursor position
      assert buffer.cursor == {2, 0}
    end

    test "handles line wrapping" do
      input = Input.new()
      buffer = ScreenBuffer.new(5, 3) # Small buffer for testing
      
      # Type text that should wrap
      input = Input.process_keyboard(input, "Hello World")
      buffer = ScreenBuffer.write_char(buffer, Input.get_buffer(input))
      
      # Verify text wrapping
      assert ScreenBuffer.get_text(buffer) == "Hello\nWorld"
    end

    test "handles screen scrolling" do
      input = Input.new()
      buffer = ScreenBuffer.new(5, 3) # Small buffer for testing
      
      # Fill buffer with text
      input = Input.process_keyboard(input, "Line 1\nLine 2\nLine 3\nLine 4")
      buffer = ScreenBuffer.write_char(buffer, Input.get_buffer(input))
      
      # Verify scrolling
      assert length(buffer.scrollback) == 1
      assert ScreenBuffer.get_text(buffer) == "Line 2\nLine 3\nLine 4"
    end
  end

  describe "input to ANSI integration" do
    test "processes ANSI escape sequences" do
      input = Input.new()
      buffer = ScreenBuffer.new(80, 24)
      
      # Send ANSI sequence for red text
      input = Input.process_keyboard(input, "\e[31mHello\e[0m")
      buffer = ScreenBuffer.write_char(buffer, Input.get_buffer(input))
      
      # Verify text color
      cell = List.first(List.first(buffer.buffer))
      assert cell.attributes[:foreground] == :red
    end

    test "handles multiple ANSI attributes" do
      input = Input.new()
      buffer = ScreenBuffer.new(80, 24)
      
      # Send ANSI sequence for bold, underlined, red text
      input = Input.process_keyboard(input, "\e[1;4;31mHello\e[0m")
      buffer = ScreenBuffer.write_char(buffer, Input.get_buffer(input))
      
      # Verify text attributes
      cell = List.first(List.first(buffer.buffer))
      assert cell.attributes[:bold] == true
      assert cell.attributes[:underline] == true
      assert cell.attributes[:foreground] == :red
    end

    test "handles cursor positioning" do
      input = Input.new()
      buffer = ScreenBuffer.new(80, 24)
      
      # Send ANSI sequence to move cursor
      input = Input.process_keyboard(input, "\e[10;5H")
      buffer = ScreenBuffer.move_cursor(buffer, 9, 4) # 0-based indexing
      
      # Verify cursor position
      assert buffer.cursor == {9, 4}
    end

    test "handles screen clearing" do
      input = Input.new()
      buffer = ScreenBuffer.new(80, 24)
      
      # Write some text
      input = Input.process_keyboard(input, "Hello")
      buffer = ScreenBuffer.write_char(buffer, Input.get_buffer(input))
      
      # Clear screen
      input = Input.process_keyboard(input, "\e[2J")
      buffer = ScreenBuffer.clear_screen(buffer, :all)
      
      # Verify screen is clear
      assert ScreenBuffer.get_text(buffer) == ""
    end
  end

  describe "mouse input integration" do
    test "handles mouse clicks" do
      input = Input.new()
      buffer = ScreenBuffer.new(80, 24)
      
      # Enable mouse
      input = Input.set_mouse_enabled(input, true)
      
      # Process mouse click
      input = Input.process_mouse(input, :left, :press, 10, 5)
      buffer = ScreenBuffer.move_cursor(buffer, 10, 5)
      
      # Verify cursor position
      assert buffer.cursor == {10, 5}
    end

    test "handles mouse selection" do
      input = Input.new()
      buffer = ScreenBuffer.new(80, 24)
      
      # Write some text
      input = Input.process_keyboard(input, "Hello World")
      buffer = ScreenBuffer.write_char(buffer, Input.get_buffer(input))
      
      # Enable mouse and set selection
      input = Input.set_mouse_enabled(input, true)
      buffer = ScreenBuffer.set_selection(buffer, 0, 0, 5, 0)
      
      # Verify selection
      assert ScreenBuffer.get_selection(buffer) == "Hello"
    end
  end

  describe "input history integration" do
    test "maintains command history" do
      input = Input.new()
      buffer = ScreenBuffer.new(80, 24)
      
      # Add commands to history
      input = Input.add_to_history(input, "ls")
      input = Input.add_to_history(input, "cd /tmp")
      
      # Retrieve and execute command from history
      command = Input.get_from_history(input, 0)
      input = Input.process_keyboard(input, command)
      buffer = ScreenBuffer.write_char(buffer, Input.get_buffer(input))
      
      # Verify command execution
      assert ScreenBuffer.get_text(buffer) == "cd /tmp"
    end
  end

  describe "mode switching integration" do
    test "handles mode transitions" do
      input = Input.new()
      buffer = ScreenBuffer.new(80, 24)
      
      # Switch to insert mode
      input = Input.process_keyboard(input, "i")
      assert input.mode == :insert
      
      # Type some text
      input = Input.process_keyboard(input, "Hello")
      buffer = ScreenBuffer.write_char(buffer, Input.get_buffer(input))
      
      # Switch to visual mode
      input = Input.process_keyboard(input, "\e")
      input = Input.process_keyboard(input, "v")
      assert input.mode == :visual
      
      # Switch back to normal mode
      input = Input.process_keyboard(input, "\e")
      assert input.mode == :normal
    end
  end

  describe "bracketed paste integration" do
    test "handles bracketed paste mode" do
      input = Input.new()
      buffer = ScreenBuffer.new(80, 24)
      
      # Enable bracketed paste
      input = Input.set_bracketed_paste(input, true)
      
      # Process pasted text
      input = Input.process_keyboard(input, "Hello\nWorld")
      buffer = ScreenBuffer.write_char(buffer, Input.get_buffer(input))
      
      # Verify pasted text
      assert ScreenBuffer.get_text(buffer) == "Hello\nWorld"
    end
  end

  describe "modifier key integration" do
    test "handles modifier keys" do
      input = Input.new()
      buffer = ScreenBuffer.new(80, 24)
      
      # Add modifier
      input = Input.add_modifier(input, :ctrl)
      
      # Process key with modifier
      input = Input.process_keyboard(input, "a")
      buffer = ScreenBuffer.write_char(buffer, Input.get_buffer(input))
      
      # Clear modifier
      input = Input.clear_modifiers(input)
      assert input.modifiers == []
    end
  end
end 
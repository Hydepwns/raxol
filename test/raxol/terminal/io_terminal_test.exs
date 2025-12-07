defmodule Raxol.Terminal.IOTerminalTest do
  use ExUnit.Case, async: false

  alias Raxol.Terminal.IOTerminal

  @moduletag :io_terminal

  describe "init/0" do
    test "initializes terminal successfully" do
      assert {:ok, state} = IOTerminal.init()
      assert is_map(state)
      assert state.initialized == true
      assert is_tuple(state.size)
      {width, height} = state.size
      assert is_integer(width)
      assert is_integer(height)
      assert width > 0
      assert height > 0

      # Cleanup
      IOTerminal.shutdown()
    end
  end

  describe "shutdown/0" do
    test "shuts down terminal gracefully" do
      {:ok, _state} = IOTerminal.init()
      assert :ok = IOTerminal.shutdown()
    end

    test "shutdown is idempotent" do
      {:ok, _state} = IOTerminal.init()
      assert :ok = IOTerminal.shutdown()
      assert :ok = IOTerminal.shutdown()
    end
  end

  describe "get_terminal_size/0" do
    test "returns terminal dimensions" do
      {:ok, _state} = IOTerminal.init()

      assert {:ok, {width, height}} = IOTerminal.get_terminal_size()
      assert is_integer(width)
      assert is_integer(height)
      assert width > 0
      assert height > 0

      IOTerminal.shutdown()
    end

    test "returns fallback size when terminal detection fails" do
      # Should still return a reasonable default
      assert {:ok, {width, height}} = IOTerminal.get_terminal_size()
      assert width >= 80
      assert height >= 24
    end
  end

  describe "cursor operations" do
    setup do
      {:ok, state} = IOTerminal.init()
      on_exit(fn -> IOTerminal.shutdown() end)
      {:ok, state: state}
    end

    test "set_cursor/2 sets cursor position" do
      assert :ok = IOTerminal.set_cursor(10, 5)
      assert :ok = IOTerminal.set_cursor(0, 0)
      assert :ok = IOTerminal.set_cursor(79, 23)
    end

    test "hide_cursor/0 hides the cursor" do
      assert :ok = IOTerminal.hide_cursor()
    end

    test "show_cursor/0 shows the cursor" do
      assert :ok = IOTerminal.show_cursor()
    end

    test "cursor visibility can be toggled" do
      assert :ok = IOTerminal.hide_cursor()
      assert :ok = IOTerminal.show_cursor()
      assert :ok = IOTerminal.hide_cursor()
    end
  end

  describe "screen operations" do
    setup do
      {:ok, state} = IOTerminal.init()
      on_exit(fn -> IOTerminal.shutdown() end)
      {:ok, state: state}
    end

    test "clear_screen/0 clears the screen" do
      assert :ok = IOTerminal.clear_screen()
    end

    test "present/0 flushes output" do
      assert :ok = IOTerminal.present()
    end
  end

  describe "cell operations" do
    setup do
      {:ok, state} = IOTerminal.init()
      on_exit(fn -> IOTerminal.shutdown() end)
      {:ok, state: state}
    end

    test "set_cell/5 sets a cell with character and colors" do
      assert :ok = IOTerminal.set_cell(0, 0, "A", 15, 0)
      assert :ok = IOTerminal.set_cell(10, 5, "B", 255, 128)
    end

    test "set_cell/5 handles unicode characters" do
      assert :ok = IOTerminal.set_cell(0, 0, "★", 15, 0)
      assert :ok = IOTerminal.set_cell(1, 0, "日", 15, 0)
    end

    test "set_cell/5 handles various color codes" do
      # Test standard 8-bit ANSI colors (0-255)
      assert :ok = IOTerminal.set_cell(0, 0, "A", 0, 0)
      assert :ok = IOTerminal.set_cell(1, 0, "B", 7, 0)
      assert :ok = IOTerminal.set_cell(2, 0, "C", 15, 0)
      assert :ok = IOTerminal.set_cell(3, 0, "D", 255, 255)
    end
  end

  describe "string operations" do
    setup do
      {:ok, state} = IOTerminal.init()
      on_exit(fn -> IOTerminal.shutdown() end)
      {:ok, state: state}
    end

    test "print_string/5 prints a string" do
      assert :ok = IOTerminal.print_string(0, 0, "Hello, World!", 15, 0)
    end

    test "print_string/5 handles empty strings" do
      assert :ok = IOTerminal.print_string(0, 0, "", 15, 0)
    end

    test "print_string/5 handles unicode strings" do
      assert :ok = IOTerminal.print_string(0, 0, "Hello, 世界!", 15, 0)
    end

    test "print_string/5 at different positions" do
      assert :ok = IOTerminal.print_string(0, 0, "Top left", 15, 0)
      assert :ok = IOTerminal.print_string(10, 5, "Middle", 15, 0)
    end
  end

  describe "title operations" do
    setup do
      {:ok, state} = IOTerminal.init()
      on_exit(fn -> IOTerminal.shutdown() end)
      {:ok, state: state}
    end

    test "set_title/1 sets terminal title" do
      assert :ok = IOTerminal.set_title("Test Title")
    end

    test "set_title/1 handles unicode in title" do
      assert :ok = IOTerminal.set_title("Test 世界")
    end

    test "set_title/1 handles empty title" do
      assert :ok = IOTerminal.set_title("")
    end
  end

  describe "integration test" do
    test "complete terminal workflow" do
      # Initialize
      {:ok, state} = IOTerminal.init()
      assert state.initialized

      # Get size
      {:ok, {width, height}} = IOTerminal.get_terminal_size()
      assert width > 0
      assert height > 0

      # Clear screen
      assert :ok = IOTerminal.clear_screen()

      # Hide cursor
      assert :ok = IOTerminal.hide_cursor()

      # Draw some content
      assert :ok = IOTerminal.set_cell(0, 0, "┌", 15, 0)

      assert :ok =
               IOTerminal.print_string(5, 5, "Hello from IOTerminal!", 15, 0)

      assert :ok = IOTerminal.set_cell(width - 1, 0, "┐", 15, 0)

      # Set title
      assert :ok = IOTerminal.set_title("IOTerminal Test")

      # Present
      assert :ok = IOTerminal.present()

      # Show cursor
      assert :ok = IOTerminal.show_cursor()

      # Cleanup
      assert :ok = IOTerminal.shutdown()
    end
  end

  describe "error handling" do
    test "handles repeated initialization" do
      {:ok, _state1} = IOTerminal.init()
      {:ok, _state2} = IOTerminal.init()
      IOTerminal.shutdown()
    end

    test "operations work without explicit init in some cases" do
      # Some operations should be safe even without init
      assert :ok = IOTerminal.set_title("Test")
    end
  end

  describe "cross-platform compatibility" do
    test "ANSI colors work correctly" do
      {:ok, _state} = IOTerminal.init()

      # Test full range of 8-bit colors
      for color <- [0, 1, 7, 8, 15, 127, 255] do
        assert :ok = IOTerminal.set_cell(0, 0, "X", color, color)
      end

      IOTerminal.shutdown()
    end

    test "unicode rendering" do
      {:ok, _state} = IOTerminal.init()

      # Test various unicode characters
      unicode_chars = ["★", "♥", "♦", "♣", "♠", "日", "本", "語"]

      Enum.each(unicode_chars, fn char ->
        assert :ok = IOTerminal.set_cell(0, 0, char, 15, 0)
      end)

      IOTerminal.shutdown()
    end
  end
end

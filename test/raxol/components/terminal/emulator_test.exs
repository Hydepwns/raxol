defmodule Raxol.Components.Terminal.EmulatorTest do
  use ExUnit.Case
  alias Raxol.Components.Terminal.Emulator

  @initial_state Emulator.init()

  test "initializes terminal emulator" do
    state = Emulator.init()
    assert state.dimensions == {80, 24}
    assert length(state.screen.cells) == 24
    assert length(hd(state.screen.cells)) == 80
    assert state.screen.cursor == {0, 0}
  end

  test "processes basic input" do
    state = Emulator.process_input("Hello", @initial_state)
    content = Emulator.get_visible_content(state)
    assert content =~ "Hello"
  end

  test "handles ANSI color codes" do
    state = Emulator.process_input("\e[31mRed\e[0m", @initial_state)
    assert state.screen.attributes == %{color: :red}
  end

  test "handles cursor movement" do
    state = Emulator.process_input("\e[5;10H", @initial_state)
    assert state.screen.cursor == {9, 4}
  end

  test "handles screen resizing" do
    # Initial state
    state = Emulator.process_input("Hello", @initial_state)
    
    # Resize to smaller
    state = Emulator.handle_resize({40, 12), state)
    assert state.dimensions == {40, 12}
    assert length(state.screen.cells) == 12
    assert length(hd(state.screen.cells)) == 40
    
    # Content should be preserved
    content = Emulator.get_visible_content(state)
    assert content =~ "Hello"
  end

  test "handles line wrapping" do
    # Create a line longer than terminal width
    long_line = String.duplicate("a", 85)
    state = Emulator.process_input(long_line, @initial_state)
    
    # Check that content is properly wrapped
    content = Emulator.get_visible_content(state)
    lines = String.split(content, "\n")
    assert length(lines) >= 2
    assert String.length(hd(lines)) == 80
  end

  test "maintains cell attributes" do
    # Set some attributes
    state = Emulator.process_input("\e[1;31mBold Red\e[0m", @initial_state)
    
    # Check cell attributes
    [first_row | _] = state.screen.cells
    [first_cell | _] = first_row
    assert first_cell.style == %{bold: true, color: :red}
  end

  test "handles scroll region" do
    state = Emulator.process_input("\e[5;20r", @initial_state)
    assert state.screen.scroll_region == {4, 19}  # 1-based to 0-based conversion
  end

  test "preserves content during resize" do
    # Fill screen with content
    content = for i <- 1..24, do: "Line #{i}"
    state = Enum.reduce(content, @initial_state, fn line, acc ->
      Emulator.process_input(line <> "\n", acc)
    end)
    
    # Resize and check content preservation
    state = Emulator.handle_resize({40, 12), state)
    new_content = Emulator.get_visible_content(state)
    
    # Should see the last 12 lines
    assert new_content =~ "Line 13"
    refute new_content =~ "Line 1"
  end

  test "handles terminal modes" do
    state = Emulator.process_input("\e[4h", @initial_state)  # Insert mode
    assert state.screen.mode == :insert
    
    state = Emulator.process_input("\e[4l", state)  # Normal mode
    assert state.screen.mode == :normal
  end

  test "handles dirty cells" do
    state = Emulator.process_input("Hello", @initial_state)
    [first_row | _] = state.screen.cells
    assert Enum.any?(first_row, & &1.dirty)
  end
end 
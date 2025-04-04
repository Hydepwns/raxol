defmodule Raxol.Terminal.EmulatorTest do
  use ExUnit.Case
  alias Raxol.Terminal.Emulator

  @initial_state Emulator.new(80, 24)

  test "initializes terminal emulator" do
    state = Emulator.new(80, 24)
    assert state.width == 80
    assert state.height == 24
    assert state.cursor_x == 0
    assert state.cursor_y == 0
    assert length(state.screen_buffer) == 24
    assert length(hd(state.screen_buffer)) == 80
    assert state.cursor_visible == true
    assert state.cursor_saved == nil
    assert state.scroll_region_top == nil
    assert state.scroll_region_bottom == nil
  end

  test "processes basic input" do
    state = Emulator.process_input("Hello", @initial_state)
    content = Emulator.get_visible_content(state)
    assert content =~ "Hello"
  end

  test "handles cursor movement" do
    state = Emulator.move_cursor(@initial_state, 10, 5)
    assert state.cursor_x == 10
    assert state.cursor_y == 5
  end

  test "handles cursor movement bounds" do
    state = Emulator.move_cursor(@initial_state, -1, -1)
    assert state.cursor_x == 0
    assert state.cursor_y == 0
    
    state = Emulator.move_cursor(@initial_state, 100, 100)
    assert state.cursor_x == 79
    assert state.cursor_y == 23
  end

  test "handles line wrapping" do
    state = Emulator.write(@initial_state, String.duplicate("a", 85))
    assert state.cursor_x == 5
    assert state.cursor_y == 1
  end

  test "handles screen clearing" do
    state = Emulator.write(@initial_state, "Hello")
    state = Emulator.clear_screen(state)
    
    assert state.cursor_x == 0
    assert state.cursor_y == 0
    assert Enum.all?(hd(state.screen_buffer), &(&1 == " "))
  end

  test "handles scrolling" do
    state = Emulator.write(@initial_state, "Line 1\nLine 2\nLine 3")
    state = Emulator.scroll(state, 1)
    
    content = Emulator.get_visible_content(state)
    assert content =~ "Line 2"
    assert content =~ "Line 3"
  end

  test "handles line insertion" do
    state = Emulator.write(@initial_state, "Hello")
    state = Emulator.insert_line(state, 2)
    
    assert length(state.screen_buffer) == 24
    assert Enum.at(state.screen_buffer, state.cursor_y) == List.duplicate(" ", 80)
    assert Enum.at(state.screen_buffer, state.cursor_y + 1) == List.duplicate(" ", 80)
  end

  test "handles line deletion" do
    state = Emulator.write(@initial_state, "Hello")
    state = Emulator.delete_line(state, 2)
    
    assert length(state.screen_buffer) == 24
    assert Enum.at(state.screen_buffer, state.cursor_y) == List.duplicate(" ", 80)
  end

  test "handles scroll region" do
    state = Emulator.set_scroll_region(@initial_state, 5, 20)
    assert state.scroll_region_top == 4
    assert state.scroll_region_bottom == 19
  end

  test "handles scroll region bounds" do
    state = Emulator.set_scroll_region(@initial_state, -1, 100)
    assert state.scroll_region_top == 0
    assert state.scroll_region_bottom == 23
  end

  test "handles cursor save and restore" do
    state = %{@initial_state | cursor_x: 10, cursor_y: 5}
    state = Emulator.save_cursor(state)
    assert state.cursor_saved == {10, 5}
    
    state = %{state | cursor_x: 0, cursor_y: 0}
    state = Emulator.restore_cursor(state)
    assert state.cursor_x == 10
    assert state.cursor_y == 5
  end

  test "handles cursor visibility" do
    state = Emulator.hide_cursor(@initial_state)
    assert state.cursor_visible == false
    
    state = Emulator.show_cursor(state)
    assert state.cursor_visible == true
  end

  test "handles line erasing" do
    state = Emulator.write(@initial_state, "Hello")
    state = Emulator.erase_line(state, 0)  # Clear from cursor to end
    
    assert Enum.at(state.screen_buffer, state.cursor_y) == List.duplicate(" ", 80)
  end

  test "handles memory cleanup" do
    state = %{@initial_state | last_cleanup: 0}
    state = Emulator.write(state, String.duplicate("a", 1000))
    
    # Force cleanup
    state = Emulator.check_memory_usage(state)
    assert length(state.scroll_buffer) <= state.virtual_scroll_size
  end

  test "handles screen resizing" do
    state = Emulator.write(@initial_state, "Hello")
    state = %{state | width: 40, height: 12}
    
    assert state.width == 40
    assert state.height == 12
    assert length(state.screen_buffer) == 12
    assert length(hd(state.screen_buffer)) == 40
  end

  test "handles scroll buffer updates" do
    state = Emulator.write(@initial_state, "Hello")
    assert length(state.scroll_buffer) > 0
    assert hd(state.scroll_buffer) =~ "Hello"
  end

  test "handles empty line filtering" do
    state = Emulator.write(@initial_state, "   ")
    assert length(state.scroll_buffer) == 0
  end
end 
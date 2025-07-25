defmodule Raxol.Terminal.CursorTest do
  use ExUnit.Case
  import Raxol.Guards
  doctest Raxol.Terminal.Cursor.Manager
  doctest Raxol.Terminal.Cursor.Movement
  doctest Raxol.Terminal.Cursor.Style

  alias Raxol.Terminal.Cursor.{Manager, Movement, Style}
  alias Raxol.Terminal.Modes
  alias Raxol.Terminal.EscapeSequence

  describe "Cursor Movement" do
    test "move_up moves cursor up" do
      cursor = Manager.new()
      cursor = Manager.move_to(cursor, 5, 5)  # Move to row 5, col 5
      cursor = Movement.move_up(cursor, 2, 80, 24)
      assert cursor.position == {5, 3}  # Should move up 2 rows from row 5 to row 3
    end

    test "move_down moves cursor down" do
      cursor = Manager.new()
      cursor = Movement.move_down(cursor, 2, 80, 24)
      assert cursor.position == {0, 2}
    end

    test "move_left moves cursor left" do
      cursor = Manager.new()
      cursor = Manager.move_to(cursor, 5, 5)  # Move to row 5, col 5
      cursor = Movement.move_left(cursor, 2, 80, 24)
      assert cursor.position == {3, 5}  # Should move left 2 cols from col 5 to col 3
    end

    test "move_right moves cursor right" do
      cursor = Manager.new()
      cursor = Movement.move_right(cursor, 2, 80, 24)
      assert cursor.position == {2, 0}
    end

    test "move_to_line_start moves cursor to beginning of line" do
      cursor = Manager.new()
      cursor = Manager.move_to(cursor, 10, 10)  # Move to row 10, col 10
      cursor = Movement.move_to_line_start(cursor)
      assert cursor.position == {0, 10}  # Should move to col 0, stay at row 10
    end

    test "move_to_line_end moves cursor to end of line" do
      cursor = Manager.new()
      cursor = Movement.move_to_line_end(cursor, 80)
      assert cursor.position == {79, 0}
    end

    test "move_to_column moves cursor to specified column" do
      cursor = Manager.new()
      cursor = Movement.move_to_column(cursor, 10, 80, 24)
      assert cursor.position == {10, 0}
    end

    test "move_to_line moves cursor to specified line" do
      cursor = Manager.new()
      cursor = Movement.move_to_line(cursor, 5)
      assert cursor.position == {0, 5}
    end

    test "move_to_position moves cursor to specified position" do
      cursor = Manager.new()
      cursor = Manager.move_to(cursor, 10, 5)
      assert cursor.position == {5, 10}  # position is {col, row} format
    end

    test "move_home moves cursor to home position" do
      cursor = Manager.new()
      cursor = Manager.move_to(cursor, 10, 5)
      cursor = Movement.move_home(cursor, 80, 24)
      assert cursor.position == {0, 0}
    end

    test "move_to_next_tab moves cursor to next tab stop" do
      cursor = Manager.new()
      cursor = Movement.move_to_next_tab(cursor, 8, 80, 24)
      assert cursor.position == {8, 0}
    end

    test "move_to_prev_tab moves cursor to previous tab stop" do
      cursor = Manager.new()
      cursor = Manager.move_to(cursor, 0, 10)  # Move to row 0, column 10
      cursor = Movement.move_to_prev_tab(cursor, 8, 80, 24)
      assert cursor.position == {8, 0}  # Should move to previous tab stop at column 8
    end
  end

  describe "Cursor Style" do
    test "set_block sets cursor style to block" do
      cursor = Manager.new()
      cursor = Style.set_block(cursor)
      assert cursor.style == :block
    end

    test "set_underline sets cursor style to underline" do
      cursor = Manager.new()
      cursor = Style.set_underline(cursor)
      assert cursor.style == :underline
    end

    test "set_bar sets cursor style to bar" do
      cursor = Manager.new()
      cursor = Style.set_bar(cursor)
      assert cursor.style == :bar
    end

    test "set_custom sets custom cursor shape" do
      cursor = Manager.new()
      cursor = Style.set_custom(cursor, "█", {2, 1})
      assert cursor.style == :custom
      assert cursor.custom_shape == "█"
    end

    test "show makes cursor visible" do
      cursor = Manager.new()
      cursor = Manager.set_state(cursor, :hidden)
      cursor = Style.show(cursor)
      assert cursor.state == :visible
    end

    test "hide hides cursor" do
      cursor = Manager.new()
      cursor = Style.hide(cursor)
      assert cursor.state == :hidden
    end

    test "blink makes cursor blink" do
      cursor = Manager.new()
      cursor = Style.blink(cursor)
      assert cursor.state == :blinking
    end

    test "set_blink_rate sets cursor blink rate" do
      cursor = Manager.new()
      cursor = Style.set_blink_rate(cursor, 1000)
      assert cursor.blink_rate == 1000
    end

    test "update_blink updates cursor blink state" do
      cursor = Manager.new()
      cursor = Style.blink(cursor)
      {_cursor, visible} = Style.update_blink(cursor)
      assert is_boolean(visible)
    end

    test "toggle_visibility toggles cursor visibility" do
      cursor = Manager.new()
      cursor = Style.toggle_visibility(cursor)
      assert cursor.state == :hidden
      cursor = Style.toggle_visibility(cursor)
      assert cursor.state == :visible
    end

    test "toggle_blink toggles cursor blinking" do
      cursor = Manager.new()
      cursor = Style.toggle_blink(cursor)
      assert cursor.state == :blinking
      cursor = Style.toggle_blink(cursor)
      assert cursor.state == :visible
    end
  end

  describe "Terminal Modes" do
    test "new creates a new terminal mode state" do
      modes = Modes.new()
      assert modes.insert == false
      assert modes.replace == true
      assert modes.visual == false
      assert modes.command == false
      assert modes.normal == true
    end

    test "set_mode sets a terminal mode" do
      modes = Modes.new()
      modes = Modes.set_mode(modes, :insert)
      assert modes.insert == true
      assert modes.replace == false
    end

    test "active? checks if a terminal mode is active" do
      modes = Modes.new()
      assert Modes.active?(modes, :normal) == true
      assert Modes.active?(modes, :insert) == false
    end

    test "process_escape processes an escape sequence for terminal mode changes" do
      modes = Modes.new()
      {modes, _} = Modes.process_escape(modes, "?1049h")
      assert Map.get(modes, :alternate_screen) == true
    end

    test "save_state saves the current terminal mode state" do
      modes = Modes.new()
      {modes, saved_modes} = Modes.save_state(modes)
      modes = Modes.set_mode(modes, :insert)
      modes = Modes.restore_state(modes, saved_modes)
      assert Modes.active?(modes, :normal) == true
    end

    test "restore_state restores a previously saved terminal mode state" do
      modes = Modes.new()
      {modes, saved_modes} = Modes.save_state(modes)
      modes = Modes.set_mode(modes, :insert)
      modes = Modes.restore_state(modes, saved_modes)
      assert Modes.active?(modes, :normal) == true
    end

    test "active_modes returns a list of all active terminal modes" do
      modes = Modes.new()
      assert Modes.active_modes(modes) == [:normal, :replace]
    end

    test "to_string returns a string representation of the terminal mode state" do
      modes = Modes.new()
      assert Modes.to_string(modes) == "Terminal Modes: normal, replace"
    end
  end

  describe "Escape Sequence" do
    # Test that the EscapeSequence.parse function correctly identifies cursor movement sequences
    test "parse correctly identifies cursor movement sequences" do
      # CUP - Cursor Position (Row 10, Col 5) -> {9, 4} 0-based
      assert EscapeSequence.parse("\e[10;5H") ==
               {:ok, {:cursor_position, {9, 4}}, ""}

      # CUU - Cursor Up 3 lines
      assert EscapeSequence.parse("\e[3A") == {:ok, {:cursor_move, :up, 3}, ""}
      # CUD - Cursor Down 1 line (default)
      assert EscapeSequence.parse("\e[B") ==
               {:ok, {:cursor_move, :down, 1}, ""}

      # CUF - Cursor Forward (Right) 2 columns
      assert EscapeSequence.parse("\e[2C") ==
               {:ok, {:cursor_move, :right, 2}, ""}

      # CUB - Cursor Backward (Left) 4 columns
      assert EscapeSequence.parse("\e[4D") ==
               {:ok, {:cursor_move, :left, 4}, ""}

      # CNL - Cursor Next Line 2 lines down
      assert EscapeSequence.parse("\e[2E") == {:ok, {:cursor_next_line, 2}, ""}
      # CPL - Cursor Previous Line 1 line up (default)
      assert EscapeSequence.parse("\e[F") == {:ok, {:cursor_prev_line, 1}, ""}
      # CHA - Cursor Horizontal Absolute (Column 8) -> 7 0-based
      assert EscapeSequence.parse("\e[8G") ==
               {:ok, {:cursor_horizontal_absolute, 7}, ""}
    end

    # Test that the EscapeSequence.parse function correctly identifies cursor style sequences
    test "parse correctly identifies cursor style/mode sequences (DEC Private)" do
      # DECTCEM - Show Cursor
      assert EscapeSequence.parse("\e[?25h") ==
               {:ok, {:set_mode, :dec_private, 25, true}, ""}

      # DECTCEM - Hide Cursor
      assert EscapeSequence.parse("\e[?25l") ==
               {:ok, {:set_mode, :dec_private, 25, false}, ""}
    end

    test "parse correctly identifies terminal mode sequences" do
      # DECSET 1049 - Use Alternate Screen Buffer
      assert EscapeSequence.parse("\e[?1049h") ==
               {:ok, {:set_mode, :dec_private, 1049, true}, ""}

      # DECRST 1049 - Use Normal Screen Buffer
      assert EscapeSequence.parse("\e[?1049l") ==
               {:ok, {:set_mode, :dec_private, 1049, false}, ""}
    end
  end

  describe "Cursor Manager Blink Enabled Test" do
    test "set_blink_enabled updates cursor blink state" do
      cursor = Manager.new()
      cursor = Manager.set_state(cursor, :blinking)
      {updated_cursor, visible} = Manager.update_blink(cursor)
      # First update toggles from true to false
      assert visible == false
      # blink should be toggled from true to false
      assert updated_cursor.blink == false
    end
  end
end

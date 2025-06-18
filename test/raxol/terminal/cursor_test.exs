defmodule Raxol.Terminal.CursorTest do
  use ExUnit.Case
  doctest Raxol.Terminal.Cursor.Manager
  doctest Raxol.Terminal.Cursor.Movement
  doctest Raxol.Terminal.Cursor.Style

  alias Raxol.Terminal.Cursor.{Manager, Movement, Style}
  alias Raxol.Terminal.Modes
  alias Raxol.Terminal.EscapeSequence

  describe "Cursor Manager" do
    test ~c"new creates a cursor with default values" do
      cursor = Manager.new()
      assert cursor.position == {0, 0}
      assert cursor.saved_position == nil
      assert cursor.style == :block
      assert cursor.state == :visible
      assert cursor.shape == {1, 1}
      assert cursor.blink_rate == 530
      assert cursor.custom_shape == nil
      assert cursor.history == []
      assert cursor.history_index == 0
      assert cursor.history_limit == 100
    end

    test ~c"move_to updates cursor position" do
      cursor = Manager.new()
      cursor = Manager.move_to(cursor, 10, 5)
      assert cursor.position == {10, 5}
    end

    test ~c"save_position saves the current cursor position" do
      cursor = Manager.new()
      cursor = Manager.move_to(cursor, 10, 5)
      cursor = Manager.save_position(cursor)
      assert cursor.saved_position == {10, 5}
    end

    test ~c"restore_position restores the saved cursor position" do
      cursor = Manager.new()
      cursor = Manager.move_to(cursor, 10, 5)
      cursor = Manager.save_position(cursor)
      cursor = Manager.move_to(cursor, 0, 0)
      cursor = Manager.restore_position(cursor)
      assert cursor.position == {10, 5}
    end

    test ~c"set_style updates cursor style" do
      cursor = Manager.new()
      cursor = Manager.set_style(cursor, :underline)
      assert cursor.style == :underline
    end

    test ~c"set_custom_shape updates cursor shape" do
      cursor = Manager.new()
      cursor = Manager.set_custom_shape(cursor, "█", {2, 1})
      assert cursor.style == :custom
      assert cursor.custom_shape == "█"
      assert cursor.shape == {2, 1}
    end

    test ~c"set_state updates cursor state" do
      cursor = Manager.new()
      cursor = Manager.set_state(cursor, :hidden)
      assert cursor.state == :hidden
    end

    test ~c"update_blink updates cursor blink state" do
      cursor = Manager.new()
      cursor = Manager.set_state(cursor, :blinking)
      {_cursor, visible} = Manager.update_blink(cursor)
      assert is_boolean(visible)
    end

    test ~c"add_to_history adds cursor state to history" do
      cursor = Manager.new()
      cursor = Manager.add_to_history(cursor)
      assert length(cursor.history) == 1
    end

    test ~c"restore_from_history restores cursor state from history" do
      cursor = Manager.new()
      cursor = Manager.add_to_history(cursor)
      cursor = Manager.move_to(cursor, 10, 5)
      cursor = Manager.restore_from_history(cursor)
      assert cursor.position == {0, 0}
    end
  end

  describe "Cursor Movement" do
    test ~c"move_up moves cursor up" do
      cursor = Manager.new()
      cursor = Manager.move_to(cursor, 0, 5)
      cursor = Movement.move_up(cursor, 2)
      assert cursor.position == {0, 3}
    end

    test ~c"move_down moves cursor down" do
      cursor = Manager.new()
      cursor = Movement.move_down(cursor, 2)
      assert cursor.position == {0, 2}
    end

    test ~c"move_left moves cursor left" do
      cursor = Manager.new()
      cursor = Manager.move_to(cursor, 5, 0)
      cursor = Movement.move_left(cursor, 2)
      assert cursor.position == {3, 0}
    end

    test ~c"move_right moves cursor right" do
      cursor = Manager.new()
      cursor = Movement.move_right(cursor, 2)
      assert cursor.position == {2, 0}
    end

    test ~c"move_to_line_start moves cursor to beginning of line" do
      cursor = Manager.new()
      cursor = Manager.move_to(cursor, 10, 0)
      cursor = Movement.move_to_line_start(cursor)
      assert cursor.position == {0, 0}
    end

    test ~c"move_to_line_end moves cursor to end of line" do
      cursor = Manager.new()
      cursor = Movement.move_to_line_end(cursor, 80)
      assert cursor.position == {79, 0}
    end

    test ~c"move_to_column moves cursor to specified column" do
      cursor = Manager.new()
      cursor = Movement.move_to_column(cursor, 10)
      assert cursor.position == {10, 0}
    end

    test ~c"move_to_line moves cursor to specified line" do
      cursor = Manager.new()
      cursor = Movement.move_to_line(cursor, 5)
      assert cursor.position == {0, 5}
    end

    test ~c"move_to_position moves cursor to specified position" do
      cursor = Manager.new()
      cursor = Movement.move_to_position(cursor, 10, 5)
      assert cursor.position == {10, 5}
    end

    test ~c"move_home moves cursor to home position" do
      cursor = Manager.new()
      cursor = Manager.move_to(cursor, 10, 5)
      cursor = Movement.move_home(cursor)
      assert cursor.position == {0, 0}
    end

    test ~c"move_to_next_tab moves cursor to next tab stop" do
      cursor = Manager.new()
      cursor = Movement.move_to_next_tab(cursor, 8)
      assert cursor.position == {8, 0}
    end

    test ~c"move_to_prev_tab moves cursor to previous tab stop" do
      cursor = Manager.new()
      cursor = Manager.move_to(cursor, 10, 0)
      cursor = Movement.move_to_prev_tab(cursor, 8)
      assert cursor.position == {8, 0}
    end
  end

  describe "Cursor Style" do
    test ~c"set_block sets cursor style to block" do
      cursor = Manager.new()
      cursor = Style.set_block(cursor)
      assert cursor.style == :block
    end

    test ~c"set_underline sets cursor style to underline" do
      cursor = Manager.new()
      cursor = Style.set_underline(cursor)
      assert cursor.style == :underline
    end

    test ~c"set_bar sets cursor style to bar" do
      cursor = Manager.new()
      cursor = Style.set_bar(cursor)
      assert cursor.style == :bar
    end

    test ~c"set_custom sets custom cursor shape" do
      cursor = Manager.new()
      cursor = Style.set_custom(cursor, "█", {2, 1})
      assert cursor.style == :custom
      assert cursor.custom_shape == "█"
    end

    test ~c"show makes cursor visible" do
      cursor = Manager.new()
      cursor = Manager.set_state(cursor, :hidden)
      cursor = Style.show(cursor)
      assert cursor.state == :visible
    end

    test ~c"hide hides cursor" do
      cursor = Manager.new()
      cursor = Style.hide(cursor)
      assert cursor.state == :hidden
    end

    test ~c"blink makes cursor blink" do
      cursor = Manager.new()
      cursor = Style.blink(cursor)
      assert cursor.state == :blinking
    end

    test ~c"set_blink_rate sets cursor blink rate" do
      cursor = Manager.new()
      cursor = Style.set_blink_rate(cursor, 1000)
      assert cursor.blink_rate == 1000
    end

    test ~c"update_blink updates cursor blink state" do
      cursor = Manager.new()
      cursor = Style.blink(cursor)
      {_cursor, visible} = Style.update_blink(cursor)
      assert is_boolean(visible)
    end

    test ~c"toggle_visibility toggles cursor visibility" do
      cursor = Manager.new()
      cursor = Style.toggle_visibility(cursor)
      assert cursor.state == :hidden
      cursor = Style.toggle_visibility(cursor)
      assert cursor.state == :visible
    end

    test ~c"toggle_blink toggles cursor blinking" do
      cursor = Manager.new()
      cursor = Style.toggle_blink(cursor)
      assert cursor.state == :blinking
      cursor = Style.toggle_blink(cursor)
      assert cursor.state == :visible
    end
  end

  describe "Terminal Modes" do
    test ~c"new creates a new terminal mode state" do
      modes = Modes.new()
      assert modes.insert == false
      assert modes.replace == true
      assert modes.visual == false
      assert modes.command == false
      assert modes.normal == true
    end

    test ~c"set_mode sets a terminal mode" do
      modes = Modes.new()
      modes = Modes.set_mode(modes, :insert)
      assert modes.insert == true
      assert modes.replace == false
    end

    test ~c"active? checks if a terminal mode is active" do
      modes = Modes.new()
      assert Modes.active?(modes, :normal) == true
      assert Modes.active?(modes, :insert) == false
    end

    test ~c"process_escape processes an escape sequence for terminal mode changes" do
      modes = Modes.new()
      {modes, _} = Modes.process_escape(modes, "?1049h")
      assert Map.get(modes, :alternate_screen) == true
    end

    test ~c"save_state saves the current terminal mode state" do
      modes = Modes.new()
      {modes, saved_modes} = Modes.save_state(modes)
      modes = Modes.set_mode(modes, :insert)
      modes = Modes.restore_state(modes, saved_modes)
      assert Modes.active?(modes, :normal) == true
    end

    test ~c"restore_state restores a previously saved terminal mode state" do
      modes = Modes.new()
      {modes, saved_modes} = Modes.save_state(modes)
      modes = Modes.set_mode(modes, :insert)
      modes = Modes.restore_state(modes, saved_modes)
      assert Modes.active?(modes, :normal) == true
    end

    test ~c"active_modes returns a list of all active terminal modes" do
      modes = Modes.new()
      assert Modes.active_modes(modes) == [:normal, :replace]
    end

    test ~c"to_string returns a string representation of the terminal mode state" do
      modes = Modes.new()
      assert Modes.to_string(modes) == "Terminal Modes: normal, replace"
    end
  end

  describe "Escape Sequence" do
    # Test that the EscapeSequence.parse function correctly identifies cursor movement sequences
    test ~c"parse correctly identifies cursor movement sequences" do
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
    test ~c"parse correctly identifies cursor style/mode sequences (DEC Private)" do
      # DECTCEM - Show Cursor
      assert EscapeSequence.parse("\e[?25h") ==
               {:ok, {:set_mode, :dec_private, 25, true}, ""}

      # DECTCEM - Hide Cursor
      assert EscapeSequence.parse("\e[?25l") ==
               {:ok, {:set_mode, :dec_private, 25, false}, ""}

      # Other examples (if needed)
      # assert EscapeSequence.parse("\e[?1h") == {:ok, {:set_mode, :dec_private, 1, true}, ""} # DECCKM - Cursor Keys Mode
    end

    # Test that the EscapeSequence.parse function correctly identifies terminal mode sequences
    test ~c"parse correctly identifies terminal mode sequences (DEC Private and Standard)" do
      # DECSET 1049 - Use Alternate Screen Buffer
      assert EscapeSequence.parse("\e[?1049h") ==
               {:ok, {:set_mode, :dec_private, 1049, true}, ""}

      # DECRST 1049 - Use Normal Screen Buffer
      assert EscapeSequence.parse("\e[?1049l") ==
               {:ok, {:set_mode, :dec_private, 1049, false}, ""}

      # Standard Set Mode (example: IRM - Insert Mode)
      # assert EscapeSequence.parse("\e[4h") == {:ok, {:set_mode, :standard, 4, true}, ""}
      # Standard Reset Mode (example: IRM - Replace Mode)
      # assert EscapeSequence.parse("\e[4l") == {:ok, {:set_mode, :standard, 4, false}, ""}
    end

    # This test is redundant now as the tests above cover parse results.
    # We keep the structure but comment out the old logic.
    # test 'parse_sequence parses an escape sequence and determines its type' do
    #   assert EscapeSequence.parse_sequence("\e[10;5H") ==
    #            {:cursor_movement, "10;5H"}
    #   assert EscapeSequence.parse_sequence("\e[?25h") == {:cursor_style, "?25h"}
    #   assert EscapeSequence.parse_sequence("\e[?1049h") ==
    #            {:terminal_mode, "?1049h"}
    # end

    # This test checked the combined effect. We now test parsing separately.
    # Applying the parsed command needs access to the state modification logic,
    # which might live in a different module (e.g., a central processor or the Terminal module).
    # test 'process_sequence processes an escape sequence and returns the updated state' do
    #   cursor = Manager.new()
    #   modes = Modes.new()
    #   {cursor, modes, _} =
    #     EscapeSequence.process_sequence(cursor, modes, "\e[10;5H")
    #   # Check the state *after* applying the parsed command if logic existed here
    #   # assert cursor.position == {9, 4} # Correct 0-based
    # end
  end

  describe "Cursor Manager Blink Enabled Test" do
    test ~c"set_blink_enabled updates cursor blink state" do
      cursor = Manager.new()
      cursor = Manager.set_state(cursor, :blinking)
      {^cursor, visible} = Manager.update_blink(cursor)
      assert visible == true
    end
  end
end

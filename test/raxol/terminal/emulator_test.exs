defmodule Raxol.Terminal.EmulatorTest do
  use ExUnit.Case
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ANSI.{CharacterSets, ScreenModes}
  alias Raxol.Terminal.Cursor.{Manager, Movement, Style}
  alias Raxol.Terminal.Modes
  alias Raxol.Terminal.EscapeSequence

  # ... existing tests ...

  describe "character set functionality" do
    test "initializes with default character set state" do
      emulator = Emulator.new(80, 24)
      assert emulator.charset_state == CharacterSets.new()
    end

    test "writes characters with character set translation" do
      emulator = Emulator.new(80, 24)
      emulator = process_escape(emulator, {:charset_switch, :g0, :french})
      emulator = process_escape(emulator, {:charset_gl, :g0})
      emulator = Emulator.write_char(emulator, 0x23)
      assert get_char_at(emulator, 0, 0) == ?£
    end

    test "writes strings with character set translation" do
      emulator = Emulator.new(80, 24)
      emulator = process_escape(emulator, {:charset_switch, :g0, :german})
      emulator = process_escape(emulator, {:charset_gl, :g0})
      emulator = Emulator.write_string(emulator, "München")
      assert get_string_at(emulator, 0, 0, 7) == "München"
    end

    test "handles character set switching" do
      emulator = Emulator.new(80, 24)
      emulator = process_escape(emulator, {:charset_switch, :g0, :french})
      emulator = process_escape(emulator, {:charset_gl, :g0})
      emulator = Emulator.write_char(emulator, 0x23)
      assert get_char_at(emulator, 0, 0) == ?£

      emulator = process_escape(emulator, {:charset_switch, :g1, :german})
      emulator = process_escape(emulator, {:charset_gl, :g1})
      emulator = Emulator.write_char(emulator, 0x7E)
      assert get_char_at(emulator, 1, 0) == ?ß
    end

    test "handles single shift" do
      emulator = Emulator.new(80, 24)
      emulator = process_escape(emulator, {:charset_switch, :g2, :french})
      emulator = process_escape(emulator, {:single_shift, :g2})
      emulator = Emulator.write_char(emulator, 0x23)
      assert get_char_at(emulator, 0, 0) == ?£

      # Single shift should be cleared after one character
      emulator = Emulator.write_char(emulator, 0x23)
      assert get_char_at(emulator, 1, 0) == ?#
    end

    test "handles lock shift" do
      emulator = Emulator.new(80, 24)
      emulator = process_escape(emulator, {:charset_switch, :g1, :french})
      emulator = process_escape(emulator, {:lock_shift, :g1})
      emulator = Emulator.write_char(emulator, 0x23)
      assert get_char_at(emulator, 0, 0) == ?£

      # Lock shift should persist
      emulator = Emulator.write_char(emulator, 0x23)
      assert get_char_at(emulator, 1, 0) == ?£

      # Unlock shift should return to normal
      emulator = process_escape(emulator, {:unlock_shift})
      emulator = Emulator.write_char(emulator, 0x23)
      assert get_char_at(emulator, 2, 0) == ?#
    end
  end

  describe "screen mode functionality" do
    test "initializes with default screen mode state" do
      emulator = Emulator.new(80, 24)
      assert emulator.mode_state == ScreenModes.new()
    end

    test "switches between normal and alternate screen buffer" do
      emulator = Emulator.new(80, 24)

      # Write some content to normal buffer
      emulator = Emulator.write_char(emulator, ?a)
      emulator = Emulator.write_char(emulator, ?b)
      assert get_char_at(emulator, 0, 0) == ?a
      assert get_char_at(emulator, 1, 0) == ?b

      # Switch to alternate buffer
      emulator = process_escape(emulator, {:screen_mode, :alternate})
      assert Emulator.get_screen_mode(emulator) == :alternate
      assert get_char_at(emulator, 0, 0) == nil
      assert get_char_at(emulator, 1, 0) == nil

      # Write content to alternate buffer
      emulator = Emulator.write_char(emulator, ?x)
      emulator = Emulator.write_char(emulator, ?y)
      assert get_char_at(emulator, 0, 0) == ?x
      assert get_char_at(emulator, 1, 0) == ?y

      # Switch back to normal buffer
      emulator = process_escape(emulator, {:screen_mode, :normal})
      assert Emulator.get_screen_mode(emulator) == :normal
      assert get_char_at(emulator, 0, 0) == ?a
      assert get_char_at(emulator, 1, 0) == ?b
    end

    test "sets and resets screen modes" do
      emulator = Emulator.new(80, 24)

      # Set insert mode
      emulator = process_escape(emulator, {:set_mode, :insert_mode})
      assert Emulator.screen_mode_enabled?(emulator, :insert_mode) == true

      # Set origin mode
      emulator = process_escape(emulator, {:set_mode, :origin_mode})
      assert Emulator.screen_mode_enabled?(emulator, :origin_mode) == true

      # Reset insert mode
      emulator = process_escape(emulator, {:reset_mode, :insert_mode})
      assert Emulator.screen_mode_enabled?(emulator, :insert_mode) == false

      # Reset origin mode
      emulator = process_escape(emulator, {:reset_mode, :origin_mode})
      assert Emulator.screen_mode_enabled?(emulator, :origin_mode) == false
    end

    test "preserves mode settings when switching buffers" do
      emulator = Emulator.new(80, 24)

      # Set some modes in normal buffer
      emulator = process_escape(emulator, {:set_mode, :insert_mode})
      emulator = process_escape(emulator, {:set_mode, :origin_mode})

      # Switch to alternate buffer
      emulator = process_escape(emulator, {:screen_mode, :alternate})

      # Modes should be preserved
      assert Emulator.screen_mode_enabled?(emulator, :insert_mode) == true
      assert Emulator.screen_mode_enabled?(emulator, :origin_mode) == true

      # Set different modes in alternate buffer
      emulator = process_escape(emulator, {:reset_mode, :insert_mode})
      emulator = process_escape(emulator, {:set_mode, :application_cursor})

      # Switch back to normal buffer
      emulator = process_escape(emulator, {:screen_mode, :normal})

      # Original modes should be restored
      assert Emulator.screen_mode_enabled?(emulator, :insert_mode) == true
      assert Emulator.screen_mode_enabled?(emulator, :origin_mode) == true

      assert Emulator.screen_mode_enabled?(emulator, :application_cursor) ==
               false
    end

    test "handles cursor visibility" do
      emulator = Emulator.new(80, 24)
      assert Emulator.screen_mode_enabled?(emulator, :cursor_visible) == true

      emulator = process_escape(emulator, {:reset_mode, :cursor_visible})
      assert Emulator.screen_mode_enabled?(emulator, :cursor_visible) == false

      emulator = process_escape(emulator, {:set_mode, :cursor_visible})
      assert Emulator.screen_mode_enabled?(emulator, :cursor_visible) == true
    end

    test "handles application keypad mode" do
      emulator = Emulator.new(80, 24)

      assert Emulator.screen_mode_enabled?(emulator, :application_keypad) ==
               false

      emulator = process_escape(emulator, {:set_mode, :application_keypad})

      assert Emulator.screen_mode_enabled?(emulator, :application_keypad) ==
               true

      emulator = process_escape(emulator, {:reset_mode, :application_keypad})

      assert Emulator.screen_mode_enabled?(emulator, :application_keypad) ==
               false
    end
  end

  describe "terminal state management" do
    test "new emulator has empty state stack" do
      emulator = Emulator.new()
      assert Emulator.state_stack_empty?(emulator) == true
      assert Emulator.state_stack_count(emulator) == 0
    end

    test "save_state saves current terminal state" do
      emulator = Emulator.new()
      emulator = Emulator.write_char(emulator, "A")
      emulator = Emulator.set_attributes(emulator, %{foreground: :red})
      emulator = Emulator.save_state(emulator)

      assert Emulator.state_stack_empty?(emulator) == false
      assert Emulator.state_stack_count(emulator) == 1

      {emulator, state} = Emulator.restore_state(emulator)
      assert state.cursor == {1, 0}
      assert state.attributes == %{foreground: :red}
    end

    test "restore_state restores most recently saved state" do
      emulator = Emulator.new()

      # Save first state
      emulator = Emulator.write_char(emulator, "A")
      emulator = Emulator.set_attributes(emulator, %{foreground: :red})
      emulator = Emulator.save_state(emulator)

      # Save second state
      emulator = Emulator.write_char(emulator, "B")
      emulator = Emulator.set_attributes(emulator, %{foreground: :blue})
      emulator = Emulator.save_state(emulator)

      # Restore second state
      {emulator, state2} = Emulator.restore_state(emulator)
      assert state2.cursor == {2, 0}
      assert state2.attributes == %{foreground: :blue}

      # Restore first state
      {emulator, state1} = Emulator.restore_state(emulator)
      assert state1.cursor == {1, 0}
      assert state1.attributes == %{foreground: :red}

      # Stack should be empty now
      assert Emulator.state_stack_empty?(emulator) == true
    end

    test "restore_state returns nil when stack is empty" do
      emulator = Emulator.new()
      {emulator, state} = Emulator.restore_state(emulator)
      assert state == nil
    end

    test "clear_state_stack clears the terminal state stack" do
      emulator = Emulator.new()
      emulator = Emulator.write_char(emulator, "A")
      emulator = Emulator.save_state(emulator)
      emulator = Emulator.write_char(emulator, "B")
      emulator = Emulator.save_state(emulator)

      assert Emulator.state_stack_count(emulator) == 2

      emulator = Emulator.clear_state_stack(emulator)
      assert Emulator.state_stack_empty?(emulator) == true
      assert Emulator.state_stack_count(emulator) == 0
    end

    test "get_state_stack returns the current state stack" do
      emulator = Emulator.new()
      emulator = Emulator.write_char(emulator, "A")
      emulator = Emulator.save_state(emulator)

      stack = Emulator.get_state_stack(emulator)
      assert length(stack) == 1

      [state | _] = stack
      assert state.cursor == {1, 0}
    end
  end

  describe "Terminal Emulator" do
    test "new creates a new terminal emulator instance" do
      emulator = Emulator.new(80, 24, %{})
      assert emulator.width == 80
      assert emulator.height == 24
      assert emulator.cursor.position == {0, 0}
      assert emulator.mode_state.insert == false
      assert emulator.mode_state.replace == true
    end

    test "process_input handles regular character input" do
      emulator = Emulator.new(80, 24, %{})
      {emulator, _} = Emulator.process_input(emulator, "a")
      assert emulator.cursor.position == {1, 0}
    end

    test "process_input handles escape sequences" do
      emulator = Emulator.new(80, 24, %{})
      {emulator, _} = Emulator.process_input(emulator, "\e[10;5H")
      # 0-based indexing
      assert emulator.cursor.position == {4, 9}
    end

    test "process_escape_sequence processes cursor movement sequences" do
      emulator = Emulator.new(80, 24, %{})
      {emulator, _} = Emulator.process_escape_sequence(emulator, "\e[10;5H")
      # 0-based indexing
      assert emulator.cursor.position == {4, 9}
    end

    test "process_escape_sequence processes cursor style sequences" do
      emulator = Emulator.new(80, 24, %{})
      {emulator, _} = Emulator.process_escape_sequence(emulator, "\e[?25h")
      assert emulator.cursor.state == :visible
    end

    test "process_escape_sequence processes terminal mode sequences" do
      emulator = Emulator.new(80, 24, %{})
      {emulator, _} = Emulator.process_escape_sequence(emulator, "\e[?1049h")
      assert emulator.mode_state.alternate_screen == true
    end

    test "move_cursor moves cursor to specified position" do
      emulator = Emulator.new(80, 24, %{})
      emulator = Emulator.move_cursor(emulator, 10, 5)
      assert emulator.cursor.position == {10, 5}
    end

    test "move_cursor_up moves cursor up" do
      emulator = Emulator.new(80, 24, %{})
      emulator = Emulator.move_cursor(emulator, 0, 5)
      emulator = Emulator.move_cursor_up(emulator, 2)
      assert emulator.cursor.position == {0, 3}
    end

    test "move_cursor_down moves cursor down" do
      emulator = Emulator.new(80, 24, %{})
      emulator = Emulator.move_cursor_down(emulator, 2)
      assert emulator.cursor.position == {0, 2}
    end

    test "move_cursor_left moves cursor left" do
      emulator = Emulator.new(80, 24, %{})
      emulator = Emulator.move_cursor(emulator, 5, 0)
      emulator = Emulator.move_cursor_left(emulator, 2)
      assert emulator.cursor.position == {3, 0}
    end

    test "move_cursor_right moves cursor right" do
      emulator = Emulator.new(80, 24, %{})
      emulator = Emulator.move_cursor_right(emulator, 2)
      assert emulator.cursor.position == {2, 0}
    end

    test "move_cursor_to_line_start moves cursor to beginning of line" do
      emulator = Emulator.new(80, 24, %{})
      emulator = Emulator.move_cursor(emulator, 10, 0)
      emulator = Emulator.move_cursor_to_line_start(emulator)
      assert emulator.cursor.position == {0, 0}
    end

    test "move_cursor_to_line_end moves cursor to end of line" do
      emulator = Emulator.new(80, 24, %{})
      emulator = Emulator.move_cursor_to_line_end(emulator)
      assert emulator.cursor.position == {79, 0}
    end

    test "save_cursor_position saves the current cursor position" do
      emulator = Emulator.new(80, 24, %{})
      emulator = Emulator.move_cursor(emulator, 10, 5)
      emulator = Emulator.save_cursor_position(emulator)
      assert emulator.cursor.saved_position == {10, 5}
    end

    test "restore_cursor_position restores the saved cursor position" do
      emulator = Emulator.new(80, 24, %{})
      emulator = Emulator.move_cursor(emulator, 10, 5)
      emulator = Emulator.save_cursor_position(emulator)
      emulator = Emulator.move_cursor(emulator, 0, 0)
      emulator = Emulator.restore_cursor_position(emulator)
      assert emulator.cursor.position == {10, 5}
    end

    test "set_cursor_style sets the cursor style" do
      emulator = Emulator.new(80, 24, %{})
      emulator = Emulator.set_cursor_style(emulator, :underline)
      assert emulator.cursor.style == :underline
    end

    test "set_cursor_visibility sets the cursor visibility" do
      emulator = Emulator.new(80, 24, %{})
      emulator = Emulator.set_cursor_visibility(emulator, false)
      assert emulator.cursor.state == :hidden
    end

    test "set_cursor_blink sets the cursor blink state" do
      emulator = Emulator.new(80, 24, %{})
      emulator = Emulator.set_cursor_blink(emulator, true)
      assert emulator.cursor.state == :blinking
    end

    test "set_terminal_mode sets a terminal mode" do
      emulator = Emulator.new(80, 24, %{})
      emulator = Emulator.set_terminal_mode(emulator, :insert)
      assert emulator.mode_state.insert == true
      assert emulator.mode_state.replace == false
    end

    test "save_terminal_state saves the current terminal state" do
      emulator = Emulator.new(80, 24, %{})
      {emulator, saved_state} = Emulator.save_terminal_state(emulator)
      emulator = Emulator.set_terminal_mode(emulator, :insert)
      emulator = Emulator.restore_terminal_state(emulator, saved_state)
      assert emulator.mode_state.insert == false
      assert emulator.mode_state.replace == true
    end

    test "restore_terminal_state restores a previously saved terminal state" do
      emulator = Emulator.new(80, 24, %{})
      {emulator, saved_state} = Emulator.save_terminal_state(emulator)
      emulator = Emulator.set_terminal_mode(emulator, :insert)
      emulator = Emulator.restore_terminal_state(emulator, saved_state)
      assert emulator.mode_state.insert == false
      assert emulator.mode_state.replace == true
    end

    test "get_active_modes returns a list of all active terminal modes" do
      emulator = Emulator.new(80, 24, %{})
      assert Emulator.get_active_modes(emulator) == [:normal, :replace]
    end

    test "get_terminal_state returns a string representation of the terminal state" do
      emulator = Emulator.new(80, 24, %{})
      state = Emulator.get_terminal_state(emulator)
      assert is_binary(state)
      assert String.contains?(state, "Terminal Modes: normal, replace")
    end
  end

  # Helper functions for testing
  defp process_escape(emulator, escape) do
    Emulator.process_escape(emulator, escape)
  end

  defp get_char_at(emulator, x, y) do
    screen = Emulator.get_screen(emulator)
    screen.cells[{x, y}].char
  end

  defp get_string_at(emulator, x, y, length) do
    screen = Emulator.get_screen(emulator)

    0..(length - 1)
    |> Enum.map(fn i -> screen.cells[{x + i, y}].char end)
    |> List.to_string()
  end
end

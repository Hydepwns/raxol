defmodule Raxol.Terminal.EmulatorTest do
  use ExUnit.Case
  # Keep top-level ANSI alias if needed elsewhere
  alias Raxol.Terminal.ANSI
  alias Raxol.Terminal.Cursor.Manager
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer

  # ... existing tests ...

  describe "character set functionality" do
    test "initializes with default character sets" do
      emulator = Emulator.new(80, 24)
      charset_state = Emulator.get_charset_state(emulator)
      assert charset_state.g_sets.g0 == :us_ascii
      assert charset_state.g_sets.g1 == :us_ascii
      assert charset_state.active_set == :us_ascii
    end

    test "writes characters with character set translation (DEC Special Graphics)" do
      emulator = Emulator.new(80, 24)
      # Set G1 to DEC Special Graphics & Character Set (ESC ) 0)
      {emulator, ""} = Emulator.process_input(emulator, "\\e)0")
      # Invoke G1 (SI) - Using SO (Shift Out)
      {emulator, ""} = Emulator.process_input(emulator, "\\x0E")
      # Write 'a' (0x61) which maps to block character in DEC Special Graphics
      # Use Emulator.write
      emulator = Emulator.write(emulator, "a")
      # Use Emulator.get_cell_at
      cell = Emulator.get_cell_at(emulator, 0, 0)
      # Assertion depends on the specific mapping implemented
      # Should be translated
      assert cell.codepoint != ?a
      # Example assertion if 'a' maps to a specific codepoint like U+2592 (▒)
      # assert cell.codepoint == 0x2592
    end

    test "handles character set switching and invoking" do
      emulator = Emulator.new(80, 24)
      # Set G0 to US ASCII (ESC ( B)
      {emulator, ""} = Emulator.process_input(emulator, "\\e(B")
      # Set G1 to DEC Special Graphics (ESC ) 0)
      {emulator, ""} = Emulator.process_input(emulator, "\\e)0")

      charset_state = Emulator.get_charset_state(emulator)
      assert charset_state.g_sets.g0 == :us_ascii
      assert charset_state.g_sets.g1 == :dec_special_graphics

      # Invoke G1 (SO)
      {emulator, ""} = Emulator.process_input(emulator, "\\x0E")
      charset_state_g1 = Emulator.get_charset_state(emulator)
      assert charset_state_g1.active_set == :dec_special_graphics

      # Invoke G0 (SI)
      {emulator, ""} = Emulator.process_input(emulator, "\\x0F")
      charset_state_g0 = Emulator.get_charset_state(emulator)
      assert charset_state_g0.active_set == :us_ascii
    end

    # Single Shift (SS2, SS3) tests might require specific Emulator functions
    # if not handled directly by ANSI.process_escape's basic writing functions.
    # test "handles single shift" do ...

    # Lock Shift (LS1R, LS2, LS2R, LS3, LS3R) tests might also require specific handling.
    # test "handles lock shift" do ...
  end

  describe "screen mode functionality" do
    test "initializes with default screen modes" do
      emulator = Emulator.new(80, 24)

      expected_default_modes = %{
        command: false,
        insert: false,
        normal: true,
        replace: true,
        visual: false
        # Add other default modes if Modes.new() defines them
      }

      # Use getter and assert correct map
      assert Emulator.get_mode_state(emulator) == expected_default_modes
    end

    test "switches between normal and alternate screen buffer" do
      emulator = Emulator.new(80, 24)

      # Write some content to normal buffer
      # Use Emulator.write
      emulator = Emulator.write(emulator, "ab")
      buffer_before = Emulator.get_buffer(emulator)
      cell_a = ScreenBuffer.get_cell_at(buffer_before, 0, 0)
      cell_b = ScreenBuffer.get_cell_at(buffer_before, 1, 0)
      # Access :char field
      assert cell_a.char == "a"
      # Access :char field
      assert cell_b.char == "b"
      # Save for later comparison, use getter
      main_buffer_content = buffer_before

      # Switch to alternate buffer (DECSET ?1049h)
      # Use process_input
      {emulator, ""} = Emulator.process_input(emulator, "\\e[?1049h")
      mode_state_alt = Emulator.get_mode_state(emulator)
      assert mode_state_alt[:alternate_screen] == true
      # Use getter
      assert ScreenBuffer.is_empty?(Emulator.get_buffer(emulator))

      # assert emulator.alternate_buffer != nil # Check that main buffer was saved - This field doesn't exist, logic might be internal

      # Write content to alternate buffer
      # Use Emulator.write
      emulator = Emulator.write(emulator, "xy")
      buffer_alt = Emulator.get_buffer(emulator)
      cell_x = ScreenBuffer.get_cell_at(buffer_alt, 0, 0)
      cell_y = ScreenBuffer.get_cell_at(buffer_alt, 1, 0)
      # Access :char field
      assert cell_x.char == "x"
      # Access :char field
      assert cell_y.char == "y"

      # Switch back to normal buffer (DECRST ?1049l)
      # Use process_input
      {emulator, ""} = Emulator.process_input(emulator, "\\e[?1049l")
      mode_state_normal = Emulator.get_mode_state(emulator)

      assert mode_state_normal[:alternate_screen] == nil or
               mode_state_normal[:alternate_screen] == false

      # Check that main buffer is restored, use getter
      assert Emulator.get_buffer(emulator) == main_buffer_content
    end

    test "sets and resets screen modes (Insert Mode - IRM)" do
      emulator = Emulator.new(80, 24)

      # Set insert mode (SM IRM - CSI 4 h)
      # Use process_input
      {emulator, ""} = Emulator.process_input(emulator, "\\e[4h")
      # Use getter
      assert Emulator.get_mode_state(emulator)[:insert_mode] == true

      # Reset insert mode (RM IRM - CSI 4 l)
      # Use process_input
      {emulator, ""} = Emulator.process_input(emulator, "\\e[4l")
      # Use getter
      assert Emulator.get_mode_state(emulator)[:insert_mode] == nil or
               Emulator.get_mode_state(emulator)[:insert_mode] == false
    end

    test "sets and resets screen modes (Origin Mode - DECOM)" do
      emulator = Emulator.new(80, 24)

      # Set origin mode (DECSET ?6h)
      # Use process_input
      {emulator, ""} = Emulator.process_input(emulator, "\\e[?6h")
      # Use getter
      assert Emulator.get_mode_state(emulator)[:origin_mode] == true

      # Reset origin mode (DECRST ?6l)
      # Use process_input
      {emulator, ""} = Emulator.process_input(emulator, "\\e[?6l")
      # Use getter
      assert Emulator.get_mode_state(emulator)[:origin_mode] == nil or
               Emulator.get_mode_state(emulator)[:origin_mode] == false
    end

    test "handles cursor visibility (DECTCEM)" do
      emulator = Emulator.new(80, 24)
      # Check state directly as getter `get_cursor_visible` returns bool
      assert emulator.cursor.state == :visible

      # Hide cursor (DECRST ?25l)
      # Use process_input
      {emulator, ""} = Emulator.process_input(emulator, "\\e[?25l")
      # Check state directly
      assert emulator.cursor.state == :hidden

      # Show cursor (DECSET ?25h)
      # Use process_input
      {emulator, ""} = Emulator.process_input(emulator, "\\e[?25h")
      # Check state directly
      assert emulator.cursor.state == :visible
    end

    test "handles application keypad mode (DECKPAM/DECKPNM)" do
      emulator = Emulator.new(80, 24)
      mode_state_initial = Emulator.get_mode_state(emulator)
      # Use getter
      assert mode_state_initial[:application_keypad] == nil or
               mode_state_initial[:application_keypad] == false

      # Set application keypad mode (DECKPAM - CSI = ?1h - Note: CSI = is often mapped to ESC =)
      # Using ESC = as per vttest
      # Use process_input
      {emulator, ""} = Emulator.process_input(emulator, "\\e=")
      # Use getter
      assert Emulator.get_mode_state(emulator)[:application_keypad] == true

      # Reset application keypad mode (DECKPNM - CSI = ?1l or ESC >)
      # Using ESC > as per vttest
      # Use process_input
      {emulator, ""} = Emulator.process_input(emulator, "\\e>")
      # Use getter
      assert Emulator.get_mode_state(emulator)[:application_keypad] == nil or
               Emulator.get_mode_state(emulator)[:application_keypad] == false
    end
  end

  describe "Emulator Initialization" do
    test "new creates a new terminal emulator instance with defaults" do
      emulator = Emulator.new(80, 24)
      assert emulator.width == 80
      assert emulator.height == 24
      # Use getter
      assert Emulator.get_cursor_position(emulator) == {0, 0}
      # Use getter
      assert is_struct(Emulator.get_buffer(emulator), ScreenBuffer)
      buffer = Emulator.get_buffer(emulator)
      # Access field on returned struct
      assert buffer.width == 80
      # Access field on returned struct
      assert buffer.height == 24
      # Direct access to cursor struct seems needed
      assert is_struct(emulator.cursor, Manager)
      # Use getter
      assert Emulator.get_scroll_region(emulator) == nil
      # Use getter
      assert Emulator.get_text_style(emulator) == %{}
      mode_state = Emulator.get_mode_state(emulator)
      # Use getter
      assert is_map(mode_state)
      # Check field on returned map (assuming :normal exists)
      assert mode_state[:normal] == true

      # assert is_struct(Emulator.get_charset_state(emulator), CharacterSets) # Use getter
      # Direct access ok
      assert is_list(emulator.state_stack)
      # Direct access ok
      assert Raxol.Terminal.ANSI.TerminalState.count(emulator.state_stack) == 0
    end
  end

  describe "Emulator Writing and Buffer" do
    test "write adds text to screen buffer and moves cursor" do
      emulator = Emulator.new(80, 24)
      emulator = Emulator.write(emulator, "Hello")
      # Check buffer content
      buffer = Emulator.get_buffer(emulator)
      line0_cells = Enum.at(buffer.cells, 0)
      line0_text = Enum.map_join(line0_cells, & &1.char)
      assert String.starts_with?(line0_text, "Hello")
      # Check cursor position (simple case, no wrap)
      # Use getter
      assert Emulator.get_cursor_position(emulator) == {5, 0}
    end

    test "clear_buffer creates a new empty buffer" do
      emulator = Emulator.new(80, 24)
      emulator = Emulator.write(emulator, "abc")
      # Use getter
      refute ScreenBuffer.is_empty?(Emulator.get_buffer(emulator))

      emulator = Emulator.clear_buffer(emulator)
      # Use getter
      assert ScreenBuffer.is_empty?(Emulator.get_buffer(emulator))
      # Should clear_buffer also reset cursor? Check implementation or docs.
      # assert Emulator.get_cursor_position(emulator) == {0, 0}
    end

    test "get_buffer returns the screen buffer struct" do
      emulator = Emulator.new(80, 24)
      buffer = Emulator.get_buffer(emulator)
      assert is_struct(buffer, ScreenBuffer)
      assert buffer.width == 80
    end
  end

  describe "Emulator Cursor Management" do
    test "move_cursor moves cursor and clamps within bounds" do
      emulator = Emulator.new(80, 24)
      emulator = Emulator.move_cursor(emulator, 10, 5)
      # Use getter
      assert Emulator.get_cursor_position(emulator) == {10, 5}

      emulator = Emulator.move_cursor(emulator, 90, 30)
      # Use getter
      assert Emulator.get_cursor_position(emulator) == {79, 23}

      emulator = Emulator.move_cursor(emulator, -5, -2)
      # Use getter
      assert Emulator.get_cursor_position(emulator) == {0, 0}
    end

    test "move_cursor_up/down/left/right delegate to Cursor.Movement" do
      emulator = Emulator.new(80, 24)
      # Test down
      emulator = Emulator.move_cursor_down(emulator, 2)
      # Use getter
      assert Emulator.get_cursor_position(emulator) == {0, 2}
      # Test right
      emulator = Emulator.move_cursor_right(emulator, 5)
      # Use getter
      assert Emulator.get_cursor_position(emulator) == {5, 2}
      # Test up
      emulator = Emulator.move_cursor_up(emulator, 1)
      # Use getter
      assert Emulator.get_cursor_position(emulator) == {5, 1}
      # Test left
      emulator = Emulator.move_cursor_left(emulator, 3)
      # Use getter
      assert Emulator.get_cursor_position(emulator) == {2, 1}
    end

    test "set_cursor_style delegates to Cursor.Manager" do
      emulator = Emulator.new(80, 24)
      # Use getter
      assert Emulator.get_cursor_style(emulator) != :underline
      emulator = Emulator.set_cursor_style(emulator, :underline)
      # Use getter
      assert Emulator.get_cursor_style(emulator) == :underline
    end

    test "set_cursor_visible delegates to Cursor.Style" do
      emulator = Emulator.new(80, 24)
      # Assuming default is visible
      # Check state directly
      assert emulator.cursor.state == :visible
      emulator = Emulator.set_cursor_visible(emulator, false)
      # Check state directly
      assert emulator.cursor.state == :hidden
      emulator = Emulator.set_cursor_visible(emulator, true)
      # Check state directly
      assert emulator.cursor.state == :visible
    end

    # DECSC/DECRC are typically ANSI sequences, Emulator might not have direct functions
    # Test these via ANSI.process_escape if needed, like in ansi_test.exs
    # test "save/restore cursor position (DECSC/DECRC)" do ...
  end

  describe "Emulator State Stack (push/pop)" do
    test "push_state saves current state onto stack" do
      emulator = Emulator.new(80, 24)
      # Modify state using available functions or direct modification for setup
      emulator = Emulator.move_cursor(emulator, 10, 5)
      emulator = Emulator.set_text_style(emulator, %{bold: true})
      # Use full path for TerminalState functions
      assert Raxol.Terminal.ANSI.TerminalState.count(emulator.state_stack) == 0

      emulator = Emulator.push_state(emulator)
      assert Raxol.Terminal.ANSI.TerminalState.count(emulator.state_stack) == 1

      # Optionally, inspect the pushed state if TerminalState provides a peek function
    end

    test "pop_state restores most recently saved state from stack" do
      emulator = Emulator.new(80, 24)

      # State 1: pos=(1,1), bold=true
      emulator1 = Emulator.move_cursor(emulator, 1, 1)
      emulator1 = Emulator.set_text_style(emulator1, %{bold: true})
      # Capture mode state if needed for assertion
      mode_state1 = Emulator.get_mode_state(emulator1)
      emulator_pushed1 = Emulator.push_state(emulator1)

      # State 2: pos=(2,2), underline=true (on top of state 1)
      emulator2 = Emulator.move_cursor(emulator_pushed1, 2, 2)
      # Reset style before setting new one to avoid merging
      emulator2 = Emulator.reset_text_style(emulator2)
      emulator2 = Emulator.set_text_style(emulator2, %{underline: true})
      mode_state2 = Emulator.get_mode_state(emulator2)
      emulator_pushed2 = Emulator.push_state(emulator2)

      assert Raxol.Terminal.ANSI.TerminalState.count(
               emulator_pushed2.state_stack
             ) == 2

      # Pop state 2, should restore to state 2's configuration
      emulator_popped2 = Emulator.pop_state(emulator_pushed2)

      assert Raxol.Terminal.ANSI.TerminalState.count(
               emulator_popped2.state_stack
             ) == 1

      # Check specific fields that should be restored by pop_state using getters
      assert Emulator.get_cursor_position(emulator_popped2) == {2, 2}
      restored_style2 = Emulator.get_text_style(emulator_popped2)
      assert restored_style2 == %{underline: true}
      # Check restored mode state
      assert Emulator.get_mode_state(emulator_popped2) == mode_state2

      # Pop state 1, should restore to state 1's configuration
      emulator_popped1 = Emulator.pop_state(emulator_popped2)

      assert Raxol.Terminal.ANSI.TerminalState.count(
               emulator_popped1.state_stack
             ) == 0

      assert Emulator.get_cursor_position(emulator_popped1) == {1, 1}
      restored_style1 = Emulator.get_text_style(emulator_popped1)
      assert restored_style1 == %{bold: true}
      # Check restored mode state
      assert Emulator.get_mode_state(emulator_popped1) == mode_state1
    end

    test "pop_state does nothing when stack is empty" do
      emulator = Emulator.new(80, 24)
      # Keep a copy for comparison
      initial_emulator = emulator
      emulator_popped = Emulator.pop_state(emulator)
      # Compare relevant fields instead of whole struct
      assert Emulator.get_cursor_position(emulator_popped) ==
               Emulator.get_cursor_position(initial_emulator)

      assert Emulator.get_text_style(emulator_popped) ==
               Emulator.get_text_style(initial_emulator)

      assert Raxol.Terminal.ANSI.TerminalState.count(
               emulator_popped.state_stack
             ) ==
               Raxol.Terminal.ANSI.TerminalState.count(
                 initial_emulator.state_stack
               )

      assert {emulator_popped.width, emulator_popped.height} ==
               {initial_emulator.width, initial_emulator.height}
    end
  end

  describe "Emulator Getters/Setters" do
    test "get/set scroll region" do
      emulator = Emulator.new(80, 24)
      assert Emulator.get_scroll_region(emulator) == nil
      emulator = Emulator.set_scroll_region(emulator, 5, 15)
      assert Emulator.get_scroll_region(emulator) == {5, 15}
      emulator = Emulator.clear_scroll_region(emulator)
      assert Emulator.get_scroll_region(emulator) == nil
    end

    test "get/set text style" do
      emulator = Emulator.new(80, 24)
      assert Emulator.get_text_style(emulator) == %{}

      emulator =
        Emulator.set_text_style(emulator, %{bold: true, foreground: :red})

      style = Emulator.get_text_style(emulator)
      assert style.bold == true
      assert style.foreground == :red
      emulator = Emulator.reset_text_style(emulator)
      assert Emulator.get_text_style(emulator) == %{}
    end

    test "get/set options" do
      emulator = Emulator.new(80, 24)
      assert Emulator.get_options(emulator) == %{}
      emulator = Emulator.set_options(emulator, %{foo: :bar})
      assert Emulator.get_options(emulator) == %{foo: :bar}
    end

    test "get dimensions and resize" do
      emulator = Emulator.new(80, 24)
      assert Emulator.get_dimensions(emulator) == {80, 24}
      emulator = Emulator.resize(emulator, 100, 30)
      assert Emulator.get_dimensions(emulator) == {100, 30}
      # Use getter
      buffer = Emulator.get_buffer(emulator)
      # Access field on returned struct
      assert buffer.width == 100
      # Access field on returned struct
      assert buffer.height == 30
    end

    # Add tests for get_mode_state, get_charset_state etc. if needed
  end

  # Removed outdated helper functions process_escape, get_char_at, get_string_at

  test "handles terminal modes" do
    # Insert mode (Standard Mode 4)
    state = Emulator.process_input("\e[4h", @initial_state)
    assert state.mode_state.insert_mode == true

    # Normal mode (Reset Standard Mode 4)
    state = Emulator.process_input("\e[4l", state)
    assert state.mode_state.insert_mode == false
  end
end

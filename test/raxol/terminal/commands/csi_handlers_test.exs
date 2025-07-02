defmodule Raxol.Terminal.Commands.CSIHandlersTest do
  use ExUnit.Case, async: false

  alias Raxol.Terminal.Commands.CSIHandlers
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.ANSI.CharacterSets.StateManager
  alias Raxol.Terminal.{Window}

  setup do
    emulator = new_emulator()
    emulator = %{emulator | saved_cursor: nil}
    {:ok, emulator: emulator}
  end

  defp unwrap_ok({:ok, value}), do: value
  defp unwrap_ok({:error, _reason, value}), do: value
  defp unwrap_ok(value) when is_map(value), do: value

  defp new_emulator() do
    width = 80
    height = 24
    main_screen_buffer = Raxol.Terminal.ScreenBuffer.new(width, height)
    alternate_screen_buffer = Raxol.Terminal.ScreenBuffer.new(width, height)
    cursor = %Raxol.Terminal.Cursor.Manager{
      row: 0,
      col: 0,
      visible: true,
      style: :block,
      position: {0, 0},
      top_margin: 0,
      bottom_margin: height - 1
    }
    %Raxol.Terminal.Emulator.Struct{
      width: width,
      height: height,
      main_screen_buffer: main_screen_buffer,
      alternate_screen_buffer: alternate_screen_buffer,
      active_buffer_type: :main,
      cursor: cursor,
      charset_state: %{
        g0: :us_ascii,
        g1: :us_ascii,
        g2: :us_ascii,
        g3: :us_ascii,
        gl: :g0,
        gr: :g2,
        single_shift: nil
      },
      style: %{},
      output_buffer: "",
      state: :normal
    }
  end

  describe "handle_s/2 (Save Cursor Position - SCP)" do
    test "saves the current cursor state (position and style)", %{
      emulator: emulator
    } do
      current_cursor_state = %CursorManager{
        row: 0,
        col: 0,
        style: :steady_block,
        visible: true
      }

      emulator_with_cursor = %{emulator | cursor: current_cursor_state}

      result_emulator =
        unwrap_ok(CSIHandlers.handle_s(emulator_with_cursor, []))

      assert result_emulator.saved_cursor == current_cursor_state
      assert result_emulator.cursor == current_cursor_state
    end
  end

  describe "handle_u/2 (Restore Cursor Position - RCP)" do
    test "restores the cursor state from saved_cursor", %{emulator: emulator} do
      saved_cursor_state = %CursorManager{
        row: 7,
        col: 3,
        style: :blink_underline,
        visible: false
      }

      emulator_with_saved = %{emulator | saved_cursor: saved_cursor_state}

      current_cursor_state = %CursorManager{
        row: 0,
        col: 0,
        style: :steady_block,
        visible: true
      }

      emulator_to_restore = %{
        emulator_with_saved
        | cursor: current_cursor_state
      }

      result_emulator = unwrap_ok(CSIHandlers.handle_u(emulator_to_restore, []))

      assert result_emulator.cursor == saved_cursor_state

      assert result_emulator.saved_cursor == saved_cursor_state
    end

    test "does nothing if saved_cursor is nil", %{emulator: emulator} do
      initial_cursor_state = emulator.cursor
      assert emulator.saved_cursor == nil

      result_emulator = unwrap_ok(CSIHandlers.handle_u(emulator, []))

      assert result_emulator == emulator
      assert result_emulator.cursor == initial_cursor_state
    end
  end

  describe "handle_q_deccusr/2 (Set Cursor Style)" do
    test "sets cursor style to blink_block (0 or 1 or default)", %{
      emulator: emulator
    } do
      res_0 = unwrap_ok(CSIHandlers.handle_q_deccusr(emulator, [0]))
      assert res_0.cursor.style == :blink_block

      res_1 = unwrap_ok(CSIHandlers.handle_q_deccusr(emulator, [1]))
      assert res_1.cursor.style == :blink_block

      res_default = unwrap_ok(CSIHandlers.handle_q_deccusr(emulator, []))
      assert res_default.cursor.style == :blink_block
    end

    test "sets cursor style to steady_block (2)", %{emulator: emulator} do
      result = unwrap_ok(CSIHandlers.handle_q_deccusr(emulator, [2]))
      assert result.cursor.style == :steady_block
    end

    test "sets cursor style to blink_underline (3)", %{emulator: emulator} do
      result = unwrap_ok(CSIHandlers.handle_q_deccusr(emulator, [3]))
      assert result.cursor.style == :blink_underline
    end

    test "sets cursor style to steady_underline (4)", %{emulator: emulator} do
      result = unwrap_ok(CSIHandlers.handle_q_deccusr(emulator, [4]))
      assert result.cursor.style == :steady_underline
    end

    test "sets cursor style to blink_bar (5)", %{emulator: emulator} do
      result = unwrap_ok(CSIHandlers.handle_q_deccusr(emulator, [5]))
      assert result.cursor.style == :blink_bar
    end

    test "sets cursor style to steady_bar (6)", %{emulator: emulator} do
      result = unwrap_ok(CSIHandlers.handle_q_deccusr(emulator, [6]))
      assert result.cursor.style == :steady_bar
    end

    test "handles invalid style code, keeps current style", %{
      emulator: emulator
    } do
      initial_style = emulator.cursor.style
      result = unwrap_ok(CSIHandlers.handle_q_deccusr(emulator, [99]))
      assert result.cursor.style == initial_style
    end

    test "handles invalid parameter type, defaults to blink_block", %{
      emulator: emulator
    } do
      result = unwrap_ok(CSIHandlers.handle_q_deccusr(emulator, ["invalid"]))
      assert result.cursor.style == :blink_block
    end
  end

  describe "handle_scs/3 (Designate Character Set - Simplified)" do
    test "sets G0 to ASCII with param '0' (actually '?(0'), final_byte '('", %{
      emulator: emulator
    } do
      result = unwrap_ok(CSIHandlers.handle_scs(emulator, "0", 40))
      assert result.charset_state.g0 == Raxol.Terminal.ANSI.CharacterSets.DEC
    end

    test "sets G1 to ASCII with param '0' (actually '?(0'), final_byte ')'", %{
      emulator: emulator
    } do
      result = unwrap_ok(CSIHandlers.handle_scs(emulator, "0", 40))
      assert result.charset_state.g1 == Raxol.Terminal.ANSI.CharacterSets.DEC
    end

    test "sets G0 with param '1' (actually '?(1'), final_byte '('", %{
      emulator: emulator
    } do
      result = unwrap_ok(CSIHandlers.handle_scs(emulator, "1", 40))
      assert result.charset_state.g0 == Raxol.Terminal.ANSI.CharacterSets.UK
    end

    test "sets G0 with param '16' (actually '?(16'), final_byte '('", %{
      emulator: emulator
    } do
      result = unwrap_ok(CSIHandlers.handle_scs(emulator, "16", 40))
      assert result.charset_state.g0 == Raxol.Terminal.ANSI.CharacterSets.DEC
    end

    test "designates G0 with specific char codes, final_byte '('", %{
      emulator: emulator
    } do
      technical_code_char = ?>

      result_technical =
        unwrap_ok(CSIHandlers.handle_scs(emulator, <<technical_code_char>>, 40))

      assert result_technical.charset_state.g0 ==
               Raxol.Terminal.ANSI.CharacterSets.DEC

      initial_g0_for_portuguese_call = emulator.charset_state.g0
      portuguese_char_code = ?'

      result_portuguese =
        unwrap_ok(
          CSIHandlers.handle_scs(emulator, <<portuguese_char_code>>, 40)
        )

      assert result_portuguese.charset_state.g0 ==
               initial_g0_for_portuguese_call

      result_A = unwrap_ok(CSIHandlers.handle_scs(emulator, "A", 40))
      assert result_A.charset_state.g0 == Raxol.Terminal.ANSI.CharacterSets.UK
    end

    test "handles unknown code/final_byte combination gracefully", %{
      emulator: emulator
    } do
      initial_charset_state = emulator.charset_state
      result = unwrap_ok(CSIHandlers.handle_scs(emulator, "99", 40))
      assert result.charset_state == initial_charset_state
      assert result == emulator

      result2 = unwrap_ok(CSIHandlers.handle_scs(emulator, "B", ?X))
      assert result2.charset_state == initial_charset_state
      assert result2 == emulator
    end

    test "handles empty params (defaults to code 'B'), final_byte '(', sets G0 to ASCII",
         %{emulator: emulator} do
      # Empty param defaults to "B" -> charset_code ?(B -> ASCII module.
      # final_byte ?(( targets :g0.
      result = unwrap_ok(CSIHandlers.handle_scs(emulator, "", 40))
      assert result.charset_state.g0 == Raxol.Terminal.ANSI.CharacterSets.ASCII
    end

    test "sets G0 to a specific character set using single char param, final_byte '('",
         %{emulator: emulator} do
      technical_code_char = ?R

      result_technical =
        unwrap_ok(CSIHandlers.handle_scs(emulator, <<technical_code_char>>, 40))

      assert emulator.charset_state.g0 ==
               Raxol.Terminal.ANSI.CharacterSets.DECTechnical

      assert result_technical == :ok

      result_A = unwrap_ok(CSIHandlers.handle_scs(emulator, "A", 40))

      assert emulator.charset_state.g0 ==
               Raxol.Terminal.ANSI.CharacterSets.USASCII

      assert result_A == :ok

      portuguese_char_code = ?6

      result_portuguese =
        unwrap_ok(
          CSIHandlers.handle_scs(emulator, <<portuguese_char_code>>, 40)
        )

      assert emulator.charset_state.g0 ==
               Raxol.Terminal.ANSI.CharacterSets.Portuguese

      assert result_portuguese == :ok
    end

    test "handles invalid param gracefully", %{emulator: emulator} do
      result = unwrap_ok(CSIHandlers.handle_scs(emulator, "99", 40))

      assert result == :ok

      assert emulator.charset_state.g0 ==
               Raxol.Terminal.ANSI.CharacterSets.ASCII
    end

    test "handles invalid final_byte gracefully", %{emulator: emulator} do
      original_g0 = emulator.charset_state.g0
      result = CSIHandlers.handle_scs(emulator, "99", 40)
      assert result == :ok
      assert emulator.charset_state.g0 == original_g0
    end

    test "sets G0 to US ASCII (default) with empty param, final_byte '('", %{
      emulator: emulator
    } do
      result = unwrap_ok(CSIHandlers.handle_scs(emulator, "", 40))

      assert emulator.charset_state.g0 ==
               Raxol.Terminal.ANSI.CharacterSets.ASCII

      assert result == :ok
    end
  end

  describe "handle_r/2 (Set Scrolling Region - DECSTBM)" do
    setup %{emulator: emulator} do
      {:ok,
       emulator: emulator,
       buffer_height:
         ScreenBuffer.get_height(Emulator.get_active_buffer(emulator))}
    end

    test "sets a valid scrolling region and moves cursor to home", %{
      emulator: emulator
    } do
      result = unwrap_ok(CSIHandlers.handle_r(emulator, [5, 10]))
      assert result.scroll_region == {4, 9}
      assert CursorManager.get_position(result.cursor) == {0, 0}
    end

    test "resets to full screen if no parameters and moves cursor to home", %{
      emulator: emulator
    } do
      emulator_with_region = %{emulator | scroll_region: {5, 10}}
      result = unwrap_ok(CSIHandlers.handle_r(emulator_with_region, []))
      assert result.scroll_region == nil
      assert CursorManager.get_position(result.cursor) == {0, 0}
    end

    test "resets to full screen if top param only and moves cursor to home", %{
      emulator: emulator,
      buffer_height: bh
    } do
      result = unwrap_ok(CSIHandlers.handle_r(emulator, [5]))
      assert result.scroll_region == {4, bh - 1}
      assert CursorManager.get_position(result.cursor) == {0, 0}
    end

    test "resets to full screen if bottom param only (invalid, top defaults to 1)",
         %{emulator: emulator, buffer_height: bh} do
      result = unwrap_ok(CSIHandlers.handle_r(emulator, [nil, 10]))
      assert result.scroll_region == {0, 9}
      assert CursorManager.get_position(result.cursor) == {0, 0}
    end

    test "resets to full screen if top >= bottom and moves cursor to home", %{
      emulator: emulator
    } do
      result = unwrap_ok(CSIHandlers.handle_r(emulator, [10, 5]))
      assert result.scroll_region == nil
      assert CursorManager.get_position(result.cursor) == {0, 0}

      result2 = unwrap_ok(CSIHandlers.handle_r(emulator, [5, 5]))
      assert result2.scroll_region == nil
      assert CursorManager.get_position(result2.cursor) == {0, 0}
    end

    test "handles region spanning full height correctly", %{
      emulator: emulator,
      buffer_height: bh
    } do
      result = unwrap_ok(CSIHandlers.handle_r(emulator, [1, bh]))
      assert result.scroll_region == {0, bh - 1}
      assert CursorManager.get_position(result.cursor) == {0, 0}
    end

    test "clamps parameters to buffer height", %{
      emulator: emulator,
      buffer_height: bh
    } do
      result = unwrap_ok(CSIHandlers.handle_r(emulator, [5, bh + 10]))
      assert result.scroll_region == {4, bh - 1}
      assert CursorManager.get_position(result.cursor) == {0, 0}

      result2 = unwrap_ok(CSIHandlers.handle_r(emulator, [-5, 10]))
      assert result2.scroll_region == {0, 9}
      assert CursorManager.get_position(result2.cursor) == {0, 0}
    end
  end

  describe "error/result tuple propagation" do
    test "handle_u/2 returns error tuple when no saved_cursor, and only emulator is passed to UI",
         %{emulator: emulator} do
      result = CSIHandlers.handle_u(emulator, [])
      assert {:error, :no_saved_cursor, returned_emulator} = result
      assert returned_emulator == emulator
      assert is_map(returned_emulator)
      assert Map.has_key?(returned_emulator, :__struct__)
      assert returned_emulator.__struct__ == Raxol.Terminal.Emulator
    end

    test "handle_scs/3 returns error tuple for invalid charset designation, and only emulator is passed to UI",
         %{emulator: emulator} do
      # Use invalid charset_param_str and final_byte
      result = CSIHandlers.handle_scs(emulator, "", ?Z)
      assert {:error, :invalid_charset_designation, returned_emulator} = result
      # Simulate executor/UI unwrapping
      assert returned_emulator == emulator
      # Only the emulator struct would be passed to the renderer/UI
      assert is_map(returned_emulator)
      assert Map.has_key?(returned_emulator, :__struct__)
      assert returned_emulator.__struct__ == Raxol.Terminal.Emulator
    end
  end

  describe "handle_sequence/2" do
    test "handles cursor movement sequences" do
      emulator = new_emulator()

      # Cursor Up
      state = CSIHandlers.handle_sequence(emulator, [?A])
      assert state.cursor.row == 0
      assert state.cursor.col == 0

      # Cursor Down
      state = CSIHandlers.handle_sequence(state, [?B])
      assert state.cursor.row == 1
      assert state.cursor.col == 0

      # Cursor Forward
      state = CSIHandlers.handle_sequence(state, [?C])
      assert state.cursor.row == 1
      assert state.cursor.col == 1

      # Cursor Backward
      state = CSIHandlers.handle_sequence(state, [?D])
      assert state.cursor.row == 1
      assert state.cursor.col == 0
    end

    test "handles cursor positioning sequences" do
      emulator = new_emulator()

      # Cursor Position
      state = CSIHandlers.handle_sequence(emulator, [?H])
      assert state.cursor.row == 0
      assert state.cursor.col == 0

      # Cursor Position with parameters
      state = CSIHandlers.handle_sequence(state, [?2, ?;, ?3, ?H])
      assert state.cursor.row == 1
      assert state.cursor.col == 2
    end

    test "handles screen clearing sequences" do
      emulator = new_emulator()
      # These will just check that the function returns an emulator struct
      state = CSIHandlers.handle_sequence(emulator, [?J])
      assert is_map(state)
      state = CSIHandlers.handle_sequence(state, [?1, ?J])
      assert is_map(state)
      state = CSIHandlers.handle_sequence(state, [?2, ?J])
      assert is_map(state)
    end

    test "handles line clearing sequences" do
      emulator = new_emulator()
      state = CSIHandlers.handle_sequence(emulator, [?K])
      assert is_map(state)
      state = CSIHandlers.handle_sequence(state, [?1, ?K])
      assert is_map(state)
      state = CSIHandlers.handle_sequence(state, [?2, ?K])
      assert is_map(state)
    end

    test "handles character set sequences" do
      emulator = new_emulator()
      # Designate G0 Character Set
      state = CSIHandlers.handle_sequence(emulator, [?/, ?B])
      assert state.charset_state.g0 == :us_ascii
      # Designate G1 Character Set
      state = CSIHandlers.handle_sequence(state, [?), ?A])
      assert state.charset_state.g1 == :uk
      # Designate G2 Character Set
      state = CSIHandlers.handle_sequence(state, [?*, ?F])
      assert state.charset_state.g2 == :german
      # Designate G3 Character Set
      state = CSIHandlers.handle_sequence(state, [?+, ?D])
      assert state.charset_state.g3 == :french
    end

    test "handles shift sequences" do
      emulator = new_emulator()

      # Locking Shift G0
      result = CSIHandlers.handle_sequence(emulator, [?N])
      # Handle the {:ok, state} return format
      state = case result do
        {:ok, state} -> state
        state -> state
      end
      assert state.charset_state.gl == :g0

      # Locking Shift G1
      result = CSIHandlers.handle_sequence(state, [?O])
      state = case result do
        {:ok, state} -> state
        state -> state
      end
      assert state.charset_state.gl == :g1

      # Single Shift G2
      result = CSIHandlers.handle_sequence(state, [?R])
      state = case result do
        {:ok, state} -> state
        state -> state
      end
      assert state.charset_state.single_shift == state.charset_state.g2

      # Single Shift G3
      result = CSIHandlers.handle_sequence(state, [?S])
      state = case result do
        {:ok, state} -> state
        state -> state
      end
      assert state.charset_state.single_shift == state.charset_state.g3
    end

    test "handles device status sequences" do
      emulator = new_emulator()

      # Device Status Report
      state = CSIHandlers.handle_sequence(emulator, [?6, ?n])
      assert state.device_status_reported == true

      # Cursor Position Report
      state = CSIHandlers.handle_sequence(emulator, [?6, ?R])
      assert state.cursor_position_reported == true
    end

    test "handles save/restore cursor sequences" do
      emulator = new_emulator()

      # Save Cursor Position
      state = CSIHandlers.handle_sequence(emulator, [?s])
      assert state.cursor_saved == true

      # Restore Cursor Position
      state = CSIHandlers.handle_sequence(state, [?u])
      assert state.cursor_restored == true
    end

    test "ignores unknown sequences" do
      emulator = new_emulator()
      original_state = emulator
      state = CSIHandlers.handle_sequence(emulator, [?X])
      assert state == original_state
    end
  end

  describe "handle_cursor_movement/2" do
    test "handles cursor up" do
      emulator = new_emulator()
      state = CSIHandlers.handle_cursor_movement(emulator, [?A])
      assert state.cursor.row == 0
      assert state.cursor.col == 0
    end

    test "handles cursor down" do
      emulator = new_emulator()
      state = CSIHandlers.handle_cursor_movement(emulator, [?B])
      assert state.cursor.row == 1
      assert state.cursor.col == 0
    end

    test "handles cursor forward" do
      emulator = new_emulator()
      state = CSIHandlers.handle_cursor_movement(emulator, [?C])
      assert state.cursor.row == 0
      assert state.cursor.col == 1
    end

    test "handles cursor backward" do
      emulator = new_emulator()
      state = CSIHandlers.handle_cursor_movement(emulator, [?D])
      assert state.cursor.row == 0
      assert state.cursor.col == 0
    end
  end

  describe "handle_cursor_position/2" do
    test "handles cursor position without parameters" do
      emulator = new_emulator()
      state = CSIHandlers.handle_cursor_position(emulator, [])
      assert state.cursor.row == 0
      assert state.cursor.col == 0
    end

    test "handles cursor position with parameters" do
      emulator = new_emulator()
      state = CSIHandlers.handle_cursor_position(emulator, [?2, ?;, ?3])
      assert state.cursor.row == 1
      assert state.cursor.col == 2
    end
  end

  describe "handle_screen_clear/2" do
    test "handles clear from cursor to end of screen" do
      state = StateManager.new()
      state = CSIHandlers.handle_screen_clear(state, [])
      assert state.screen_cleared == true
    end

    test "handles clear from cursor to beginning of screen" do
      emulator = Raxol.Terminal.Emulator.Struct.new(80, 24)
      result = CSIHandlers.handle_screen_clear(emulator, [?1])
      assert result.main_screen_buffer != nil
    end

    test "handles clear entire screen" do
      emulator = Raxol.Terminal.Emulator.Struct.new(80, 24)
      result = CSIHandlers.handle_screen_clear(emulator, [?2])
      assert result.main_screen_buffer != nil
    end
  end

  describe "handle_line_clear/2" do
    test "handles clear from cursor to end of line" do
      emulator = Raxol.Terminal.Emulator.Struct.new(80, 24)
      result = CSIHandlers.handle_line_clear(emulator, [])
      assert result.main_screen_buffer != nil
    end

    test "handles clear from cursor to beginning of line" do
      emulator = Raxol.Terminal.Emulator.Struct.new(80, 24)
      result = CSIHandlers.handle_line_clear(emulator, [?1])
      assert result.main_screen_buffer != nil
    end

    test "handles clear entire line" do
      emulator = Raxol.Terminal.Emulator.Struct.new(80, 24)
      result = CSIHandlers.handle_line_clear(emulator, [?2])
      assert result.main_screen_buffer != nil
    end
  end

  describe "handle_device_status/2" do
    test "handles device status report" do
      emulator = Raxol.Terminal.Emulator.Struct.new(80, 24)
      result = CSIHandlers.handle_device_status(emulator, [?6, ?n])
      assert result != nil
    end

    test "handles cursor position report" do
      emulator = Raxol.Terminal.Emulator.Struct.new(80, 24)
      result = CSIHandlers.handle_device_status(emulator, [?6, ?R])
      assert result != nil
    end
  end

  describe "handle_save_restore_cursor/2" do
    test "handles save cursor position" do
      emulator = Raxol.Terminal.Emulator.Struct.new(80, 24)
      result = CSIHandlers.handle_save_restore_cursor(emulator, [?s])
      assert result.saved_cursor != nil
    end

    test "handles restore cursor position" do
      emulator = Raxol.Terminal.Emulator.Struct.new(80, 24)
      emulator = %{emulator | saved_cursor: %{row: 5, col: 5, style: :block, visible: true}}
      result = CSIHandlers.handle_save_restore_cursor(emulator, [?u])
      assert result.cursor != nil
    end
  end

  describe "cursor movement" do
    test "moves cursor up", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{row: 10, col: 10}}
      result = CSIHandlers.handle_cursor_up(emulator, 5)
      assert result.cursor.row == 5
    end

    test "moves cursor down", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{row: 10, col: 10}}
      result = CSIHandlers.handle_cursor_down(emulator, 5)
      assert result.cursor.row == 15
    end

    test "moves cursor forward", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | row: 10, col: 10, top_margin: 0, bottom_margin: 23}}
      result = CSIHandlers.handle_cursor_forward(emulator, 5)
      assert result.cursor.col == 15
    end

    test "moves cursor backward", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | row: 10, col: 10, top_margin: 0, bottom_margin: 23}}
      result = CSIHandlers.handle_cursor_backward(emulator, 5)
      assert result.cursor.col == 5
    end

    test "moves cursor to column", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | row: 10, col: 10, top_margin: 0, bottom_margin: 23}}
      result = CSIHandlers.handle_cursor_column(emulator, 5)
      assert result.cursor.col == 5
    end

    test "moves cursor to position", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | row: 10, col: 10, top_margin: 0, bottom_margin: 23}}
      result = CSIHandlers.handle_cursor_position(emulator, 5, 15)
      assert result.cursor.col == 5
      assert result.cursor.row == 15
    end

    test "clamps cursor to screen boundaries", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | row: 10, col: 10, top_margin: 0, bottom_margin: 23}}
      result = CSIHandlers.handle_cursor_position(emulator, 100, 100)
      assert result.cursor.row == 23
      assert result.cursor.col == 79
    end

    test "handles negative cursor positions", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | row: 10, col: 10, top_margin: 0, bottom_margin: 23}}
      result = CSIHandlers.handle_cursor_position(emulator, -5, -5)
      assert result.cursor.row == 0
      assert result.cursor.col == 0
    end

    test "handles zero movement", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | row: 10, col: 10, top_margin: 0, bottom_margin: 23}}
      result = CSIHandlers.handle_cursor_up(emulator, 0)
      assert result.cursor.row == 10
    end
  end

  describe "scrolling" do
    test "scrolls up", %{emulator: emulator} do
      result = CSIHandlers.handle_scroll_up(emulator, 5)
      assert result != nil
    end

    test "scrolls down", %{emulator: emulator} do
      emulator = %{emulator | scroll_offset: 10}
      result = CSIHandlers.handle_scroll_down(emulator, 5)
      assert result != nil
    end

    test "clamps scroll offset to valid range", %{emulator: emulator} do
      result = CSIHandlers.handle_scroll_up(emulator, 1000)
      assert result != nil
    end

    test "handles negative scroll amounts", %{emulator: emulator} do
      result = CSIHandlers.handle_scroll_up(emulator, -5)
      assert result != nil
    end
  end

  describe "erasing" do
    test "erases display from cursor to end", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | row: 10, col: 10}}
      result = CSIHandlers.handle_erase_display(emulator, 0)
      assert result != nil
    end

    test "erases display from start to cursor", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | row: 10, col: 10}}
      result = CSIHandlers.handle_erase_display(emulator, 1)
      assert result != nil
    end

    test "erases entire display", %{emulator: emulator} do
      result = CSIHandlers.handle_erase_display(emulator, 2)
      assert result != nil
    end

    test "erases line from cursor to end", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | row: 10, col: 10}}
      result = CSIHandlers.handle_erase_line(emulator, 0)
      assert result != nil
    end

    test "erases line from start to cursor", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | row: 10, col: 10}}
      result = CSIHandlers.handle_erase_line(emulator, 1)
      assert result != nil
    end

    test "erases entire line", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | row: 10, col: 10}}
      result = CSIHandlers.handle_erase_line(emulator, 2)
      assert result != nil
    end

    test "handles invalid erase parameters", %{emulator: emulator} do
      result = CSIHandlers.handle_erase_display(emulator, 3)
      assert result == emulator
    end
  end

  describe "text attributes" do
    test "sets text attributes", %{emulator: emulator} do
      result = CSIHandlers.handle_text_attributes(emulator, [1, 4, 31])
      assert result != nil
    end

    test "resets text attributes", %{emulator: emulator} do
      emulator = %{
        emulator
        | style: %{bold: true, underline: true, foreground: :red}
      }

      result = CSIHandlers.handle_text_attributes(emulator, [0])
      assert result != nil
    end

    test "handles multiple attribute changes", %{emulator: emulator} do
      result = CSIHandlers.handle_text_attributes(emulator, [1, 0, 4, 0, 31, 0])
      assert result != nil
    end

    test "handles invalid attribute codes", %{emulator: emulator} do
      result = CSIHandlers.handle_text_attributes(emulator, [999])
      assert result == emulator
    end
  end

  describe "mode changes" do
    test "sets insert mode", %{emulator: emulator} do
      result = CSIHandlers.handle_mode_change(emulator, 4, true)
      assert result.state == :insert
    end

    test "unsets insert mode", %{emulator: emulator} do
      emulator = %{emulator | state: :insert}
      result = CSIHandlers.handle_mode_change(emulator, 4, false)
      assert result.state == :normal
    end

    test "sets cursor visibility", %{emulator: emulator} do
      result = CSIHandlers.handle_mode_change(emulator, 25, true)
      assert result.cursor.visible == true
    end

    test "unsets cursor visibility", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | visible: true}}
      result = CSIHandlers.handle_mode_change(emulator, 25, false)
      assert result.cursor.visible == false
    end

    test "handles invalid mode codes", %{emulator: emulator} do
      result = CSIHandlers.handle_mode_change(emulator, 999, true)
      assert result == emulator
    end
  end

  describe "device status" do
    test "reports cursor position", %{emulator: emulator} do
      emulator = %{emulator | cursor: %{emulator.cursor | row: 10, col: 10}}
      result = CSIHandlers.handle_device_status(emulator, 6)
      assert result.output_buffer =~ ~r/\x1B\[10;10R/
    end

    test "reports device status", %{emulator: emulator} do
      result = CSIHandlers.handle_device_status(emulator, 5)
      assert result.output_buffer =~ ~r/\x1B\[0n/
    end

    test "handles invalid status codes", %{emulator: emulator} do
      result = CSIHandlers.handle_device_status(emulator, 999)
      assert result == emulator
    end
  end
end

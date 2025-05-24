defmodule Raxol.Terminal.Commands.CSIHandlersTest do
  # async: true if no shared state mutation beyond emulator instance
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Commands.CSIHandlers
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  # For creating initial style
  alias Raxol.Terminal.ANSI.TextFormatting
  # For setup if needed
  alias Raxol.Terminal.ScreenBuffer

  setup do
    # Basic emulator setup for tests
    emulator = Emulator.new(80, 24)
    # Ensure saved_cursor is initially nil as per recent Emulator.ex changes
    emulator = %{emulator | saved_cursor: nil}
    {:ok, emulator: emulator}
  end

  describe "handle_s/2 (Save Cursor Position - SCP)" do
    test "saves the current cursor state (position and style)", %{
      emulator: emulator
    } do
      # Modify current cursor state
      current_cursor_state = %CursorManager{
        # row 5, col 10
        position: {5, 10},
        # Example style
        style: :steady_bar,
        state: :visible
      }

      emulator_with_cursor = %{emulator | cursor: current_cursor_state}

      # Apply SCP
      result_emulator = CSIHandlers.handle_s(emulator_with_cursor, [])

      # Verify that saved_cursor now holds the current_cursor_state
      assert result_emulator.saved_cursor == current_cursor_state
      # Verify current cursor is unchanged by SCP itself
      assert result_emulator.cursor == current_cursor_state
    end
  end

  describe "handle_u/2 (Restore Cursor Position - RCP)" do
    test "restores the cursor state from saved_cursor", %{emulator: emulator} do
      # Define a saved cursor state
      saved_cursor_state = %CursorManager{
        position: {3, 7},
        style: :blink_underline,
        state: :hidden
      }

      emulator_with_saved = %{emulator | saved_cursor: saved_cursor_state}

      # Current cursor is different
      current_cursor_state = %CursorManager{
        position: {0, 0},
        style: :steady_block,
        state: :visible
      }

      emulator_to_restore = %{
        emulator_with_saved
        | cursor: current_cursor_state
      }

      # Apply RCP
      result_emulator = CSIHandlers.handle_u(emulator_to_restore, [])

      # Verify that current cursor is now the saved_cursor_state
      assert result_emulator.cursor == saved_cursor_state

      # Verify saved_cursor itself is not cleared by RCP (as per typical terminal behavior)
      assert result_emulator.saved_cursor == saved_cursor_state
    end

    test "does nothing if saved_cursor is nil", %{emulator: emulator} do
      initial_cursor_state = emulator.cursor
      # Ensure saved_cursor is nil (should be from setup)
      assert emulator.saved_cursor == nil

      # Apply RCP
      result_emulator = CSIHandlers.handle_u(emulator, [])

      # Verify that emulator state (and cursor) is unchanged
      assert result_emulator == emulator
      assert result_emulator.cursor == initial_cursor_state
    end
  end

  describe "handle_q_deccusr/2 (Set Cursor Style)" do
    test "sets cursor style to blink_block (0 or 1 or default)", %{
      emulator: emulator
    } do
      res_0 = CSIHandlers.handle_q_deccusr(emulator, [0])
      assert res_0.cursor.style == :blink_block

      res_1 = CSIHandlers.handle_q_deccusr(emulator, [1])
      assert res_1.cursor.style == :blink_block

      # Default param is 0
      res_default = CSIHandlers.handle_q_deccusr(emulator, [])
      assert res_default.cursor.style == :blink_block
    end

    test "sets cursor style to steady_block (2)", %{emulator: emulator} do
      result = CSIHandlers.handle_q_deccusr(emulator, [2])
      assert result.cursor.style == :steady_block
    end

    test "sets cursor style to blink_underline (3)", %{emulator: emulator} do
      result = CSIHandlers.handle_q_deccusr(emulator, [3])
      assert result.cursor.style == :blink_underline
    end

    test "sets cursor style to steady_underline (4)", %{emulator: emulator} do
      result = CSIHandlers.handle_q_deccusr(emulator, [4])
      assert result.cursor.style == :steady_underline
    end

    test "sets cursor style to blink_bar (5)", %{emulator: emulator} do
      result = CSIHandlers.handle_q_deccusr(emulator, [5])
      assert result.cursor.style == :blink_bar
    end

    test "sets cursor style to steady_bar (6)", %{emulator: emulator} do
      result = CSIHandlers.handle_q_deccusr(emulator, [6])
      assert result.cursor.style == :steady_bar
    end

    test "handles invalid style code, keeps current style", %{
      emulator: emulator
    } do
      # Default from CursorManager.new()
      initial_style = emulator.cursor.style
      # Invalid code
      result = CSIHandlers.handle_q_deccusr(emulator, [99])
      assert result.cursor.style == initial_style
    end

    test "handles invalid parameter type, defaults to blink_block", %{
      emulator: emulator
    } do
      # ParameterValidation.get_valid_non_neg_param converts non-integer to default (0)
      result = CSIHandlers.handle_q_deccusr(emulator, ["invalid"])
      assert result.cursor.style == :blink_block
    end
  end

  describe "handle_scs/3 (Designate Character Set - Simplified)" do
    # Test based on the current simplified implementation in CSIHandlers.ex
    # which uses integer codes and only affects charset_state.active

    test "sets active charset to :us_ascii with {0, '('}", %{emulator: emulator} do
      result = CSIHandlers.handle_scs(emulator, [0], ?()
      assert result.charset_state.active == :us_ascii
    end

    test "sets active charset to :us_ascii with {0, ')'}", %{emulator: emulator} do
      result = CSIHandlers.handle_scs(emulator, [0], ?))
      assert result.charset_state.active == :us_ascii
    end

    test "sets active charset to :dec_supplementary with {1, '('}", %{
      emulator: emulator
    } do
      result = CSIHandlers.handle_scs(emulator, [1], ?()
      assert result.charset_state.active == :dec_supplementary
    end

    test "sets active charset to :dec_special_graphics with {16, '('}", %{
      emulator: emulator
    } do
      result = CSIHandlers.handle_scs(emulator, [16], ?()
      assert result.charset_state.active == :dec_special_graphics
    end

    test "sets active charset to :dec_technical with {codepoint('?'), '('}", %{
      emulator: emulator
    } do
      # 'A' (65) -> code for :uk in full mapping
      result = CSIHandlers.handle_scs(emulator, [?A], ?()
      # The local map_charset_code in CSIHandlers has {?, ?(} -> :dec_technical.
      # ParameterValidation turns [?A] into 65. The map has no match for {65, ?(}.
      # So it should return nil, and charset_state.active should remain unchanged.
      initial_active = emulator.charset_state.active

      # Test for :dec_technical using its actual code in the map (codepoint of '?')
      technical_code = ??
      result_technical = CSIHandlers.handle_scs(emulator, [technical_code], ?()
      assert result_technical.charset_state.active == :dec_technical
    end

    test "sets active charset to :portuguese with {codepoint('\"'), '('}", %{
      emulator: emulator
    } do
      portuguese_code = ?"
      result = CSIHandlers.handle_scs(emulator, [portuguese_code], ?()
      assert result.charset_state.active == :portuguese
    end

    test "handles unknown code/final_byte combination gracefully", %{
      emulator: emulator
    } do
      initial_active = emulator.charset_state.active
      # Unknown code
      result = CSIHandlers.handle_scs(emulator, [99], ?()
      assert result.charset_state.active == initial_active
      # Should return emulator unchanged if charset is nil
      assert result == emulator

      # Unknown final_byte
      result2 = CSIHandlers.handle_scs(emulator, [0], ?X)
      assert result2.charset_state.active == initial_active
      assert result2 == emulator
    end

    test "handles empty params, defaults to code 0", %{emulator: emulator} do
      # Default param for get_valid_non_neg_param is 0
      result = CSIHandlers.handle_scs(emulator, [], ?()
      assert result.charset_state.active == :us_ascii
    end
  end

  describe "handle_r/2 (Set Scrolling Region - DECSTBM)" do
    setup %{emulator: emulator} do
      # Buffer is 80x24. Height is 24.
      # Scroll region is 0-based internally {top_line_idx, bottom_line_idx}
      {:ok,
       emulator: emulator,
       buffer_height:
         ScreenBuffer.get_height(Emulator.get_active_buffer(emulator))}
    end

    test "sets a valid scrolling region and moves cursor to home", %{
      emulator: emulator
    } do
      # Params are 1-based: [top, bottom]. e.g. lines 5 to 10.
      # Internally: {4, 9}
      result = CSIHandlers.handle_r(emulator, [5, 10])
      assert result.scroll_region == {4, 9}
      assert CursorManager.get_position(result) == {0, 0}
    end

    test "resets to full screen if no parameters and moves cursor to home", %{
      emulator: emulator
    } do
      # Set a region first to ensure it's cleared
      emulator_with_region = %{emulator | scroll_region: {5, 10}}
      result = CSIHandlers.handle_r(emulator_with_region, [])
      assert result.scroll_region == nil
      assert CursorManager.get_position(result) == {0, 0}
    end

    test "resets to full screen if top param only and moves cursor to home", %{
      emulator: emulator,
      buffer_height: bh
    } do
      # Params: [top]. Bottom defaults to buffer_height.
      # e.g., [5] -> top=5 (0-based 4), bottom=24 (0-based 23)
      result = CSIHandlers.handle_r(emulator, [5])
      # {4, 23} for 24 line buffer
      assert result.scroll_region == {4, bh - 1}
      assert CursorManager.get_position(result) == {0, 0}
    end

    test "resets to full screen if bottom param only (invalid, top defaults to 1)",
         %{emulator: emulator, buffer_height: bh} do
      # Params: [nil, bottom]. Top defaults to 1.
      # Effectively [1, bottom_param]
      # ParameterValidation.get_valid_param(params, 0, 1, ...) will make top=1
      result = CSIHandlers.handle_r(emulator, [nil, 10])
      # {0, 9} for [1, 10]
      assert result.scroll_region == {0, 9}
      assert CursorManager.get_position(result) == {0, 0}
    end

    test "resets to full screen if top >= bottom and moves cursor to home", %{
      emulator: emulator
    } do
      # Params [10, 5] -> top=10, bottom=5. This is invalid.
      result = CSIHandlers.handle_r(emulator, [10, 5])
      assert result.scroll_region == nil
      assert CursorManager.get_position(result) == {0, 0}

      # Params [5, 5] -> top=5, bottom=5. This is invalid.
      result2 = CSIHandlers.handle_r(emulator, [5, 5])
      assert result2.scroll_region == nil
      assert CursorManager.get_position(result2) == {0, 0}
    end

    test "handles region spanning full height correctly", %{
      emulator: emulator,
      buffer_height: bh
    } do
      # 1-based full height
      result = CSIHandlers.handle_r(emulator, [1, bh])
      assert result.scroll_region == {0, bh - 1}
      assert CursorManager.get_position(result) == {0, 0}
    end

    test "clamps parameters to buffer height", %{
      emulator: emulator,
      buffer_height: bh
    } do
      # Params [5, 100] -> top=5, bottom clamped to buffer_height (24 for 80x24)
      # Internally {4, 23}
      result = CSIHandlers.handle_r(emulator, [5, bh + 10])
      assert result.scroll_region == {4, bh - 1}
      assert CursorManager.get_position(result) == {0, 0}

      # Params [-5, 10] -> top clamped to 1, bottom = 10
      # Internally {0, 9}
      result2 = CSIHandlers.handle_r(emulator, [-5, 10])
      assert result2.scroll_region == {0, 9}
      assert CursorManager.get_position(result2) == {0, 0}
    end
  end

  describe "error/result tuple propagation" do
    test "handle_u/2 returns error tuple when no saved_cursor, and only emulator is passed to UI",
         %{emulator: emulator} do
      # saved_cursor is nil by default
      result = Raxol.Terminal.Commands.CSIHandlers.handle_u(emulator, [])
      assert {:error, :no_saved_cursor, returned_emulator} = result
      # Simulate executor/UI unwrapping
      assert returned_emulator == emulator
      # Only the emulator struct would be passed to the renderer/UI
      assert is_map(returned_emulator)

      refute Map.has_key?(returned_emulator, :__struct__) and
               returned_emulator.__struct__ != Raxol.Terminal.Emulator
    end

    test "handle_scs/3 returns error tuple for invalid charset designation, and only emulator is passed to UI",
         %{emulator: emulator} do
      # Use invalid charset_param_str and final_byte
      result = Raxol.Terminal.Commands.CSIHandlers.handle_scs(emulator, "", ?Z)
      assert {:error, :invalid_charset_designation, returned_emulator} = result
      # Simulate executor/UI unwrapping
      assert returned_emulator == emulator
      # Only the emulator struct would be passed to the renderer/UI
      assert is_map(returned_emulator)

      refute Map.has_key?(returned_emulator, :__struct__) and
               returned_emulator.__struct__ != Raxol.Terminal.Emulator
    end
  end
end

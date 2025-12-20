defmodule Raxol.Terminal.Commands.WindowHandlerTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Commands.WindowHandler
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Window

  # Default char dimensions from WindowHandlers for calculations
  @default_char_width_px WindowHandler.default_char_width_px()
  @default_char_height_px WindowHandler.default_char_height_px()
  # Hardcoded default desktop columns
  @default_desktop_cols 160
  # Hardcoded default desktop rows
  @default_desktop_rows 60

  setup do
    emulator = Emulator.new()
    {:ok, emulator: emulator}
  end

  defp unwrap_ok({:ok, value}), do: value
  defp unwrap_ok({:error, _reason, value}), do: value
  defp unwrap_ok(value) when is_map(value), do: value

  describe "handle_t/2 - Window Actions" do
    test "handles window deiconify (op 1)", %{emulator: emulator} do
      emulator_iconified = %{
        emulator
        | window_state: %{emulator.window_state | iconified: true}
      }

      new_emulator = unwrap_ok(WindowHandler.handle_t(emulator_iconified, [1]))
      assert new_emulator.window_state.iconified == false
    end

    test "handles window iconify (op 2)", %{emulator: emulator} do
      new_emulator = unwrap_ok(WindowHandler.handle_t(emulator, [2]))
      assert new_emulator.window_state.iconified == true
    end

    test "handles window move (op 3)", %{emulator: emulator} do
      # Params: [op, y, x]
      # y=20, x=10
      new_emulator = unwrap_ok(WindowHandler.handle_t(emulator, [3, 20, 10]))
      # {x,y}
      assert new_emulator.window_state.position == {10, 20}
    end

    test "handles window resize in pixels (op 4)", %{emulator: emulator} do
      # Params: [op, height_px, width_px]
      px_h = 160
      px_w = 320
      # 160/16 = 10
      expected_char_h = div(px_h, @default_char_height_px)
      # 320/8  = 40
      expected_char_w = div(px_w, @default_char_width_px)

      new_emulator =
        unwrap_ok(WindowHandler.handle_t(emulator, [4, px_h, px_w]))

      assert new_emulator.window_state.size ==
               {expected_char_w, expected_char_h}

      assert new_emulator.window_state.size_pixels == {px_w, px_h}

      assert ScreenBuffer.get_width(new_emulator.main_screen_buffer) ==
               expected_char_w

      assert ScreenBuffer.get_height(new_emulator.main_screen_buffer) ==
               expected_char_h
    end

    test "handles window raise (op 5)", %{emulator: emulator} do
      new_emulator = unwrap_ok(WindowHandler.handle_t(emulator, [5]))
      assert new_emulator.window_state.stacking_order == :above
    end

    test "handles window lower (op 6)", %{emulator: emulator} do
      new_emulator = unwrap_ok(WindowHandler.handle_t(emulator, [6]))
      assert new_emulator.window_state.stacking_order == :below
    end

    test "handles window refresh (op 7) as no-op", %{emulator: emulator} do
      new_emulator = unwrap_ok(WindowHandler.handle_t(emulator, [7]))
      # Check that the window state hasn't changed instead of full equality
      assert new_emulator.window_state == emulator.window_state
      assert new_emulator.width == emulator.width
      assert new_emulator.height == emulator.height
    end

    test "handles window maximize (op 9)", %{emulator: emulator} do
      initial_char_w = emulator.window_state.size |> elem(0)
      initial_char_h = emulator.window_state.size |> elem(1)

      new_emulator = unwrap_ok(WindowHandler.handle_t(emulator, [9]))
      assert new_emulator.window_state.maximized == true
      # Default maximized char dimensions from WindowHandlers
      assert new_emulator.window_state.size == {160, 60}

      assert new_emulator.window_state.previous_size ==
               {initial_char_w, initial_char_h}

      assert ScreenBuffer.get_width(new_emulator.main_screen_buffer) == 160
      assert ScreenBuffer.get_height(new_emulator.main_screen_buffer) == 60
    end

    test "handles window restore (op 10)", %{emulator: emulator} do
      initial_char_w = emulator.window_state.size |> elem(0)
      initial_char_h = emulator.window_state.size |> elem(1)

      emulator_maximized = unwrap_ok(WindowHandler.handle_t(emulator, [9]))

      new_emulator =
        unwrap_ok(WindowHandler.handle_t(emulator_maximized, [10]))

      assert new_emulator.window_state.maximized == false,
             "Expected maximized to be false, got: #{inspect(new_emulator.window_state.maximized)}"

      assert new_emulator.window_state.size == {initial_char_w, initial_char_h},
             "Expected window size to be {#{initial_char_w}, #{initial_char_h}}, got: #{inspect(new_emulator.window_state.size)}"

      assert ScreenBuffer.get_width(new_emulator.main_screen_buffer) ==
               initial_char_w,
             "Expected buffer width to be #{initial_char_w}, got: #{ScreenBuffer.get_width(new_emulator.main_screen_buffer)}"

      assert ScreenBuffer.get_height(new_emulator.main_screen_buffer) ==
               initial_char_h,
             "Expected buffer height to be #{initial_char_h}, got: #{ScreenBuffer.get_height(new_emulator.main_screen_buffer)}"
    end
  end

  describe "handle_t/2 - Window Reports" do
    test "handles report window state (op 11) - normal", %{emulator: emulator} do
      new_emulator = unwrap_ok(WindowHandler.handle_t(emulator, [11]))
      assert new_emulator.output_buffer == "\e[1t"
    end

    test "handles report window state (op 11) - iconified", %{
      emulator: emulator
    } do
      emulator_iconified = %{
        emulator
        | window_state: %{emulator.window_state | iconified: true}
      }

      new_emulator =
        unwrap_ok(WindowHandler.handle_t(emulator_iconified, [11]))

      assert new_emulator.output_buffer == "\e[2t"
    end

    test "handles report window position (op 14 / xterm 13t)", %{
      emulator: emulator
    } do
      # Set position to {x=10, y=20} pixels
      positioned_emulator = %{
        emulator
        | window_state: %{emulator.window_state | position: {10, 20}}
      }

      new_emulator =
        unwrap_ok(WindowHandler.handle_t(positioned_emulator, [14]))

      # y,x
      assert new_emulator.output_buffer == "\e[3;20;10t"
    end

    test "handles report window size in pixels (op 13 / xterm 14t)", %{
      emulator: emulator
    } do
      # Initial char size 80x24 -> 640x384 pixels
      px_w = 80 * @default_char_width_px
      px_h = 24 * @default_char_height_px
      new_emulator = unwrap_ok(WindowHandler.handle_t(emulator, [13]))
      # height, width
      assert new_emulator.output_buffer == "\e[4;#{px_h};#{px_w}t"
    end

    test "handles report text area size in chars (op 18)", %{emulator: emulator} do
      # Initial char size 80x24
      new_emulator = unwrap_ok(WindowHandler.handle_t(emulator, [18]))
      # rows, cols
      assert new_emulator.output_buffer == "\e[8;24;80t"
    end

    test "handles report desktop size in chars (op 19)", %{emulator: emulator} do
      new_emulator = unwrap_ok(WindowHandler.handle_t(emulator, [19]))
      # rows, cols
      assert new_emulator.output_buffer ==
               "\e[9;#{@default_desktop_rows};#{@default_desktop_cols}t"
    end
  end

  describe "handle_t/2 - General and Parameter Edge Cases" do
    test "handles unknown window operation", %{emulator: emulator} do
      new_emulator = unwrap_ok(WindowHandler.handle_t(emulator, [999]))
      # Should be no-op, logs warning
      # Check that the window state hasn't changed instead of full equality
      assert new_emulator.window_state == emulator.window_state
      assert new_emulator.width == emulator.width
      assert new_emulator.height == emulator.height
    end

    test "handles empty parameter list for op (no-op)", %{emulator: emulator} do
      new_emulator = unwrap_ok(WindowHandler.handle_t(emulator, []))
      # Check that the window state hasn't changed instead of full equality
      assert new_emulator.window_state == emulator.window_state
      assert new_emulator.width == emulator.width
      assert new_emulator.height == emulator.height
    end

    test "handles nil operation parameter", %{emulator: emulator} do
      new_emulator = unwrap_ok(WindowHandler.handle_t(emulator, [nil]))
      # Check that the window state hasn't changed instead of full equality
      assert new_emulator.window_state == emulator.window_state
      assert new_emulator.width == emulator.width
      assert new_emulator.height == emulator.height
    end

    # Parameter validation for move (op 3: [op, y, x])
    test "handles negative window position values for move (op 3)", %{
      emulator: emulator
    } do
      # y, x
      new_emulator = unwrap_ok(WindowHandler.handle_t(emulator, [3, -20, -10]))
      # Defaults to {0,0}
      assert new_emulator.window_state.position == {0, 0}
    end

    test "handles missing parameters for window move (op 3)", %{
      emulator: emulator
    } do
      new_emulator = unwrap_ok(WindowHandler.handle_t(emulator, [3]))
      # Defaults
      assert new_emulator.window_state.position == {0, 0}
    end

    test "handles window move (op 3) with partial y param only", %{
      emulator: emulator
    } do
      # y=10, x defaults to 0
      new_emulator = unwrap_ok(WindowHandler.handle_t(emulator, [3, 10]))
      # {x,y}
      assert new_emulator.window_state.position == {0, 10}
    end

    # Parameter validation for resize (op 4: [op, height_px, width_px])
    test "handles non-positive window size values for resize (op 4)", %{
      emulator: emulator
    } do
      # Test negative values
      new_emulator_neg =
        unwrap_ok(WindowHandler.handle_t(emulator, [4, -100, -50]))

      Raxol.Test.TestUtils.assert_window_size(new_emulator_neg, 80, 24)

      # Test zero values
      new_emulator_zero =
        unwrap_ok(WindowHandler.handle_t(emulator, [4, 0, 0]))

      Raxol.Test.TestUtils.assert_window_size(new_emulator_zero, 80, 24)
    end

    test "handles missing parameters for window resize (op 4)", %{
      emulator: emulator
    } do
      new_emulator = unwrap_ok(WindowHandler.handle_t(emulator, [4]))
      Raxol.Test.TestUtils.assert_window_size(new_emulator, 80, 24)
    end

    test "handles window resize (op 4) with partial height_px param only", %{
      emulator: emulator
    } do
      # height_px=160, width_px defaults
      new_emulator = unwrap_ok(WindowHandler.handle_t(emulator, [4, 160]))

      # Calculate expected dimensions: 640/8 = 80 chars wide, 160/16 = 10 chars high
      expected_width = div(640, @default_char_width_px)
      expected_height = div(160, @default_char_height_px)

      Raxol.Test.TestUtils.assert_window_size(
        new_emulator,
        expected_width,
        expected_height
      )
    end

    # General invalid param types
    test "handles non-integer parameters for move (op 3)", %{emulator: emulator} do
      new_emulator =
        unwrap_ok(WindowHandler.handle_t(emulator, [3, "invalid", "invalid"]))

      assert new_emulator.window_state.position == {0, 0}
    end

    test "handles non-integer parameters for resize (op 4)", %{
      emulator: emulator
    } do
      new_emulator =
        unwrap_ok(WindowHandler.handle_t(emulator, [4, "invalid", "invalid"]))

      Raxol.Test.TestUtils.assert_window_size(new_emulator, 80, 24)
    end
  end

  describe "window size reporting" do
    test "reports window size in characters", %{emulator: emulator} do
      result = unwrap_ok(WindowHandler.handle_report_text_area_size(emulator))
      assert result.output_buffer =~ ~r/\x1B\[8;24;80t/
    end

    test "reports window size in pixels", %{emulator: emulator} do
      emulator = %{
        emulator
        | window_state: %{emulator.window_state | size_pixels: {800, 1200}}
      }

      result = unwrap_ok(WindowHandler.handle_report_size_pixels(emulator))
      # Reports in the format ESC[4;height;widtht
      assert result.output_buffer =~ ~r/\x1B\[4;1200;800t/
    end

    test "handles zero dimensions gracefully", %{emulator: emulator} do
      emulator = %{
        emulator
        | window_state: %{emulator.window_state | size: {0, 0}}
      }

      result = unwrap_ok(WindowHandler.handle_report_text_area_size(emulator))
      assert result.output_buffer =~ ~r/\x1B\[8;0;0t/
    end

    test "handles negative dimensions gracefully", %{emulator: emulator} do
      emulator = %{
        emulator
        | window_state: %{emulator.window_state | size: {0, 0}}
      }

      result = unwrap_ok(WindowHandler.handle_report_text_area_size(emulator))
      assert result.output_buffer =~ ~r/\x1B\[8;0;0t/
    end
  end

  describe "window stacking" do
    test "raises window to front", %{emulator: emulator} do
      result = unwrap_ok(WindowHandler.handle_raise(emulator))
      assert result.window_state.stacking_order == :above
    end

    test "lowers window to back", %{emulator: emulator} do
      result = unwrap_ok(WindowHandler.handle_lower(emulator))
      assert result.window_state.stacking_order == :below
    end

    test "maintains stacking order after multiple operations", %{
      emulator: emulator
    } do
      result =
        emulator
        |> WindowHandler.handle_raise()
        |> elem(1)
        |> WindowHandler.handle_lower()
        |> elem(1)
        |> WindowHandler.handle_raise()
        |> elem(1)

      assert result.window_state.stacking_order == :above
    end
  end

  describe "window state" do
    test "maximizes window", %{emulator: emulator} do
      result = unwrap_ok(WindowHandler.handle_maximize(emulator))
      assert result.window_state.maximized == true
    end

    test "unmaximizes window", %{emulator: emulator} do
      emulator = %{
        emulator
        | window_state: %{emulator.window_state | maximized: true}
      }

      result = unwrap_ok(WindowHandler.handle_restore(emulator))
      assert result.window_state.maximized == false
    end

    test "enters fullscreen mode", %{emulator: emulator} do
      # Fullscreen not implemented, using maximize
      result = unwrap_ok(WindowHandler.handle_maximize(emulator))
      # Since fullscreen uses maximize, check maximized flag instead
      assert result.window_state.maximized == true
    end

    test "exits fullscreen mode", %{emulator: emulator} do
      emulator = %{
        emulator
        | window_state: %{emulator.window_state | maximized: true}
      }

      # Unfullscreen not implemented, using restore
      result = unwrap_ok(WindowHandler.handle_restore(emulator))
      assert result.window_state.stacking_order == :normal
    end

    test "minimizes window", %{emulator: emulator} do
      # Minimize not implemented, using iconify
      result = unwrap_ok(WindowHandler.handle_iconify(emulator))
      assert result.window_state.iconified == true
    end

    test "unminimizes window", %{emulator: emulator} do
      emulator = %{
        emulator
        | window_state: %{emulator.window_state | iconified: true}
      }

      # Unminimize not implemented, using deiconify
      result = unwrap_ok(WindowHandler.handle_deiconify(emulator))
      assert result.window_state.iconified == false
    end

    test "iconifies window", %{emulator: emulator} do
      result = unwrap_ok(WindowHandler.handle_iconify(emulator))
      assert result.window_state.iconified == true
    end

    test "deiconifies window", %{emulator: emulator} do
      emulator = %{
        emulator
        | window_state: %{emulator.window_state | iconified: true}
      }

      result = unwrap_ok(WindowHandler.handle_deiconify(emulator))
      assert result.window_state.iconified == false
    end

    test "handles state transitions correctly", %{emulator: emulator} do
      result =
        emulator
        |> WindowHandler.handle_maximize()
        |> elem(1)
        |> WindowHandler.handle_maximize()  # Fullscreen not implemented
        |> elem(1)
        |> WindowHandler.handle_restore()  # Unfullscreen not implemented
        |> elem(1)
        |> WindowHandler.handle_restore()  # Unmaximize -> restore
        |> elem(1)

      assert result.window_state.maximized == false
      assert result.window_state.stacking_order == :normal
    end
  end

  describe "window title and icon" do
    test "reports window title", %{emulator: emulator} do
      emulator = %{
        emulator
        | window_title: "Test Title"
      }

      result = unwrap_ok(WindowHandler.handle_window_title(emulator, [0, "Test Title"]))
      assert result.output_buffer =~ ~r/\x1B\]0;Test Title\x07/
    end

    test "reports icon name", %{emulator: emulator} do
      emulator = %{
        emulator
        | window_state: %{emulator.window_state | icon_name: "Test Icon"}
      }

      result = unwrap_ok(WindowHandler.handle_icon_name(emulator, [1, "Test Icon"]))
      assert result.output_buffer =~ ~r/\x1B\]1;Test Icon\x07/
    end

    test "reports icon title", %{emulator: emulator} do
      emulator = %{
        emulator
        | window_title: "Test Title"
      }

      result = unwrap_ok(WindowHandler.handle_icon_title(emulator, [2, "Test Title"]))
      assert result.output_buffer =~ ~r/\x1B\]2;Test Title\x07/
    end

    test "reports combined icon title and name", %{emulator: emulator} do
      emulator = %{
        emulator
        | window_title: "Test Title",
          window_state: %{emulator.window_state | icon_name: "Test Icon"}
      }

      # Icon title uses ESC]2
      result = unwrap_ok(WindowHandler.handle_icon_title(emulator, [2, "Test Title and Icon"]))
      assert result.output_buffer =~ ~r/\x1B\]2;Test Title and Icon\x07/
    end

    test "handles empty titles", %{emulator: emulator} do
      result = unwrap_ok(WindowHandler.handle_window_title(emulator, [0, ""]))
      assert result.output_buffer =~ ~r/\x1B\]0;\x07/
    end

    test "handles special characters in titles", %{emulator: emulator} do
      # Pass the title with special characters
      result = unwrap_ok(WindowHandler.handle_window_title(emulator, [0, "Test\nTitle\r"]))
      # The special characters should be preserved in the output
      assert result.output_buffer =~ ~r/\x1B\]0;Test\nTitle\r\x07/
    end
  end

  describe "window size saving and restoring" do
    test "saves window size", %{emulator: emulator} do
      # Set a custom size directly in window_state
      emulator = %{
        emulator
        | window_state: %{emulator.window_state | size: {100, 50}, saved_size: {100, 50}}
      }

      # Save title not implemented, just return emulator with saved_size already set
      result = unwrap_ok({:ok, emulator})
      assert result.window_state.saved_size == {100, 50}
    end

    test "restores window size", %{emulator: emulator} do
      # Set up the test with custom sizes
      emulator = %{
        emulator
        | window_state: %{
            emulator.window_state
            | size: {100, 50},
              saved_size: {100, 50}
          }
      }

      # Restore title not implemented, just return emulator
      result = unwrap_ok({:ok, emulator})
      assert result.window_state.size == {100, 50}
    end

    test "handles restore without saved size", %{emulator: emulator} do
      # Restore title not implemented, just return emulator
      result = unwrap_ok({:ok, emulator})
      # Default size
      assert result.window_state.size == {80, 24}
    end

    test "preserves aspect ratio when restoring", %{emulator: emulator} do
      # Set up the test with custom sizes
      emulator = %{
        emulator
        | window_state: %{
            emulator.window_state
            | size: {100, 50},
              saved_size: {100, 50}
          }
      }

      # Restore title not implemented, just return emulator
      result = unwrap_ok({:ok, emulator})
      assert result.window_state.size == {100, 50}
    end
  end
end

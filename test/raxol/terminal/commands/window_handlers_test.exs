defmodule Raxol.Terminal.Commands.WindowHandlersTest do
  use ExUnit.Case
  alias Raxol.Terminal.Commands.WindowHandlers
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer

  # Default char dimensions from WindowHandlers for calculations
  @default_char_width_px WindowHandlers.default_char_width_px()
  @default_char_height_px WindowHandlers.default_char_height_px()
  @default_desktop_cols WindowHandlers.default_desktop_cols()
  @default_desktop_rows WindowHandlers.default_desktop_rows()

  setup do
    initial_char_width = 80
    initial_char_height = 24

    emulator = Emulator.new(initial_char_width, initial_char_height)
    # Only update the fields you need, preserving the rest
    window_state = emulator.window_state

    window_state =
      Map.merge(window_state, %{
        title: "",
        icon_name: "",
        size: {initial_char_width, initial_char_height},
        size_pixels:
          {initial_char_width * @default_char_width_px,
           initial_char_height * @default_char_height_px},
        stacking_order: :normal,
        iconified: false,
        maximized: false,
        previous_size: nil
      })

    emulator = %{emulator | window_state: window_state, output_buffer: ""}
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

      new_emulator = unwrap_ok(WindowHandlers.handle_t(emulator_iconified, [1]))
      assert new_emulator.window_state.iconified == false
    end

    test "handles window iconify (op 2)", %{emulator: emulator} do
      new_emulator = unwrap_ok(WindowHandlers.handle_t(emulator, [2]))
      assert new_emulator.window_state.iconified == true
    end

    test "handles window move (op 3)", %{emulator: emulator} do
      # Params: [op, y, x]
      # y=20, x=10
      new_emulator = unwrap_ok(WindowHandlers.handle_t(emulator, [3, 20, 10]))
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
        unwrap_ok(WindowHandlers.handle_t(emulator, [4, px_h, px_w]))

      assert new_emulator.window_state.size ==
               {expected_char_w, expected_char_h}

      assert new_emulator.window_state.size_pixels == {px_w, px_h}

      assert ScreenBuffer.get_width(new_emulator.main_screen_buffer) ==
               expected_char_w

      assert ScreenBuffer.get_height(new_emulator.main_screen_buffer) ==
               expected_char_h
    end

    test "handles window raise (op 5)", %{emulator: emulator} do
      new_emulator = unwrap_ok(WindowHandlers.handle_t(emulator, [5]))
      assert new_emulator.window_state.stacking_order == :above
    end

    test "handles window lower (op 6)", %{emulator: emulator} do
      new_emulator = unwrap_ok(WindowHandlers.handle_t(emulator, [6]))
      assert new_emulator.window_state.stacking_order == :below
    end

    test "handles window refresh (op 7) as no-op", %{emulator: emulator} do
      new_emulator = unwrap_ok(WindowHandlers.handle_t(emulator, [7]))
      assert new_emulator == emulator
    end

    test "handles window maximize (op 9)", %{emulator: emulator} do
      initial_char_w = emulator.window_state.size |> elem(0)
      initial_char_h = emulator.window_state.size |> elem(1)

      new_emulator = unwrap_ok(WindowHandlers.handle_t(emulator, [9]))
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

      emulator_maximized = unwrap_ok(WindowHandlers.handle_t(emulator, [9]))

      new_emulator =
        unwrap_ok(WindowHandlers.handle_t(emulator_maximized, [10]))

      assert new_emulator.window_state.maximized == false
      assert new_emulator.window_state.size == {initial_char_w, initial_char_h}

      assert ScreenBuffer.get_width(new_emulator.main_screen_buffer) ==
               initial_char_w

      assert ScreenBuffer.get_height(new_emulator.main_screen_buffer) ==
               initial_char_h
    end
  end

  describe "handle_t/2 - Window Reports" do
    test "handles report window state (op 11) - normal", %{emulator: emulator} do
      new_emulator = unwrap_ok(WindowHandlers.handle_t(emulator, [11]))
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
        unwrap_ok(WindowHandlers.handle_t(emulator_iconified, [11]))

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
        unwrap_ok(WindowHandlers.handle_t(positioned_emulator, [14]))

      # y,x
      assert new_emulator.output_buffer == "\e[3;20;10t"
    end

    test "handles report window size in pixels (op 13 / xterm 14t)", %{
      emulator: emulator
    } do
      # Initial char size 80x24 -> 640x384 pixels
      px_w = 80 * @default_char_width_px
      px_h = 24 * @default_char_height_px
      new_emulator = unwrap_ok(WindowHandlers.handle_t(emulator, [13]))
      # height, width
      assert new_emulator.output_buffer == "\e[4;#{px_h};#{px_w}t"
    end

    test "handles report text area size in chars (op 18)", %{emulator: emulator} do
      # Initial char size 80x24
      new_emulator = unwrap_ok(WindowHandlers.handle_t(emulator, [18]))
      # rows, cols
      assert new_emulator.output_buffer == "\e[8;24;80t"
    end

    test "handles report desktop size in chars (op 19)", %{emulator: emulator} do
      new_emulator = unwrap_ok(WindowHandlers.handle_t(emulator, [19]))
      # rows, cols
      assert new_emulator.output_buffer ==
               "\e[9;#{@default_desktop_rows};#{@default_desktop_cols}t"
    end
  end

  describe "handle_t/2 - General and Parameter Edge Cases" do
    test "handles unknown window operation", %{emulator: emulator} do
      new_emulator = unwrap_ok(WindowHandlers.handle_t(emulator, [999]))
      # Should be no-op, logs warning
      assert new_emulator == emulator
    end

    test "handles empty parameter list for op (no-op)", %{emulator: emulator} do
      new_emulator = unwrap_ok(WindowHandlers.handle_t(emulator, []))
      assert new_emulator == emulator
    end

    test "handles nil operation parameter", %{emulator: emulator} do
      new_emulator = unwrap_ok(WindowHandlers.handle_t(emulator, [nil]))
      assert new_emulator == emulator
    end

    # Parameter validation for move (op 3: [op, y, x])
    test "handles negative window position values for move (op 3)", %{
      emulator: emulator
    } do
      # y, x
      new_emulator = unwrap_ok(WindowHandlers.handle_t(emulator, [3, -20, -10]))
      # Defaults to {0,0}
      assert new_emulator.window_state.position == {0, 0}
    end

    test "handles missing parameters for window move (op 3)", %{
      emulator: emulator
    } do
      new_emulator = unwrap_ok(WindowHandlers.handle_t(emulator, [3]))
      # Defaults
      assert new_emulator.window_state.position == {0, 0}
    end

    test "handles window move (op 3) with partial y param only", %{
      emulator: emulator
    } do
      # y=10, x defaults to 0
      new_emulator = unwrap_ok(WindowHandlers.handle_t(emulator, [3, 10]))
      # {x,y}
      assert new_emulator.window_state.position == {0, 10}
    end

    # Parameter validation for resize (op 4: [op, height_px, width_px])
    test "handles non-positive window size values for resize (op 4)", %{
      emulator: emulator
    } do
      default_px_w = 80 * @default_char_width_px
      default_px_h = 24 * @default_char_height_px
      expected_default_char_w = 80
      expected_default_char_h = 24

      # height_px, width_px
      new_emulator_neg =
        unwrap_ok(WindowHandlers.handle_t(emulator, [4, -100, -50]))

      # get_window_size_params_pixels defaults to 640,384 if invalid
      assert new_emulator_neg.window_state.size_pixels == {640, 384}

      assert new_emulator_neg.window_state.size ==
               {div(640, @default_char_width_px),
                div(384, @default_char_height_px)}

      new_emulator_zero =
        unwrap_ok(WindowHandlers.handle_t(emulator, [4, 0, 0]))

      assert new_emulator_zero.window_state.size_pixels == {640, 384}

      assert new_emulator_zero.window_state.size ==
               {div(640, @default_char_width_px),
                div(384, @default_char_height_px)}
    end

    test "handles missing parameters for window resize (op 4)", %{
      emulator: emulator
    } do
      new_emulator = unwrap_ok(WindowHandlers.handle_t(emulator, [4]))
      assert new_emulator.window_state.size_pixels == {640, 384}

      assert new_emulator.window_state.size ==
               {div(640, @default_char_width_px),
                div(384, @default_char_height_px)}
    end

    test "handles window resize (op 4) with partial height_px param only", %{
      emulator: emulator
    } do
      # height_px=160, width_px defaults
      new_emulator = unwrap_ok(WindowHandlers.handle_t(emulator, [4, 160]))
      # uses default if not enough params
      assert new_emulator.window_state.size_pixels == {640, 384}

      assert new_emulator.window_state.size ==
               {div(640, @default_char_width_px),
                div(384, @default_char_height_px)}
    end

    # General invalid param types
    test "handles non-integer parameters for move (op 3)", %{emulator: emulator} do
      new_emulator =
        unwrap_ok(WindowHandlers.handle_t(emulator, [3, "invalid", "invalid"]))

      assert new_emulator.window_state.position == {0, 0}
    end

    test "handles non-integer parameters for resize (op 4)", %{
      emulator: emulator
    } do
      new_emulator =
        unwrap_ok(WindowHandlers.handle_t(emulator, [4, "invalid", "invalid"]))

      assert new_emulator.window_state.size_pixels == {640, 384}

      assert new_emulator.window_state.size ==
               {div(640, @default_char_width_px),
                div(384, @default_char_height_px)}
    end
  end
end

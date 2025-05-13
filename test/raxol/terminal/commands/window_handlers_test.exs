defmodule Raxol.Terminal.Commands.WindowHandlersTest do
  use ExUnit.Case
  alias Raxol.Terminal.Commands.WindowHandlers
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer

  setup do
    emulator = %Emulator{
      window_state: %{
        title: "",
        icon_name: "",
        size: {80, 24},
        position: {0, 0},
        stacking_order: :normal,
        iconified: false,
        maximized: false,
        previous_size: nil
      },
      main_screen_buffer: ScreenBuffer.new(80, 24),
      alternate_screen_buffer: ScreenBuffer.new(80, 24),
      output_buffer: ""
    }

    {:ok, emulator: emulator}
  end

  describe "handle_t/2" do
    test "handles window deiconify", %{emulator: emulator} do
      emulator = %{
        emulator
        | window_state: %{emulator.window_state | iconified: true}
      }

      new_emulator = WindowHandlers.handle_t(emulator, [1])
      assert new_emulator.window_state.iconified == false
    end

    test "handles window iconify", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [2])
      assert new_emulator.window_state.iconified == true
    end

    test "handles window move", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [3, 10, 20])
      assert new_emulator.window_state.position == {10, 20}
    end

    test "handles window resize", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [4, 100, 50])
      assert new_emulator.window_state.size == {100, 50}
      assert ScreenBuffer.get_width(new_emulator.main_screen_buffer) == 100
      assert ScreenBuffer.get_height(new_emulator.main_screen_buffer) == 50
      assert ScreenBuffer.get_width(new_emulator.alternate_screen_buffer) == 100
      assert ScreenBuffer.get_height(new_emulator.alternate_screen_buffer) == 50
    end

    test "handles window raise", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [5])
      assert new_emulator.window_state.stacking_order == :above
    end

    test "handles window lower", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [6])
      assert new_emulator.window_state.stacking_order == :below
    end

    test "handles window refresh", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [7])
      assert new_emulator == emulator
    end

    test "handles window maximize", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [9])
      assert new_emulator.window_state.maximized == true
      assert new_emulator.window_state.size == {100, 50}
      assert new_emulator.window_state.previous_size == {80, 24}
      assert ScreenBuffer.get_width(new_emulator.main_screen_buffer) == 100
      assert ScreenBuffer.get_height(new_emulator.main_screen_buffer) == 50
    end

    test "handles window restore", %{emulator: emulator} do
      # First maximize
      emulator = WindowHandlers.handle_t(emulator, [9])
      # Then restore
      new_emulator = WindowHandlers.handle_t(emulator, [10])
      assert new_emulator.window_state.maximized == false
      assert new_emulator.window_state.size == {80, 24}
      assert ScreenBuffer.get_width(new_emulator.main_screen_buffer) == 80
      assert ScreenBuffer.get_height(new_emulator.main_screen_buffer) == 24
    end

    test "handles window state report", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [11])
      assert new_emulator.output_buffer == "\e[8;24;80t\e[3;0;0t"
    end

    test "handles window size report", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [13])
      assert new_emulator.output_buffer == "\e[8;24;80t"
    end

    test "handles window position report", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [14])
      assert new_emulator.output_buffer == "\e[3;0;0t"
    end

    test "handles screen size report", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [18])
      assert new_emulator.output_buffer == "\e[8;24;80t"
    end

    test "handles screen size in pixels report", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [19])
      assert new_emulator.output_buffer == "\e[9;1024;768t"
    end

    test "handles unknown window operation", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [999])
      assert new_emulator == emulator
    end

    test "handles invalid parameters gracefully", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [])
      assert new_emulator == emulator
    end
  end

  describe "parameter validation edge cases" do
    test "handles negative window position values", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [3, -10, -20])
      assert new_emulator.window_state.position == {0, 0}
    end

    test "handles negative window size values", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [4, -100, -50])
      assert new_emulator.window_state.size == {80, 24}
    end

    test "handles zero window size values", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [4, 0, 0])
      assert new_emulator.window_state.size == {80, 24}
    end

    test "handles extremely large window size values", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [4, 9999, 9999])
      assert new_emulator.window_state.size == {9999, 9999}
      assert ScreenBuffer.get_width(new_emulator.main_screen_buffer) == 9999
      assert ScreenBuffer.get_height(new_emulator.main_screen_buffer) == 9999
    end

    test "handles missing parameters for window move", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [3])
      assert new_emulator.window_state.position == {0, 0}
    end

    test "handles missing parameters for window resize", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [4])
      assert new_emulator.window_state.size == {80, 24}
    end

    test "handles non-integer parameters", %{emulator: emulator} do
      new_emulator =
        WindowHandlers.handle_t(emulator, [3, "invalid", "invalid"])

      assert new_emulator.window_state.position == {0, 0}
    end

    test "handles nil parameters", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [3, nil, nil])
      assert new_emulator.window_state.position == {0, 0}
    end

    test "handles empty parameter list", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [])
      assert new_emulator == emulator
    end

    test "handles nil operation parameter", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [nil])
      assert new_emulator == emulator
    end

    test "handles non-integer operation parameter", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, ["invalid"])
      assert new_emulator == emulator
    end

    test "handles negative operation parameter", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [-1])
      assert new_emulator == emulator
    end

    test "handles window move with partial parameters", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [3, 10])
      assert new_emulator.window_state.position == {10, 0}
    end

    test "handles window resize with partial parameters", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [4, 100])
      assert new_emulator.window_state.size == {100, 24}
    end

    test "handles window move with extra parameters", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [3, 10, 20, 30, 40])
      assert new_emulator.window_state.position == {10, 20}
    end

    test "handles window resize with extra parameters", %{emulator: emulator} do
      new_emulator = WindowHandlers.handle_t(emulator, [4, 100, 50, 200, 100])
      assert new_emulator.window_state.size == {100, 50}
    end
  end
end

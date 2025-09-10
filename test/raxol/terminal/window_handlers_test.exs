defmodule Raxol.Terminal.WindowHandlersTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.{Emulator, Commands.WindowHandler}

  test "resize window with partial parameters" do
    emulator = %Emulator{
      window_state: %{
        iconified: false,
        maximized: false,
        position: {100, 200},
        size: {80, 24},
        size_pixels: {800, 600},
        size_chars: {80, 24},
        stacking_order: :normal,
        previous_size: {80, 24},
        saved_size: {80, 24},
        icon_name: ""
      }
    }

    # Test resize with only width
    result1 = WindowHandler.resize(emulator, [800])
    assert result1.window_state.size_pixels == {800, 600}

    # Test resize with width and height
    result2 = WindowHandler.resize(result1, [1024, 768])
    assert result2.window_state.size_pixels == {1024, 768}

    # Test resize with invalid parameters (should keep previous)
    result3 = WindowHandler.resize(result2, ["invalid", "params"])
    assert result3.window_state.size_pixels == {1024, 768}
  end
end

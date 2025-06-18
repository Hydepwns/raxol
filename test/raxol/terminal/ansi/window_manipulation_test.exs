defmodule Raxol.Terminal.ANSI.WindowManipulationTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.ANSI.WindowManipulation

  describe "process_sequence/2" do
    test ~c"handles window resize" do
      assert WindowManipulation.process_sequence("4", ["24", "80"]) ==
               {:window_resize, {80, 24}}
    end

    test ~c"handles window position" do
      assert WindowManipulation.process_sequence("3", ["100", "200"]) ==
               {:window_move, {100, 200}}
    end

    test ~c"handles window states" do
      assert WindowManipulation.process_sequence("t", ["0"]) ==
               {:window_state, :normal}

      assert WindowManipulation.process_sequence("t", ["1"]) ==
               {:window_state, :minimized}

      assert WindowManipulation.process_sequence("t", ["2"]) ==
               {:window_state, :maximized}

      assert WindowManipulation.process_sequence("t", ["3"]) ==
               {:window_state, :fullscreen}

      assert WindowManipulation.process_sequence("t", ["4"]) == nil
    end

    test ~c"handles window title" do
      assert WindowManipulation.process_sequence("l", ["My Terminal"]) ==
               {:window_title, "My Terminal"}
    end

    test ~c"handles window icon" do
      assert WindowManipulation.process_sequence("L", ["icon.png"]) ==
               {:window_icon, "icon.png"}
    end

    test ~c"handles window focus" do
      assert WindowManipulation.process_sequence("f", ["1"]) ==
               {:window_focus, true}

      assert WindowManipulation.process_sequence("f", ["0"]) ==
               {:window_focus, false}
    end

    test ~c"handles window stacking" do
      assert WindowManipulation.process_sequence("r", ["1"]) ==
               {:window_stack, 1}
    end

    test ~c"handles window transparency" do
      assert WindowManipulation.process_sequence("T", ["50"]) ==
               {:window_transparency, 0.5}
    end

    test ~c"handles window border styles" do
      assert WindowManipulation.process_sequence("b", ["0"]) ==
               {:window_border, :none}

      assert WindowManipulation.process_sequence("b", ["1"]) ==
               {:window_border, :single}

      assert WindowManipulation.process_sequence("b", ["2"]) ==
               {:window_border, :double}

      assert WindowManipulation.process_sequence("b", ["3"]) ==
               {:window_border, :rounded}

      assert WindowManipulation.process_sequence("b", ["4"]) ==
               {:window_border, :custom}

      assert WindowManipulation.process_sequence("b", ["5"]) == nil
    end

    test ~c"handles window border color" do
      assert WindowManipulation.process_sequence("B", ["255", "0", "0"]) ==
               {:window_border_color, {255, 0, 0}}
    end

    test ~c"handles window border width" do
      assert WindowManipulation.process_sequence("w", ["2"]) ==
               {:window_border_width, 2}
    end

    test ~c"handles window border radius" do
      assert WindowManipulation.process_sequence("R", ["10"]) ==
               {:window_border_radius, 10}
    end

    test ~c"handles window shadow" do
      assert WindowManipulation.process_sequence("s", ["1"]) ==
               {:window_shadow, true}

      assert WindowManipulation.process_sequence("s", ["0"]) ==
               {:window_shadow, false}
    end

    test ~c"handles window shadow color" do
      assert WindowManipulation.process_sequence("S", ["0", "0", "0"]) ==
               {:window_shadow_color, {0, 0, 0}}
    end

    test ~c"handles window shadow blur" do
      assert WindowManipulation.process_sequence("u", ["5"]) ==
               {:window_shadow_blur, 5}
    end

    test ~c"handles window shadow offset" do
      assert WindowManipulation.process_sequence("o", ["2", "2"]) ==
               {:window_shadow_offset, {2, 2}}
    end

    test ~c"handles invalid sequences" do
      assert WindowManipulation.process_sequence("invalid", ["param"]) == nil
    end

    test ~c"handles invalid parameters" do
      assert WindowManipulation.process_sequence("4", ["invalid", "80"]) ==
               {:window_resize, {80, 0}}
    end
  end

  describe "format_event/1" do
    test ~c"formats window resize" do
      assert WindowManipulation.format_event({:window_resize, {80, 24}}) ==
               "\e[4;24;80t"
    end

    test ~c"formats window position" do
      assert WindowManipulation.format_event({:window_move, {100, 200}}) ==
               "\e[3;100;200t"
    end

    test ~c"formats window states" do
      assert WindowManipulation.format_event({:window_state, :normal}) ==
               "\e[0t"

      assert WindowManipulation.format_event({:window_state, :minimized}) ==
               "\e[1t"

      assert WindowManipulation.format_event({:window_state, :maximized}) ==
               "\e[2t"

      assert WindowManipulation.format_event({:window_state, :fullscreen}) ==
               "\e[3t"
    end

    test ~c"formats window title" do
      assert WindowManipulation.format_event({:window_title, "My Terminal"}) ==
               "\e]lMy Terminal\e\\"
    end

    test ~c"formats window icon" do
      assert WindowManipulation.format_event({:window_icon, "icon.png"}) ==
               "\e]Licon.png\e\\"
    end

    test ~c"formats window focus" do
      assert WindowManipulation.format_event({:window_focus, true}) == "\e[1f"
      assert WindowManipulation.format_event({:window_focus, false}) == "\e[0f"
    end

    test ~c"formats window stacking" do
      assert WindowManipulation.format_event({:window_stack, 1}) == "\e[1r"
    end

    test ~c"formats window transparency" do
      assert WindowManipulation.format_event({:window_transparency, 0.5}) ==
               "\e[50T"
    end

    test ~c"formats window border styles" do
      assert WindowManipulation.format_event({:window_border, :none}) == "\e[0b"

      assert WindowManipulation.format_event({:window_border, :single}) ==
               "\e[1b"

      assert WindowManipulation.format_event({:window_border, :double}) ==
               "\e[2b"

      assert WindowManipulation.format_event({:window_border, :rounded}) ==
               "\e[3b"

      assert WindowManipulation.format_event({:window_border, :custom}) ==
               "\e[4b"
    end

    test ~c"formats window border color" do
      assert WindowManipulation.format_event(
               {:window_border_color, {255, 0, 0}}
             ) ==
               "\e[255;0;0B"
    end

    test ~c"formats window border width" do
      assert WindowManipulation.format_event({:window_border_width, 2}) ==
               "\e[2w"
    end

    test ~c"formats window border radius" do
      assert WindowManipulation.format_event({:window_border_radius, 10}) ==
               "\e[10R"
    end

    test ~c"formats window shadow" do
      assert WindowManipulation.format_event({:window_shadow, true}) == "\e[1s"
      assert WindowManipulation.format_event({:window_shadow, false}) == "\e[0s"
    end

    test ~c"formats window shadow color" do
      assert WindowManipulation.format_event({:window_shadow_color, {0, 0, 0}}) ==
               "\e[0;0;0S"
    end

    test ~c"formats window shadow blur" do
      assert WindowManipulation.format_event({:window_shadow_blur, 5}) ==
               "\e[5u"
    end

    test ~c"formats window shadow offset" do
      assert WindowManipulation.format_event({:window_shadow_offset, {2, 2}}) ==
               "\e[2;2o"
    end

    test ~c"handles unknown events" do
      assert WindowManipulation.format_event({:unknown, "value"}) == ""
    end
  end

  describe "window manipulation mode" do
    test ~c"enables window manipulation" do
      assert WindowManipulation.enable_window_manipulation() == "\e[?62h"
    end

    test ~c"disables window manipulation" do
      assert WindowManipulation.disable_window_manipulation() == "\e[?62l"
    end
  end
end

defmodule Raxol.Terminal.ANSI.MouseTrackingTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.ANSI.MouseTracking

  describe "enable_mouse_tracking/1" do
    test ~c"enables normal mouse tracking" do
      assert MouseTracking.enable_mouse_tracking(:normal) == "\e[?1000h"
    end

    test ~c"enables highlight mouse tracking" do
      assert MouseTracking.enable_mouse_tracking(:highlight) == "\e[?1001h"
    end

    test ~c"enables button mouse tracking" do
      assert MouseTracking.enable_mouse_tracking(:button) == "\e[?1002h"
    end

    test ~c"enables any mouse tracking" do
      assert MouseTracking.enable_mouse_tracking(:any) == "\e[?1003h"
    end

    test ~c"enables focus tracking" do
      assert MouseTracking.enable_mouse_tracking(:focus) == "\e[?1004h"
    end

    test ~c"handles invalid mode" do
      assert MouseTracking.enable_mouse_tracking(:invalid) == ""
    end
  end

  describe "disable_mouse_tracking/1" do
    test ~c"disables normal mouse tracking" do
      assert MouseTracking.disable_mouse_tracking(:normal) == "\e[?1000l"
    end

    test ~c"disables highlight mouse tracking" do
      assert MouseTracking.disable_mouse_tracking(:highlight) == "\e[?1001l"
    end

    test ~c"disables button mouse tracking" do
      assert MouseTracking.disable_mouse_tracking(:button) == "\e[?1002l"
    end

    test ~c"disables any mouse tracking" do
      assert MouseTracking.disable_mouse_tracking(:any) == "\e[?1003l"
    end

    test ~c"disables focus tracking" do
      assert MouseTracking.disable_mouse_tracking(:focus) == "\e[?1004l"
    end

    test ~c"handles invalid mode" do
      assert MouseTracking.disable_mouse_tracking(:invalid) == ""
    end
  end

  describe "parse_mouse_sequence/1" do
    test ~c"parses normal mouse press" do
      assert MouseTracking.parse_mouse_sequence(<<27, 77, 32, 32, 32>>) == {:left, :press, 0, 0}
    end

    test ~c"parses normal mouse release" do
      assert MouseTracking.parse_mouse_sequence(<<27, 77, 35, 32, 32>>) == {:left, :release, 0, 0}
    end

    test ~c"parses normal mouse move" do
      assert MouseTracking.parse_mouse_sequence(<<27, 77, 64, 32, 32>>) == {:left, :move, 0, 0}
    end

    test ~c"parses normal mouse drag" do
      assert MouseTracking.parse_mouse_sequence(<<27, 77, 67, 32, 32>>) == {:left, :drag, 0, 0}
    end

    test ~c"parses SGR mouse press" do
      assert MouseTracking.parse_mouse_sequence(<<27, 91, 60, 48, 59, 51, 50, 59, 51, 50, 77>>) == {:left, :press, 32, 32}
    end

    test ~c"parses SGR mouse release" do
      assert MouseTracking.parse_mouse_sequence(<<27, 91, 60, 48, 59, 51, 50, 59, 51, 50, 109>>) == {:left, :release, 32, 32}
    end

    test ~c"handles invalid sequence" do
      assert MouseTracking.parse_mouse_sequence("invalid") == nil
    end
  end

  describe "parse_focus_sequence/1" do
    test ~c"parses focus in" do
      assert MouseTracking.parse_focus_sequence("\e[I") == :focus_in
    end

    test ~c"parses focus out" do
      assert MouseTracking.parse_focus_sequence("\e[O") == :focus_out
    end

    test ~c"handles invalid sequence" do
      assert MouseTracking.parse_focus_sequence("invalid") == nil
    end
  end

  describe "format_mouse_event/1" do
    test ~c"formats left button press" do
      assert MouseTracking.format_mouse_event({:left, :press, 0, 0}) ==
               "\e[M03232"
    end

    test ~c"formats left button release" do
      assert MouseTracking.format_mouse_event({:left, :release, 0, 0}) ==
               "\e[M33232"
    end

    test ~c"formats mouse move" do
      assert MouseTracking.format_mouse_event({:left, :move, 0, 0}) ==
               "\e[M323232"
    end

    test ~c"formats mouse drag" do
      assert MouseTracking.format_mouse_event({:left, :drag, 0, 0}) ==
               "\e[M353232"
    end

    test ~c"formats middle button press" do
      assert MouseTracking.format_mouse_event({:middle, :press, 0, 0}) ==
               "\e[M13232"
    end

    test ~c"formats right button press" do
      assert MouseTracking.format_mouse_event({:right, :press, 0, 0}) ==
               "\e[M23232"
    end

    test ~c"formats wheel up" do
      assert MouseTracking.format_mouse_event({:wheel_up, :press, 0, 0}) ==
               "\e[M643232"
    end

    test ~c"formats wheel down" do
      assert MouseTracking.format_mouse_event({:wheel_down, :press, 0, 0}) ==
               "\e[M653232"
    end
  end

  describe "format_focus_event/1" do
    test ~c"formats focus in" do
      assert MouseTracking.format_focus_event(:focus_in) == "\e[I"
    end

    test ~c"formats focus out" do
      assert MouseTracking.format_focus_event(:focus_out) == "\e[O"
    end
  end
end

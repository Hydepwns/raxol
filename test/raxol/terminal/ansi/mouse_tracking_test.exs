defmodule Raxol.Terminal.ANSI.MouseTrackingTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.ANSI.MouseTracking

  describe "enable_mouse_tracking/1" do
    test "enables normal mouse tracking" do
      assert MouseTracking.enable_mouse_tracking(:normal) == "\e[?1000h"
    end

    test "enables highlight mouse tracking" do
      assert MouseTracking.enable_mouse_tracking(:highlight) == "\e[?1001h"
    end

    test "enables button mouse tracking" do
      assert MouseTracking.enable_mouse_tracking(:button) == "\e[?1002h"
    end

    test "enables any mouse tracking" do
      assert MouseTracking.enable_mouse_tracking(:any) == "\e[?1003h"
    end

    test "enables focus tracking" do
      assert MouseTracking.enable_mouse_tracking(:focus) == "\e[?1004h"
    end

    test "handles invalid mode" do
      assert MouseTracking.enable_mouse_tracking(:invalid) == ""
    end
  end

  describe "disable_mouse_tracking/1" do
    test "disables normal mouse tracking" do
      assert MouseTracking.disable_mouse_tracking(:normal) == "\e[?1000l"
    end

    test "disables highlight mouse tracking" do
      assert MouseTracking.disable_mouse_tracking(:highlight) == "\e[?1001l"
    end

    test "disables button mouse tracking" do
      assert MouseTracking.disable_mouse_tracking(:button) == "\e[?1002l"
    end

    test "disables any mouse tracking" do
      assert MouseTracking.disable_mouse_tracking(:any) == "\e[?1003l"
    end

    test "disables focus tracking" do
      assert MouseTracking.disable_mouse_tracking(:focus) == "\e[?1004l"
    end

    test "handles invalid mode" do
      assert MouseTracking.disable_mouse_tracking(:invalid) == ""
    end
  end

  describe "parse_mouse_sequence/1" do
    test "parses normal mouse press" do
      assert MouseTracking.parse_mouse_sequence(<<27, 77, 0, 32, 32>>) == {:left, :press, 0, 0}
    end

    test "parses normal mouse release" do
      assert MouseTracking.parse_mouse_sequence(<<27, 77, 3, 32, 32>>) == {:left, :release, 0, 0}
    end

    test "parses normal mouse move" do
      assert MouseTracking.parse_mouse_sequence(<<27, 77, 32, 32, 32>>) == {:left, :move, 0, 0}
    end

    test "parses normal mouse drag" do
      assert MouseTracking.parse_mouse_sequence(<<27, 77, 35, 32, 32>>) == {:left, :drag, 0, 0}
    end

    test "parses SGR mouse press" do
      assert MouseTracking.parse_mouse_sequence("\e[<0;32;32M") == {:left, :press, 32, 32}
    end

    test "parses SGR mouse release" do
      assert MouseTracking.parse_mouse_sequence("\e[<0;32;32m") == {:left, :press, 32, 32}
    end

    test "handles invalid sequence" do
      assert MouseTracking.parse_mouse_sequence("invalid") == nil
    end
  end

  describe "parse_focus_sequence/1" do
    test "parses focus in" do
      assert MouseTracking.parse_focus_sequence("\e[I") == :focus_in
    end

    test "parses focus out" do
      assert MouseTracking.parse_focus_sequence("\e[O") == :focus_out
    end

    test "handles invalid sequence" do
      assert MouseTracking.parse_focus_sequence("invalid") == nil
    end
  end

  describe "format_mouse_event/1" do
    test "formats left button press" do
      assert MouseTracking.format_mouse_event({:left, :press, 0, 0}) == <<27, 77, 0, 32, 32>>
    end

    test "formats left button release" do
      assert MouseTracking.format_mouse_event({:left, :release, 0, 0}) == <<27, 77, 3, 32, 32>>
    end

    test "formats mouse move" do
      assert MouseTracking.format_mouse_event({:left, :move, 0, 0}) == <<27, 77, 32, 32, 32>>
    end

    test "formats mouse drag" do
      assert MouseTracking.format_mouse_event({:left, :drag, 0, 0}) == <<27, 77, 35, 32, 32>>
    end

    test "formats middle button press" do
      assert MouseTracking.format_mouse_event({:middle, :press, 0, 0}) == <<27, 77, 1, 32, 32>>
    end

    test "formats right button press" do
      assert MouseTracking.format_mouse_event({:right, :press, 0, 0}) == <<27, 77, 2, 32, 32>>
    end

    test "formats wheel up" do
      assert MouseTracking.format_mouse_event({:wheel_up, :press, 0, 0}) == <<27, 77, 64, 32, 32>>
    end

    test "formats wheel down" do
      assert MouseTracking.format_mouse_event({:wheel_down, :press, 0, 0}) == <<27, 77, 65, 32, 32>>
    end
  end

  describe "format_focus_event/1" do
    test "formats focus in" do
      assert MouseTracking.format_focus_event(:focus_in) == "\e[I"
    end

    test "formats focus out" do
      assert MouseTracking.format_focus_event(:focus_out) == "\e[O"
    end
  end
end

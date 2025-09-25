defmodule Raxol.Terminal.ANSI.WindowEventsTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.ANSI.Window, as: WindowEvents

  describe "process_sequence/2" do
    test ~c"handles window close event" do
      assert WindowEvents.process_sequence("c", []) ==
               {:window_event, :close, %{}}
    end

    test ~c"handles window minimize event" do
      assert WindowEvents.process_sequence("m", []) ==
               {:window_event, :minimize, %{}}
    end

    test ~c"handles window maximize event" do
      assert WindowEvents.process_sequence("M", []) ==
               {:window_event, :maximize, %{}}
    end

    test ~c"handles window restore event" do
      assert WindowEvents.process_sequence("r", []) ==
               {:window_event, :restore, %{}}
    end

    test ~c"handles window focus event" do
      assert WindowEvents.process_sequence("f", []) ==
               {:window_event, :focus, %{}}
    end

    test ~c"handles window blur event" do
      assert WindowEvents.process_sequence("b", []) ==
               {:window_event, :blur, %{}}
    end

    test ~c"handles window move event" do
      assert WindowEvents.process_sequence("v", ["100", "200"]) ==
               {:window_event, :move, %{x: 100, y: 200}}
    end

    test ~c"handles window resize event" do
      assert WindowEvents.process_sequence("z", ["800", "600"]) ==
               {:window_event, :resize, %{width: 800, height: 600}}
    end

    test ~c"handles window state change event" do
      assert WindowEvents.process_sequence("s", ["maximized"]) ==
               {:window_event, :state_change, %{state: "maximized"}}
    end

    test ~c"handles window show event" do
      assert WindowEvents.process_sequence("w", []) ==
               {:window_event, :show, %{}}
    end

    test ~c"handles window hide event" do
      assert WindowEvents.process_sequence("h", []) ==
               {:window_event, :hide, %{}}
    end

    test ~c"handles window activate event" do
      assert WindowEvents.process_sequence("a", []) ==
               {:window_event, :activate, %{}}
    end

    test ~c"handles window deactivate event" do
      assert WindowEvents.process_sequence("d", []) ==
               {:window_event, :deactivate, %{}}
    end

    test ~c"handles window drag start event" do
      assert WindowEvents.process_sequence("D", ["100", "200"]) ==
               {:window_event, :drag_start, %{x: 100, y: 200}}
    end

    test ~c"handles window drag end event" do
      assert WindowEvents.process_sequence("E", ["100", "200"]) ==
               {:window_event, :drag_end, %{x: 100, y: 200}}
    end

    test ~c"handles window drop event" do
      assert WindowEvents.process_sequence("p", ["100", "200"]) ==
               {:window_event, :drop, %{x: 100, y: 200}}
    end

    test ~c"handles invalid sequence" do
      assert WindowEvents.process_sequence("x", []) == nil
    end

    test ~c"handles invalid parameters" do
      assert WindowEvents.process_sequence("v", ["invalid", "200"]) ==
               {:window_event, :move, %{x: 0, y: 200}}
    end
  end

  describe "format_event/1" do
    test ~c"formats window close event" do
      assert WindowEvents.format_event({:window_event, :close, %{}}) == "\e[?c"
    end

    test ~c"formats window minimize event" do
      assert WindowEvents.format_event({:window_event, :minimize, %{}}) ==
               "\e[?m"
    end

    test ~c"formats window maximize event" do
      assert WindowEvents.format_event({:window_event, :maximize, %{}}) ==
               "\e[?M"
    end

    test ~c"formats window restore event" do
      assert WindowEvents.format_event({:window_event, :restore, %{}}) ==
               "\e[?r"
    end

    test ~c"formats window focus event" do
      assert WindowEvents.format_event({:window_event, :focus, %{}}) == "\e[?f"
    end

    test ~c"formats window blur event" do
      assert WindowEvents.format_event({:window_event, :blur, %{}}) == "\e[?b"
    end

    test ~c"formats window move event" do
      assert WindowEvents.format_event(
               {:window_event, :move, %{x: 100, y: 200}}
             ) ==
               "\e[?v;100;200"
    end

    test ~c"formats window resize event" do
      assert WindowEvents.format_event(
               {:window_event, :resize, %{width: 800, height: 600}}
             ) ==
               "\e[?z;800;600"
    end

    test ~c"formats window state change event" do
      assert WindowEvents.format_event(
               {:window_event, :state_change, %{state: "maximized"}}
             ) ==
               "\e[?s;maximized"
    end

    test ~c"formats window show event" do
      assert WindowEvents.format_event({:window_event, :show, %{}}) == "\e[?w"
    end

    test ~c"formats window hide event" do
      assert WindowEvents.format_event({:window_event, :hide, %{}}) == "\e[?h"
    end

    test ~c"formats window activate event" do
      assert WindowEvents.format_event({:window_event, :activate, %{}}) ==
               "\e[?a"
    end

    test ~c"formats window deactivate event" do
      assert WindowEvents.format_event({:window_event, :deactivate, %{}}) ==
               "\e[?d"
    end

    test ~c"formats window drag start event" do
      assert WindowEvents.format_event(
               {:window_event, :drag_start, %{x: 100, y: 200}}
             ) ==
               "\e[?D;100;200"
    end

    test ~c"formats window drag end event" do
      assert WindowEvents.format_event(
               {:window_event, :drag_end, %{x: 100, y: 200}}
             ) ==
               "\e[?E;100;200"
    end

    test ~c"formats window drop event" do
      assert WindowEvents.format_event(
               {:window_event, :drop, %{x: 100, y: 200}}
             ) ==
               "\e[?p;100;200"
    end

    test ~c"handles unknown event" do
      assert WindowEvents.format_event({:window_event, :unknown, %{}}) == ""
    end
  end

  describe "enable_window_events/0" do
    test ~c"returns enable sequence" do
      assert WindowEvents.enable_window_events() == "\e[?63h"
    end
  end

  describe "disable_window_events/0" do
    test ~c"returns disable sequence" do
      assert WindowEvents.disable_window_events() == "\e[?63l"
    end
  end
end

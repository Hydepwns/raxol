defmodule Raxol.Terminal.ANSI.WindowEventsTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.ANSI.WindowEvents

  describe "process_sequence/2" do
    test 'handles window close event' do
      assert WindowEvents.process_sequence("c", []) ==
               {:window_event, :close, %{}}
    end

    test 'handles window minimize event' do
      assert WindowEvents.process_sequence("m", []) ==
               {:window_event, :minimize, %{}}
    end

    test 'handles window maximize event' do
      assert WindowEvents.process_sequence("M", []) ==
               {:window_event, :maximize, %{}}
    end

    test 'handles window restore event' do
      assert WindowEvents.process_sequence("r", []) ==
               {:window_event, :restore, %{}}
    end

    test 'handles window focus event' do
      assert WindowEvents.process_sequence("f", []) ==
               {:window_event, :focus, %{}}
    end

    test 'handles window blur event' do
      assert WindowEvents.process_sequence("b", []) ==
               {:window_event, :blur, %{}}
    end

    test 'handles window move event' do
      assert WindowEvents.process_sequence("v", ["100", "200"]) ==
               {:window_event, :move, %{x: 100, y: 200}}
    end

    test 'handles window resize event' do
      assert WindowEvents.process_sequence("z", ["800", "600"]) ==
               {:window_event, :resize, %{width: 800, height: 600}}
    end

    test 'handles window state change event' do
      assert WindowEvents.process_sequence("s", ["maximized"]) ==
               {:window_event, :state_change, %{state: "maximized"}}
    end

    test 'handles window show event' do
      assert WindowEvents.process_sequence("w", []) ==
               {:window_event, :show, %{}}
    end

    test 'handles window hide event' do
      assert WindowEvents.process_sequence("h", []) ==
               {:window_event, :hide, %{}}
    end

    test 'handles window activate event' do
      assert WindowEvents.process_sequence("a", []) ==
               {:window_event, :activate, %{}}
    end

    test 'handles window deactivate event' do
      assert WindowEvents.process_sequence("d", []) ==
               {:window_event, :deactivate, %{}}
    end

    test 'handles window drag start event' do
      assert WindowEvents.process_sequence("D", ["100", "200"]) ==
               {:window_event, :drag_start, %{x: 100, y: 200}}
    end

    test 'handles window drag end event' do
      assert WindowEvents.process_sequence("E", ["100", "200"]) ==
               {:window_event, :drag_end, %{x: 100, y: 200}}
    end

    test 'handles window drop event' do
      assert WindowEvents.process_sequence("p", ["100", "200"]) ==
               {:window_event, :drop, %{x: 100, y: 200}}
    end

    test 'handles invalid sequence' do
      assert WindowEvents.process_sequence("x", []) == nil
    end

    test 'handles invalid parameters' do
      assert WindowEvents.process_sequence("v", ["invalid", "200"]) ==
               {:window_event, :move, %{x: 0, y: 200}}
    end
  end

  describe "format_event/1" do
    test 'formats window close event' do
      assert WindowEvents.format_event({:window_event, :close, %{}}) == "\e[?c"
    end

    test 'formats window minimize event' do
      assert WindowEvents.format_event({:window_event, :minimize, %{}}) ==
               "\e[?m"
    end

    test 'formats window maximize event' do
      assert WindowEvents.format_event({:window_event, :maximize, %{}}) ==
               "\e[?M"
    end

    test 'formats window restore event' do
      assert WindowEvents.format_event({:window_event, :restore, %{}}) ==
               "\e[?r"
    end

    test 'formats window focus event' do
      assert WindowEvents.format_event({:window_event, :focus, %{}}) == "\e[?f"
    end

    test 'formats window blur event' do
      assert WindowEvents.format_event({:window_event, :blur, %{}}) == "\e[?b"
    end

    test 'formats window move event' do
      assert WindowEvents.format_event(
               {:window_event, :move, %{x: 100, y: 200}}
             ) ==
               "\e[?v;100;200"
    end

    test 'formats window resize event' do
      assert WindowEvents.format_event(
               {:window_event, :resize, %{width: 800, height: 600}}
             ) ==
               "\e[?z;800;600"
    end

    test 'formats window state change event' do
      assert WindowEvents.format_event(
               {:window_event, :state_change, %{state: "maximized"}}
             ) ==
               "\e[?s;maximized"
    end

    test 'formats window show event' do
      assert WindowEvents.format_event({:window_event, :show, %{}}) == "\e[?w"
    end

    test 'formats window hide event' do
      assert WindowEvents.format_event({:window_event, :hide, %{}}) == "\e[?h"
    end

    test 'formats window activate event' do
      assert WindowEvents.format_event({:window_event, :activate, %{}}) ==
               "\e[?a"
    end

    test 'formats window deactivate event' do
      assert WindowEvents.format_event({:window_event, :deactivate, %{}}) ==
               "\e[?d"
    end

    test 'formats window drag start event' do
      assert WindowEvents.format_event(
               {:window_event, :drag_start, %{x: 100, y: 200}}
             ) ==
               "\e[?D;100;200"
    end

    test 'formats window drag end event' do
      assert WindowEvents.format_event(
               {:window_event, :drag_end, %{x: 100, y: 200}}
             ) ==
               "\e[?E;100;200"
    end

    test 'formats window drop event' do
      assert WindowEvents.format_event(
               {:window_event, :drop, %{x: 100, y: 200}}
             ) ==
               "\e[?p;100;200"
    end

    test 'handles unknown event' do
      assert WindowEvents.format_event({:window_event, :unknown, %{}}) == ""
    end
  end

  describe "enable_window_events/0" do
    test 'returns enable sequence' do
      assert WindowEvents.enable_window_events() == "\e[?63h"
    end
  end

  describe "disable_window_events/0" do
    test 'returns disable sequence' do
      assert WindowEvents.disable_window_events() == "\e[?63l"
    end
  end
end

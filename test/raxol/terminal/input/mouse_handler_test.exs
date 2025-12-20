defmodule Raxol.Terminal.Input.MouseHandlerTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Input.MouseHandler

  describe "parse_mouse_event/1 - SGR protocol" do
    test "parses left button press" do
      assert {:ok, event} = MouseHandler.parse_mouse_event("\e[<0;10;20M")
      assert event.type == :press
      assert event.button == :left
      assert event.x == 9  # 0-based
      assert event.y == 19  # 0-based
      assert event.protocol == :sgr
    end

    test "parses left button release" do
      assert {:ok, event} = MouseHandler.parse_mouse_event("\e[<0;10;20m")
      assert event.type == :release
      assert event.button == :left
    end

    test "parses middle button press" do
      assert {:ok, event} = MouseHandler.parse_mouse_event("\e[<1;15;25M")
      assert event.button == :middle
      assert event.x == 14
      assert event.y == 24
    end

    test "parses right button press" do
      assert {:ok, event} = MouseHandler.parse_mouse_event("\e[<2;30;40M")
      assert event.button == :right
    end

    test "parses wheel up event" do
      assert {:ok, event} = MouseHandler.parse_mouse_event("\e[<64;10;20M")
      assert event.type == :scroll
      assert event.button == :wheel_up
    end

    test "parses wheel down event" do
      assert {:ok, event} = MouseHandler.parse_mouse_event("\e[<65;10;20M")
      assert event.type == :scroll
      assert event.button == :wheel_down
    end

    test "parses button with shift modifier" do
      assert {:ok, event} = MouseHandler.parse_mouse_event("\e[<4;10;20M")
      assert event.button == :left
      assert event.modifiers.shift == true
      assert event.modifiers.alt == false
      assert event.modifiers.ctrl == false
    end

    test "parses button with ctrl modifier" do
      assert {:ok, event} = MouseHandler.parse_mouse_event("\e[<16;10;20M")
      assert event.button == :left
      assert event.modifiers.ctrl == true
    end

    test "parses button with alt modifier" do
      assert {:ok, event} = MouseHandler.parse_mouse_event("\e[<8;10;20M")
      assert event.button == :left
      assert event.modifiers.alt == true
    end

    test "parses button with multiple modifiers" do
      # Shift + Alt = 4 + 8 = 12
      assert {:ok, event} = MouseHandler.parse_mouse_event("\e[<12;10;20M")
      assert event.button == :left
      assert event.modifiers.shift == true
      assert event.modifiers.alt == true
      assert event.modifiers.ctrl == false
    end

    test "handles large coordinates" do
      assert {:ok, event} = MouseHandler.parse_mouse_event("\e[<0;1000;2000M")
      assert event.x == 999
      assert event.y == 1999
    end
  end

  describe "parse_mouse_event/1 - X10/X11 protocol" do
    test "parses left button press" do
      # Button 0, X=10 (33+10), Y=20 (33+20) = !-5
      sequence = "\e[M !-"
      assert {:ok, event} = MouseHandler.parse_mouse_event(sequence)
      assert event.type == :press
      assert event.button == :left
      assert event.x == 0
      assert event.y == 12
      assert event.protocol == :x10
    end

    test "parses middle button press" do
      # Button 1 (32+1=33='!'), X=10 (33+10=43='+'), Y=20 (33+20=53='5')
      sequence = "\e[M!+5"
      assert {:ok, event} = MouseHandler.parse_mouse_event(sequence)
      assert event.button == :middle
    end

    test "parses button release in X11 mode" do
      # Button release (3+32=35='#')
      sequence = "\e[M#+5"
      assert {:ok, event} = MouseHandler.parse_mouse_event(sequence)
      assert event.type == :release
      assert event.button == :release
    end

    test "parses motion event" do
      # Motion bit set (32+32=64='@')
      sequence = "\e[M@+5"
      assert {:ok, event} = MouseHandler.parse_mouse_event(sequence)
      assert event.type == :move
      assert event.button == nil
    end
  end

  describe "parse_mouse_event/1 - URXVT protocol" do
    test "parses basic click" do
      assert {:ok, event} = MouseHandler.parse_mouse_event("\e[32;10;20M")
      assert event.button == :left
      assert event.x == 9
      assert event.y == 19
      assert event.protocol == :urxvt
    end

    test "parses with modifiers" do
      assert {:ok, event} = MouseHandler.parse_mouse_event("\e[36;10;20M")
      assert event.button == :left
      assert event.modifiers.shift == true
    end
  end

  describe "parse_mouse_event/1 - error cases" do
    test "returns error for invalid sequence" do
      assert {:error, :unknown_mouse_sequence} = MouseHandler.parse_mouse_event("invalid")
    end

    test "returns error for incomplete SGR sequence" do
      assert {:error, :unknown_mouse_sequence} = MouseHandler.parse_mouse_event("\e[<0;10")
    end

    test "returns error for malformed X10 sequence" do
      assert {:error, :unknown_mouse_sequence} = MouseHandler.parse_mouse_event("\e[M")
    end
  end

  describe "enable_mouse_tracking/1" do
    test "returns X10 mode sequence" do
      assert MouseHandler.enable_mouse_tracking(:x10) == "\e[?9h"
    end

    test "returns X11 mode sequence" do
      assert MouseHandler.enable_mouse_tracking(:x11) == "\e[?1000h"
    end

    test "returns button event mode sequence" do
      assert MouseHandler.enable_mouse_tracking(:button_event) == "\e[?1002h"
    end

    test "returns any event mode sequence" do
      assert MouseHandler.enable_mouse_tracking(:any_event) == "\e[?1003h"
    end

    test "returns SGR mode sequence" do
      assert MouseHandler.enable_mouse_tracking(:sgr) == "\e[?1006h"
    end

    test "returns URXVT mode sequence" do
      assert MouseHandler.enable_mouse_tracking(:urxvt) == "\e[?1015h"
    end

    test "returns disable sequence for :off" do
      result = MouseHandler.enable_mouse_tracking(:off)
      assert String.contains?(result, "\e[?9l")
      assert String.contains?(result, "\e[?1000l")
      assert String.contains?(result, "\e[?1006l")
    end
  end

  describe "disable_mouse_tracking/0" do
    test "disables all modes" do
      result = MouseHandler.disable_mouse_tracking()
      assert String.contains?(result, "\e[?9l")
      assert String.contains?(result, "\e[?1000l")
      assert String.contains?(result, "\e[?1002l")
      assert String.contains?(result, "\e[?1003l")
      assert String.contains?(result, "\e[?1006l")
      assert String.contains?(result, "\e[?1015l")
    end
  end

  describe "handle_event/2 - state tracking" do
    setup do
      {:ok, state: MouseHandler.new()}
    end

    test "tracks button press", %{state: state} do
      event = %{
        type: :press,
        button: :left,
        x: 10,
        y: 20,
        modifiers: %{},
        protocol: :sgr,
        timestamp: System.monotonic_time(:millisecond)
      }

      {new_state, _actions} = MouseHandler.handle_event(state, event)

      assert MapSet.member?(new_state.pressed_buttons, :left)
      assert new_state.last_position == {10, 20}
      assert new_state.drag_start == {10, 20}
    end

    test "tracks button release", %{state: state} do
      # First press
      press_event = %{
        type: :press,
        button: :left,
        x: 10,
        y: 20,
        modifiers: %{},
        protocol: :sgr,
        timestamp: System.monotonic_time(:millisecond)
      }

      {state_after_press, _} = MouseHandler.handle_event(state, press_event)

      # Then release
      release_event = %{press_event | type: :release}
      {state_after_release, _} = MouseHandler.handle_event(state_after_press, release_event)

      refute MapSet.member?(state_after_release.pressed_buttons, :left)
      assert state_after_release.drag_start == nil
    end

    test "detects double click", %{state: state} do
      event1 = %{
        type: :press,
        button: :left,
        x: 10,
        y: 20,
        modifiers: %{},
        protocol: :sgr,
        timestamp: System.monotonic_time(:millisecond)
      }

      {state1, _} = MouseHandler.handle_event(state, event1)
      assert state1.click_count == 1

      # Second click within threshold
      event2 = %{event1 | timestamp: event1.timestamp + 100}
      {state2, actions} = MouseHandler.handle_event(state1, event2)

      assert state2.click_count == 2
      assert Enum.any?(actions, fn
        {:double_click, _} -> true
        _ -> false
      end)
    end

    test "detects triple click", %{state: state} do
      event1 = %{
        type: :press,
        button: :left,
        x: 10,
        y: 20,
        modifiers: %{},
        protocol: :sgr,
        timestamp: System.monotonic_time(:millisecond)
      }

      {state1, _} = MouseHandler.handle_event(state, event1)

      event2 = %{event1 | timestamp: event1.timestamp + 100}
      {state2, _} = MouseHandler.handle_event(state1, event2)

      event3 = %{event1 | timestamp: event1.timestamp + 200}
      {state3, actions} = MouseHandler.handle_event(state2, event3)

      assert state3.click_count == 3
      assert Enum.any?(actions, fn
        {:triple_click, _} -> true
        _ -> false
      end)
    end

    test "resets click count after threshold", %{state: state} do
      event1 = %{
        type: :press,
        button: :left,
        x: 10,
        y: 20,
        modifiers: %{},
        protocol: :sgr,
        timestamp: System.monotonic_time(:millisecond)
      }

      {state1, _} = MouseHandler.handle_event(state, event1)

      # Click after threshold
      event2 = %{event1 | timestamp: event1.timestamp + 1000}
      {state2, _} = MouseHandler.handle_event(state1, event2)

      assert state2.click_count == 1
    end

    test "detects drag operation", %{state: state} do
      press_event = %{
        type: :press,
        button: :left,
        x: 10,
        y: 20,
        modifiers: %{},
        protocol: :sgr,
        timestamp: System.monotonic_time(:millisecond)
      }

      {state1, _} = MouseHandler.handle_event(state, press_event)

      move_event = %{press_event | type: :move, x: 15, y: 25}
      {_state2, actions} = MouseHandler.handle_event(state1, move_event)

      assert {:drag, %{start: {10, 20}, current: {15, 25}}} in actions
    end

    test "detects button chord", %{state: state} do
      left_press = %{
        type: :press,
        button: :left,
        x: 10,
        y: 20,
        modifiers: %{},
        protocol: :sgr,
        timestamp: System.monotonic_time(:millisecond)
      }

      {state1, _} = MouseHandler.handle_event(state, left_press)

      right_press = %{left_press | button: :right}
      {_state2, actions} = MouseHandler.handle_event(state1, right_press)

      chord_action = Enum.find(actions, fn
        {:chord, _} -> true
        _ -> false
      end)

      assert chord_action != nil
      {:chord, buttons} = chord_action
      assert :left in buttons
      assert :right in buttons
    end
  end

  describe "set_mouse_mode/2" do
    test "generates enable sequences" do
      assert MouseHandler.set_mouse_mode(:click_only, true) == "\e[?9h"
      assert MouseHandler.set_mouse_mode(:click_drag, true) == "\e[?1000h"
      assert MouseHandler.set_mouse_mode(:button_events, true) == "\e[?1002h"
      assert MouseHandler.set_mouse_mode(:all_events, true) == "\e[?1003h"
      assert MouseHandler.set_mouse_mode(:sgr_extended, true) == "\e[?1006h"
      assert MouseHandler.set_mouse_mode(:urxvt_extended, true) == "\e[?1015h"
      assert MouseHandler.set_mouse_mode(:focus_events, true) == "\e[?1004h"
    end

    test "generates disable sequences" do
      assert MouseHandler.set_mouse_mode(:click_only, false) == "\e[?9l"
      assert MouseHandler.set_mouse_mode(:click_drag, false) == "\e[?1000l"
    end

    test "returns empty string for unknown mode" do
      assert MouseHandler.set_mouse_mode(:unknown, true) == ""
    end
  end

  describe "detect_best_mode/0" do
    test "detects SGR for modern terminals" do
      System.put_env("TERM", "xterm-256color")
      assert MouseHandler.detect_best_mode() == :sgr
    end

    test "detects URXVT for rxvt terminals" do
      System.put_env("TERM", "rxvt-unicode")
      System.delete_env("TERM_PROGRAM")
      assert MouseHandler.detect_best_mode() == :urxvt
    end

    test "detects X11 for basic xterm" do
      System.put_env("TERM", "xterm")
      System.delete_env("TERM_PROGRAM")
      assert MouseHandler.detect_best_mode() == :x11
    end

    test "falls back to X10 for unknown terminals" do
      System.put_env("TERM", "dumb")
      System.delete_env("TERM_PROGRAM")
      assert MouseHandler.detect_best_mode() == :x10
    end

    test "detects SGR for known terminal programs" do
      # Save original env vars
      original_term = System.get_env("TERM")
      original_term_program = System.get_env("TERM_PROGRAM")

      # Set test environment
      System.put_env("TERM", "xterm")  # Clear any rxvt values
      System.put_env("TERM_PROGRAM", "iTerm.app")

      assert MouseHandler.detect_best_mode() == :sgr

      # Restore original env vars
      if original_term, do: System.put_env("TERM", original_term), else: System.delete_env("TERM")
      if original_term_program do
        System.put_env("TERM_PROGRAM", original_term_program)
      else
        System.delete_env("TERM_PROGRAM")
      end
    end
  end
end

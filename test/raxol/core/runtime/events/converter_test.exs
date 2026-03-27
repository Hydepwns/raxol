defmodule Raxol.Core.Runtime.Events.ConverterTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Runtime.Events.Converter
  alias Raxol.Core.Events.Event

  describe "convert_termbox_event/6 - key events" do
    test "converts special key event (ch=0) with no modifiers" do
      event = Converter.convert_termbox_event(:key, 0, 65, 0)

      assert %Event{type: :key, data: data} = event
      assert data.key == 65
      assert data.modifiers == [ctrl: false, alt: false, shift: false]
    end

    test "converts character key event (ch non-zero)" do
      event = Converter.convert_termbox_event(:key, 0, 0, ?a)

      assert %Event{type: :key, data: data} = event
      assert data.key == ?a
      assert data.key_code == 0
      assert data.modifiers == [ctrl: false, alt: false, shift: false]
    end

    test "extracts ctrl modifier from bitmask" do
      event = Converter.convert_termbox_event(:key, 1, 0, ?c)

      assert %Event{type: :key, data: data} = event
      assert data.modifiers[:ctrl] == true
      assert data.modifiers[:alt] == false
      assert data.modifiers[:shift] == false
    end

    test "extracts alt modifier from bitmask" do
      event = Converter.convert_termbox_event(:key, 2, 0, ?x)

      assert %Event{type: :key, data: data} = event
      assert data.modifiers[:ctrl] == false
      assert data.modifiers[:alt] == true
    end

    test "extracts shift modifier from bitmask" do
      event = Converter.convert_termbox_event(:key, 4, 0, ?A)

      assert %Event{type: :key, data: data} = event
      assert data.modifiers[:shift] == true
    end

    test "extracts combined modifiers (ctrl+alt = 3)" do
      event = Converter.convert_termbox_event(:key, 3, 0, ?a)

      assert %Event{type: :key, data: data} = event
      assert data.modifiers[:ctrl] == true
      assert data.modifiers[:alt] == true
      assert data.modifiers[:shift] == false
    end

    test "extracts all modifiers (ctrl+alt+shift = 7)" do
      event = Converter.convert_termbox_event(:key, 7, 42, 0)

      assert %Event{type: :key, data: data} = event
      assert data.modifiers[:ctrl] == true
      assert data.modifiers[:alt] == true
      assert data.modifiers[:shift] == true
    end
  end

  describe "convert_termbox_event/6 - resize events" do
    test "converts resize event with width and height" do
      event = Converter.convert_termbox_event(:resize, 0, 0, 0, 120, 40)

      assert %Event{type: :resize, data: data} = event
      assert data.width == 120
      assert data.height == 40
    end
  end

  describe "convert_termbox_event/6 - mouse events" do
    test "converts left button press" do
      event = Converter.convert_termbox_event(:mouse, 0, 1, 0, 10, 5)

      assert %Event{type: :mouse, data: data} = event
      assert data.button == :left
      assert data.action == :press
      assert data.x == 10
      assert data.y == 5
    end

    test "converts middle button release" do
      event = Converter.convert_termbox_event(:mouse, 0, 2, 1, 20, 15)

      assert %Event{type: :mouse, data: data} = event
      assert data.button == :middle
      assert data.action == :release
    end

    test "converts right button drag" do
      event = Converter.convert_termbox_event(:mouse, 0, 3, 2, 30, 25)

      assert %Event{type: :mouse, data: data} = event
      assert data.button == :right
      assert data.action == :drag
    end

    test "unknown button maps to :unknown" do
      event = Converter.convert_termbox_event(:mouse, 0, 99, 0, 0, 0)

      assert %Event{type: :mouse, data: data} = event
      assert data.button == :unknown
    end

    test "unknown action maps to :unknown" do
      event = Converter.convert_termbox_event(:mouse, 0, 1, 99, 0, 0)

      assert %Event{type: :mouse, data: data} = event
      assert data.action == :unknown
    end

    test "mouse event includes modifiers" do
      event = Converter.convert_termbox_event(:mouse, 1, 1, 0, 5, 5)

      assert %Event{type: :mouse, data: data} = event
      assert data.modifiers[:ctrl] == true
    end
  end

  describe "convert_termbox_event/6 - unknown events" do
    test "passes through unknown event type with raw data" do
      event = Converter.convert_termbox_event(:custom, 0, 0, 0)

      assert %Event{data: data} = event
      assert data.raw_event == {:custom, 0, 0, 0, nil, nil}
    end
  end

  describe "convert_vscode_event/1" do
    test "converts keydown event" do
      event = Converter.convert_vscode_event(%{type: "keydown", key: "a", modifiers: []})

      assert %Event{type: :key, data: data} = event
      assert data.key == ?a
      assert data.raw_key == "a"
    end

    test "converts named key via vscode key map" do
      event = Converter.convert_vscode_event(%{type: "keydown", key: "Enter", modifiers: []})

      assert %Event{type: :key, data: data} = event
      assert data.key == :enter
      assert data.raw_key == "Enter"
    end

    test "converts arrow keys" do
      event = Converter.convert_vscode_event(%{type: "keydown", key: "ArrowUp", modifiers: []})

      assert %Event{type: :key, data: data} = event
      assert data.key == :arrow_up
    end

    test "converts resize event" do
      event = Converter.convert_vscode_event(%{type: "resize", width: 100, height: 50})

      assert %Event{type: :resize, data: data} = event
      assert data.width == 100
      assert data.height == 50
    end

    test "converts mouse event" do
      event =
        Converter.convert_vscode_event(%{
          type: "mouse",
          action: "down",
          x: 10,
          y: 20,
          button: "left"
        })

      assert %Event{type: :mouse, data: data} = event
      assert data.button == :left
      assert data.action == :press
      assert data.x == 10
      assert data.y == 20
    end

    test "converts text event" do
      event = Converter.convert_vscode_event(%{type: "text", content: "hello"})

      assert %Event{type: :text, data: data} = event
      assert data.text == "hello"
    end

    test "converts focus event" do
      event = Converter.convert_vscode_event(%{type: "focus", focused: true})

      assert %Event{type: :focus, data: data} = event
      assert data.focused == true
    end

    test "converts quit event" do
      event = Converter.convert_vscode_event(%{type: "quit"})

      assert %Event{type: :quit} = event
    end

    test "unknown vscode event type returns :unknown" do
      event = Converter.convert_vscode_event(%{type: "custom_event"})

      assert %Event{type: :unknown, data: data} = event
      assert data.raw_event.type == "custom_event"
    end

    test "keydown with modifiers" do
      event =
        Converter.convert_vscode_event(%{
          type: "keydown",
          key: "c",
          modifiers: ["ctrl", "shift"]
        })

      assert %Event{type: :key, data: data} = event
      # Single char "c" becomes char code 99
      assert data.key == ?c
      assert data.raw_key == "c"
      assert data.modifiers[:ctrl] == true
      assert data.modifiers[:shift] == true
      assert data.modifiers[:alt] == false
    end

    test "keydown with alternative modifier names" do
      event =
        Converter.convert_vscode_event(%{
          type: "keydown",
          key: "a",
          modifiers: ["control", "option", "command"]
        })

      assert %Event{type: :key, data: data} = event
      assert data.modifiers[:ctrl] == true
      assert data.modifiers[:alt] == true
      assert data.modifiers[:meta] == true
    end

    test "mouse with unknown button returns :unknown" do
      event =
        Converter.convert_vscode_event(%{
          type: "mouse",
          action: "down",
          x: 0,
          y: 0,
          button: "extra"
        })

      assert %Event{type: :mouse, data: data} = event
      assert data.button == :unknown
    end

    test "mouse move action" do
      event =
        Converter.convert_vscode_event(%{
          type: "mouse",
          action: "move",
          x: 5,
          y: 10,
          button: "left"
        })

      assert %Event{type: :mouse, data: data} = event
      assert data.action == :move
    end
  end

  describe "normalize_event/1" do
    test "passes through existing Event struct unchanged" do
      original = Event.new(:key, %{key: ?a})
      assert Converter.normalize_event(original) == original
    end

    test "normalizes 6-tuple as termbox event" do
      event = Converter.normalize_event({:key, 0, 0, ?z, nil, nil})

      assert %Event{type: :key, data: data} = event
      assert data.key == ?z
    end

    test "normalizes map with :type key as vscode event" do
      event = Converter.normalize_event(%{type: "quit"})

      assert %Event{type: :quit} = event
    end

    test "normalizes {:key, key} tuple" do
      event = Converter.normalize_event({:key, :enter})

      assert %Event{type: :key, data: data} = event
      assert data.key == :enter
    end

    test "normalizes {:mouse, x, y, button} tuple" do
      event = Converter.normalize_event({:mouse, 10, 20, :left})

      assert %Event{type: :mouse, data: data} = event
      assert data.x == 10
      assert data.y == 20
      assert data.button == :left
    end

    test "normalizes {:text, text} tuple" do
      event = Converter.normalize_event({:text, "hello world"})

      assert %Event{type: :text, data: data} = event
      assert data.text == "hello world"
    end

    test "wraps unrecognized values as :unknown" do
      event = Converter.normalize_event(:something_random)

      assert %Event{type: :unknown, data: data} = event
      assert data.raw_event == :something_random
    end

    test "wraps unrecognized tuple as :unknown" do
      event = Converter.normalize_event({:weird, 1, 2})

      assert %Event{type: :unknown, data: data} = event
      assert data.raw_event == {:weird, 1, 2}
    end
  end
end

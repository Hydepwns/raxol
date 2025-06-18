defmodule Raxol.Terminal.Input.ProcessorTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Input.{
    Processor,
    Event,
    Event.MouseEvent,
    Event.KeyEvent
  }

  describe "input processing" do
    test 'processes regular character input' do
      assert {:ok, %KeyEvent{key: "a", modifiers: []}} =
               Processor.process_input("a")
    end

    test 'processes escape sequences' do
      assert {:ok, %KeyEvent{key: "A", modifiers: [:shift]}} =
               Processor.process_input("\e[2A")
    end

    test 'handles invalid input' do
      assert {:error, :invalid_input} = Processor.process_input("")
    end
  end

  describe "mouse events" do
    test 'parses mouse press event' do
      sequence = "\e[0;0;10;20M"
      assert {:ok, event} = Processor.parse_mouse_event(sequence)

      assert %MouseEvent{
               button: :left,
               action: :press,
               x: 10,
               y: 20,
               modifiers: []
             } = event
    end

    test 'parses mouse release event' do
      sequence = "\e[3;0;10;20M"
      assert {:ok, event} = Processor.parse_mouse_event(sequence)

      assert %MouseEvent{
               button: :left,
               action: :release,
               x: 10,
               y: 20,
               modifiers: []
             } = event
    end

    test 'parses mouse drag event' do
      sequence = "\e[32;0;10;20M"
      assert {:ok, event} = Processor.parse_mouse_event(sequence)

      assert %MouseEvent{
               button: :left,
               action: :drag,
               x: 10,
               y: 20,
               modifiers: []
             } = event
    end

    test 'parses mouse move event' do
      sequence = "\e[35;0;10;20M"
      assert {:ok, event} = Processor.parse_mouse_event(sequence)

      assert %MouseEvent{
               button: :left,
               action: :move,
               x: 10,
               y: 20,
               modifiers: []
             } = event
    end

    test 'parses mouse events with modifiers' do
      sequence = "\e[0;0;10;20;2;3M"
      assert {:ok, event} = Processor.parse_mouse_event(sequence)

      assert %MouseEvent{
               button: :left,
               action: :press,
               x: 10,
               y: 20,
               modifiers: [:shift, :alt]
             } = event
    end

    test 'handles invalid mouse events' do
      assert {:error, :invalid_mouse_event} =
               Processor.parse_mouse_event("invalid")

      assert {:error, :invalid_mouse_sequence} =
               Processor.parse_mouse_event("\e[invalid")
    end
  end

  describe "key events" do
    test 'parses regular key press' do
      assert {:ok, %KeyEvent{key: "a", modifiers: []}} =
               Processor.parse_key_event("a")
    end

    test 'parses function keys' do
      assert {:ok, %KeyEvent{key: "A", modifiers: []}} =
               Processor.parse_key_event("\e[A")
    end

    test 'parses keys with modifiers' do
      assert {:ok, %KeyEvent{key: "A", modifiers: [:shift, :ctrl]}} =
               Processor.parse_key_event("\e[2;5A")
    end

    test 'handles invalid key events' do
      assert {:error, :invalid_key_event} = Processor.parse_key_event("")

      assert {:error, :invalid_key_sequence} =
               Processor.parse_key_event("\e[invalid")
    end
  end

  describe "event formatting" do
    test 'formats mouse events' do
      event = %MouseEvent{
        button: :left,
        action: :press,
        x: 10,
        y: 20,
        modifiers: [:shift, :ctrl]
      }

      expected = "\e[0;0;10;20;2;5M"
      assert expected == Processor.format_mouse_event(event)
    end

    test 'formats key events' do
      event = %KeyEvent{
        key: "A",
        modifiers: [:shift, :ctrl]
      }

      expected = "\e[2;5A"
      assert expected == Processor.format_key_event(event)
    end

    test 'formats regular key events without escape sequence' do
      event = %KeyEvent{
        key: "a",
        modifiers: []
      }

      assert "a" == Processor.format_key_event(event)
    end
  end
end

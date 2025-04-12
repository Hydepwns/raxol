defmodule Raxol.Terminal.InputTest do
  use ExUnit.Case
  alias Raxol.Terminal.Input

  describe "new/1" do
    test "creates a new input processor with default options" do
      processor = Input.new()
      assert processor.mode == :normal
      assert processor.buffer == ""
      assert processor.mouse_enabled == false
      assert processor.bracketed_paste == false
    end

    test "creates a new input processor with custom options" do
      processor = Input.new(mode: :app, mouse_enabled: true)
      assert processor.mode == :app
      assert processor.mouse_enabled == true
    end
  end

  describe "process_input/2" do
    test "processes normal text input" do
      processor = Input.new()
      {events, processor} = Input.process_input("Hello", processor)

      assert length(events) == 5
      assert Enum.all?(events, fn {:key, char} -> char in 'Hello' end)
    end

    test "processes escape sequences" do
      processor = Input.new()
      {events, processor} = Input.process_input("\e[10;5H", processor)

      assert length(events) == 1
      assert hd(events) == {:cursor_move, 10, 5}
    end

    test "processes mouse events" do
      processor = Input.new(mode: :mouse)
      {events, processor} = Input.process_input("\e[M aaa", processor)

      assert length(events) == 1
      assert hd(events) == {:mouse_event, 0, 0, 0}
    end

    test "processes bracketed paste" do
      processor = Input.new(mode: :paste)

      {events, processor} =
        Input.process_input("\e[200~Hello\e[201~", processor)

      assert length(events) == 3
      assert Enum.at(events, 0) == {:paste_start}
      assert Enum.at(events, 1) == {:key, ?H}
      assert Enum.at(events, 2) == {:paste_end}
    end

    test "buffers incomplete sequences" do
      processor = Input.new()
      {events, processor} = Input.process_input("\e[", processor)

      assert length(events) == 0
      assert processor.buffer == "\e["
    end

    test "flushes buffer after timeout" do
      processor = %{Input.new() | last_event: 0}
      {events, processor} = Input.process_input("Hello", processor)

      assert length(events) == 5
      assert processor.buffer == ""
    end
  end

  describe "mode management" do
    test "sets input mode" do
      processor = Input.new()
      processor = Input.set_mode(processor, :app)
      assert processor.mode == :app
    end

    test "sets mouse enabled state" do
      processor = Input.new()
      processor = Input.set_mouse_enabled(processor, true)
      assert processor.mouse_enabled == true
    end

    test "sets bracketed paste mode" do
      processor = Input.new()
      processor = Input.set_bracketed_paste(processor, true)
      assert processor.bracketed_paste == true
    end
  end

  describe "event filtering" do
    test "filters events using custom filter" do
      processor = Input.new(filter: fn {:key, char} -> char != ?l end)
      {events, _processor} = Input.process_input("Hello", processor)

      assert length(events) == 4
      assert Enum.all?(events, fn {:key, char} -> char != ?l end)
    end

    test "uses default filter when none specified" do
      processor = Input.new()
      {events, _processor} = Input.process_input("Hello", processor)

      assert length(events) == 5
    end
  end

  describe "special sequences" do
    test "processes cursor movement sequences" do
      processor = Input.new()

      {events, _processor} =
        Input.process_input("\e[10;5H\e[3A\e[2B\e[4C\e[1D", processor)

      assert length(events) == 5
      assert Enum.at(events, 0) == {:cursor_move, 10, 5}
      assert Enum.at(events, 1) == {:cursor_up, 3}
      assert Enum.at(events, 2) == {:cursor_down, 2}
      assert Enum.at(events, 3) == {:cursor_forward, 4}
      assert Enum.at(events, 4) == {:cursor_backward, 1}
    end

    test "processes text attribute sequences" do
      processor = Input.new()

      {events, _processor} =
        Input.process_input("\e[1;4;5;7m\e[31;42m", processor)

      assert length(events) == 6
      assert {:set_attribute, :bold} in events
      assert {:set_attribute, :underline} in events
      assert {:set_attribute, :blink} in events
      assert {:set_attribute, :reverse} in events
      assert {:set_foreground, :red} in events
      assert {:set_background, :green} in events
    end

    test "processes cursor visibility sequences" do
      processor = Input.new()
      {events, _processor} = Input.process_input("\e[?25l\e[?25h", processor)

      assert length(events) == 2
      assert Enum.at(events, 0) == {:hide_cursor}
      assert Enum.at(events, 1) == {:show_cursor}
    end

    test "processes cursor save/restore sequences" do
      processor = Input.new()
      {events, _processor} = Input.process_input("\e[s\e[u", processor)

      assert length(events) == 2
      assert Enum.at(events, 0) == {:save_cursor}
      assert Enum.at(events, 1) == {:restore_cursor}
    end
  end

  describe "process_input/1" do
    test "processes regular characters" do
      events = Input.process_input("a")
      assert events == [{:key, ?a, []}]
    end

    test "processes arrow keys" do
      events = Input.process_input("\e[A")
      assert events == [{:key, :up, []}]

      events = Input.process_input("\e[B")
      assert events == [{:key, :down, []}]

      events = Input.process_input("\e[C")
      assert events == [{:key, :right, []}]

      events = Input.process_input("\e[D")
      assert events == [{:key, :left, []}]
    end

    test "processes function keys" do
      events = Input.process_input("\eOP")
      assert events == [{:key, :f1, []}]

      events = Input.process_input("\eOQ")
      assert events == [{:key, :f2, []}]
    end

    test "processes mouse events" do
      events = Input.process_input("\e[1;2M")
      assert events == [{:mouse, 1, 2, :left, []}]

      events = Input.process_input("\e[1;2m")
      assert events == [{:mouse, 1, 2, :release, []}]
    end

    test "ignores unknown sequences" do
      events = Input.process_input("\e[?")
      assert events == []
    end
  end

  describe "buffer_events/2" do
    test "buffers valid events" do
      events = [
        {:key, :a, []},
        {:mouse, 1, 2, :left, []},
        {:unknown, "data"}
      ]

      buffered = Input.buffer_events(events)
      assert length(buffered) == 2
      assert {:key, :a, []} in buffered
      assert {:mouse, 1, 2, :left, []} in buffered
    end

    test "maintains event order" do
      events = [
        {:key, :a, []},
        {:key, :b, []},
        {:key, :c, []}
      ]

      buffered = Input.buffer_events(events)

      assert buffered == [
               {:key, :a, []},
               {:key, :b, []},
               {:key, :c, []}
             ]
    end
  end

  describe "validate_event/1" do
    test "validates key events" do
      assert {:ok, _} = Input.validate_event({:key, :a, []})
      assert {:ok, _} = Input.validate_event({:key, :up, [:ctrl]})
    end

    test "validates mouse events" do
      assert {:ok, _} = Input.validate_event({:mouse, 1, 2, :left, []})
      assert {:ok, _} = Input.validate_event({:mouse, 10, 20, :right, [:shift]})
    end

    test "rejects invalid events" do
      assert {:error, :invalid_event} = Input.validate_event({:key, "a", []})

      assert {:error, :invalid_event} =
               Input.validate_event({:mouse, "1", 2, :left, []})

      assert {:error, :invalid_event} = Input.validate_event({:unknown, "data"})
    end
  end
end

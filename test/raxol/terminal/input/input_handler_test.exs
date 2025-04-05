defmodule Raxol.Terminal.Input.InputHandlerTest do
  use ExUnit.Case
  alias Raxol.Terminal.Input.InputHandler

  describe "new/0" do
    test "creates a new input handler with default values" do
      handler = InputHandler.new()
      assert InputHandler.get_mode(handler) == :normal
      assert InputHandler.buffer_empty?(handler)
      assert handler.mouse_enabled == false
      assert MapSet.size(handler.mouse_buttons) == 0
      assert handler.mouse_position == {0, 0}
      assert handler.input_history == []
      assert handler.history_index == 0
    end
  end

  describe "process_keyboard/2" do
    test "processes keyboard input" do
      handler = InputHandler.new()
      handler = InputHandler.process_keyboard(handler, "a")
      assert InputHandler.get_buffer_contents(handler) == "a"
    end

    test "accumulates keyboard input" do
      handler = InputHandler.new()
      handler = handler
        |> InputHandler.process_keyboard("Hello")
        |> InputHandler.process_keyboard(" ")
        |> InputHandler.process_keyboard("World")
      
      assert InputHandler.get_buffer_contents(handler) == "Hello World"
    end
  end

  describe "process_special_key/2" do
    test "processes special key input" do
      handler = InputHandler.new()
      handler = InputHandler.process_special_key(handler, :up)
      assert InputHandler.get_buffer_contents(handler) == "\e[A"
    end

    test "accumulates special key input" do
      handler = InputHandler.new()
      handler = handler
        |> InputHandler.process_special_key(:up)
        |> InputHandler.process_special_key(:down)
      
      assert InputHandler.get_buffer_contents(handler) == "\e[A\e[B"
    end
  end

  describe "process_mouse/2" do
    test "processes mouse events when mouse is enabled" do
      handler = InputHandler.new()
      handler = InputHandler.set_mouse_enabled(handler, true)
      handler = InputHandler.process_mouse(handler, {:press, 0, 10, 20})
      
      # Mouse event encoding adds 32 to make characters printable
      # and converts to 1-based coordinates
      assert String.length(InputHandler.get_buffer_contents(handler)) > 0
      assert handler.mouse_position == {10, 20}
      assert MapSet.member?(handler.mouse_buttons, 0)
    end

    test "ignores mouse events when mouse is disabled" do
      handler = InputHandler.new()
      handler = InputHandler.process_mouse(handler, {:press, 0, 10, 20})
      
      assert InputHandler.buffer_empty?(handler)
      assert handler.mouse_position == {0, 0}
      assert MapSet.size(handler.mouse_buttons) == 0
    end

    test "tracks mouse button state" do
      handler = InputHandler.new()
      handler = InputHandler.set_mouse_enabled(handler, true)
      
      # Press button
      handler = InputHandler.process_mouse(handler, {:press, 1, 10, 20})
      assert MapSet.member?(handler.mouse_buttons, 1)
      
      # Release button
      handler = InputHandler.process_mouse(handler, {:release, 1, 10, 20})
      refute MapSet.member?(handler.mouse_buttons, 1)
    end
  end

  describe "set_mouse_enabled/2" do
    test "enables mouse event handling" do
      handler = InputHandler.new()
      handler = InputHandler.set_mouse_enabled(handler, true)
      assert handler.mouse_enabled == true
    end

    test "disables mouse event handling" do
      handler = InputHandler.new()
      handler = InputHandler.set_mouse_enabled(handler, true)
      handler = InputHandler.set_mouse_enabled(handler, false)
      assert handler.mouse_enabled == false
    end
  end

  describe "set_mode/2" do
    test "sets the input mode" do
      handler = InputHandler.new()
      handler = InputHandler.set_mode(handler, :insert)
      assert InputHandler.get_mode(handler) == :insert
    end
  end

  describe "add_to_history/1" do
    test "adds buffer contents to history" do
      handler = InputHandler.new()
      handler = InputHandler.process_keyboard(handler, "test input")
      handler = InputHandler.add_to_history(handler)
      
      assert length(handler.input_history) == 1
      assert List.first(handler.input_history) == "test input"
    end

    test "does not add empty buffer to history" do
      handler = InputHandler.new()
      handler = InputHandler.add_to_history(handler)
      
      assert length(handler.input_history) == 0
    end
  end

  describe "get_history_entry/2" do
    test "retrieves a history entry" do
      handler = InputHandler.new()
      handler = handler
        |> InputHandler.process_keyboard("first")
        |> InputHandler.add_to_history()
        |> InputHandler.clear_buffer()
        |> InputHandler.process_keyboard("second")
        |> InputHandler.add_to_history()
        |> InputHandler.clear_buffer()
      
      handler = InputHandler.get_history_entry(handler, 0)
      assert InputHandler.get_buffer_contents(handler) == "second"
      
      handler = InputHandler.get_history_entry(handler, 1)
      assert InputHandler.get_buffer_contents(handler) == "first"
    end
  end

  describe "next_history_entry/1" do
    test "moves to the next history entry" do
      handler = InputHandler.new()
      handler = handler
        |> InputHandler.process_keyboard("first")
        |> InputHandler.add_to_history()
        |> InputHandler.clear_buffer()
        |> InputHandler.process_keyboard("second")
        |> InputHandler.add_to_history()
        |> InputHandler.clear_buffer()
        |> InputHandler.get_history_entry(handler, 1)
      
      assert InputHandler.get_buffer_contents(handler) == "first"
      
      handler = InputHandler.next_history_entry(handler)
      assert InputHandler.get_buffer_contents(handler) == "second"
    end

    test "does not move beyond the last history entry" do
      handler = InputHandler.new()
      handler = handler
        |> InputHandler.process_keyboard("test")
        |> InputHandler.add_to_history()
        |> InputHandler.clear_buffer()
        |> InputHandler.get_history_entry(handler, 0)
      
      assert InputHandler.get_buffer_contents(handler) == "test"
      
      handler = InputHandler.next_history_entry(handler)
      assert InputHandler.get_buffer_contents(handler) == "test"
    end
  end

  describe "previous_history_entry/1" do
    test "moves to the previous history entry" do
      handler = InputHandler.new()
      handler = handler
        |> InputHandler.process_keyboard("first")
        |> InputHandler.add_to_history()
        |> InputHandler.clear_buffer()
        |> InputHandler.process_keyboard("second")
        |> InputHandler.add_to_history()
        |> InputHandler.clear_buffer()
        |> InputHandler.get_history_entry(handler, 0)
      
      assert InputHandler.get_buffer_contents(handler) == "second"
      
      handler = InputHandler.previous_history_entry(handler)
      assert InputHandler.get_buffer_contents(handler) == "first"
    end

    test "does not move before the first history entry" do
      handler = InputHandler.new()
      handler = handler
        |> InputHandler.process_keyboard("test")
        |> InputHandler.add_to_history()
        |> InputHandler.clear_buffer()
        |> InputHandler.get_history_entry(handler, 0)
      
      assert InputHandler.get_buffer_contents(handler) == "test"
      
      handler = InputHandler.previous_history_entry(handler)
      assert InputHandler.get_buffer_contents(handler) == "test"
    end
  end

  describe "clear_buffer/1" do
    test "clears the input buffer" do
      handler = InputHandler.new()
      handler = InputHandler.process_keyboard(handler, "test input")
      assert InputHandler.get_buffer_contents(handler) == "test input"
      
      handler = InputHandler.clear_buffer(handler)
      assert InputHandler.buffer_empty?(handler)
    end
  end
end 
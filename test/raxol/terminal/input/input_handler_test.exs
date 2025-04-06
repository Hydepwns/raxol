defmodule Raxol.Terminal.Input.InputHandlerTest do
  use ExUnit.Case
  alias Raxol.Terminal.Input.InputHandler

  describe "new/0" do
    test "creates a new input handler with default values" do
      handler = InputHandler.new()
      assert handler.mode == :normal
      assert handler.mouse_enabled == false
      assert handler.mouse_buttons == MapSet.new()
      assert handler.mouse_position == {0, 0}
      assert handler.input_history == []
      assert handler.history_index == 0
      assert handler.modifier_state.ctrl == false
      assert handler.modifier_state.alt == false
      assert handler.modifier_state.shift == false
      assert handler.modifier_state.meta == false
    end
  end

  describe "process_keyboard/2" do
    test "processes regular keyboard input" do
      handler = InputHandler.new()
      handler = InputHandler.process_keyboard(handler, "a")
      assert InputHandler.get_buffer_contents(handler) == "a"
    end

    test "processes multiple keyboard inputs" do
      handler = InputHandler.new()
      handler = handler
        |> InputHandler.process_keyboard("h")
        |> InputHandler.process_keyboard("e")
        |> InputHandler.process_keyboard("l")
        |> InputHandler.process_keyboard("l")
        |> InputHandler.process_keyboard("o")
      assert InputHandler.get_buffer_contents(handler) == "hello"
    end
  end

  describe "process_special_key/2" do
    test "processes arrow keys" do
      handler = InputHandler.new()
      handler = InputHandler.process_special_key(handler, :up)
      assert InputHandler.get_buffer_contents(handler) == "\e[A"
    end

    test "processes navigation keys" do
      handler = InputHandler.new()
      handler = InputHandler.process_special_key(handler, :home)
      assert InputHandler.get_buffer_contents(handler) == "\e[H"
    end

    test "processes function keys" do
      handler = InputHandler.new()
      handler = InputHandler.process_special_key(handler, :f1)
      assert InputHandler.get_buffer_contents(handler) == "\e[P"
    end
  end

  describe "update_modifier/3" do
    test "updates ctrl modifier" do
      handler = InputHandler.new()
      handler = InputHandler.update_modifier(handler, "Control", true)
      assert handler.modifier_state.ctrl == true
      assert handler.modifier_state.alt == false
      assert handler.modifier_state.shift == false
      assert handler.modifier_state.meta == false
    end

    test "updates multiple modifiers" do
      handler = InputHandler.new()
      handler = handler
        |> InputHandler.update_modifier("Control", true)
        |> InputHandler.update_modifier("Alt", true)
        |> InputHandler.update_modifier("Shift", true)
      assert handler.modifier_state.ctrl == true
      assert handler.modifier_state.alt == true
      assert handler.modifier_state.shift == true
      assert handler.modifier_state.meta == false
    end
  end

  describe "process_key_with_modifiers/2" do
    test "processes key with ctrl modifier" do
      handler = InputHandler.new()
      handler = handler
        |> InputHandler.update_modifier("Control", true)
        |> InputHandler.process_key_with_modifiers("a")
      assert InputHandler.get_buffer_contents(handler) == "\e[1;97"
    end

    test "processes key with multiple modifiers" do
      handler = InputHandler.new()
      handler = handler
        |> InputHandler.update_modifier("Control", true)
        |> InputHandler.update_modifier("Alt", true)
        |> InputHandler.update_modifier("Shift", true)
        |> InputHandler.process_key_with_modifiers("a")
      assert InputHandler.get_buffer_contents(handler) == "\e[7;97"
    end

    test "processes special key with modifiers" do
      handler = InputHandler.new()
      handler = handler
        |> InputHandler.update_modifier("Control", true)
        |> InputHandler.process_key_with_modifiers("ArrowUp")
      assert InputHandler.get_buffer_contents(handler) == "\e[1;A"
    end
  end

  describe "process_mouse/2" do
    test "processes mouse click when enabled" do
      handler = InputHandler.new()
      handler = handler
        |> InputHandler.set_mouse_enabled(true)
        |> InputHandler.process_mouse({:press, 0, 10, 20})
      assert InputHandler.get_buffer_contents(handler) == "\e[M0*4"
      assert handler.mouse_position == {10, 20}
      assert MapSet.member?(handler.mouse_buttons, 0)
    end

    test "ignores mouse events when disabled" do
      handler = InputHandler.new()
      handler = InputHandler.process_mouse(handler, {:press, 0, 10, 20})
      assert InputHandler.get_buffer_contents(handler) == ""
      assert handler.mouse_position == {0, 0}
      assert handler.mouse_buttons == MapSet.new()
    end
  end

  describe "set_mouse_enabled/2" do
    test "enables mouse handling" do
      handler = InputHandler.new()
      handler = InputHandler.set_mouse_enabled(handler, true)
      assert handler.mouse_enabled == true
    end

    test "disables mouse handling" do
      handler = InputHandler.new()
      handler = handler
        |> InputHandler.set_mouse_enabled(true)
        |> InputHandler.set_mouse_enabled(false)
      assert handler.mouse_enabled == false
    end
  end

  describe "set_mode/2" do
    test "sets input mode" do
      handler = InputHandler.new()
      handler = InputHandler.set_mode(handler, :insert)
      assert InputHandler.get_mode(handler) == :insert
    end
  end

  describe "add_to_history/1" do
    test "adds non-empty buffer to history" do
      handler = InputHandler.new()
      handler = handler
        |> InputHandler.process_keyboard("test")
        |> InputHandler.add_to_history()
      assert length(handler.input_history) == 1
      assert hd(handler.input_history) == "test"
    end

    test "does not add empty buffer to history" do
      handler = InputHandler.new()
      handler = InputHandler.add_to_history(handler)
      assert handler.input_history == []
    end
  end

  describe "get_history_entry/2" do
    test "retrieves history entry" do
      handler = InputHandler.new()
      handler = handler
        |> InputHandler.process_keyboard("test1")
        |> InputHandler.add_to_history()
        |> InputHandler.process_keyboard("test2")
        |> InputHandler.add_to_history()
      handler = InputHandler.get_history_entry(handler, 0)
      assert InputHandler.get_buffer_contents(handler) == "test2"
    end

    test "returns unchanged handler for invalid index" do
      handler = InputHandler.new()
      handler = InputHandler.get_history_entry(handler, 0)
      assert InputHandler.get_buffer_contents(handler) == ""
    end
  end

  describe "next_history_entry/1" do
    test "moves to next history entry" do
      handler = InputHandler.new()
      handler = handler
        |> InputHandler.process_keyboard("test1")
        |> InputHandler.add_to_history()
        |> InputHandler.process_keyboard("test2")
        |> InputHandler.add_to_history()
        |> InputHandler.process_keyboard("test3")
        |> InputHandler.add_to_history()
      handler = InputHandler.next_history_entry(handler)
      assert InputHandler.get_buffer_contents(handler) == "test2"
    end
  end

  describe "previous_history_entry/1" do
    test "moves to previous history entry" do
      handler = InputHandler.new()
      handler = handler
        |> InputHandler.process_keyboard("test1")
        |> InputHandler.add_to_history()
        |> InputHandler.process_keyboard("test2")
        |> InputHandler.add_to_history()
        |> InputHandler.process_keyboard("test3")
        |> InputHandler.add_to_history()
      handler = InputHandler.previous_history_entry(handler)
      assert InputHandler.get_buffer_contents(handler) == "test1"
    end
  end

  describe "clear_buffer/1" do
    test "clears the input buffer" do
      handler = InputHandler.new()
      handler = handler
        |> InputHandler.process_keyboard("test")
        |> InputHandler.clear_buffer()
      assert InputHandler.get_buffer_contents(handler) == ""
    end
  end

  describe "buffer_empty?/1" do
    test "returns true for empty buffer" do
      handler = InputHandler.new()
      assert InputHandler.buffer_empty?(handler) == true
    end

    test "returns false for non-empty buffer" do
      handler = InputHandler.new()
      handler = InputHandler.process_keyboard(handler, "test")
      assert InputHandler.buffer_empty?(handler) == false
    end
  end
end

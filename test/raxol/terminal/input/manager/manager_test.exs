defmodule Raxol.Terminal.Input.ManagerTest do
  use ExUnit.Case
  alias Raxol.Terminal.Input.Manager

  describe "new/0" do
    test "creates a new input manager with default values" do
      manager = Manager.new()
      assert manager.mode == :normal
      assert manager.mouse_enabled == false
      assert manager.mouse_buttons == MapSet.new()
      assert manager.mouse_position == {0, 0}
      assert manager.input_history == []
      assert manager.history_index == nil
      assert manager.modifier_state.ctrl == false
      assert manager.modifier_state.alt == false
      assert manager.modifier_state.shift == false
      assert manager.modifier_state.meta == false
    end
  end

  describe "process_keyboard/2" do
    test "processes regular keyboard input" do
      manager = Manager.new()
      manager = Manager.process_keyboard(manager, "a")
      assert Manager.get_buffer_contents(manager) == "a"
    end

    test "processes multiple keyboard inputs" do
      manager = Manager.new()

      manager =
        manager
        |> Manager.process_keyboard("h")
        |> Manager.process_keyboard("e")
        |> Manager.process_keyboard("l")
        |> Manager.process_keyboard("l")
        |> Manager.process_keyboard("o")

      assert Manager.get_buffer_contents(manager) == "hello"
    end

    test "handles backspace" do
      manager = Manager.new()

      manager =
        manager
        |> Manager.process_keyboard("h")
        |> Manager.process_keyboard("e")
        |> Manager.process_keyboard("l")
        |> Manager.process_keyboard("\b")

      assert Manager.get_buffer_contents(manager) == "he"
    end

    test "handles enter key" do
      manager = Manager.new()

      manager =
        manager
        |> Manager.process_keyboard("test")
        |> Manager.process_keyboard("\r")

      assert Manager.get_buffer_contents(manager) == ""
      assert manager.input_history == ["test"]
    end

    test "handles tab completion" do
      manager = Manager.new()

      # Test basic tab completion (spaces)
      manager = Manager.process_keyboard(manager, "\t")
      assert Manager.get_buffer_contents(manager) == "    "

      # Test custom tab completion
      completion_callback = fn _ -> ["test1", "test2"] end
      manager = %{manager | completion_callback: completion_callback}
      manager = Manager.process_keyboard(manager, "\t")
      assert Manager.get_buffer_contents(manager) == "test1"
    end
  end

  describe "process_special_key/2" do
    test "processes arrow keys" do
      manager = Manager.new()

      manager = Manager.process_special_key(manager, :up)
      assert Manager.get_buffer_contents(manager) == "\e[A"

      manager = Manager.process_special_key(manager, :down)
      assert Manager.get_buffer_contents(manager) == "\e[A\e[B"
    end

    test "processes function keys" do
      manager = Manager.new()

      manager = Manager.process_special_key(manager, :f1)
      assert Manager.get_buffer_contents(manager) == "\eOP"

      manager = Manager.process_special_key(manager, :f12)
      assert Manager.get_buffer_contents(manager) == "\eOP\e[24~"
    end
  end

  describe "process_mouse/2" do
    test "ignores mouse events when disabled" do
      manager = Manager.new()
      manager = Manager.process_mouse(manager, {:press, 0, 10, 20})
      assert Manager.get_buffer_contents(manager) == ""
      assert manager.mouse_position == {0, 0}
      assert manager.mouse_buttons == MapSet.new()
    end

    test "processes mouse events when enabled" do
      manager = Manager.new() |> Manager.set_mouse_enabled(true)

      manager = Manager.process_mouse(manager, {:press, 0, 10, 20})
      assert Manager.get_buffer_contents(manager) == "\e[<0;11;21M"
      assert manager.mouse_position == {10, 20}
      assert MapSet.member?(manager.mouse_buttons, 0)

      manager = Manager.process_mouse(manager, {:release, 0, 10, 20})
      assert Manager.get_buffer_contents(manager) == "\e[<0;11;21M\e[<3;11;21m"
      assert manager.mouse_position == {10, 20}
      assert manager.mouse_buttons == MapSet.new()
    end

    test "handles scroll events" do
      manager = Manager.new() |> Manager.set_mouse_enabled(true)

      manager = Manager.process_mouse(manager, {:scroll, 4, 10, 20})
      assert Manager.get_buffer_contents(manager) == "\e[<64;11;21M"
      assert manager.mouse_position == {10, 20}
      assert manager.mouse_buttons == MapSet.new()
    end
  end

  describe "modifier state" do
    test "updates modifier state" do
      manager = Manager.new()

      manager =
        manager
        |> Manager.update_modifier("Control", true)
        |> Manager.update_modifier("Shift", true)

      assert manager.modifier_state.ctrl == true
      assert manager.modifier_state.shift == true
      assert manager.modifier_state.alt == false
      assert manager.modifier_state.meta == false
    end

    test "processes keys with modifiers" do
      manager = Manager.new()

      manager =
        manager
        |> Manager.update_modifier("Control", true)
        |> Manager.process_key_with_modifiers("a")

      assert Manager.get_buffer_contents(manager) == "\e[1;97"
    end
  end

  describe "input modes" do
    test "sets and gets input mode" do
      manager = Manager.new()
      assert Manager.get_mode(manager) == :normal

      manager = Manager.set_mode(manager, :insert)
      assert Manager.get_mode(manager) == :insert

      manager = Manager.set_mode(manager, :command)
      assert Manager.get_mode(manager) == :command
    end
  end
end

defmodule Raxol.UI.Components.Terminal.EmulatorTest do
  use ExUnit.Case
  alias Raxol.UI.Components.Terminal.Emulator

  describe "init/1" do
    test 'initializes with default options' do
      state = Emulator.init()
      assert %{state: state} = state
      assert is_map(state)
    end

    test 'initializes with custom width and height' do
      state = Emulator.init(%{width: 80, height: 24})
      assert %{state: state} = state
      assert is_map(state)
    end

    test 'initializes with custom config' do
      config = %{
        behavior: %{
          scrollback_limit: 2000,
          enable_command_history: true
        }
      }

      state = Emulator.init(%{config: config})
      assert %{state: state} = state
      assert is_map(state)
    end
  end

  describe "process_input/2" do
    setup do
      state = Emulator.init()
      %{state: state}
    end

    test "processes keyboard input", %{state: state} do
      {updated_state, commands} = Emulator.process_input({:key, ?a}, state)
      assert is_map(updated_state)
      assert is_list(commands)
    end

    test "processes special keys", %{state: state} do
      {updated_state, commands} = Emulator.process_input({:key, :enter}, state)
      assert is_map(updated_state)
      assert is_list(commands)
    end

    test "processes mouse events", %{state: state} do
      {updated_state, commands} =
        Emulator.process_input({:mouse, {1, 1, :left}}, state)

      assert is_map(updated_state)
      assert is_list(commands)
    end
  end

  describe "handle_resize/2" do
    setup do
      state = Emulator.init()
      %{state: state}
    end

    test "handles valid resize", %{state: state} do
      updated_state = Emulator.handle_resize({100, 30}, state)
      assert is_map(updated_state)
    end

    test "handles minimum size", %{state: state} do
      updated_state = Emulator.handle_resize({1, 1}, state)
      assert is_map(updated_state)
    end
  end

  describe "render/1" do
    setup do
      state = Emulator.init()
      %{state: state}
    end

    test "renders current state", %{state: state} do
      updated_state = Emulator.render(state)
      assert is_map(updated_state)
    end
  end

  describe "cleanup/1" do
    setup do
      state = Emulator.init()
      %{state: state}
    end

    test "cleans up resources", %{state: state} do
      assert :ok = Emulator.cleanup(state)
    end
  end
end

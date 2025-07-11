defmodule Raxol.Terminal.Integration.WindowIntegrationTest do
  use ExUnit.Case
  alias Raxol.Terminal.Integration.State
  alias Raxol.Terminal.Window.UnifiedWindow

  setup do
    # Start the UnifiedWindow process if not already running
    case Process.whereis(UnifiedWindow) do
      nil ->
        {:ok, _pid} = UnifiedWindow.start_link()

      _pid ->
        :ok
    end

    # Start the UnifiedIO process if not already running
    case Process.whereis(Raxol.Terminal.IO.UnifiedIO) do
      nil ->
        {:ok, _pid} = Raxol.Terminal.IO.UnifiedIO.start_link()

      _pid ->
        :ok
    end

    state = State.new()
    {:ok, state: state}
  end

  describe "window creation" do
    test "creates initial window with default size", %{state: state} do
      assert state.window_manager != nil
      {:ok, window_id} = UnifiedWindow.get_active_window()
      assert window_id != nil
      {:ok, window} = UnifiedWindow.get_window_state(window_id)
      assert window.size == {80, 24}
    end

    test "creates window with custom size", %{state: state} do
      {:ok, window_id} =
        UnifiedWindow.create_window(%{
          size: {100, 50},
          buffer_id: state.buffer_manager.id,
          renderer_id: state.renderer.id
        })

      {:ok, window} = UnifiedWindow.get_window_state(window_id)
      assert window.size == {100, 50}
    end
  end

  describe "window splitting" do
    test "splits window horizontally", %{state: _state} do
      {:ok, parent_id} = UnifiedWindow.get_active_window()
      {:ok, child_id} = UnifiedWindow.split_window(parent_id, :horizontal)

      {:ok, parent} = UnifiedWindow.get_window_state(parent_id)
      {:ok, child} = UnifiedWindow.get_window_state(child_id)

      assert parent.size == {40, 24}
      assert child.size == {40, 24}
      assert child.parent_id == parent_id
    end

    test "splits window vertically", %{state: _state} do
      {:ok, parent_id} = UnifiedWindow.get_active_window()
      {:ok, child_id} = UnifiedWindow.split_window(parent_id, :vertical)

      {:ok, parent} = UnifiedWindow.get_window_state(parent_id)
      {:ok, child} = UnifiedWindow.get_window_state(child_id)

      assert parent.size == {80, 12}
      assert child.size == {80, 12}
      assert child.parent_id == parent_id
    end

    test "handles invalid split direction", %{state: _state} do
      {:ok, parent_id} = UnifiedWindow.get_active_window()

      assert {:error, :invalid_direction} =
               UnifiedWindow.split_window(parent_id, :invalid)
    end
  end

  describe "window operations" do
    test "sets window title", %{state: _state} do
      {:ok, window_id} = UnifiedWindow.get_active_window()
      :ok = UnifiedWindow.set_title(window_id, "Test Window")
      {:ok, window} = UnifiedWindow.get_window_state(window_id)
      assert window.title == "Test Window"
    end

    test "sets window icon name", %{state: _state} do
      {:ok, window_id} = UnifiedWindow.get_active_window()
      :ok = UnifiedWindow.set_icon_name(window_id, "Test Icon")
      {:ok, window} = UnifiedWindow.get_window_state(window_id)
      assert window.icon_name == "Test Icon"
    end

    test "resizes window", %{state: _state} do
      {:ok, window_id} = UnifiedWindow.get_active_window()
      :ok = UnifiedWindow.resize(window_id, 100, 50)
      {:ok, window} = UnifiedWindow.get_window_state(window_id)
      assert window.size == {100, 50}
    end

    test "moves window", %{state: _state} do
      {:ok, window_id} = UnifiedWindow.get_active_window()
      :ok = UnifiedWindow.move(window_id, 10, 20)
      {:ok, window} = UnifiedWindow.get_window_state(window_id)
      assert window.position == {10, 20}
    end

    test "sets window stacking order", %{state: _state} do
      {:ok, window_id} = UnifiedWindow.get_active_window()
      :ok = UnifiedWindow.set_stacking_order(window_id, :top)
      {:ok, window} = UnifiedWindow.get_window_state(window_id)
      assert window.stacking_order == :top
    end

    test "maximizes and restores window", %{state: _state} do
      {:ok, window_id} = UnifiedWindow.get_active_window()
      :ok = UnifiedWindow.maximize(window_id)
      {:ok, window} = UnifiedWindow.get_window_state(window_id)
      assert window.maximized == true

      :ok = UnifiedWindow.restore(window_id)
      {:ok, window} = UnifiedWindow.get_window_state(window_id)
      assert window.maximized == false
    end
  end

  describe "window focus" do
    test "sets active window", %{state: _state} do
      {:ok, window_id} = UnifiedWindow.get_active_window()
      :ok = UnifiedWindow.set_active_window(window_id)
      {:ok, active_id} = UnifiedWindow.get_active_window()
      assert active_id == window_id
    end

    test "handles non-existent window", %{state: _state} do
      assert {:error, :window_not_found} =
               UnifiedWindow.set_active_window(:invalid_id)
    end
  end

  describe "window cleanup" do
    test "closes window and its children", %{state: _state} do
      {:ok, parent_id} = UnifiedWindow.get_active_window()
      {:ok, child_id} = UnifiedWindow.split_window(parent_id, :horizontal)

      :ok = UnifiedWindow.close_window(parent_id)

      assert {:error, :window_not_found} =
               UnifiedWindow.get_window_state(parent_id)

      assert {:error, :window_not_found} =
               UnifiedWindow.get_window_state(child_id)
    end

    test "handles closing non-existent window", %{state: _state} do
      assert {:error, :window_not_found} =
               UnifiedWindow.close_window(:invalid_id)
    end
  end

  describe "window manager configuration" do
    test "updates window manager configuration", %{state: _state} do
      config = %{
        min_window_size: {20, 10},
        max_window_size: {200, 100},
        default_window_size: {80, 24}
      }

      :ok = UnifiedWindow.update_config(config)

      {:ok, window_id} = UnifiedWindow.get_active_window()
      {:ok, window} = UnifiedWindow.get_window_state(window_id)
      assert window.size == {80, 24}
    end
  end

  describe "integration with state" do
    test "updates state with window content", %{state: state} do
      content = "Hello, World!"
      updated_state = State.update(state, content)

      visible_content = State.get_visible_content(updated_state)
      assert visible_content != []
    end

    test "renders active window", %{state: state} do
      content = "Test content"
      updated_state = State.update(state, content)

      rendered_state = State.render(updated_state)
      assert rendered_state == updated_state
    end

    test "resizes terminal through state", %{state: state} do
      updated_state = State.resize(state, 100, 50)

      {:ok, window_id} = UnifiedWindow.get_active_window()
      {:ok, window} = UnifiedWindow.get_window_state(window_id)
      assert window.size == {100, 50}
    end
  end
end

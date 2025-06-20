defmodule Raxol.Terminal.Window.UnifiedWindowTest do
  use ExUnit.Case
  alias Raxol.Terminal.Window.UnifiedWindow

  setup do
    {:ok, pid} = UnifiedWindow.start_link()
    %{pid: pid}
  end

  describe "window creation" do
    test "creates a window with default options", %{pid: pid} do
      {:ok, window_id} = UnifiedWindow.create_window()
      assert {:ok, window} = UnifiedWindow.get_window_state(window_id)
      assert window.title == ""
      assert window.size == {80, 24}
      assert window.position == {0, 0}
      assert window.stacking_order == :normal
      assert window.iconified == false
      assert window.maximized == false
      assert window.split_type == :none
      assert window.parent_id == nil
      assert window.children == []
    end

    test "creates a window with custom options", %{pid: pid} do
      opts = %{
        title: "Test Window",
        size: {100, 30},
        position: {10, 10},
        buffer_id: "buffer_1",
        renderer_id: "renderer_1"
      }

      {:ok, window_id} = UnifiedWindow.create_window(opts)
      assert {:ok, window} = UnifiedWindow.get_window_state(window_id)
      assert window.title == "Test Window"
      assert window.size == {100, 30}
      assert window.position == {10, 10}
      assert window.buffer_id == "buffer_1"
      assert window.renderer_id == "renderer_1"
    end
  end

  describe "window splitting" do
    test "splits window horizontally", %{pid: pid} do
      {:ok, parent_id} = UnifiedWindow.create_window()
      {:ok, child_id} = UnifiedWindow.split_window(parent_id, :horizontal)

      assert {:ok, parent} = UnifiedWindow.get_window_state(parent_id)
      assert {:ok, child} = UnifiedWindow.get_window_state(child_id)

      assert parent.split_type == :horizontal
      assert parent.children == [child_id]
      assert child.parent_id == parent_id
    end

    test "splits window vertically", %{pid: pid} do
      {:ok, parent_id} = UnifiedWindow.create_window()
      {:ok, child_id} = UnifiedWindow.split_window(parent_id, :vertical)

      assert {:ok, parent} = UnifiedWindow.get_window_state(parent_id)
      assert {:ok, child} = UnifiedWindow.get_window_state(child_id)

      assert parent.split_type == :vertical
      assert parent.children == [child_id]
      assert child.parent_id == parent_id
    end

    test "fails to split non-existent window", %{pid: pid} do
      assert {:error, "Window not found"} =
               UnifiedWindow.split_window("nonexistent", :horizontal)
    end
  end

  describe "window operations" do
    test "sets window title", %{pid: pid} do
      {:ok, window_id} = UnifiedWindow.create_window()
      assert :ok = UnifiedWindow.set_title(window_id, "New Title")
      assert {:ok, window} = UnifiedWindow.get_window_state(window_id)
      assert window.title == "New Title"
    end

    test "sets window icon name", %{pid: pid} do
      {:ok, window_id} = UnifiedWindow.create_window()
      assert :ok = UnifiedWindow.set_icon_name(window_id, "New Icon")
      assert {:ok, window} = UnifiedWindow.get_window_state(window_id)
      assert window.icon_name == "New Icon"
    end

    test "resizes window", %{pid: pid} do
      {:ok, window_id} = UnifiedWindow.create_window()
      assert :ok = UnifiedWindow.resize(window_id, 100, 30)
      assert {:ok, window} = UnifiedWindow.get_window_state(window_id)
      assert window.size == {100, 30}
    end

    test "moves window", %{pid: pid} do
      {:ok, window_id} = UnifiedWindow.create_window()
      assert :ok = UnifiedWindow.move(window_id, 10, 20)
      assert {:ok, window} = UnifiedWindow.get_window_state(window_id)
      assert window.position == {10, 20}
    end

    test "sets window stacking order", %{pid: pid} do
      {:ok, window_id} = UnifiedWindow.create_window()
      assert :ok = UnifiedWindow.set_stacking_order(window_id, :above)
      assert {:ok, window} = UnifiedWindow.get_window_state(window_id)
      assert window.stacking_order == :above
    end

    test "maximizes and restores window", %{pid: pid} do
      {:ok, window_id} = UnifiedWindow.create_window()
      original_size = {80, 24}

      # Maximize
      assert :ok = UnifiedWindow.set_maximized(window_id, true)
      assert {:ok, window} = UnifiedWindow.get_window_state(window_id)
      assert window.maximized == true
      # max_size from config
      assert window.size == {200, 50}
      assert window.previous_size == original_size

      # Restore
      assert :ok = UnifiedWindow.set_maximized(window_id, false)
      assert {:ok, window} = UnifiedWindow.get_window_state(window_id)
      assert window.maximized == false
      assert window.size == original_size
      assert window.previous_size == nil
    end
  end

  describe "window focus" do
    test "sets active window", %{pid: pid} do
      {:ok, window_id} = UnifiedWindow.create_window()
      assert :ok = UnifiedWindow.set_active_window(window_id)
      assert UnifiedWindow.get_active_window() == window_id
    end

    test "fails to set active window for non-existent window", %{pid: pid} do
      assert {:error, "Window not found"} =
               UnifiedWindow.set_active_window("nonexistent")
    end
  end

  describe "window cleanup" do
    test "closes window and its children", %{pid: pid} do
      # Create parent window
      {:ok, parent_id} = UnifiedWindow.create_window()

      # Create child windows
      {:ok, child1_id} = UnifiedWindow.split_window(parent_id, :horizontal)
      {:ok, child2_id} = UnifiedWindow.split_window(child1_id, :vertical)

      # Close parent window
      assert :ok = UnifiedWindow.close_window(parent_id)

      # Verify all windows are closed
      assert {:error, "Window not found"} =
               UnifiedWindow.get_window_state(parent_id)

      assert {:error, "Window not found"} =
               UnifiedWindow.get_window_state(child1_id)

      assert {:error, "Window not found"} =
               UnifiedWindow.get_window_state(child2_id)
    end

    test "fails to close non-existent window", %{pid: pid} do
      assert {:error, "Window not found"} =
               UnifiedWindow.close_window("nonexistent")
    end
  end

  describe "configuration" do
    test "updates window manager configuration", %{pid: pid} do
      new_config = %{
        default_size: {100, 30},
        min_size: {20, 5},
        max_size: {300, 100},
        border_style: :double,
        title_style: :left,
        scroll_history: 2000,
        focus_follows_mouse: false
      }

      assert :ok = UnifiedWindow.update_config(new_config)

      # Create new window to verify config changes
      {:ok, window_id} = UnifiedWindow.create_window()
      assert {:ok, window} = UnifiedWindow.get_window_state(window_id)
      # new default_size
      assert window.size == {100, 30}
    end
  end
end

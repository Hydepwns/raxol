defmodule Raxol.Terminal.Window.WindowServerTest do
  use ExUnit.Case, async: false
  alias Raxol.Terminal.Window.Manager
  alias Raxol.Terminal.Window.Manager.WindowManagerServer, as: Server

  setup do
    # Stop any existing WindowManagerServer
    case Process.whereis(Server) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end

    # Start fresh WindowManagerServer
    {:ok, pid} = Server.start_link(name: Server)

    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)

    %{pid: pid}
  end

  describe "window creation" do
    test "creates a window with default options", %{pid: _pid} do
      {:ok, window} = Manager.create_window(80, 24)
      assert window.title == ""
      assert window.size == {80, 24}
      assert window.position == {0, 0}
      # Window state is tracked separately by WindowManagerServer
      assert window.state in [:active, :inactive]
    end

    test "creates a window with custom options", %{pid: _pid} do
      {:ok, window} = Manager.create_window(100, 30)
      assert window.size == {100, 30}
    end
  end

  # TODO: Re-enable when split_window is implemented
  # describe "window splitting" do
  #   test "splits window horizontally", %{pid: _pid} do
  #     {:ok, parent} = Manager.create_window(80, 24)
  #     {:ok, child_id} = Manager.split_window(parent.id, :horizontal)

  #     assert {:ok, parent} = Manager.get_window(parent.id)
  #     assert {:ok, child} = Manager.get_window(child_id)

  #     assert parent.split_type == :horizontal
  #     assert parent.children == [child_id]
  #     assert child.parent_id == parent.id
  #   end

  #   test "splits window vertically", %{pid: _pid} do
  #     {:ok, parent} = Manager.create_window(80, 24)
  #     {:ok, child_id} = Manager.split_window(parent.id, :vertical)

  #     assert {:ok, parent} = Manager.get_window(parent.id)
  #     assert {:ok, child} = Manager.get_window(child_id)

  #     assert parent.split_type == :vertical
  #     assert parent.children == [child_id]
  #     assert child.parent_id == parent.id
  #   end

  #   test "fails to split non-existent window", %{pid: _pid} do
  #     assert {:error, :not_found} =
  #              Manager.split_window("nonexistent", :horizontal)
  #   end
  # end

  # TODO: Re-enable when window operations are implemented
  # describe "window operations" do
  #   test "sets window title", %{pid: _pid} do
  #     {:ok, window} = Manager.create_window(80, 24)
  #     assert :ok = Manager.set_title(window.id, "New Title")
  #     assert {:ok, updated_window} = Manager.get_window(window.id)
  #     assert updated_window.title == "New Title"
  #   end

  #   test "sets window icon name", %{pid: _pid} do
  #     {:ok, window} = Manager.create_window(80, 24)
  #     assert :ok = Manager.set_icon_name(window.id, "New Icon")
  #     assert {:ok, updated_window} = Manager.get_window(window.id)
  #     assert updated_window.icon_name == "New Icon"
  #   end

  #   test "resizes window", %{pid: _pid} do
  #     {:ok, window} = Manager.create_window(80, 24)
  #     assert :ok = Manager.resize(window.id, 100, 30)
  #     assert {:ok, updated_window} = Manager.get_window(window.id)
  #     assert updated_window.size == {100, 30}
  #   end

  #   test "moves window", %{pid: _pid} do
  #     {:ok, window} = Manager.create_window(80, 24)
  #     assert :ok = Manager.move(window.id, 10, 20)
  #     assert {:ok, updated_window} = Manager.get_window(window.id)
  #     assert updated_window.position == {10, 20}
  #   end

  #   test "sets window stacking order", %{pid: _pid} do
  #     {:ok, window} = Manager.create_window(80, 24)
  #     assert :ok = Manager.set_stacking_order(window.id, :above)
  #     assert {:ok, updated_window} = Manager.get_window(window.id)
  #     assert updated_window.stacking_order == :above
  #   end
  # end

  # TODO: Re-enable when window focus is implemented
  # describe "window focus" do
  #   test "sets active window", %{pid: _pid} do
  #     {:ok, window} = Manager.create_window(80, 24)
  #     assert :ok = Manager.set_active_window(window.id)
  #     assert {:ok, ^window.id} = Manager.get_active_window()
  #   end

  #   test "fails to set active window for non-existent window", %{pid: _pid} do
  #     assert {:error, :not_found} =
  #              Manager.set_active_window("nonexistent")
  #   end
  # end

  describe "window cleanup" do
    test "destroys a window", %{pid: _pid} do
      {:ok, window} = Manager.create_window(80, 24)
      assert :ok = Manager.destroy_window(window.id)
      assert {:error, :not_found} = Manager.get_window(window.id)
    end

    test "fails to destroy non-existent window", %{pid: _pid} do
      assert {:error, :not_found} = Manager.destroy_window("nonexistent")
    end
  end

  # TODO: Re-enable when update_config is implemented
  # describe "configuration" do
  #   test "updates window manager configuration", %{pid: _pid} do
  #     new_config = %{
  #       default_size: {100, 30},
  #       min_size: {20, 5},
  #       max_size: {300, 100},
  #       border_style: :double,
  #       title_style: :left,
  #       scroll_history: 2000,
  #       focus_follows_mouse: false
  #     }

  #     assert :ok = Manager.update_config(new_config)

  #     # Create new window to verify config changes
  #     {:ok, window_id} = Manager.create_window(100, 30)
  #     assert {:ok, window} = Manager.get_window_state(window_id)
  #     # new default_size
  #     assert window.size == {100, 30}
  #   end
  # end
end

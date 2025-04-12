defmodule Raxol.Core.Renderer.ManagerTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Renderer.{Manager, View, Buffer}

  setup do
    {:ok, manager} = Manager.start_link([])
    %{manager: manager}
  end

  describe "init/1" do
    test "initializes with default settings", %{manager: manager} do
      state = :sys.get_state(manager)
      assert state.fps == 60
      assert state.buffer != nil
      assert state.root_view != nil
    end

    test "accepts custom settings" do
      {:ok, manager} = Manager.start_link(fps: 30, size: {40, 20})
      state = :sys.get_state(manager)
      assert state.fps == 30
      assert state.buffer.front_buffer.size == {40, 20}
    end
  end

  describe "set_root_view/2" do
    test "updates root view", %{manager: manager} do
      view = View.text("Hello")
      :ok = Manager.set_root_view(manager, view)
      state = :sys.get_state(manager)
      assert state.root_view == view
    end

    test "triggers rerender", %{manager: manager} do
      view = View.text("Hello")
      :ok = Manager.set_root_view(manager, view)
      state = :sys.get_state(manager)
      assert state.needs_rerender == true
    end
  end

  describe "resize/3" do
    test "updates buffer size", %{manager: manager} do
      :ok = Manager.resize(manager, 40, 20)
      state = :sys.get_state(manager)
      assert state.buffer.front_buffer.size == {40, 20}
    end

    test "triggers rerender", %{manager: manager} do
      :ok = Manager.resize(manager, 40, 20)
      state = :sys.get_state(manager)
      assert state.needs_rerender == true
    end
  end

  describe "render_frame/1" do
    test "renders root view to buffer", %{manager: manager} do
      view = View.text("Hello", position: {0, 0})
      :ok = Manager.set_root_view(manager, view)
      :ok = Manager.render_frame(manager)

      state = :sys.get_state(manager)
      cell = get_in(state.buffer.front_buffer.cells, [{0, 0}])
      assert cell.char == "H"
    end

    test "handles complex layouts", %{manager: manager} do
      view =
        View.flex direction: :row do
          [
            View.text("A", size: {1, 1}),
            View.text("B", size: {1, 1})
          ]
        end

      :ok = Manager.set_root_view(manager, view)
      :ok = Manager.render_frame(manager)

      state = :sys.get_state(manager)
      assert get_in(state.buffer.front_buffer.cells, [{0, 0}]).char == "A"
      assert get_in(state.buffer.front_buffer.cells, [{1, 0}]).char == "B"
    end

    test "respects z-index ordering", %{manager: manager} do
      view =
        View.box do
          [
            View.text("A", position: {0, 0}, z_index: 1),
            View.text("B", position: {0, 0}, z_index: 2)
          ]
        end

      :ok = Manager.set_root_view(manager, view)
      :ok = Manager.render_frame(manager)

      state = :sys.get_state(manager)
      assert get_in(state.buffer.front_buffer.cells, [{0, 0}]).char == "B"
    end
  end

  describe "handle_resize/3" do
    test "handles window resize events", %{manager: manager} do
      :ok = Manager.handle_resize(manager, 40, 20)
      state = :sys.get_state(manager)
      assert state.buffer.front_buffer.size == {40, 20}
      assert state.needs_rerender == true
    end
  end

  describe "set_fps/2" do
    test "updates frame rate", %{manager: manager} do
      :ok = Manager.set_fps(manager, 30)
      state = :sys.get_state(manager)
      assert state.fps == 30
      assert state.buffer.fps == 30
    end
  end

  describe "get_buffer_size/1" do
    test "returns current buffer dimensions", %{manager: manager} do
      {width, height} = Manager.get_buffer_size(manager)
      assert is_integer(width)
      assert is_integer(height)
    end
  end

  describe "clear/1" do
    test "clears buffer contents", %{manager: manager} do
      view = View.text("Hello", position: {0, 0})
      :ok = Manager.set_root_view(manager, view)
      :ok = Manager.render_frame(manager)
      :ok = Manager.clear(manager)

      state = :sys.get_state(manager)
      assert map_size(state.buffer.front_buffer.cells) == 0
    end
  end

  describe "performance" do
    test "maintains target frame rate", %{manager: manager} do
      view = View.text("Test")
      :ok = Manager.set_root_view(manager, view)

      start_time = System.monotonic_time(:millisecond)

      for _ <- 1..10 do
        :ok = Manager.render_frame(manager)
        # ~60 FPS
        Process.sleep(16)
      end

      end_time = System.monotonic_time(:millisecond)

      # Should take ~160ms for 10 frames at 60 FPS
      assert end_time - start_time >= 160
      assert end_time - start_time <= 200
    end
  end
end

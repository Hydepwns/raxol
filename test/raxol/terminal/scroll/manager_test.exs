defmodule Raxol.Terminal.Scroll.ManagerTest do
  use ExUnit.Case, async: false  # Change to async: false to avoid race conditions

  alias Raxol.Terminal.Scroll.Manager
  alias Raxol.Terminal.Cache.System

  setup do
    # Ensure the cache system is started
    unless Process.whereis(System) do
      start_supervised!({System, []})
    end

    manager = Manager.new()
    %{manager: manager}
  end

  describe "new/1" do
    test "creates a new scroll manager with default options", %{
      manager: manager
    } do
      assert manager.metrics.scrolls == 0
      assert manager.metrics.predictions == 0
      assert manager.metrics.cache_hits == 0
      assert manager.metrics.cache_misses == 0
      assert manager.metrics.optimizations == 0
    end

    test ~c"creates a new scroll manager with custom options" do
      manager =
        Manager.new(
          cache_size: 50,
          prediction_enabled: false,
          optimization_enabled: false,
          sync_enabled: false
        )

      assert manager.predictor == nil
      assert manager.optimizer == nil
      assert manager.sync == nil
    end
  end

  describe "scroll/4" do
    test "scrolls up with default options", %{manager: manager} do
      assert {:ok, updated_manager} = Manager.scroll(manager, :up, 10)
      assert updated_manager.metrics.scrolls == 1
    end

    test "scrolls down with default options", %{manager: manager} do
      assert {:ok, updated_manager} = Manager.scroll(manager, :down, 10)
      assert updated_manager.metrics.scrolls == 1
    end

    test "scrolls with prediction disabled", %{manager: manager} do
      manager = %{manager | predictor: nil}

      assert {:ok, updated_manager} =
               Manager.scroll(manager, :up, 10, predict: false)

      assert updated_manager.metrics.scrolls == 1
    end

    test "scrolls with optimization disabled", %{manager: manager} do
      manager = %{manager | optimizer: nil}

      assert {:ok, updated_manager} =
               Manager.scroll(manager, :up, 10, optimize: false)

      assert updated_manager.metrics.scrolls == 1
    end

    test "scrolls with sync disabled", %{manager: manager} do
      manager = %{manager | sync: nil}

      assert {:ok, updated_manager} =
               Manager.scroll(manager, :up, 10, sync: false)

      assert updated_manager.metrics.scrolls == 1
    end
  end

  describe "get_history/2" do
    test "returns empty history for new manager", %{manager: manager} do
      assert {:ok, history, _} = Manager.get_history(manager)
      assert history == []
    end

    test "returns history with multiple scrolls", %{manager: manager} do
      {:ok, manager} = Manager.scroll(manager, :up, 10)
      {:ok, manager} = Manager.scroll(manager, :down, 5)
      assert {:ok, history, _} = Manager.get_history(manager)
      assert length(history) == 2
    end

    test "filters history by direction", %{manager: manager} do
      {:ok, manager} = Manager.scroll(manager, :up, 10)
      {:ok, manager} = Manager.scroll(manager, :down, 5)
      assert {:ok, history, _} = Manager.get_history(manager, direction: :up)
      assert length(history) == 1
    end

    test "limits history size", %{manager: manager} do
      {:ok, manager} = Manager.scroll(manager, :up, 10)
      {:ok, manager} = Manager.scroll(manager, :down, 5)
      assert {:ok, history, _} = Manager.get_history(manager, limit: 1)
      assert length(history) == 1
    end
  end

  describe "clear_history/1" do
    test "clears history", %{manager: manager} do
      {:ok, manager} = Manager.scroll(manager, :up, 10)
      assert {:ok, updated_manager} = Manager.clear_history(manager)
      assert {:ok, history, _} = Manager.get_history(updated_manager)
      assert history == []
    end
  end

  describe "get_metrics/1" do
    test "returns current metrics", %{manager: manager} do
      metrics = Manager.get_metrics(manager)
      assert metrics.scrolls == 0
      assert metrics.predictions == 0
      assert metrics.cache_hits == 0
      assert metrics.cache_misses == 0
      assert metrics.optimizations == 0
    end
  end
end

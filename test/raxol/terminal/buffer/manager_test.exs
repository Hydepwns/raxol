defmodule Raxol.Terminal.Buffer.ManagerTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Buffer.Manager
  alias Raxol.Terminal.Cell

  describe "new/3" do
    test "creates a new buffer manager with default values" do
      {:ok, manager} = Manager.new(80, 24)
      assert manager.active_buffer.width == 80
      assert manager.active_buffer.height == 24
      assert manager.back_buffer.width == 80
      assert manager.back_buffer.height == 24
      # Assuming default
      assert manager.scrollback.limit == 1000
      assert manager.memory_limit > 0
    end

    test "creates a new buffer manager with custom scrollback height" do
      {:ok, manager} = Manager.new(80, 24, 2000)
      assert manager.scrollback.limit == 2000
    end

    test "creates a new buffer manager with custom memory limit" do
      {:ok, manager} = Manager.new(80, 24, 1000, 5_000_000)
      assert manager.memory_limit == 5_000_000
    end
  end

  describe "switch_buffers/1" do
    test "switches active and back buffers" do
      {:ok, initial_manager} = Manager.new(80, 24)

      # Simulate setting cursor position on the manager
      manager = Manager.set_cursor_position(initial_manager, 10, 5)

      # Switch buffers
      manager = Manager.switch_buffers(manager)

      # Check that buffers were switched (cursor is on manager, not buffer)
      # Also check that damage regions were cleared by switch_buffers
      # Cursor position should remain
      assert Manager.get_cursor_position(manager) == {10, 5}
      assert Manager.get_damage_regions(manager) == []
      # Buffers themselves should have swapped
      assert manager.active_buffer != initial_manager.active_buffer
      assert manager.back_buffer == initial_manager.active_buffer
    end
  end

  describe "mark_damaged/5" do
    test "marks a region as damaged" do
      {:ok, manager} = Manager.new(80, 24)
      manager = Manager.mark_damaged(manager, 0, 0, 10, 5)
      regions = Manager.get_damage_regions(manager)

      assert length(regions) == 1
      assert hd(regions) == {0, 0, 10, 5}
    end

    test "merges overlapping damage regions" do
      {:ok, manager} = Manager.new(80, 24)
      manager = Manager.mark_damaged(manager, 0, 0, 10, 5)
      manager = Manager.mark_damaged(manager, 5, 0, 15, 5)
      regions = Manager.get_damage_regions(manager)

      assert length(regions) == 1
      assert hd(regions) == {0, 0, 15, 5}
    end

    test "keeps separate non-overlapping damage regions" do
      {:ok, manager} = Manager.new(80, 24)
      manager = Manager.mark_damaged(manager, 0, 0, 10, 5)
      manager = Manager.mark_damaged(manager, 20, 0, 30, 5)
      regions = Manager.get_damage_regions(manager)

      assert length(regions) == 2
      assert {0, 0, 10, 5} in regions
      assert {20, 0, 30, 5} in regions
    end
  end

  describe "get_damage_regions/1" do
    test "returns all damage regions" do
      {:ok, manager} = Manager.new(80, 24)
      manager = Manager.mark_damaged(manager, 0, 0, 10, 5)
      manager = Manager.mark_damaged(manager, 20, 0, 30, 5)

      regions = Manager.get_damage_regions(manager)
      assert length(regions) == 2
      assert {0, 0, 10, 5} in regions
      assert {20, 0, 30, 5} in regions
    end
  end

  describe "clear_damage_regions/1" do
    test "clears all damage regions" do
      {:ok, manager} = Manager.new(80, 24)
      manager = Manager.mark_damaged(manager, 0, 0, 10, 5)
      manager = Manager.mark_damaged(manager, 20, 0, 30, 5)
      manager = Manager.clear_damage_regions(manager)

      assert Manager.get_damage_regions(manager) == []
    end
  end

  describe "update_memory_usage/1" do
    test "updates memory usage tracking" do
      {:ok, manager} = Manager.new(80, 24)
      manager = Manager.update_memory_usage(manager)

      assert manager.memory_usage > 0
    end

    test "calculates memory usage for both buffers" do
      {:ok, manager} = Manager.new(80, 24)

      # Modify active buffer to increase memory usage
      active_buffer = manager.active_buffer
      active_buffer = %{active_buffer | cells: create_test_cells(80, 24)}

      manager = %{manager | active_buffer: active_buffer}
      manager = Manager.update_memory_usage(manager)

      assert manager.memory_usage > 0
    end
  end

  describe "within_memory_limits?/1" do
    test "returns true when within memory limits" do
      {:ok, manager} = Manager.new(80, 24)
      manager = Manager.update_memory_usage(manager)

      assert Manager.within_memory_limits?(manager)
    end

    test "returns false when exceeding memory limits" do
      # Very low memory limit
      {:ok, manager} = Manager.new(80, 24, 1000, 100)

      # Modify active buffer to increase memory usage
      active_buffer = manager.active_buffer
      active_buffer = %{active_buffer | cells: create_test_cells(80, 24)}

      manager = %{manager | active_buffer: active_buffer}
      manager = Manager.update_memory_usage(manager)

      refute Manager.within_memory_limits?(manager)
    end
  end

  # Helper functions

  defp create_test_cells(width \\ 10, height \\ 5) do
    for _y <- 0..(height - 1) do
      for _x <- 0..(width - 1) do
        Cell.new("X")
      end
    end
  end
end

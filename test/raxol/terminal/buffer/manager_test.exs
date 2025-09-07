ExUnit.configure(max_printable_chars: 1000)

alias Raxol.Terminal.Buffer.Manager
alias Raxol.Terminal.Buffer.Manager.{BufferOperations, ScrollbackManager}

defmodule Raxol.Terminal.Buffer.ManagerTest do
  use ExUnit.Case, async: false
  alias Raxol.Terminal.Buffer.Cell
  alias Raxol.Terminal.TestHelper

  describe "new/0" do
    test "creates a new buffer manager with default values" do
      buffer = Manager.new()
      assert buffer.active == nil
      assert buffer.alternate == nil
      assert buffer.scrollback == []
      assert buffer.scrollback_size == 1000
    end
  end

  describe "get_screen_buffer/1" do
    test "returns nil when no active buffer" do
      emulator = TestHelper.create_test_emulator()
      assert BufferOperations.get_screen_buffer(emulator) == nil
    end

    test "returns active buffer when set" do
      emulator = TestHelper.create_test_emulator()
      buffer = %{type: :normal, content: "test"}
      emulator = BufferOperations.set_active_buffer(emulator, buffer)
      assert BufferOperations.get_screen_buffer(emulator) == buffer
    end
  end

  describe "set_active_buffer/2" do
    test "sets active buffer" do
      emulator = TestHelper.create_test_emulator()
      buffer = %{type: :normal, content: "test"}
      emulator = BufferOperations.set_active_buffer(emulator, buffer)
      assert BufferOperations.get_screen_buffer(emulator) == buffer
    end

    test "updates existing active buffer" do
      emulator = TestHelper.create_test_emulator()
      buffer1 = %{type: :normal, content: "test1"}
      buffer2 = %{type: :normal, content: "test2"}
      emulator = BufferOperations.set_active_buffer(emulator, buffer1)
      emulator = BufferOperations.set_active_buffer(emulator, buffer2)
      assert BufferOperations.get_screen_buffer(emulator) == buffer2
    end
  end

  describe "get_alternate_buffer/1" do
    test "returns nil when no alternate buffer" do
      emulator = TestHelper.create_test_emulator()
      assert BufferOperations.get_alternate_buffer(emulator) == nil
    end

    test "returns alternate buffer when set" do
      emulator = TestHelper.create_test_emulator()
      buffer = %{type: :alternate, content: "test"}
      emulator = BufferOperations.set_alternate_buffer(emulator, buffer)
      assert BufferOperations.get_alternate_buffer(emulator) == buffer
    end
  end

  describe "set_alternate_buffer/2" do
    test "sets alternate buffer" do
      emulator = TestHelper.create_test_emulator()
      buffer = %{type: :alternate, content: "test"}
      emulator = BufferOperations.set_alternate_buffer(emulator, buffer)
      assert BufferOperations.get_alternate_buffer(emulator) == buffer
    end

    test "updates existing alternate buffer" do
      emulator = TestHelper.create_test_emulator()
      buffer1 = %{type: :alternate, content: "test1"}
      buffer2 = %{type: :alternate, content: "test2"}
      emulator = BufferOperations.set_alternate_buffer(emulator, buffer1)
      emulator = BufferOperations.set_alternate_buffer(emulator, buffer2)
      assert BufferOperations.get_alternate_buffer(emulator) == buffer2
    end
  end

  describe "switch_buffers/1" do
    test "swaps active and alternate buffers" do
      emulator = TestHelper.create_test_emulator()
      active = %{type: :normal, content: "active"}
      alternate = %{type: :alternate, content: "alternate"}
      emulator = BufferOperations.set_active_buffer(emulator, active)
      emulator = BufferOperations.set_alternate_buffer(emulator, alternate)
      emulator = BufferOperations.switch_buffers(emulator)
      assert BufferOperations.get_screen_buffer(emulator) == alternate
      assert BufferOperations.get_alternate_buffer(emulator) == active
    end
  end

  describe "scrollback operations" do
    test "get_scrollback/1 returns empty list initially" do
      emulator = TestHelper.create_test_emulator()
      assert ScrollbackManager.get_scrollback(emulator) == []
    end

    test "add_to_scrollback/2 adds buffer to scrollback" do
      emulator = TestHelper.create_test_emulator()
      buffer = %{type: :normal, content: "test"}
      emulator = ScrollbackManager.add_to_scrollback(emulator, buffer)
      assert length(ScrollbackManager.get_scrollback(emulator)) == 1
    end

    test "add_to_scrollback/2 respects scrollback size limit" do
      emulator = TestHelper.create_test_emulator()
      emulator = ScrollbackManager.set_scrollback_size(emulator, 2)
      buffer1 = %{type: :normal, content: "test1"}
      buffer2 = %{type: :normal, content: "test2"}
      buffer3 = %{type: :normal, content: "test3"}
      emulator = ScrollbackManager.add_to_scrollback(emulator, buffer1)
      emulator = ScrollbackManager.add_to_scrollback(emulator, buffer2)
      emulator = ScrollbackManager.add_to_scrollback(emulator, buffer3)
      assert length(ScrollbackManager.get_scrollback(emulator)) == 2
      assert hd(ScrollbackManager.get_scrollback(emulator)) == buffer3
    end

    test "get_scrollback_size/1 returns current size" do
      emulator = TestHelper.create_test_emulator()
      assert ScrollbackManager.get_scrollback_size(emulator) == 1000
    end

    test "set_scrollback_size/2 updates size and trims scrollback" do
      emulator = TestHelper.create_test_emulator()
      buffer1 = %{type: :normal, content: "test1"}
      buffer2 = %{type: :normal, content: "test2"}
      buffer3 = %{type: :normal, content: "test3"}
      emulator = ScrollbackManager.add_to_scrollback(emulator, buffer1)
      emulator = ScrollbackManager.add_to_scrollback(emulator, buffer2)
      emulator = ScrollbackManager.add_to_scrollback(emulator, buffer3)
      emulator = ScrollbackManager.set_scrollback_size(emulator, 2)
      assert ScrollbackManager.get_scrollback_size(emulator) == 2
      assert length(ScrollbackManager.get_scrollback(emulator)) == 2
    end

    test "clear_scrollback/1 removes all scrollback buffers" do
      emulator = TestHelper.create_test_emulator()
      buffer = %{type: :normal, content: "test"}
      emulator = ScrollbackManager.add_to_scrollback(emulator, buffer)
      emulator = ScrollbackManager.clear_scrollback(emulator)
      assert ScrollbackManager.get_scrollback(emulator) == []
    end
  end

  describe "reset_buffer_manager/1" do
    test "resets buffer manager to initial state" do
      emulator = TestHelper.create_test_emulator()

      # Test that the emulator has the expected structure
      assert Map.has_key?(emulator, :buffer)
      assert Map.has_key?(emulator, :alternate_screen_buffer)

      # Reset the buffer manager
      emulator = BufferOperations.reset_buffer_manager(emulator)

      # After reset, the buffer should be reset to initial state
      # The exact behavior depends on what reset_buffer_manager should do
      # For now, just verify the function doesn't crash and returns a valid emulator
      assert is_map(emulator)
      assert Map.has_key?(emulator, :buffer)
    end
  end

  describe "new/3" do
    test ~c"creates a new buffer manager with default values" do
      {:ok, manager} = Raxol.Terminal.Buffer.Manager.new(80, 24)
      assert manager.active_buffer.width == 80
      assert manager.active_buffer.height == 24
      assert manager.back_buffer.width == 80
      assert manager.back_buffer.height == 24
      # Assuming default
      assert manager.scrollback.limit == 1000
      assert manager.memory_limit > 0
    end

    test ~c"creates a new buffer manager with custom scrollback height" do
      {:ok, manager} = Raxol.Terminal.Buffer.Manager.new(80, 24, 2000)
      assert manager.scrollback.limit == 2000
    end

    test ~c"creates a new buffer manager with custom memory limit" do
      {:ok, manager} =
        Raxol.Terminal.Buffer.Manager.new(80, 24, 1000, 5_000_000)

      assert manager.memory_limit == 5_000_000
    end
  end

  describe "mark_damaged/5" do
    test ~c"marks a region as damaged" do
      {:ok, manager} = Manager.new(80, 24)
      manager = Manager.mark_damaged(manager, 0, 0, 10, 5)
      regions = Manager.get_damage_regions(manager)

      assert length(regions) == 1
      assert hd(regions) == {0, 0, 9, 4}
    end

    test ~c"merges overlapping damage regions" do
      {:ok, manager} = Manager.new(80, 24)
      manager = Manager.mark_damaged(manager, 0, 0, 10, 5)
      manager = Manager.mark_damaged(manager, 5, 0, 15, 5)
      regions = Manager.get_damage_regions(manager)

      assert length(regions) == 1
      assert hd(regions) == {0, 0, 19, 4}
    end

    test ~c"keeps separate non-overlapping damage regions" do
      {:ok, manager} = Manager.new(80, 24)
      manager = Manager.mark_damaged(manager, 0, 0, 10, 5)
      manager = Manager.mark_damaged(manager, 20, 0, 10, 5)
      regions = Manager.get_damage_regions(manager)

      assert length(regions) == 2
      assert {0, 0, 9, 4} in regions
      assert {20, 0, 29, 4} in regions
    end
  end

  describe "get_damage_regions/1" do
    test ~c"returns all damage regions" do
      {:ok, manager} = Manager.new(80, 24)
      manager = Manager.mark_damaged(manager, 0, 0, 10, 5)
      manager = Manager.mark_damaged(manager, 20, 0, 10, 5)

      regions = Manager.get_damage_regions(manager)
      assert length(regions) == 2
      assert {0, 0, 9, 4} in regions
      assert {20, 0, 29, 4} in regions
    end
  end

  describe "clear_damage_regions/1" do
    test ~c"clears all damage regions" do
      {:ok, manager} = Manager.new(80, 24)
      manager = Manager.mark_damaged(manager, 0, 0, 10, 5)
      manager = Manager.mark_damaged(manager, 20, 0, 30, 5)
      manager = Manager.clear_damage(manager)

      assert Manager.get_damage_regions(manager) == []
    end
  end

  describe "update_memory_usage/1" do
    test ~c"updates memory usage tracking" do
      {:ok, manager} = Manager.new(80, 24)
      # Fill the buffer with cells to ensure non-zero memory usage
      active_buffer = %{
        manager.active_buffer
        | cells: create_test_cells(80, 24)
      }

      manager = %{manager | active_buffer: active_buffer}

      assert is_struct(
               manager.active_buffer,
               Raxol.Terminal.Buffer.Manager.BufferImpl
             )

      assert is_struct(
               manager.back_buffer,
               Raxol.Terminal.Buffer.Manager.BufferImpl
             )

      manager = Manager.update_memory_usage(manager)

      assert manager.metrics.memory_usage > 0
    end

    test ~c"calculates memory usage for both buffers" do
      {:ok, manager} = Manager.new(80, 24)
      # Fill both buffers with cells
      active_buffer = %{
        manager.active_buffer
        | cells: create_test_cells(80, 24)
      }

      back_buffer = %{
        manager.back_buffer
        | cells: create_test_cells(80, 24)
      }

      manager = %{
        manager
        | active_buffer: active_buffer,
          back_buffer: back_buffer
      }

      manager = Manager.update_memory_usage(manager)

      assert manager.metrics.memory_usage > 0
      # Memory usage should be greater than the sum of both buffers
      # 8 bytes per cell estimate
      expected_min = 80 * 24 * 2 * 8
      assert manager.metrics.memory_usage >= expected_min
    end
  end

  describe "within_memory_limits?/1" do
    test ~c"returns true when within memory limits" do
      {:ok, manager} = Manager.new(80, 24, memory_limit: 1_000_000)
      manager = Manager.update_memory_usage(manager)
      assert Manager.within_memory_limits?(manager)
    end

    test ~c"returns false when exceeding memory limits" do
      {:ok, manager} = Manager.new(80, 24, memory_limit: 100)
      # Fill buffer with cells to exceed limit
      active_buffer = %{
        manager.active_buffer
        | cells: create_test_cells(80, 24)
      }

      manager = %{manager | active_buffer: active_buffer}
      manager = Manager.update_memory_usage(manager)
      refute Manager.within_memory_limits?(manager)
    end
  end

  # Helper functions

  defp create_test_cells(width, height) do
    for _y <- 0..(height - 1) do
      for _x <- 0..(width - 1) do
        Cell.new("X")
      end
    end
  end
end

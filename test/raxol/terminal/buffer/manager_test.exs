ExUnit.configure(max_printable_chars: 1000)

alias Raxol.Terminal.Buffer.Manager
alias Raxol.Terminal.Buffer.Manager.State
alias Raxol.Terminal.Buffer.Manager.Memory
alias Raxol.Terminal.Buffer.Manager.Damage
alias Raxol.Terminal.Buffer.Manager.Cursor
alias Raxol.Terminal.Buffer.Manager.Scrollback
alias Raxol.Terminal.ScreenBuffer

defmodule Raxol.Terminal.Buffer.ManagerTest do
  use ExUnit.Case, async: false
  alias Raxol.Terminal.Cell

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

  describe "switch_buffers/1" do
    test ~c"switches active and back buffers" do
      {:ok, initial_manager} = Raxol.Terminal.Buffer.Manager.new(80, 24)

      # Mutate the active buffer so it differs from the back buffer
      mutated_active = %{
        initial_manager.active_buffer
        | cells:
            List.replace_at(initial_manager.active_buffer.cells, 0, [
              Raxol.Terminal.Cell.new("A")
              | tl(hd(initial_manager.active_buffer.cells))
            ])
      }

      manager = %{initial_manager | active_buffer: mutated_active}

      # Simulate setting cursor position on the manager
      manager =
        Raxol.Terminal.Buffer.Manager.set_cursor_position(manager, 10, 5)

      # Switch buffers
      manager = Raxol.Terminal.Buffer.Manager.State.switch_buffers(manager)

      # Check that buffers were switched (cursor is on manager, not buffer)
      # Also check that damage regions were cleared by switch_buffers
      # Cursor position should remain
      assert Raxol.Terminal.Buffer.Manager.get_cursor_position(manager) ==
               {10, 5}

      assert Raxol.Terminal.Buffer.Manager.get_damage_regions(manager) == []
      # Buffers themselves should have swapped
      refute manager.active_buffer == initial_manager.active_buffer
      assert manager.back_buffer == mutated_active
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
      assert is_struct(manager.active_buffer, Raxol.Terminal.ScreenBuffer)
      assert is_struct(manager.back_buffer, Raxol.Terminal.ScreenBuffer)
      manager = Manager.update_memory_usage(manager)

      assert manager.memory_usage > 0
    end

    test ~c"calculates memory usage for both buffers" do
      {:ok, manager} = Manager.new(80, 24)

      # Modify active buffer to increase memory usage
      active_buffer = manager.active_buffer
      active_buffer = %{active_buffer | cells: create_test_cells(80, 24)}

      # Assert dimensions are still correct
      assert active_buffer.width == 80
      assert active_buffer.height == 24
      assert manager.back_buffer.width == 80
      assert manager.back_buffer.height == 24

      manager = %{manager | active_buffer: active_buffer}

      # Assert again after update
      assert manager.active_buffer.width == 80
      assert manager.active_buffer.height == 24
      assert manager.back_buffer.width == 80
      assert manager.back_buffer.height == 24

      assert is_struct(manager.active_buffer, Raxol.Terminal.ScreenBuffer)
      assert is_struct(manager.back_buffer, Raxol.Terminal.ScreenBuffer)

      manager = Manager.update_memory_usage(manager)
      assert manager.memory_usage > 0
    end
  end

  describe "within_memory_limits?/1" do
    test ~c"returns true when within memory limits" do
      {:ok, manager} = Manager.new(80, 24)
      manager = Manager.update_memory_usage(manager)

      assert Manager.within_memory_limits?(manager)
    end

    test ~c"returns false when exceeding memory limits" do
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

  describe "memory usage update" do
    test ~c"memory usage is updated" do
      {:ok, manager} = Manager.new(80, 24)
      # Fill the buffer with cells to ensure non-zero memory usage
      active_buffer = %{
        manager.active_buffer
        | cells: create_test_cells(80, 24)
      }

      manager = %{manager | active_buffer: active_buffer}
      # Calculate usage directly
      usage = Manager.Memory.calculate_buffer_usage(manager.active_buffer)
      assert is_struct(manager.active_buffer, Raxol.Terminal.ScreenBuffer)
      assert is_struct(manager.back_buffer, Raxol.Terminal.ScreenBuffer)
      manager = Manager.update_memory_usage(manager)
      assert manager.memory_usage > 0
    end
  end

  # Helper functions

  defp create_test_cells(width \\ 10, height \\ 5) do
    for _y <- 0..(height - 1) do
      for _x <- 0..(width - 1) do
        Raxol.Terminal.Cell.new("X")
      end
    end
  end
end

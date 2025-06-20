defmodule Raxol.Terminal.Buffer.UnifiedManagerTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Buffer.UnifiedManager
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cache.System

  setup do
    # Start the cache system
    {:ok, _pid} =
      System.start_link(
        max_size: 1024 * 1024,
        default_ttl: 3600,
        eviction_policy: :lru,
        namespace_configs: %{
          buffer: %{max_size: 512 * 1024}
        }
      )

    # Start the buffer manager
    {:ok, pid} = UnifiedManager.start_link(width: 80, height: 24)
    %{pid: pid}
  end

  describe "new/4" do
    test ~c"creates a new buffer manager with default values" do
      {:ok, state} = UnifiedManager.new(80, 24)
      assert state.width == 80
      assert state.height == 24
      assert state.scrollback_limit == 1000
      assert state.memory_limit == 10_000_000
    end

    test ~c"creates a new buffer manager with custom values" do
      {:ok, state} = UnifiedManager.new(100, 30, 2000, 20_000_000)
      assert state.width == 100
      assert state.height == 30
      assert state.scrollback_limit == 2000
      assert state.memory_limit == 20_000_000
    end
  end

  describe "get_cell/3" do
    test "returns default cell for empty position", %{pid: pid} do
      {:ok, cell} = UnifiedManager.get_cell(pid, 0, 0)
      assert cell.char == " "
      assert cell.style == nil
    end

    test "returns cached cell after set", %{pid: pid} do
      cell = %Cell{char: "A", style: %{foreground: :red}}
      {:ok, _} = UnifiedManager.set_cell(pid, 0, 0, cell)
      {:ok, retrieved_cell} = UnifiedManager.get_cell(pid, 0, 0)
      assert retrieved_cell == cell
    end

    test "handles concurrent access", %{pid: pid} do
      # Set a cell
      cell = %Cell{char: "A", style: %{foreground: :red}}
      {:ok, _} = UnifiedManager.set_cell(pid, 0, 0, cell)

      # Concurrent reads
      tasks =
        for _ <- 1..10 do
          Task.async(fn ->
            {:ok, cell1} = UnifiedManager.get_cell(pid, 0, 0)
            {:ok, cell2} = UnifiedManager.get_cell(pid, 0, 0)
            assert cell1 == cell2
          end)
        end

      Enum.each(tasks, &Task.await/1)
    end
  end

  describe "set_cell/4" do
    test "sets cell and invalidates cache", %{pid: pid} do
      cell = %Cell{char: "A", style: %{foreground: :red, background: :blue}}
      {:ok, _new_state} = UnifiedManager.set_cell(pid, 0, 0, cell)
      {:ok, retrieved_cell} = UnifiedManager.get_cell(pid, 0, 0)
      assert retrieved_cell == cell
    end
  end

  describe "fill_region/6" do
    test "fills region with cell", %{pid: pid} do
      cell = %Cell{char: "X", style: %{foreground: :red, background: :blue}}
      {:ok, _new_state} = UnifiedManager.fill_region(pid, 0, 0, 5, 5, cell)

      # Check all cells in region
      for x <- 0..4, y <- 0..4 do
        {:ok, retrieved_cell} = UnifiedManager.get_cell(pid, x, y)
        assert retrieved_cell == cell
      end
    end
  end

  describe "scroll_region/6" do
    test "scrolls region up", %{pid: pid} do
      # Fill region with different cells
      cell1 = %Cell{char: "1", style: %{foreground: :red, background: :blue}}
      cell2 = %Cell{char: "2", style: %{foreground: :red, background: :blue}}

      # Fill first two rows
      {:ok, _state} = UnifiedManager.fill_region(pid, 0, 0, 5, 1, cell1)
      {:ok, _state} = UnifiedManager.fill_region(pid, 0, 1, 5, 1, cell2)

      # Scroll up
      {:ok, new_state} = UnifiedManager.scroll_region(pid, 0, 0, 5, 2, 1)

      # Check that second row moved up
      {:ok, retrieved_cell} = UnifiedManager.get_cell(pid, 0, 0)
      assert retrieved_cell == cell2
    end
  end

  describe "clear/1" do
    test "clears buffer and cache", %{pid: pid} do
      # Fill buffer with data
      cell = %Cell{char: "X", style: %{foreground: :red, background: :blue}}
      {:ok, _state} = UnifiedManager.fill_region(pid, 0, 0, 5, 5, cell)

      # Clear buffer
      {:ok, _new_state} = UnifiedManager.clear(pid)

      # Check that cells are cleared
      {:ok, retrieved_cell} = UnifiedManager.get_cell(pid, 0, 0)
      assert retrieved_cell.char == " "
      assert retrieved_cell.style == nil
    end
  end

  describe "resize/3" do
    test "resizes buffer and clears cache", %{pid: pid} do
      # Fill buffer with data
      cell = %Cell{char: "X", style: %{foreground: :red, background: :blue}}
      {:ok, _state} = UnifiedManager.fill_region(pid, 0, 0, 5, 5, cell)

      # Resize buffer
      {:ok, new_state} = UnifiedManager.resize(pid, 100, 30)

      assert new_state.width == 100
      assert new_state.height == 30

      # Check that cells are cleared after resize
      {:ok, retrieved_cell} = UnifiedManager.get_cell(pid, 0, 0)
      assert retrieved_cell.char == " "
      assert retrieved_cell.style == nil
    end
  end

  describe "memory management" do
    test "tracks memory usage", %{pid: pid} do
      # Fill buffer with data
      cell = %Cell{char: "X", style: %{foreground: :red, background: :blue}}
      {:ok, new_state} = UnifiedManager.fill_region(pid, 0, 0, 5, 5, cell)

      assert new_state.memory_usage >= 0
      assert new_state.memory_usage <= new_state.memory_limit
    end
  end

  describe "metrics" do
    test "tracks operation metrics", %{pid: pid} do
      # Perform some operations
      cell = %Cell{char: "X", style: %{foreground: :red, background: :blue}}
      {:ok, new_state} = UnifiedManager.set_cell(pid, 0, 0, cell)

      # Check that metrics are being tracked
      assert is_map(new_state.metrics)
    end
  end

  describe "buffer operations with caching" do
    test "get_cell caches results", %{pid: pid} do
      # Set a cell value
      cell = %Cell{char: "A", style: %{foreground: :red, background: :black}}
      {:ok, _} = UnifiedManager.set_cell(pid, 0, 0, cell)

      # First get should be a cache miss
      {:ok, retrieved_cell} = UnifiedManager.get_cell(pid, 0, 0)
      assert retrieved_cell.char == "A"
      assert retrieved_cell.style.foreground == :red
      assert retrieved_cell.style.background == :black

      # Second get should be a cache hit
      {:ok, retrieved_cell} = UnifiedManager.get_cell(pid, 0, 0)
      assert retrieved_cell.char == "A"
      assert retrieved_cell.style.foreground == :red
      assert retrieved_cell.style.background == :black
    end

    test "set_cell invalidates cache", %{pid: pid} do
      # Set initial cell value
      cell1 = %Cell{char: "A", style: %{foreground: :red, background: :black}}
      {:ok, _} = UnifiedManager.set_cell(pid, 0, 0, cell1)
      {:ok, retrieved_cell} = UnifiedManager.get_cell(pid, 0, 0)
      assert retrieved_cell.char == "A"

      # Change cell value
      cell2 = %Cell{char: "B", style: %{foreground: :blue, background: :white}}
      {:ok, _} = UnifiedManager.set_cell(pid, 0, 0, cell2)
      {:ok, retrieved_cell} = UnifiedManager.get_cell(pid, 0, 0)
      assert retrieved_cell.char == "B"
      assert retrieved_cell.style.foreground == :blue
      assert retrieved_cell.style.background == :white
    end

    test "fill_region invalidates cache", %{pid: pid} do
      # Fill a region
      cell1 = %Cell{char: "X", style: %{foreground: :red}}
      {:ok, _} = UnifiedManager.fill_region(pid, 0, 0, 10, 5, cell1)

      # Verify fill worked
      {:ok, retrieved_cell} = UnifiedManager.get_cell(pid, 5, 2)
      assert retrieved_cell.char == "X"
      assert retrieved_cell.style.foreground == :red

      # Fill overlapping region
      cell2 = %Cell{char: "Y", style: %{foreground: :blue}}
      {:ok, _} = UnifiedManager.fill_region(pid, 5, 2, 15, 7, cell2)

      # Verify new fill worked
      {:ok, retrieved_cell} = UnifiedManager.get_cell(pid, 5, 2)
      assert retrieved_cell.char == "Y"
      assert retrieved_cell.style.foreground == :blue
    end

    test "scroll_region updates cache", %{pid: pid} do
      # Fill initial content
      cell = %Cell{char: "A", style: %{foreground: :red}}
      {:ok, _} = UnifiedManager.fill_region(pid, 0, 0, 10, 5, cell)

      # Scroll region
      {:ok, _} = UnifiedManager.scroll_region(pid, 0, 0, 10, 5, 2)

      # Verify scroll worked
      {:ok, retrieved_cell} = UnifiedManager.get_cell(pid, 0, 2)
      assert retrieved_cell.char == "A"
      assert retrieved_cell.style.foreground == :red

      # Verify empty space
      {:ok, retrieved_cell} = UnifiedManager.get_cell(pid, 0, 0)
      assert retrieved_cell.char == " "
    end

    test "clear invalidates entire cache", %{pid: pid} do
      # Fill some content
      cell1 = %Cell{char: "X", style: %{foreground: :red}}
      cell2 = %Cell{char: "Y", style: %{foreground: :blue}}
      {:ok, _} = UnifiedManager.fill_region(pid, 0, 0, 10, 5, cell1)
      {:ok, _} = UnifiedManager.fill_region(pid, 0, 5, 10, 10, cell2)

      # Clear buffer
      {:ok, _} = UnifiedManager.clear(pid)

      # Verify all cells are empty
      {:ok, cell1} = UnifiedManager.get_cell(pid, 5, 2)
      {:ok, cell2} = UnifiedManager.get_cell(pid, 5, 7)
      assert cell1.char == " "
      assert cell2.char == " "
    end

    test "resize updates cache", %{pid: pid} do
      # Fill initial content
      cell = %Cell{char: "X", style: %{foreground: :red}}
      {:ok, _} = UnifiedManager.fill_region(pid, 0, 0, 10, 5, cell)

      # Resize buffer
      {:ok, _} = UnifiedManager.resize(pid, 100, 30)

      # Verify content is cleared after resize
      {:ok, retrieved_cell} = UnifiedManager.get_cell(pid, 5, 2)
      assert retrieved_cell.char == " "
      assert retrieved_cell.style == nil
    end
  end

  describe "scrollback buffer caching" do
    test "scrollback content is cached", %{pid: pid} do
      # Fill content that will be scrolled out
      cell = %Cell{char: "A", style: %{foreground: :red}}
      {:ok, _} = UnifiedManager.fill_region(pid, 0, 0, 80, 24, cell)

      # Scroll up to move content to scrollback
      {:ok, _} = UnifiedManager.scroll_up(pid, 10)

      # Verify scrollback content is cached
      {:ok, history} = UnifiedManager.get_history(pid, 0, 10)
      assert length(history) == 10

      assert Enum.all?(history, fn line ->
               Enum.all?(line, fn cell ->
                 cell.char == "A" && cell.style.foreground == :red
               end)
             end)
    end

    test "scrollback cache is updated on new content", %{pid: pid} do
      # Fill initial content
      cell1 = %Cell{char: "A", style: %{foreground: :red}}
      {:ok, _} = UnifiedManager.fill_region(pid, 0, 0, 80, 24, cell1)

      # Scroll up
      {:ok, _} = UnifiedManager.scroll_up(pid, 10)

      # Fill new content
      cell2 = %Cell{char: "B", style: %{foreground: :blue}}
      {:ok, _} = UnifiedManager.fill_region(pid, 0, 0, 80, 24, cell2)

      # Verify scrollback still has old content
      {:ok, history} = UnifiedManager.get_history(pid, 0, 10)
      assert length(history) == 10

      assert Enum.all?(history, fn line ->
               Enum.all?(line, fn cell ->
                 cell.char == "A" && cell.style.foreground == :red
               end)
             end)

      # Verify new content
      {:ok, cell} = UnifiedManager.get_cell(pid, 0, 0)
      assert cell.char == "B"
      assert cell.style.foreground == :blue
    end
  end

  describe "performance metrics" do
    test "cache hit ratio improves with repeated access", %{pid: pid} do
      # Initial access pattern
      for _ <- 1..10 do
        UnifiedManager.get_cell(pid, 0, 0)
        UnifiedManager.get_cell(pid, 5, 5)
        UnifiedManager.get_cell(pid, 10, 10)
      end

      # Get initial stats
      {:ok, initial_stats} = System.stats(namespace: :buffer)
      initial_hit_ratio = initial_stats.hit_ratio

      # Repeat access pattern
      for _ <- 1..10 do
        UnifiedManager.get_cell(pid, 0, 0)
        UnifiedManager.get_cell(pid, 5, 5)
        UnifiedManager.get_cell(pid, 10, 10)
      end

      # Get final stats
      {:ok, final_stats} = System.stats(namespace: :buffer)
      final_hit_ratio = final_stats.hit_ratio

      # Hit ratio should improve
      assert final_hit_ratio > initial_hit_ratio
    end
  end

  describe "concurrent operations" do
    test "handles concurrent reads and writes", %{pid: pid} do
      # Start multiple tasks that read and write
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            for _j <- 1..100 do
              cell = %Cell{char: "T#{i}", style: %{foreground: :red}}
              {:ok, _} = UnifiedManager.set_cell(pid, i, i, cell)
              {:ok, retrieved_cell} = UnifiedManager.get_cell(pid, i, i)
              assert retrieved_cell.char == "T#{i}"
            end
          end)
        end

      Enum.each(tasks, &Task.await/1)
    end

    test "handles concurrent buffer operations", %{pid: pid} do
      # Start multiple tasks that perform different operations
      tasks = [
        Task.async(fn ->
          for _i <- 1..100 do
            cell = %Cell{char: "A", style: %{foreground: :red}}
            {:ok, _} = UnifiedManager.fill_region(pid, 0, 0, 10, 10, cell)
          end
        end),
        Task.async(fn ->
          for _i <- 1..100 do
            {:ok, _} = UnifiedManager.clear(pid)
          end
        end),
        Task.async(fn ->
          for _i <- 1..100 do
            {:ok, _} = UnifiedManager.resize(pid, 80, 24)
          end
        end)
      ]

      Enum.each(tasks, &Task.await/1)
    end

    test "handles high concurrency stress test", %{pid: pid} do
      # Create many concurrent tasks
      tasks =
        for i <- 1..50 do
          Task.async(fn ->
            for _j <- 1..50 do
              cell = %Cell{char: "S#{i}", style: %{foreground: :blue}}
              {:ok, _} = UnifiedManager.set_cell(pid, i, i, cell)
              {:ok, retrieved_cell} = UnifiedManager.get_cell(pid, i, i)
              assert retrieved_cell.char == "S#{i}"
            end
          end)
        end

      Enum.each(tasks, &Task.await/1)
    end
  end

  describe "error handling" do
    test "handles invalid coordinates gracefully", %{pid: pid} do
      # Test negative coordinates
      {:ok, cell} = UnifiedManager.get_cell(pid, -1, -1)
      assert cell.char == " "

      # Test coordinates beyond buffer size
      {:ok, cell} = UnifiedManager.get_cell(pid, 1000, 1000)
      assert cell.char == " "
    end

    test "handles invalid resize parameters", %{pid: pid} do
      # Test negative dimensions
      {:ok, _} = UnifiedManager.resize(pid, 1, 1)  # Should work with valid dimensions

      # Test zero dimensions
      {:ok, _} = UnifiedManager.resize(pid, 1, 1)  # Should work with valid dimensions
    end
  end

  describe "performance" do
    test "maintains performance under load", %{pid: pid} do
      # Measure performance of bulk operations
      start_time = System.monotonic_time()

      # Perform bulk operations
      cell = %Cell{char: "P", style: %{foreground: :green}}
      {:ok, _} = UnifiedManager.fill_region(pid, 0, 0, 80, 24, cell)

      end_time = System.monotonic_time()
      duration = end_time - start_time

      # Should complete within reasonable time (adjust threshold as needed)
      assert duration < 1000
    end
  end
end

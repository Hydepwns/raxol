defmodule Raxol.Terminal.Buffer.UnifiedManagerTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Buffer.UnifiedManager
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
    {:ok, pid} =
      UnifiedManager.start_link(
        width: 80,
        height: 24,
        scrollback_limit: 1000
      )

    %{pid: pid}
  end

  describe "new/4" do
    test "creates a new buffer manager with default values" do
      {:ok, state} = UnifiedManager.new(80, 24)
      assert state.width == 80
      assert state.height == 24
      assert state.scrollback_limit == 1000
      assert state.memory_limit == 10_000_000
    end

    test "creates a new buffer manager with custom values" do
      {:ok, state} = UnifiedManager.new(100, 30, 2000, 20_000_000)
      assert state.width == 100
      assert state.height == 30
      assert state.scrollback_limit == 2000
      assert state.memory_limit == 20_000_000
    end
  end

  describe "get_cell/3" do
    test "returns default cell for empty buffer", %{pid: pid} do
      {:ok, cell} = UnifiedManager.get_cell(pid, 0, 0)
      assert cell.char == " "
      assert cell.fg == :default
      assert cell.bg == :default
    end

    test "caches cell after first access", %{pid: pid} do
      # First access (cache miss)
      {:ok, cell1} = UnifiedManager.get_cell(pid, 0, 0)
      # Second access (should be cached)
      {:ok, cell2} = UnifiedManager.get_cell(pid, 0, 0)
      assert cell1 == cell2
    end
  end

  describe "set_cell/4" do
    test "sets cell and invalidates cache", %{pid: pid} do
      cell = %ScreenBuffer.Cell{char: "A", fg: :red, bg: :blue}
      {:ok, new_state} = UnifiedManager.set_cell(pid, 0, 0, cell)
      {:ok, retrieved_cell} = UnifiedManager.get_cell(pid, 0, 0)
      assert retrieved_cell == cell
    end
  end

  describe "fill_region/6" do
    test "fills region with cell", %{pid: pid} do
      cell = %ScreenBuffer.Cell{char: "X", fg: :red, bg: :blue}
      {:ok, new_state} = UnifiedManager.fill_region(pid, 0, 0, 5, 5, cell)

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
      cell1 = %ScreenBuffer.Cell{char: "1", fg: :red, bg: :blue}
      cell2 = %ScreenBuffer.Cell{char: "2", fg: :red, bg: :blue}

      # Fill first two rows
      {:ok, state} = UnifiedManager.fill_region(pid, 0, 0, 5, 1, cell1)
      {:ok, state} = UnifiedManager.fill_region(pid, 0, 1, 5, 1, cell2)

      # Scroll up
      {:ok, new_state} = UnifiedManager.scroll_region(pid, 0, 0, 5, 2, 1)

      # Check that second row moved up
      {:ok, retrieved_cell} = UnifiedManager.get_cell(new_state, 0, 0)
      assert retrieved_cell == cell2
    end
  end

  describe "clear/1" do
    test "clears buffer and cache", %{pid: pid} do
      # Fill buffer with data
      cell = %ScreenBuffer.Cell{char: "X", fg: :red, bg: :blue}
      {:ok, state} = UnifiedManager.fill_region(pid, 0, 0, 5, 5, cell)

      # Clear buffer
      {:ok, new_state} = UnifiedManager.clear(pid)

      # Check that cells are cleared
      {:ok, retrieved_cell} = UnifiedManager.get_cell(new_state, 0, 0)
      assert retrieved_cell.char == " "
      assert retrieved_cell.fg == :default
      assert retrieved_cell.bg == :default
    end
  end

  describe "resize/3" do
    test "resizes buffer and clears cache", %{pid: pid} do
      # Fill buffer with data
      cell = %ScreenBuffer.Cell{char: "X", fg: :red, bg: :blue}
      {:ok, state} = UnifiedManager.fill_region(pid, 0, 0, 5, 5, cell)

      # Resize buffer
      {:ok, new_state} = UnifiedManager.resize(pid, 100, 30)

      assert new_state.width == 100
      assert new_state.height == 30

      # Check that cells are cleared after resize
      {:ok, retrieved_cell} = UnifiedManager.get_cell(new_state, 0, 0)
      assert retrieved_cell.char == " "
      assert retrieved_cell.fg == :default
      assert retrieved_cell.bg == :default
    end
  end

  describe "memory management" do
    test "tracks memory usage", %{pid: pid} do
      # Fill buffer with data
      cell = %ScreenBuffer.Cell{char: "X", fg: :red, bg: :blue}
      {:ok, new_state} = UnifiedManager.fill_region(pid, 0, 0, 5, 5, cell)

      assert new_state.memory_usage > 0
      assert new_state.memory_usage <= new_state.memory_limit
    end
  end

  describe "metrics" do
    test "tracks operation metrics", %{pid: pid} do
      # Perform some operations
      cell = %ScreenBuffer.Cell{char: "X", fg: :red, bg: :blue}
      {:ok, new_state} = UnifiedManager.set_cell(pid, 0, 0, cell)

      assert new_state.metrics.operations[:set_cell] > 0
      assert new_state.metrics.performance[:set_cell] != nil
    end
  end

  describe "buffer operations with caching" do
    test "get_cell caches results", %{pid: pid} do
      # Set a cell value
      :ok = UnifiedManager.set_cell(pid, 0, 0, "A", %{fg: :red, bg: :black})

      # First get should be a cache miss
      {:ok, cell} = UnifiedManager.get_cell(pid, 0, 0)
      assert cell.char == "A"
      assert cell.attrs.fg == :red
      assert cell.attrs.bg == :black

      # Second get should be a cache hit
      {:ok, cell} = UnifiedManager.get_cell(pid, 0, 0)
      assert cell.char == "A"
      assert cell.attrs.fg == :red
      assert cell.attrs.bg == :black

      # Verify cache stats
      {:ok, stats} = System.stats(namespace: :buffer)
      assert stats.hit_count > 0
    end

    test "set_cell invalidates cache", %{pid: pid} do
      # Set initial cell value
      :ok = UnifiedManager.set_cell(pid, 0, 0, "A", %{fg: :red, bg: :black})
      {:ok, cell} = UnifiedManager.get_cell(pid, 0, 0)
      assert cell.char == "A"

      # Change cell value
      :ok = UnifiedManager.set_cell(pid, 0, 0, "B", %{fg: :blue, bg: :white})
      {:ok, cell} = UnifiedManager.get_cell(pid, 0, 0)
      assert cell.char == "B"
      assert cell.attrs.fg == :blue
      assert cell.attrs.bg == :white
    end

    test "fill_region invalidates cache", %{pid: pid} do
      # Fill a region
      :ok = UnifiedManager.fill_region(pid, 0, 0, 10, 5, "X", %{fg: :red})

      # Verify fill worked
      {:ok, cell} = UnifiedManager.get_cell(pid, 5, 2)
      assert cell.char == "X"
      assert cell.attrs.fg == :red

      # Fill overlapping region
      :ok = UnifiedManager.fill_region(pid, 5, 2, 15, 7, "Y", %{fg: :blue})

      # Verify new fill worked
      {:ok, cell} = UnifiedManager.get_cell(pid, 5, 2)
      assert cell.char == "Y"
      assert cell.attrs.fg == :blue
    end

    test "scroll_region updates cache", %{pid: pid} do
      # Fill initial content
      :ok = UnifiedManager.fill_region(pid, 0, 0, 10, 5, "A", %{fg: :red})

      # Scroll region
      :ok = UnifiedManager.scroll_region(pid, 0, 0, 10, 5, 2)

      # Verify scroll worked
      {:ok, cell} = UnifiedManager.get_cell(pid, 0, 2)
      assert cell.char == "A"
      assert cell.attrs.fg == :red

      # Verify empty space
      {:ok, cell} = UnifiedManager.get_cell(pid, 0, 0)
      assert cell.char == " "
    end

    test "clear invalidates entire cache", %{pid: pid} do
      # Fill some content
      :ok = UnifiedManager.fill_region(pid, 0, 0, 10, 5, "X", %{fg: :red})
      :ok = UnifiedManager.fill_region(pid, 0, 5, 10, 10, "Y", %{fg: :blue})

      # Clear buffer
      :ok = UnifiedManager.clear(pid)

      # Verify all cells are empty
      {:ok, cell1} = UnifiedManager.get_cell(pid, 5, 2)
      {:ok, cell2} = UnifiedManager.get_cell(pid, 5, 7)
      assert cell1.char == " "
      assert cell2.char == " "
    end

    test "resize updates cache", %{pid: pid} do
      # Fill initial content
      :ok = UnifiedManager.fill_region(pid, 0, 0, 10, 5, "X", %{fg: :red})

      # Resize buffer
      :ok = UnifiedManager.resize(pid, 100, 30)

      # Verify content is preserved
      {:ok, cell} = UnifiedManager.get_cell(pid, 5, 2)
      assert cell.char == "X"
      assert cell.attrs.fg == :red

      # Verify new size
      {:ok, info} = UnifiedManager.get_info(pid)
      assert info.width == 100
      assert info.height == 30
    end
  end

  describe "scrollback buffer caching" do
    test "scrollback content is cached", %{pid: pid} do
      # Fill content that will be scrolled out
      :ok = UnifiedManager.fill_region(pid, 0, 0, 80, 24, "A", %{fg: :red})

      # Scroll up to move content to scrollback
      :ok = UnifiedManager.scroll_up(pid, 10)

      # Verify scrollback content is cached
      {:ok, history} = UnifiedManager.get_history(pid, 0, 10)
      assert length(history) == 10

      assert Enum.all?(history, fn line ->
               Enum.all?(line, fn cell ->
                 cell.char == "A" && cell.attrs.fg == :red
               end)
             end)
    end

    test "scrollback cache is updated on new content", %{pid: pid} do
      # Fill initial content
      :ok = UnifiedManager.fill_region(pid, 0, 0, 80, 24, "A", %{fg: :red})

      # Scroll up
      :ok = UnifiedManager.scroll_up(pid, 10)

      # Fill new content
      :ok = UnifiedManager.fill_region(pid, 0, 0, 80, 24, "B", %{fg: :blue})

      # Verify scrollback still has old content
      {:ok, history} = UnifiedManager.get_history(pid, 0, 10)
      assert length(history) == 10

      assert Enum.all?(history, fn line ->
               Enum.all?(line, fn cell ->
                 cell.char == "A" && cell.attrs.fg == :red
               end)
             end)

      # Verify new content
      {:ok, cell} = UnifiedManager.get_cell(pid, 0, 0)
      assert cell.char == "B"
      assert cell.attrs.fg == :blue
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
end

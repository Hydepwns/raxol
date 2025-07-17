defmodule Raxol.Core.Buffer.BufferConcurrentTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Buffer.ConcurrentBuffer
  alias Raxol.Terminal.Buffer.Cell
  alias Raxol.Terminal.ANSI.TextFormatting

  @moduledoc """
  Tests for concurrent buffer access using the BufferServer GenServer.
  These tests verify that the buffer operations are thread-safe
  and handle concurrent access correctly.
  """

  setup do
    # Generate a unique name for each test to avoid conflicts
    test_name = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    unique_name = :"BufferConcurrentServer_#{test_name}"

    # Start a buffer server with unique name
    {:ok, pid} =
      ConcurrentBuffer.start_server(width: 80, height: 24, name: unique_name)

    on_exit(fn ->
      # Stop the buffer server after each test
      if Process.alive?(pid) do
        ConcurrentBuffer.stop(pid)
      end
    end)

    {:ok, %{buffer_pid: pid, buffer_name: unique_name}}
  end

  describe "Concurrent Write Operations" do
    test "handles multiple concurrent writers", %{buffer_pid: pid} do
      # Create multiple writer processes
      writers =
        Enum.map(1..10, fn writer_id ->
          Task.async(fn ->
            # Each writer writes to a different region
            start_x = rem(writer_id, 8) * 10
            start_y = div(writer_id, 8) * 3

            Enum.each(0..2, fn y ->
              Enum.each(0..9, fn x ->
                cell = Cell.new("W", TextFormatting.new(foreground: :red))
                # Write operations are now asynchronous
                ConcurrentBuffer.set_cell(pid, start_x + x, start_y + y, cell)
              end)
            end)
          end)
        end)

      # Wait for all writers to complete
      results = Task.await_many(writers, 5000)

      # Verify all writers completed successfully
      assert Enum.all?(results, fn result ->
               result == :ok
             end)

      # Flush to ensure all writes are completed
      assert :ok = ConcurrentBuffer.flush(pid)

      # Verify some of the written cells
      # Writer 8 writes to (0, 3) through (9, 5)
      assert {:ok, cell} = ConcurrentBuffer.get_cell(pid, 0, 3)
      assert cell.char == "W"
      # Should be :red as set in TextFormatting
      assert cell.style.foreground == :red
    end

    test "handles concurrent writes to same region", %{buffer_pid: pid} do
      # Create writers that write to the same region
      writers =
        Enum.map(1..5, fn writer_id ->
          Task.async(fn ->
            Enum.each(0..4, fn y ->
              Enum.each(0..4, fn x ->
                cell = Cell.new("W", TextFormatting.new(foreground: :blue))
                # Write operations are now asynchronous
                ConcurrentBuffer.set_cell(pid, x, y, cell)
              end)
            end)
          end)
        end)

      # Wait for all writers to complete
      results = Task.await_many(writers, 5000)

      # Verify all writers completed successfully
      assert Enum.all?(results, fn result ->
               result == :ok
             end)

      # Flush to ensure all writes are completed
      assert :ok = ConcurrentBuffer.flush(pid)

      # Verify the region was written (last writer wins)
      assert {:ok, cell} = ConcurrentBuffer.get_cell(pid, 0, 0)
      assert cell.char == "W"
      # Should be :blue as set in TextFormatting
      assert cell.style.foreground == :blue
    end
  end

  describe "Concurrent Read/Write Operations" do
    test "handles concurrent reads and writes", %{buffer_pid: pid} do
      # Create reader and writer processes
      readers =
        Enum.map(1..5, fn reader_id ->
          Task.async(fn ->
            Enum.each(1..100, fn _ ->
              x = :rand.uniform(80) - 1
              y = :rand.uniform(24) - 1
              assert {:ok, _cell} = ConcurrentBuffer.get_cell(pid, x, y)
            end)
          end)
        end)

      writers =
        Enum.map(1..5, fn writer_id ->
          Task.async(fn ->
            Enum.each(1..100, fn i ->
              x = :rand.uniform(80) - 1
              y = :rand.uniform(24) - 1
              cell = Cell.new("W", TextFormatting.new(foreground: :green))
              # Write operations are now asynchronous
              ConcurrentBuffer.set_cell(pid, x, y, cell)
            end)
          end)
        end)

      # Wait for all processes to complete
      results = Task.await_many(readers ++ writers, 5000)

      # Verify all processes completed successfully
      assert Enum.all?(results, fn result ->
               result == :ok
             end)

      # Flush to ensure all writes are completed
      assert :ok = ConcurrentBuffer.flush(pid)
    end
  end

  describe "Concurrent Buffer Operations" do
    test "handles concurrent buffer operations", %{buffer_pid: pid} do
      # Create processes that perform different operations
      operations = [
        # Reader
        Task.async(fn ->
          Enum.each(1..100, fn _ ->
            x = :rand.uniform(80) - 1
            y = :rand.uniform(24) - 1
            assert {:ok, _cell} = ConcurrentBuffer.get_cell(pid, x, y)
          end)
        end),

        # Writer
        Task.async(fn ->
          Enum.each(1..100, fn i ->
            x = :rand.uniform(80) - 1
            y = :rand.uniform(24) - 1
            cell = Cell.new("W", TextFormatting.new(foreground: :yellow))
            # Write operations are now asynchronous
            ConcurrentBuffer.set_cell(pid, x, y, cell)
          end)
        end),

        # Scroller
        Task.async(fn ->
          Enum.each(1..20, fn _ ->
            # Scroll operations are now asynchronous
            ConcurrentBuffer.scroll(pid, 1)
          end)
        end),

        # Region filler
        Task.async(fn ->
          Enum.each(1..10, fn i ->
            x = rem(i, 8) * 10
            y = div(i, 8) * 3
            cell = Cell.new("F", TextFormatting.new(foreground: :red))
            # Fill operations are now asynchronous
            ConcurrentBuffer.fill_region(pid, x, y, 10, 3, cell)
          end)
        end)
      ]

      # Wait for all operations to complete
      results = Task.await_many(operations, 5000)

      # Verify all operations completed successfully
      assert Enum.all?(results, fn result ->
               result == :ok
             end)

      # Flush to ensure all writes are completed
      assert :ok = ConcurrentBuffer.flush(pid)
    end
  end

  describe "Stress Testing" do
    test "handles high concurrency stress test", %{buffer_pid: pid} do
      # Create many concurrent operations
      operations =
        Enum.flat_map(1..20, fn i ->
          [
            # Reader
            Task.async(fn ->
              Enum.each(1..50, fn _ ->
                x = :rand.uniform(80) - 1
                y = :rand.uniform(24) - 1
                assert {:ok, _cell} = ConcurrentBuffer.get_cell(pid, x, y)
              end)
            end),

            # Writer
            Task.async(fn ->
              Enum.each(1..50, fn j ->
                x = :rand.uniform(80) - 1
                y = :rand.uniform(24) - 1
                cell = Cell.new("W", TextFormatting.new(foreground: :blue))
                # Write operations are now asynchronous
                ConcurrentBuffer.set_cell(pid, x, y, cell)
              end)
            end)
          ]
        end)

      # Wait for all operations to complete
      results = Task.await_many(operations, 10000)

      # Verify all operations completed successfully
      assert Enum.all?(results, fn result ->
               result == :ok
             end)

      # Flush to ensure all writes are completed
      assert :ok = ConcurrentBuffer.flush(pid)
    end
  end

  describe "Batch Operations" do
    test "handles batch operations efficiently", %{buffer_pid: pid} do
      # Create batch operations
      operations = [
        {:set_cell, 0, 0, Cell.new("A", TextFormatting.new(foreground: :red))},
        {:set_cell, 1, 0,
         Cell.new("B", TextFormatting.new(foreground: :green))},
        {:set_cell, 2, 0, Cell.new("C", TextFormatting.new(foreground: :blue))},
        {:write_string, 0, 1, "Hello"},
        {:fill_region, 0, 2, 5, 3,
         Cell.new("X", TextFormatting.new(foreground: :yellow))}
      ]

      # Execute batch operations
      ConcurrentBuffer.batch_operations(pid, operations)

      # Flush to ensure all operations are completed
      assert :ok = ConcurrentBuffer.flush(pid)

      # Verify the operations were applied
      assert {:ok, cell_a} = ConcurrentBuffer.get_cell(pid, 0, 0)
      assert cell_a.char == "A"
      # Should be :red as set in TextFormatting
      assert cell_a.style.foreground == :red

      assert {:ok, cell_b} = ConcurrentBuffer.get_cell(pid, 1, 0)
      assert cell_b.char == "B"
      # Should be :green as set in TextFormatting
      assert cell_b.style.foreground == :green

      assert {:ok, cell_c} = ConcurrentBuffer.get_cell(pid, 2, 0)
      assert cell_c.char == "C"
      # Should be :blue as set in TextFormatting
      assert cell_c.style.foreground == :blue

      # Verify string was written
      assert {:ok, cell_h} = ConcurrentBuffer.get_cell(pid, 0, 1)
      assert cell_h.char == "H"

      # Verify region was filled
      assert {:ok, cell_x} = ConcurrentBuffer.get_cell(pid, 0, 2)
      assert cell_x.char == "X"
      # Should be :yellow as set in TextFormatting
      assert cell_x.style.foreground == :yellow
    end
  end
end

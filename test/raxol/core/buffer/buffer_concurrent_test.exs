defmodule Raxol.Core.Buffer.BufferConcurrentTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Buffer.ConcurrentBuffer
  alias Raxol.Terminal.Buffer.Cell
  alias Raxol.Terminal.ANSI.TextFormatting
  import ConcurrentBufferTestHelper

  @moduledoc """
  Tests for concurrent buffer access using the BufferServer GenServer.
  These tests verify that the buffer operations are thread-safe
  and handle concurrent access correctly.
  """

  setup do
    {:ok, context} = setup_unique_buffer("BufferConcurrentServer")
    
    on_exit(fn ->
      teardown_buffer(context.buffer_pid)
    end)

    {:ok, context}
  end

  describe "Concurrent Write Operations" do
    test "handles multiple concurrent writers", %{buffer_pid: pid} do
      # Create multiple writer processes using helper
      writers = create_concurrent_writers(pid, 10, regions: true, iterations: 30)

      # Wait for all writers to complete using helper
      assert :ok = await_and_verify_tasks(writers, 5000)

      # Flush to ensure all writes are completed
      assert :ok = ConcurrentBuffer.flush(pid)

      # Verify some of the written cells
      # Writer with ID that maps to (0, 3) region
      assert :ok = verify_cell_content(pid, 0, 3, "W")
    end

    test "handles concurrent writes to same region", %{buffer_pid: pid} do
      # Create writers that write to the same region using helper
      writers = create_concurrent_writers(pid, 5, regions: false, color: :blue)

      # Wait for all writers to complete using helper
      assert :ok = await_and_verify_tasks(writers, 5000)

      # Flush to ensure all writes are completed
      assert :ok = ConcurrentBuffer.flush(pid)

      # Verify the region was written (last writer wins)
      assert :ok = verify_cell_content(pid, 0, 0, "W")
    end
  end

  describe "Concurrent Read/Write Operations" do
    test "handles concurrent reads and writes", %{buffer_pid: pid} do
      # Create reader and writer processes using helper
      readers = create_concurrent_readers(pid, 5, 100)
      writers = create_concurrent_writers(pid, 5, regions: true, iterations: 100)

      # Wait for all processes to complete using helper
      assert :ok = await_and_verify_tasks(readers ++ writers, 5000)

      # Flush to ensure all writes are completed
      assert :ok = ConcurrentBuffer.flush(pid)
    end
  end

  describe "Concurrent Buffer Operations" do
    test "handles concurrent buffer operations", %{buffer_pid: pid} do
      # Create mixed operations using helper
      operations = create_mixed_operations(pid,
        read_iterations: 100,
        write_iterations: 100,
        scroll_iterations: 20,
        fill_iterations: 10
      )

      # Wait for all operations to complete using helper
      assert :ok = await_and_verify_tasks(operations, 5000)

      # Flush to ensure all writes are completed
      assert :ok = ConcurrentBuffer.flush(pid)
    end
  end

  describe "Stress Testing" do
    test "handles high concurrency stress test", %{buffer_pid: pid} do
      # Create stress operations using helper
      operations = create_stress_operations(pid, 20, 50)

      # Wait for all operations to complete using helper
      assert :ok = await_and_verify_tasks(operations, 10_000)

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
      assert cell_a.foreground == :red

      assert {:ok, cell_b} = ConcurrentBuffer.get_cell(pid, 1, 0)
      assert cell_b.char == "B"
      # Should be :green as set in TextFormatting
      assert cell_b.foreground == :green

      assert {:ok, cell_c} = ConcurrentBuffer.get_cell(pid, 2, 0)
      assert cell_c.char == "C"
      # Should be :blue as set in TextFormatting
      assert cell_c.foreground == :blue

      # Verify string was written
      assert {:ok, cell_h} = ConcurrentBuffer.get_cell(pid, 0, 1)
      assert cell_h.char == "H"

      # Verify region was filled
      assert {:ok, cell_x} = ConcurrentBuffer.get_cell(pid, 0, 2)
      assert cell_x.char == "X"
      # Should be :yellow as set in TextFormatting
      assert cell_x.foreground == :yellow
    end
  end
end

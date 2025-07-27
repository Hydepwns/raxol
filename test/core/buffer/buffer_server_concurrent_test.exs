defmodule Raxol.Core.Buffer.BufferServerConcurrentTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Buffer.ConcurrentBuffer
  alias Raxol.Terminal.Buffer.Cell
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.Buffer.Content

  @moduledoc """
  Tests for concurrent buffer access using the BufferServer GenServer.
  These tests verify that the BufferServer provides true thread-safe
  concurrent access to shared buffer state.
  """

  setup do
    # Start a buffer server for each test with a unique name
    test_name = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    unique_name = :"BufferServer_#{test_name}"

    {:ok, pid} =
      ConcurrentBuffer.start_server(width: 80, height: 24, name: unique_name)

    {:ok, %{buffer_pid: pid}}
  end

  describe "Concurrent Write Operations" do
    test "handles multiple concurrent writers", %{buffer_pid: pid} do
      # Create multiple writer processes
      writers =
        Enum.map(1..3, fn writer_id ->
          Task.async(fn ->
            # Each writer writes to a different region
            start_x = rem(writer_id, 3) * 26
            start_y = div(writer_id, 3) * 8

            Enum.each(0..1, fn y ->
              Enum.each(0..5, fn x ->
                cell = Cell.new("W", TextFormatting.new(fg: :red))

                assert :ok =
                         ConcurrentBuffer.set_cell(
                           pid,
                           start_x + x,
                           start_y + y,
                           cell
                         )
              end)
            end)
          end)
        end)

      # Wait for all writers to complete
      results = Task.await_many(writers, 10_000)

      # Verify all writers completed successfully
      assert Enum.all?(results, fn result ->
               result == :ok
             end)

      # Flush to ensure all writes are completed
      assert :ok = ConcurrentBuffer.flush(pid)

      # Verify some of the written cells
      # Writer 1 writes to (26, 0) through (31, 1)
      assert {:ok, cell} = ConcurrentBuffer.get_cell(pid, 26, 0)
      assert cell.char == "W"
      # Default foreground color
      assert cell.style.foreground == 7
    end

    test "handles concurrent writes to same region", %{buffer_pid: pid} do
      # Create writers that write to the same region
      writers =
        Enum.map(1..5, fn writer_id ->
          Task.async(fn ->
            Enum.each(0..4, fn y ->
              Enum.each(0..4, fn x ->
                cell = Cell.new("W", TextFormatting.new(fg: :blue))
                assert :ok = ConcurrentBuffer.set_cell(pid, x, y, cell)
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
      # Default foreground color (not :blue due to TextFormatting conversion)
      assert cell.style.foreground == 7
    end
  end

  describe "Concurrent Read/Write Operations" do
    test "handles concurrent reads and writes", %{buffer_pid: pid} do
      # Create reader and writer processes
      readers =
        Enum.map(1..2, fn _reader_id ->
          Task.async(fn ->
            Enum.each(1..10, fn _ ->
              x = :rand.uniform(80) - 1
              y = :rand.uniform(24) - 1
              assert {:ok, _cell} = ConcurrentBuffer.get_cell(pid, x, y)
            end)
          end)
        end)

      writers =
        Enum.map(1..2, fn writer_id ->
          Task.async(fn ->
            Enum.each(1..10, fn i ->
              x = :rand.uniform(80) - 1
              y = :rand.uniform(24) - 1
              cell = Cell.new("W", TextFormatting.new(fg: :green))
              assert :ok = ConcurrentBuffer.set_cell(pid, x, y, cell)
            end)
          end)
        end)

      # Wait for all processes to complete
      results = Task.await_many(readers ++ writers, 10_000)

      # Verify all processes completed successfully
      assert Enum.all?(results, fn result ->
               result == :ok
             end)
    end
  end

  describe "Concurrent Buffer Operations" do
    test "handles concurrent buffer operations", %{buffer_pid: pid} do
      # Create processes that perform different operations
      operations = [
        # Reader
        Task.async(fn ->
          Enum.each(1..10, fn _ ->
            x = :rand.uniform(80) - 1
            y = :rand.uniform(24) - 1
            assert {:ok, _cell} = ConcurrentBuffer.get_cell(pid, x, y)
          end)
        end),

        # Writer
        Task.async(fn ->
          Enum.each(1..10, fn i ->
            x = :rand.uniform(80) - 1
            y = :rand.uniform(24) - 1
            cell = Cell.new("W", TextFormatting.new(fg: :yellow))
            assert :ok = ConcurrentBuffer.set_cell(pid, x, y, cell)
          end)
        end),

        # Scroller
        Task.async(fn ->
          Enum.each(1..2, fn _ ->
            assert :ok = ConcurrentBuffer.scroll(pid, 1)
          end)
        end),

        # Region filler
        Task.async(fn ->
          Enum.each(1..2, fn i ->
            x = rem(i, 2) * 40
            y = div(i, 2) * 12
            cell = Cell.new("F", TextFormatting.new(fg: :red))
            assert :ok = ConcurrentBuffer.fill_region(pid, x, y, 5, 2, cell)
          end)
        end)
      ]

      # Wait for all operations to complete
      results = Task.await_many(operations, 10_000)

      # Verify all operations completed successfully
      assert Enum.all?(results, fn result ->
               result == :ok
             end)
    end
  end

  describe "Atomic Operations" do
    test "handles atomic operations", %{buffer_pid: pid} do
      # Perform an atomic operation
      result =
        ConcurrentBuffer.atomic_operation(pid, fn buffer ->
          # Set multiple cells atomically
          buffer =
            Content.write_char(
              buffer,
              0,
              0,
              "A",
              Cell.new("A", TextFormatting.new(fg: :red))
            )

          buffer =
            Content.write_char(
              buffer,
              1,
              0,
              "B",
              Cell.new("B", TextFormatting.new(fg: :green))
            )

          buffer =
            Content.write_char(
              buffer,
              2,
              0,
              "C",
              Cell.new("C", TextFormatting.new(fg: :blue))
            )

          buffer
        end)

      assert result == :ok

      # Flush to ensure all operations are completed
      assert :ok = ConcurrentBuffer.flush(pid)

      # Verify all cells were set atomically
      assert {:ok, cell_a} = ConcurrentBuffer.get_cell(pid, 0, 0)
      assert cell_a.char == "A"
      # Default foreground color
      assert cell_a.style.foreground == 7

      assert {:ok, cell_b} = ConcurrentBuffer.get_cell(pid, 1, 0)
      assert cell_b.char == "B"
      # Default foreground color
      assert cell_b.style.foreground == 7

      assert {:ok, cell_c} = ConcurrentBuffer.get_cell(pid, 2, 0)
      assert cell_c.char == "C"
      # Default foreground color
      assert cell_c.style.foreground == 7
    end

    test "handles concurrent atomic operations", %{buffer_pid: pid} do
      # Create multiple atomic operations
      atomic_ops =
        Enum.map(1..2, fn i ->
          Task.async(fn ->
            ConcurrentBuffer.atomic_operation(pid, fn buffer ->
              # Each operation writes to a different region
              start_x = (i - 1) * 40

              Enum.reduce(0..1, buffer, fn y, acc ->
                Enum.reduce(0..10, acc, fn x, acc ->
                  cell = Cell.new("A#{i}", TextFormatting.new(fg: :red))
                  Content.write_char(acc, start_x + x, y, cell.char, cell)
                end)
              end)
            end)
          end)
        end)

      # Wait for all atomic operations to complete
      results = Task.await_many(atomic_ops, 10000)

      # Verify all operations completed successfully
      assert Enum.all?(results, fn result ->
               case result do
                 {:ok, _buffer} -> true
                 :ok -> true
                 _ -> false
               end
             end)

      # Flush to ensure all operations are completed
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
                cell = Cell.new("W", TextFormatting.new(fg: :blue))
                assert :ok = ConcurrentBuffer.set_cell(pid, x, y, cell)
              end)
            end)
          ]
        end)

      # Wait for all operations to complete
      results = Task.await_many(operations, 10_000)

      # Verify all operations completed successfully
      assert Enum.all?(results, fn result ->
               result == :ok
             end)
    end
  end

  describe "Performance Tests" do
    test "handles rapid buffer updates efficiently", %{buffer_pid: pid} do
      # Measure time for rapid updates
      start_time = System.monotonic_time()

      # Perform 1000 rapid updates
      Enum.each(1..1000, fn i ->
        x = rem(i, 80)
        y = div(i, 80)
        cell = Cell.new("X", TextFormatting.new(fg: :blue))
        assert :ok = ConcurrentBuffer.set_cell(pid, x, y, cell)
      end)

      end_time = System.monotonic_time()

      execution_time =
        System.convert_time_unit(end_time - start_time, :native, :millisecond)

      # Assert reasonable performance (adjust threshold as needed)
      assert execution_time < 2000,
             "Rapid updates took too long: #{execution_time}ms"
    end

    test "provides performance metrics", %{buffer_pid: pid} do
      # Perform some operations
      Enum.each(1..100, fn i ->
        x = rem(i, 80)
        y = div(i, 80)
        cell = Cell.new("X", TextFormatting.new(fg: :green))
        ConcurrentBuffer.set_cell(pid, x, y, cell)
      end)

      # Get metrics
      assert {:ok, metrics} = ConcurrentBuffer.get_metrics(pid)

      # Verify metrics structure (new format)
      assert is_map(metrics.operation_counts)
      assert metrics.operation_counts.writes >= 100
      assert metrics.total_operations >= 100
      assert is_number(metrics.average_response_time_us)
    end
  end

  describe "Error Handling" do
    test "handles invalid coordinates gracefully", %{buffer_pid: pid} do
      # Test out of bounds coordinates
      assert {:error, :invalid_coordinates} =
               ConcurrentBuffer.set_cell_sync(pid, 100, 100, Cell.new("X"))

      assert {:error, :invalid_coordinates} =
               ConcurrentBuffer.get_cell(pid, 100, 100)

      assert {:error, :invalid_coordinates} =
               ConcurrentBuffer.set_cell_sync(pid, -1, -1, Cell.new("X"))

      assert {:error, :invalid_coordinates} =
               ConcurrentBuffer.get_cell(pid, -1, -1)
    end

    test "handles invalid operations gracefully", %{buffer_pid: pid} do
      # Test invalid atomic operation
      result =
        ConcurrentBuffer.atomic_operation(pid, fn _buffer ->
          raise "Simulated error"
        end)

      assert {:error, _} = result
    end
  end

  describe "Buffer State Consistency" do
    test "maintains buffer state consistency under concurrent access", %{
      buffer_pid: pid
    } do
      # Write some initial data
      cell = Cell.new("X", TextFormatting.new(fg: :red))
      assert :ok = ConcurrentBuffer.set_cell(pid, 0, 0, cell)

      # Create concurrent readers and writers
      readers =
        Enum.map(1..10, fn _ ->
          Task.async(fn ->
            Enum.each(1..50, fn _ ->
              assert {:ok, _} = ConcurrentBuffer.get_cell(pid, 0, 0)
            end)
          end)
        end)

      writers =
        Enum.map(1..5, fn i ->
          Task.async(fn ->
            Enum.each(1..20, fn j ->
              cell = Cell.new("W#{i}", TextFormatting.new(fg: :blue))
              assert :ok = ConcurrentBuffer.set_cell(pid, i, j, cell)
            end)
          end)
        end)

      # Wait for all operations
      Task.await_many(readers ++ writers, 5000)

      # Verify buffer state is consistent
      assert {:ok, cell} = ConcurrentBuffer.get_cell(pid, 0, 0)
      assert cell.char == "X"
      # Default foreground color
      assert cell.style.foreground == 7

      # Verify some of the written cells
      assert {:ok, cell} = ConcurrentBuffer.get_cell(pid, 1, 1)
      assert String.starts_with?(cell.char, "W")
      # Default foreground color
      assert cell.style.foreground == 7
    end
  end
end

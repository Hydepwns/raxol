defmodule Raxol.Core.Buffer.BufferOperationsTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Buffer
  alias Raxol.Terminal.Buffer.Cell, as: BufferCell
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.Buffer.ConcurrentBuffer
  alias Raxol.Terminal.ANSI.TextFormatting

    setup do
    # Generate a unique name for each test to avoid conflicts
    test_name = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    unique_name = :"BufferServer_#{test_name}"

    # Start a buffer server with unique name
    {:ok, pid} = ConcurrentBuffer.start_server(width: 80, height: 24, name: unique_name)

    # Set up teardown to stop the server after each test
    on_exit(fn ->
      if Process.alive?(pid) do
        ConcurrentBuffer.stop(pid)
      end
    end)

    {:ok, %{buffer_pid: pid, buffer_name: unique_name}}
  end

  describe "Edge Cases" do
    test ~c"handles out of bounds coordinates" do
      buffer = Buffer.new({80, 24})

      # Test negative coordinates
      assert_raise ArgumentError, fn ->
        Buffer.set_cell(buffer, -1, 0, BufferCell.new())
      end

      assert_raise ArgumentError, fn ->
        Buffer.set_cell(buffer, 0, -1, BufferCell.new())
      end

      # Test coordinates beyond buffer dimensions
      assert_raise ArgumentError, fn ->
        Buffer.set_cell(buffer, 81, 0, BufferCell.new())
      end

      assert_raise ArgumentError, fn ->
        Buffer.set_cell(buffer, 0, 25, BufferCell.new())
      end
    end

    test ~c"handles empty buffer operations" do
      assert_raise ArgumentError, fn ->
        Buffer.new({0, 0})
      end
    end

    test ~c"handles buffer resize edge cases" do
      buffer = Buffer.new({80, 24})

      # Test resize to same dimensions
      assert buffer == Buffer.resize(buffer, 80, 24)

      # Test resize to zero dimensions
      assert_raise ArgumentError, fn ->
        Buffer.resize(buffer, 0, 0)
      end

      # Test resize to negative dimensions
      assert_raise ArgumentError, fn ->
        Buffer.resize(buffer, -1, -1)
      end
    end

    test ~c"handles scroll region edge cases" do
      buffer = Buffer.new({80, 24})

      # Test invalid scroll region (top > bottom)
      assert_raise ArgumentError, fn ->
        Buffer.set_scroll_region(buffer, 10, 5)
      end

      # Test scroll region beyond buffer dimensions
      assert_raise ArgumentError, fn ->
        Buffer.set_scroll_region(buffer, 0, 25)
      end

      # Test negative scroll region
      assert_raise ArgumentError, fn ->
        Buffer.set_scroll_region(buffer, -1, 10)
      end
    end
  end

  describe "Performance Tests" do
    test ~c"handles large buffer operations efficiently" do
      # Create a large buffer
      buffer = Buffer.new({200, 100})

      # Measure time for filling the entire buffer
      start_time = System.monotonic_time()

      # Fill buffer with data using efficient fill_region operation
      cell = BufferCell.new("X", TextFormatting.new(foreground: :red))
      _buffer = Buffer.fill_region(buffer, 0, 0, 200, 100, cell)

      end_time = System.monotonic_time()

      execution_time =
        System.convert_time_unit(end_time - start_time, :native, :millisecond)

      # Assert reasonable performance (adjust threshold as needed)
      assert execution_time < 1000,
             "Buffer fill operation took too long: #{execution_time}ms"
    end

    test ~c"handles rapid buffer updates efficiently" do
      buffer = Buffer.new({80, 24})

      # Measure time for rapid updates
      start_time = System.monotonic_time()

              # Perform 1000 rapid updates
        _buffer =
          Enum.reduce(1..1000, buffer, fn i, acc ->
            x = rem(i, 80)
            y = div(i, 80)
            cell = BufferCell.new("X", TextFormatting.new(foreground: :blue))
            Buffer.set_cell(acc, x, y, cell)
          end)

      end_time = System.monotonic_time()

      execution_time =
        System.convert_time_unit(end_time - start_time, :native, :millisecond)

      # Assert reasonable performance
      assert execution_time < 500,
             "Rapid updates took too long: #{execution_time}ms"
    end
  end

  describe "Concurrent Access Tests" do
    test "handles concurrent buffer access safely", %{buffer_pid: pid} do

      # Create multiple processes that access the buffer
      processes =
        Enum.map(1..10, fn _ ->
          Task.async(fn ->
            # Each process performs multiple operations
            Enum.each(0..99, fn i ->
              x = rem(i, 80)
              y = div(i, 80)
              cell = BufferCell.new("X", TextFormatting.new(foreground: :green))
              # Write operations are now asynchronous
              ConcurrentBuffer.set_cell(pid, x, y, cell)
            end)
          end)
        end)

      # Wait for all processes to complete
      results = Task.await_many(processes, 5000)

      # Verify all processes completed successfully
      assert Enum.all?(results, fn result ->
               result == :ok
             end)

      # Flush to ensure all writes are completed
      assert :ok = ConcurrentBuffer.flush(pid)

      # Verify some cells were written
      assert {:ok, cell} = ConcurrentBuffer.get_cell(pid, 0, 0)
      assert cell.char == "X"
      assert Cell.fg(cell) == :green
    end

    test "handles concurrent read/write operations", %{buffer_pid: pid} do

      # Create reader and writer processes
      reader =
        Task.async(fn ->
          Enum.each(1..1000, fn _i ->
            x = :rand.uniform(80) - 1
            y = :rand.uniform(24) - 1
            assert {:ok, _cell} = ConcurrentBuffer.get_cell(pid, x, y)
          end)
        end)

      writer =
        Task.async(fn ->
          Enum.each(1..1000, fn i ->
            x = :rand.uniform(80) - 1
            y = :rand.uniform(24) - 1
            cell = BufferCell.new("X", TextFormatting.new(foreground: :yellow))
            # Write operations are now asynchronous
            ConcurrentBuffer.set_cell(pid, x, y, cell)
          end)
        end)

      # Wait for both processes to complete
      reader_result = Task.await(reader, 5000)
      writer_result = Task.await(writer, 5000)

      # Verify both processes completed successfully
      assert reader_result == :ok
      assert writer_result == :ok

      # Flush to ensure all writes are completed
      assert :ok = ConcurrentBuffer.flush(pid)

      # Write to a specific position and verify it was written correctly
      test_cell = BufferCell.new("X", TextFormatting.new(foreground: :yellow))
      ConcurrentBuffer.set_cell(pid, 10, 10, test_cell)
      assert :ok = ConcurrentBuffer.flush(pid)

      # Verify the cell was written correctly
      assert {:ok, cell} = ConcurrentBuffer.get_cell(pid, 10, 10)
      assert cell.char == "X"
      assert Cell.fg(cell) == :yellow
    end
  end

  describe "Error Handling" do
    test ~c"handles invalid cell data" do
      buffer = Buffer.new({80, 24})

      # Test invalid cell data
      assert_raise ArgumentError, fn ->
        Buffer.set_cell(buffer, 0, 0, "invalid")
      end

      # Test nil cell
      assert_raise ArgumentError, fn ->
        Buffer.set_cell(buffer, 0, 0, nil)
      end
    end

    test ~c"handles invalid buffer operations" do
      buffer = Buffer.new({80, 24})

      # Test invalid write operations
      assert_raise ArgumentError, fn ->
        Buffer.write(buffer, nil)
      end

      # Test invalid read operations
      assert_raise ArgumentError, fn ->
        Buffer.read(buffer, invalid: true)
      end
    end

    test ~c"handles buffer corruption gracefully" do
      buffer = Buffer.new({80, 24})

      # Simulate buffer corruption by directly modifying the struct
      corrupted_buffer = %{buffer | cells: nil}

      # Verify that operations fail gracefully
      assert_raise RuntimeError, "Buffer cells are nil", fn ->
        Buffer.get_cell(corrupted_buffer, 0, 0)
      end
    end
  end
end

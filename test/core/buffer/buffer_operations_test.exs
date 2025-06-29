defmodule Raxol.Core.Buffer.BufferOperationsTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Buffer
  alias Raxol.Terminal.Buffer.Cell
  alias Raxol.Terminal.ANSI.TextFormatting

  describe "Edge Cases" do
    test ~c"handles out of bounds coordinates" do
      buffer = Buffer.new({80, 24})

      # Test negative coordinates
      assert_raise ArgumentError, fn ->
        Buffer.set_cell(buffer, -1, 0, Cell.new())
      end

      assert_raise ArgumentError, fn ->
        Buffer.set_cell(buffer, 0, -1, Cell.new())
      end

      # Test coordinates beyond buffer dimensions
      assert_raise ArgumentError, fn ->
        Buffer.set_cell(buffer, 81, 0, Cell.new())
      end

      assert_raise ArgumentError, fn ->
        Buffer.set_cell(buffer, 0, 25, Cell.new())
      end
    end

    test ~c"handles empty buffer operations" do
      buffer = Buffer.new({0, 0})
      assert Buffer.get_cell(buffer, 0, 0) == Cell.new()
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

      # Fill buffer with data
      buffer =
        Enum.reduce(0..99, buffer, fn y, acc ->
          Enum.reduce(0..199, acc, fn x, acc ->
            cell = Cell.new("X", TextFormatting.new(fg: :red))
            Buffer.set_cell(acc, x, y, cell)
          end)
        end)

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
      buffer =
        Enum.reduce(1..1000, buffer, fn i, acc ->
          x = rem(i, 80)
          y = div(i, 80)
          cell = Cell.new("X", TextFormatting.new(fg: :blue))
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
    test ~c"handles concurrent buffer access safely" do
      buffer = Buffer.new({80, 24})

      # Create multiple processes that access the buffer
      processes =
        Enum.map(1..10, fn _ ->
          Task.async(fn ->
            # Each process performs multiple operations
            Enum.reduce(1..100, buffer, fn i, acc ->
              x = rem(i, 80)
              y = div(i, 80)
              cell = Cell.new("X", TextFormatting.new(fg: :green))
              Buffer.set_cell(acc, x, y, cell)
            end)
          end)
        end)

      # Wait for all processes to complete
      results = Task.await_many(processes, 5000)

      # Verify all processes completed successfully (returned buffer structs)
      assert Enum.all?(results, fn result ->
               is_struct(result, Raxol.Terminal.Buffer)
             end)
    end

    test ~c"handles concurrent read/write operations" do
      buffer = Buffer.new({80, 24})

      # Create reader and writer processes
      reader =
        Task.async(fn ->
          Enum.reduce(1..1000, buffer, fn _, acc ->
            x = :rand.uniform(80) - 1
            y = :rand.uniform(24) - 1
            Buffer.get_cell(acc, x, y)
            acc
          end)
        end)

      writer =
        Task.async(fn ->
          Enum.reduce(1..1000, buffer, fn i, acc ->
            x = :rand.uniform(80) - 1
            y = :rand.uniform(24) - 1
            cell = Cell.new("X", TextFormatting.new(fg: :yellow))
            Buffer.set_cell(acc, x, y, cell)
          end)
        end)

      # Wait for both processes to complete
      reader_result = Task.await(reader, 5000)
      writer_result = Task.await(writer, 5000)

      # Verify both processes completed successfully (returned buffer structs)
      assert is_struct(reader_result, Raxol.Terminal.Buffer)
      assert is_struct(writer_result, Raxol.Terminal.Buffer)
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
      assert_raise Protocol.UndefinedError, fn ->
        Buffer.get_cell(corrupted_buffer, 0, 0)
      end
    end
  end
end

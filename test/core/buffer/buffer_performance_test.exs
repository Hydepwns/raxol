defmodule Raxol.Core.Buffer.BufferPerformanceTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Buffer
  alias Raxol.Terminal.Buffer.Cell
  alias Raxol.Terminal.ANSI.TextFormatting

  @moduledoc """
  Performance benchmarks for buffer operations.
  These tests measure the performance of various buffer operations
  under different conditions and load patterns.
  """

  # Helper function to fill buffer with cells
  defp fill_buffer(buffer, width, height, char \\ "X", color \\ :red) do
    Enum.reduce(0..(height - 1), buffer, fn y, acc ->
      Enum.reduce(0..(width - 1), acc, fn x, acc ->
        cell = Cell.new(char, TextFormatting.new(foreground: color))
        Buffer.set_cell(acc, x, y, cell)
      end)
    end)
  end

  describe "Buffer Fill Performance" do
    test ~c"measures performance of filling large buffers" do
      sizes = [
        # Standard terminal
        {80, 24},
        # Large terminal
        {200, 100},
        # Very large buffer
        {500, 500}
      ]

      Enum.each(sizes, fn {width, height} ->
        buffer = Buffer.new({width, height})

        # Measure fill performance
        {time, _} =
          :timer.tc(fn ->
            fill_buffer(buffer, width, height)
          end)

        # Convert to milliseconds
        time_ms = time / 1000

        # Log performance metrics
        IO.puts("Fill performance for #{width}x#{height}: #{time_ms}ms")

        # Assert reasonable performance
        # 0.1ms per cell
        max_time = width * height * 0.1

        assert time_ms < max_time,
               "Fill operation too slow: #{time_ms}ms (max: #{max_time}ms)"
      end)
    end

    test ~c"measures performance of partial buffer updates" do
      buffer = Buffer.new({200, 100})

      # Test different update patterns
      patterns = [
        # Small region
        {10, 10},
        # Medium region
        {50, 50},
        # Large region
        {100, 100}
      ]

      Enum.each(patterns, fn {width, height} ->
        {time, _} =
          :timer.tc(fn ->
            fill_buffer(buffer, width, height, "X", :blue)
          end)

        time_ms = time / 1000

        IO.puts(
          "Partial update performance for #{width}x#{height}: #{time_ms}ms"
        )

        max_time = width * height * 0.1

        assert time_ms < max_time,
               "Partial update too slow: #{time_ms}ms (max: #{max_time}ms)"
      end)
    end
  end

  describe "Buffer Read Performance" do
    test ~c"measures performance of reading from large buffers" do
      buffer = Buffer.new({200, 100})

      # Fill buffer with data
      buffer = fill_buffer(buffer, 200, 100, "X", :green)

      # Measure read performance
      {time, _} =
        :timer.tc(fn ->
          Enum.each(0..99, fn y ->
            Enum.each(0..199, fn x ->
              Buffer.get_cell(buffer, x, y)
            end)
          end)
        end)

      time_ms = time / 1000
      IO.puts("Read performance for 200x100: #{time_ms}ms")

      # 0.05ms per cell
      max_time = 200 * 100 * 0.05

      assert time_ms < max_time,
             "Read operation too slow: #{time_ms}ms (max: #{max_time}ms)"
    end
  end

  describe "Buffer Scroll Performance" do
    test ~c"measures performance of scrolling operations" do
      buffer = Buffer.new({80, 24})

      # Fill buffer with data
      buffer = fill_buffer(buffer, 80, 24, "X", :yellow)

      # Test different scroll amounts
      scroll_amounts = [1, 5, 10, 20]

      Enum.each(scroll_amounts, fn amount ->
        {time, result} =
          :timer.tc(fn ->
            Buffer.scroll_state(buffer, amount)
          end)

        # Ensure we got a valid result
        assert is_struct(result, Raxol.Terminal.Buffer)

        time_ms = time / 1000
        IO.puts("Scroll performance for #{amount} lines: #{time_ms}ms")

        # 0.5ms per line
        max_time = amount * 0.5

        assert time_ms < max_time,
               "Scroll operation too slow: #{time_ms}ms (max: #{max_time}ms)"
      end)
    end
  end

  describe "Memory Usage" do
    test ~c"measures memory usage of buffer operations" do
      sizes = [
        # Standard terminal
        {80, 24},
        # Large terminal
        {200, 100},
        # Very large buffer
        {500, 500}
      ]

      Enum.each(sizes, fn {width, height} ->
        # Measure memory before
        :erlang.garbage_collect()
        before = :erlang.memory(:total)

        # Create and fill buffer
        buffer = Buffer.new({width, height})
        _buffer = fill_buffer(buffer, width, height)

        # Measure memory after
        :erlang.garbage_collect()
        after_ = :erlang.memory(:total)

        # Calculate memory usage
        memory_usage = after_ - before
        memory_per_cell = memory_usage / (width * height)

        IO.puts(
          "Memory usage for #{width}x#{height}: #{memory_usage} bytes (#{memory_per_cell} bytes per cell)"
        )

        # Assert reasonable memory usage
        # 6000 bytes per cell (allowing for struct overhead, maps, and Erlang memory management)
        max_memory_per_cell = 6000

        assert memory_per_cell < max_memory_per_cell,
               "Memory usage too high: #{memory_per_cell} bytes per cell (max: #{max_memory_per_cell})"
      end)
    end
  end
end

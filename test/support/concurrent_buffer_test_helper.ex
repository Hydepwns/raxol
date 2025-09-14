defmodule ConcurrentBufferTestHelper do
  @moduledoc """
  Shared helper functions for concurrent buffer tests.

  This module contains common functions used across different concurrent
  buffer test modules to avoid code duplication and ensure consistent
  test behavior.
  """

  alias Raxol.Terminal.Buffer.ConcurrentBuffer
  alias Raxol.Terminal.Buffer.Cell
  alias Raxol.Terminal.ANSI.TextFormatting

  @doc """
  Creates a unique buffer server for testing.

  Generates a unique name using crypto random bytes and starts a buffer server
  with standard test dimensions (80x24).

  ## Parameters

  - `prefix` - String prefix for the unique name (defaults to "TestBuffer")

  ## Returns

  `{:ok, %{buffer_pid: pid, buffer_name: unique_name}}`
  """
  def setup_unique_buffer(prefix \\ "TestBuffer") do
    test_name = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    unique_name = :"#{prefix}_#{test_name}"

    {:ok, pid} =
      ConcurrentBuffer.start_server(width: 80, height: 24, name: unique_name)

    {:ok, %{buffer_pid: pid, buffer_name: unique_name}}
  end

  @doc """
  Tears down buffer server safely.

  Stops the buffer server if it's still alive.
  """
  def teardown_buffer(pid) do
    if Process.alive?(pid) do
      ConcurrentBuffer.stop(pid)
    end
  end

  @doc """
  Creates multiple concurrent writer tasks.

  ## Parameters

  - `pid` - Buffer server PID
  - `writer_count` - Number of writer tasks to create
  - `regions` - Whether writers should write to different regions (default: true)
  - `iterations` - Number of write operations per writer (default: 100)

  ## Returns

  List of Task structs
  """
  def create_concurrent_writers(pid, writer_count, opts \\ []) do
    regions = Keyword.get(opts, :regions, true)
    iterations = Keyword.get(opts, :iterations, 100)
    color = Keyword.get(opts, :color, :red)

    Enum.map(1..writer_count, fn writer_id ->
      Task.async(fn ->
        {start_x, start_y, width, height} =
          get_writer_region(writer_id, regions)

        Enum.each(0..(height - 1), fn y ->
          Enum.each(0..(width - 1), fn x ->
            if iterations > 0 do
              cell = Cell.new("W", TextFormatting.new(foreground: color))
              ConcurrentBuffer.set_cell(pid, start_x + x, start_y + y, cell)
            end
          end)
        end)
      end)
    end)
  end

  @doc """
  Creates multiple concurrent reader tasks.

  ## Parameters

  - `pid` - Buffer server PID  
  - `reader_count` - Number of reader tasks to create
  - `iterations` - Number of read operations per reader (default: 100)

  ## Returns

  List of Task structs
  """
  def create_concurrent_readers(pid, reader_count, iterations \\ 100) do
    Enum.map(1..reader_count, fn _reader_id ->
      Task.async(fn ->
        Enum.each(1..iterations, fn _ ->
          x = :rand.uniform(80) - 1
          y = :rand.uniform(24) - 1
          {:ok, _cell} = ConcurrentBuffer.get_cell(pid, x, y)
        end)
      end)
    end)
  end

  @doc """
  Creates mixed concurrent operations (readers, writers, scrollers, region fillers).

  ## Parameters

  - `pid` - Buffer server PID
  - `opts` - Options for operation configuration

  ## Returns

  List of Task structs with mixed operations
  """
  def create_mixed_operations(pid, opts \\ []) do
    read_iterations = Keyword.get(opts, :read_iterations, 100)
    write_iterations = Keyword.get(opts, :write_iterations, 100)
    scroll_iterations = Keyword.get(opts, :scroll_iterations, 20)
    fill_iterations = Keyword.get(opts, :fill_iterations, 10)

    [
      # Reader
      Task.async(fn ->
        Enum.each(1..read_iterations, fn _ ->
          x = :rand.uniform(80) - 1
          y = :rand.uniform(24) - 1
          {:ok, _cell} = ConcurrentBuffer.get_cell(pid, x, y)
        end)
      end),

      # Writer
      Task.async(fn ->
        Enum.each(1..write_iterations, fn _i ->
          x = :rand.uniform(80) - 1
          y = :rand.uniform(24) - 1
          cell = Cell.new("W", TextFormatting.new(foreground: :yellow))
          ConcurrentBuffer.set_cell(pid, x, y, cell)
        end)
      end),

      # Scroller
      Task.async(fn ->
        Enum.each(1..scroll_iterations, fn _ ->
          ConcurrentBuffer.scroll(pid, 1)
        end)
      end),

      # Region filler
      Task.async(fn ->
        Enum.each(1..fill_iterations, fn i ->
          x = rem(i, 8) * 10
          y = div(i, 8) * 3
          cell = Cell.new("F", TextFormatting.new(foreground: :red))
          ConcurrentBuffer.fill_region(pid, x, y, 10, 3, cell)
        end)
      end)
    ]
  end

  @doc """
  Creates a stress test with many concurrent operations.

  ## Parameters

  - `pid` - Buffer server PID
  - `operation_count` - Number of operation pairs to create (default: 20)
  - `iterations_per_op` - Iterations per operation (default: 50)

  ## Returns

  List of Task structs for stress testing
  """
  def create_stress_operations(
        pid,
        operation_count \\ 20,
        iterations_per_op \\ 50
      ) do
    Enum.flat_map(1..operation_count, fn _i ->
      [
        # Reader
        Task.async(fn ->
          Enum.each(1..iterations_per_op, fn _ ->
            x = :rand.uniform(80) - 1
            y = :rand.uniform(24) - 1
            {:ok, _cell} = ConcurrentBuffer.get_cell(pid, x, y)
          end)
        end),

        # Writer
        Task.async(fn ->
          Enum.each(1..iterations_per_op, fn _j ->
            x = :rand.uniform(80) - 1
            y = :rand.uniform(24) - 1
            cell = Cell.new("W", TextFormatting.new(foreground: :blue))
            ConcurrentBuffer.set_cell(pid, x, y, cell)
          end)
        end)
      ]
    end)
  end

  @doc """
  Waits for all tasks to complete and verifies results.

  ## Parameters

  - `tasks` - List of Task structs
  - `timeout` - Timeout in milliseconds (default: 5000)

  ## Returns

  `:ok` if all tasks completed successfully
  """
  def await_and_verify_tasks(tasks, timeout \\ 5000) do
    results = Task.await_many(tasks, timeout)

    # Verify all tasks completed successfully
    all_ok =
      Enum.all?(results, fn result ->
        case result do
          :ok -> true
          {:ok, _} -> true
          _ -> false
        end
      end)

    if all_ok do
      :ok
    else
      {:error, :some_tasks_failed}
    end
  end

  @doc """
  Verifies basic cell content after concurrent operations.

  ## Parameters

  - `pid` - Buffer server PID
  - `x` - X coordinate to check
  - `y` - Y coordinate to check
  - `expected_char` - Expected character content

  ## Returns

  `:ok` if verification passes, `{:error, reason}` otherwise
  """
  def verify_cell_content(pid, x, y, expected_char) do
    case ConcurrentBuffer.get_cell(pid, x, y) do
      {:ok, cell} ->
        if cell.char == expected_char do
          :ok
        else
          {:error, "Expected char '#{expected_char}', got '#{cell.char}'"}
        end

      error ->
        error
    end
  end

  # Private helper functions

  defp get_writer_region(writer_id, true) do
    # Different regions for each writer
    start_x = rem(writer_id, 8) * 10
    start_y = div(writer_id, 8) * 3
    {start_x, start_y, 10, 3}
  end

  defp get_writer_region(_writer_id, false) do
    # Same region for all writers (overlap testing)
    {0, 0, 5, 5}
  end
end

#!/usr/bin/env elixir

# Terminal Memory Benchmark
# Tests memory usage patterns for terminal operations

Mix.install([
  {:benchee, "~> 1.1"},
  {:jason, "~> 1.4"}
])

# Add project lib path
Code.append_path("lib")

defmodule TerminalMemoryBenchmark do
  @moduledoc """
  Memory benchmarks for terminal operations.

  This benchmark suite tests memory usage patterns for:
  - Buffer operations (creation, updates, rendering)
  - ANSI sequence processing
  - Cursor management
  - Large terminal operations
  """

  alias Raxol.Terminal.{Buffer, ANSI.AnsiParser, Cursor.Manager}

  def run_benchmarks(opts \\ []) do
    config = [
      time: 3,
      memory_time: 2,
      warmup: 1,
      formatters: [
        Benchee.Formatters.HTML,
        Benchee.Formatters.Console,
        {Benchee.Formatters.JSON, file: "bench/output/terminal_memory.json"}
      ]
    ] |> Keyword.merge(opts)

    IO.puts("Running Terminal Memory Benchmarks...")
    IO.puts("Config: #{inspect(config)}")

    Benchee.run(
      %{
        "small_buffer_create" => fn -> create_small_buffer() end,
        "medium_buffer_create" => fn -> create_medium_buffer() end,
        "large_buffer_create" => fn -> create_large_buffer() end,
        "buffer_write_operations" => fn -> buffer_write_operations() end,
        "ansi_sequence_processing" => fn -> ansi_sequence_processing() end,
        "cursor_management" => fn -> cursor_management_operations() end,
        "large_screen_render" => fn -> large_screen_render() end,
        "memory_intensive_ops" => fn -> memory_intensive_operations() end
      },
      config
    )
  end

  # Small buffer (80x24 - typical terminal size)
  defp create_small_buffer do
    {:ok, buffer} = Buffer.create(80, 24)
    buffer
  end

  # Medium buffer (120x40 - larger terminal)
  defp create_medium_buffer do
    {:ok, buffer} = Buffer.create(120, 40)
    buffer
  end

  # Large buffer (200x60 - very large terminal)
  defp create_large_buffer do
    {:ok, buffer} = Buffer.create(200, 60)
    buffer
  end

  # Test buffer write operations
  defp buffer_write_operations do
    {:ok, buffer} = Buffer.create(80, 24)

    # Write multiple lines
    Enum.reduce(1..10, buffer, fn line_num, acc_buffer ->
      content = "Line #{line_num}: #{String.duplicate("test ", 10)}"
      case Buffer.write_at(acc_buffer, 0, line_num - 1, content) do
        {:ok, new_buffer} -> new_buffer
        _ -> acc_buffer
      end
    end)
  end

  # Test ANSI sequence processing memory usage
  defp ansi_sequence_processing do
    sequences = [
      "\e[31mRed text\e[0m",
      "\e[1;32mBold green\e[0m",
      "\e[4;34mUnderlined blue\e[0m",
      "\e[7;35mReverse magenta\e[0m",
      "\e[48;5;214mOrange background\e[0m"
    ]

    Enum.map(sequences, fn seq ->
      AnsiParser.parse(seq)
    end)
  end

  # Test cursor management operations
  defp cursor_management_operations do
    {:ok, cursor} = Manager.new()

    # Perform various cursor operations
    cursor
    |> Manager.move_to(10, 5)
    |> Manager.move_relative(5, 3)
    |> Manager.move_to_column(20)
    |> Manager.move_to_row(15)
    |> Manager.save_position()
    |> Manager.restore_position()
  end

  # Test large screen rendering
  defp large_screen_render do
    {:ok, buffer} = Buffer.create(200, 60)

    # Fill buffer with content
    filled_buffer = Enum.reduce(0..59, buffer, fn row, acc_buffer ->
      content = String.duplicate("█", 200)
      case Buffer.write_at(acc_buffer, 0, row, content) do
        {:ok, new_buffer} -> new_buffer
        _ -> acc_buffer
      end
    end)

    # Render the buffer
    Buffer.render(filled_buffer)
  end

  # Memory intensive operations that stress the system
  defp memory_intensive_operations do
    # Create multiple buffers
    buffers = Enum.map(1..5, fn _i ->
      {:ok, buffer} = Buffer.create(100, 30)
      buffer
    end)

    # Process complex ANSI sequences
    complex_sequences = Enum.map(1..100, fn i ->
      "\e[#{rem(i, 8) + 30}m\e[#{rem(i, 2) + 1}mComplex #{i}\e[0m"
    end)

    parsed_sequences = Enum.map(complex_sequences, &AnsiParser.parse/1)

    # Return both to ensure they're not garbage collected during benchmark
    {buffers, parsed_sequences}
  end
end

# Parse command line arguments
{opts, _args, _invalid} = OptionParser.parse(System.argv(),
  switches: [
    json: :boolean,
    time: :integer,
    memory_time: :integer,
    warmup: :integer
  ]
)

# Configure benchmark options
benchmark_opts = []

if opts[:json] do
  benchmark_opts = Keyword.put(benchmark_opts, :formatters, [
    {Benchee.Formatters.JSON, file: "/dev/stdout"}
  ])
end

if opts[:time] do
  benchmark_opts = Keyword.put(benchmark_opts, :time, opts[:time])
end

if opts[:memory_time] do
  benchmark_opts = Keyword.put(benchmark_opts, :memory_time, opts[:memory_time])
end

if opts[:warmup] do
  benchmark_opts = Keyword.put(benchmark_opts, :warmup, opts[:warmup])
end

# Ensure output directory exists
File.mkdir_p("bench/output")

# Run the benchmarks
try do
  TerminalMemoryBenchmark.run_benchmarks(benchmark_opts)
rescue
  error ->
    IO.puts("Error running terminal memory benchmarks: #{inspect(error)}")
    System.halt(1)
end
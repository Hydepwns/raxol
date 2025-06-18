defmodule Raxol.Terminal.ANSI.Benchmark do
  @moduledoc '''
  Provides benchmarking capabilities for the ANSI handling system.
  Measures performance of parsing and processing ANSI sequences.
  '''

  alias Raxol.Terminal.ANSI.Parser

  @doc '''
  Runs a benchmark suite on the ANSI handling system.
  Returns a map of benchmark results.
  '''
  @spec run_benchmark() :: map()
  def run_benchmark do
    %{
      parse_benchmark: benchmark_parsing(),
      process_benchmark: benchmark_processing(),
      state_machine_benchmark: benchmark_state_machine()
    }
  end

  @doc '''
  Benchmarks the parsing performance with various ANSI sequences.
  '''
  @spec benchmark_parsing() :: map()
  def benchmark_parsing do
    sequences = generate_test_sequences()
    iterations = 1000

    {parse_time, _} =
      :timer.tc(fn ->
        Enum.each(1..iterations, fn _ ->
          process_parsing_iteration(sequences)
        end)
      end)

    %{
      total_time_ms: parse_time / 1000,
      iterations: iterations,
      sequences_per_second:
        iterations * length(sequences) / (parse_time / 1_000_000),
      average_time_per_sequence_ms:
        parse_time / (iterations * length(sequences)) / 1000
    }
  end

  defp process_parsing_iteration(sequences) do
    Enum.each(sequences, &Parser.parse/1)
  end

  @doc '''
  Benchmarks the processing performance with various ANSI sequences.
  '''
  @spec benchmark_processing() :: map()
  def benchmark_processing do
    sequences = generate_test_sequences()
    iterations = 1000

    {process_time, _} =
      :timer.tc(fn ->
        Enum.each(1..iterations, fn _ -> process_iteration(sequences) end)
      end)

    %{
      total_time_ms: process_time / 1000,
      iterations: iterations,
      sequences_per_second:
        iterations * length(sequences) / (process_time / 1_000_000),
      average_time_per_sequence_ms:
        process_time / (iterations * length(sequences)) / 1000
    }
  end

  defp process_iteration(sequences) do
    Enum.each(sequences, fn seq ->
      Parser.parse(seq)
      # If you need to process the result, do so here
    end)
  end

  @doc '''
  Benchmarks the state machine performance with various inputs.
  '''
  @spec benchmark_state_machine() :: map()
  def benchmark_state_machine do
    inputs = generate_test_inputs()
    iterations = 1000

    {state_machine_time, _} =
      :timer.tc(fn ->
        # Placeholder: simulate state machine processing
        Enum.each(1..iterations, fn _ ->
          Enum.each(inputs, fn input -> :ok end)
        end)
      end)

    %{
      total_time_ms: state_machine_time / 1000,
      iterations: iterations,
      inputs_per_second:
        iterations * length(inputs) / (state_machine_time / 1_000_000),
      average_time_per_input_ms:
        state_machine_time / (iterations * length(inputs)) / 1000
    }
  end

  defp generate_test_sequences do
    [
      "Hello, World!",
      "\e[1;1H\e[2;3H\e[3;4H",
      "\e[1m\e[31m\e[42mBold Red on Green\e[0m",
      "\e[2J\e[K\e[2K",
      "\e[1;31m\e[42m\e[1;1H\e[2JHello\e[0m",
      "\e[1mBold\e[0m\e[4mUnderline\e[0m\e[7mInverse\e[0m",
      # OSC sequences
      "\e]0;Window Title\a\e]1;Icon Name\a",
      # Character set designation
      "\e(0\e)B",
      # Mixed content
      "Normal text\e[1mBold text\e[0m\e[4mUnderlined\e[0m"
    ]
  end

  defp generate_test_inputs do
    [
      # Small input
      "Hello",
      # Medium input with some sequences
      "Hello\e[1mWorld\e[0m",
      # Large input with many sequences
      String.duplicate("Hello\e[1mWorld\e[0m", 10),
      # Input with invalid sequences
      "Hello\e[invalid\e[1mWorld\e[0m",
      # Input with mixed content
      "Normal\e[1mBold\e[0m\e[4mUnderline\e[0m\e[7mInverse\e[0m"
    ]
  end
end

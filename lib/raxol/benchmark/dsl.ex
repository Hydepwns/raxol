defmodule Raxol.Benchmark.DSL do
  @moduledoc """
  Domain-specific language for defining benchmarks in an idiomatic Elixir way.

  This is a simplified implementation that avoids compile-time function storage issues.
  Benchmarks are defined as regular module functions for better compatibility.
  """

  defmacro __using__(_opts) do
    quote do
      import Raxol.Benchmark.DSL

      # Default implementation - override in your module
      def run_benchmarks(opts \\ []) do
        IO.puts(
          "No benchmarks defined. Use the DSL macros to define benchmarks."
        )

        :ok
      end

      def list_suites do
        []
      end
    end
  end

  @doc """
  Define a simple benchmark function.
  This creates a module function that can be called by benchmarking tools.
  """
  defmacro benchmark(name, do: block) do
    fun_name = String.to_atom("benchmark_#{name}")

    quote do
      def unquote(fun_name)() do
        unquote(block)
      end
    end
  end

  @doc """
  Define a benchmark with setup.
  """
  defmacro benchmark_with_setup(name, setup_block, do: benchmark_block) do
    fun_name = String.to_atom("benchmark_#{name}")

    quote do
      def unquote(fun_name)() do
        context = unquote(setup_block)
        var!(context) = context
        unquote(benchmark_block)
      end
    end
  end
end

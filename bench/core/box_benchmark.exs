defmodule Raxol.Core.BoxBenchmark do
  @moduledoc """
  Benchmarks for Raxol.Core.Box module.
  Verifies that all operations complete within < 1ms target.

  Run with: mix run bench/core/box_benchmark.exs
  """

  alias Raxol.Core.{Buffer, Box}

  def run do
    IO.puts("\n=== Raxol.Core.Box Benchmarks ===\n")

    buffer = Buffer.create_blank_buffer(80, 24)

    benchmarks = [
      {"draw_box (single style)", fn -> Box.draw_box(buffer, 10, 5, 30, 10, :single) end},
      {"draw_box (double style)", fn -> Box.draw_box(buffer, 10, 5, 30, 10, :double) end},
      {"draw_box (rounded style)", fn -> Box.draw_box(buffer, 10, 5, 30, 10, :rounded) end},
      {"draw_box (heavy style)", fn -> Box.draw_box(buffer, 10, 5, 30, 10, :heavy) end},
      {"draw_box (dashed style)", fn -> Box.draw_box(buffer, 10, 5, 30, 10, :dashed) end},
      {"draw_horizontal_line (20 chars)", fn ->
        Box.draw_horizontal_line(buffer, 10, 5, 20)
      end},
      {"draw_vertical_line (10 chars)", fn -> Box.draw_vertical_line(buffer, 10, 5, 10) end},
      {"fill_area (10x10)", fn -> Box.fill_area(buffer, 10, 5, 10, 10, "#") end},
      {"fill_area (entire buffer)", fn -> Box.fill_area(buffer, 0, 0, 80, 24, " ") end},
      {"complex scene (multiple boxes)", fn ->
        buffer
        |> Box.draw_box(5, 3, 30, 10, :double)
        |> Box.draw_box(40, 8, 25, 12, :single)
        |> Box.draw_horizontal_line(0, 0, 80)
        |> Box.fill_area(6, 4, 28, 8, ".")
      end}
    ]

    target_us = 1000

    results =
      Enum.map(benchmarks, fn {name, fun} ->
        {time_us, _result} = measure_us(fun)
        status = if time_us < target_us, do: "PASS", else: "FAIL"
        IO.puts("#{status} | #{String.pad_trailing(name, 40)} | #{time_us} us")
        {name, time_us}
      end)

    IO.puts("\n=== Summary ===")
    IO.puts("Target: < #{target_us} us per operation")

    total_us = results |> Enum.map(fn {_, t} -> t end) |> Enum.sum()
    avg_us = div(total_us, length(results))

    IO.puts("Average: #{avg_us} us")

    failures =
      Enum.filter(results, fn {_, time} -> time >= target_us end)

    if Enum.empty?(failures) do
      IO.puts("\nAll benchmarks PASSED!")
    else
      IO.puts("\n#{length(failures)} benchmark(s) exceeded target:")

      Enum.each(failures, fn {name, time} ->
        IO.puts("  - #{name}: #{time} us (#{time - target_us} us over)")
      end)
    end

    IO.puts("")
  end

  defp measure_us(fun) do
    start = System.monotonic_time(:microsecond)
    result = fun.()
    finish = System.monotonic_time(:microsecond)
    {finish - start, result}
  end
end

Raxol.Core.BoxBenchmark.run()

defmodule Raxol.Performance.CycleProfiler.Stats do
  @moduledoc """
  Pure functions for computing statistics from cycle profiler timing data.

  Computes min, max, average, and percentile (p50, p95, p99) values from
  lists of timing measurements. Used by CycleProfiler to summarize
  update and render cycle performance.
  """

  @type timing_stats :: %{
          count: non_neg_integer(),
          min: number(),
          max: number(),
          avg: float(),
          p50: number(),
          p95: number(),
          p99: number()
        }

  @doc """
  Computes statistics for a list of numeric values (microseconds).

  Returns a map with count, min, max, avg, p50, p95, p99.
  Returns nil for an empty list.
  """
  @spec compute([number()]) :: timing_stats() | nil
  def compute([]), do: nil

  def compute(values) when is_list(values) do
    sorted = Enum.sort(values)
    count = length(sorted)

    %{
      count: count,
      min: List.first(sorted),
      max: List.last(sorted),
      avg: Enum.sum(sorted) / count,
      p50: percentile(sorted, count, 50),
      p95: percentile(sorted, count, 95),
      p99: percentile(sorted, count, 99)
    }
  end

  @doc """
  Formats a timing_stats map into a human-readable report string.
  """
  @spec format_report(timing_stats() | nil, String.t()) :: String.t()
  def format_report(nil, label), do: "#{label}: no data"

  def format_report(stats, label) do
    "#{label}: avg=#{format_us(stats.avg)} " <>
      "min=#{format_us(stats.min)} max=#{format_us(stats.max)} " <>
      "p50=#{format_us(stats.p50)} p95=#{format_us(stats.p95)} p99=#{format_us(stats.p99)} " <>
      "(n=#{stats.count})"
  end

  @doc """
  Computes statistics for multiple named fields extracted from a list of structs/maps.

  ## Parameters
    - `entries` - List of maps/structs
    - `fields` - List of field keys to extract and compute stats for

  ## Returns
    Map of `%{field_name => timing_stats()}`.
  """
  @spec compute_multi([map()], [atom()]) :: %{atom() => timing_stats() | nil}
  def compute_multi(entries, fields)
      when is_list(entries) and is_list(fields) do
    Map.new(fields, fn field ->
      values =
        entries
        |> Enum.map(&Map.get(&1, field))
        |> Enum.reject(&is_nil/1)

      {field, compute(values)}
    end)
  end

  # -- Private --

  defp percentile(sorted, count, p) do
    index = Float.ceil(count * p / 100) - 1
    Enum.at(sorted, max(0, trunc(index)))
  end

  defp format_us(value) when is_float(value) do
    cond do
      value >= 1_000_000 -> "#{Float.round(value / 1_000_000, 2)}s"
      value >= 1_000 -> "#{Float.round(value / 1_000, 2)}ms"
      true -> "#{Float.round(value, 1)}us"
    end
  end

  defp format_us(value) when is_integer(value) do
    format_us(value * 1.0)
  end
end

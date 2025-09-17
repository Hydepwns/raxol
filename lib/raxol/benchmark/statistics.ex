defmodule Raxol.Benchmark.Statistics do
  @moduledoc """
  Common statistical functions for benchmark analysis.
  """

  @doc """
  Calculate the variance of a list of values.
  """
  @spec calculate_variance([number()]) :: float()
  def calculate_variance(values) when length(values) > 1 do
    mean = Enum.sum(values) / length(values)

    sum_squared_diffs =
      values
      |> Enum.map(fn val -> (val - mean) * (val - mean) end)
      |> Enum.sum()

    sum_squared_diffs / length(values)
  end

  def calculate_variance(_), do: 0.0

  @doc """
  Calculate the standard deviation of a list of values.
  """
  @spec calculate_std_dev([number()]) :: float()
  def calculate_std_dev(values) when length(values) > 1 do
    values
    |> calculate_variance()
    |> :math.sqrt()
  end

  def calculate_std_dev(_), do: 0.0

  @doc """
  Calculate the mean of a list of values.
  """
  @spec calculate_mean([number()]) :: float()
  def calculate_mean([]), do: 0.0

  def calculate_mean(values) do
    Enum.sum(values) / length(values)
  end

  @doc """
  Calculate the median of a list of values.
  """
  @spec calculate_median([number()]) :: float()
  def calculate_median([]), do: 0.0

  def calculate_median(values) do
    sorted = Enum.sort(values)
    mid = div(length(sorted), 2)

    case rem(length(sorted), 2) do
      0 ->
        (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2

      _ ->
        Enum.at(sorted, mid)
    end
  end

  @doc """
  Calculate percentiles from a list of values.
  """
  @spec calculate_percentile([number()], number()) :: float()
  def calculate_percentile([], _percentile), do: 0.0

  def calculate_percentile(values, percentile)
      when percentile >= 0 and percentile <= 100 do
    sorted = Enum.sort(values)
    k = percentile / 100 * length(sorted)
    lower = trunc(k)
    upper = lower + 1

    cond do
      upper >= length(sorted) ->
        Enum.at(sorted, -1)

      k == lower ->
        Enum.at(sorted, lower)

      true ->
        lower_val = Enum.at(sorted, lower)
        upper_val = Enum.at(sorted, upper)
        lower_val + (k - lower) * (upper_val - lower_val)
    end
  end
end

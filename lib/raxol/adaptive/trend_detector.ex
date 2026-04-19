defmodule Raxol.Adaptive.TrendDetector do
  @moduledoc """
  Pure functional trend detection across aggregate windows.

  Computes per-pane slopes for dwell, command, and scroll metrics
  over the last N aggregates. Returns a map of pane_id to trend data.

  No GenServer -- call from LayoutRecommender before applying rules.
  """

  @type trend :: %{
          dwell_trend: float(),
          command_trend: float(),
          scroll_trend: float()
        }

  @type trends :: %{atom() => trend()}

  @doc """
  Compute per-pane trends from a list of aggregates (newest first).

  Returns `%{pane_id => %{dwell_trend: slope, command_trend: slope, scroll_trend: slope}}`.
  Slopes are per-window change rates. Positive = increasing, negative = decreasing.
  Requires at least 2 aggregates; returns empty map otherwise.
  """
  @spec compute([map()]) :: trends()
  def compute(aggregates) when length(aggregates) < 2, do: %{}

  def compute(aggregates) do
    # Reverse so oldest is first (index 0 = oldest)
    ordered = Enum.reverse(aggregates)
    pane_ids = extract_all_pane_ids(ordered)

    Map.new(pane_ids, fn pane_id ->
      dwell_series = extract_series(ordered, pane_id, :pane_dwell_times)
      command_series = extract_series(ordered, pane_id, :command_concentration)
      scroll_series = extract_series(ordered, pane_id, :scroll_frequency)

      {pane_id,
       %{
         dwell_trend: linear_slope(dwell_series),
         command_trend: linear_slope(command_series),
         scroll_trend: linear_slope(scroll_series)
       }}
    end)
  end

  @doc """
  Check if a pane's dwell is trending upward despite currently being low.

  Useful for suppressing hide recommendations on panes gaining importance.
  """
  @spec rising?(trends(), atom(), keyword()) :: boolean()
  def rising?(trends, pane_id, opts \\ []) do
    min_slope = Keyword.get(opts, :min_slope, 0.01)

    case Map.get(trends, pane_id) do
      %{dwell_trend: slope} when slope >= min_slope -> true
      _ -> false
    end
  end

  # -- Private --

  defp extract_all_pane_ids(aggregates) do
    aggregates
    |> Enum.flat_map(fn agg ->
      dwell_keys = agg |> Map.get(:pane_dwell_times, %{}) |> Map.keys()
      cmd_keys = agg |> Map.get(:command_concentration, %{}) |> Map.keys()
      scroll_keys = agg |> Map.get(:scroll_frequency, %{}) |> Map.keys()
      dwell_keys ++ cmd_keys ++ scroll_keys
    end)
    |> Enum.uniq()
  end

  defp extract_series(aggregates, pane_id, field) do
    Enum.map(aggregates, fn agg ->
      agg
      |> Map.get(field, %{})
      |> Map.get(pane_id, 0)
      |> to_float()
    end)
  end

  defp to_float(n) when is_float(n), do: n
  defp to_float(n) when is_integer(n), do: n * 1.0

  @doc false
  @spec linear_slope([float()]) :: float()
  def linear_slope([]), do: 0.0
  def linear_slope([_]), do: 0.0

  def linear_slope(values) do
    n = length(values)
    xs = Enum.to_list(0..(n - 1))

    sum_x = Enum.sum(xs) * 1.0
    sum_y = Enum.sum(values)

    sum_xy =
      xs |> Enum.zip(values) |> Enum.map(fn {x, y} -> x * y end) |> Enum.sum()

    sum_x2 = xs |> Enum.map(fn x -> x * x end) |> Enum.sum() |> Kernel.*(1.0)

    denominator = n * sum_x2 - sum_x * sum_x

    if denominator == 0.0 do
      0.0
    else
      (n * sum_xy - sum_x * sum_y) / denominator
    end
  end
end

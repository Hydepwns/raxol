defmodule Raxol.Playground.Demos.ScatterChartDemo do
  @moduledoc "Playground demo: braille scatter plot with animated clusters."
  use Raxol.Core.Runtime.Application

  @points_per_cluster 20
  @chart_width 60
  @chart_height 15
  @tick_interval_ms 200

  @impl true
  def init(_context) do
    %{tick: 0, show_legend: true}
  end

  @impl true
  def update(message, model) do
    case message do
      key_match("l") ->
        {%{model | show_legend: not model.show_legend}, []}

      key_match("r") ->
        {%{model | tick: 0}, []}

      :tick ->
        {%{model | tick: model.tick + 1}, []}

      _ ->
        {model, []}
    end
  end

  @impl true
  def view(model) do
    series = build_series(model.tick)
    point_count = series |> Enum.map(fn s -> length(s.data) end) |> Enum.sum()

    chart_element =
      scatter_chart(
        series: series,
        width: @chart_width,
        height: @chart_height,
        show_legend: model.show_legend
      )

    legend_label = if model.show_legend, do: "ON", else: "OFF"

    column style: %{gap: 1} do
      [
        text("ScatterChart Demo", style: [:bold]),
        divider(),
        chart_element,
        text(
          "Legend: #{legend_label}  Points: #{point_count}  Tick: #{model.tick}"
        ),
        text("[l] legend  [r] reset", style: [:dim])
      ]
    end
  end

  @impl true
  def subscribe(_model), do: [subscribe_interval(@tick_interval_ms, :tick)]

  defp build_series(tick) do
    t = tick * 0.05
    range = 0..(@points_per_cluster - 1)

    cluster_a =
      for i <- range do
        {30 + 10 * :math.cos(i * 0.3 + t), 20 + 10 * :math.sin(i * 0.4 + t)}
      end

    cluster_b =
      for i <- range do
        {60 + 8 * :math.sin(i * 0.35 + t * 1.2),
         40 + 8 * :math.cos(i * 0.25 + t * 0.8)}
      end

    [
      %{name: "Alpha", data: cluster_a, color: :green},
      %{name: "Beta", data: cluster_b, color: :yellow}
    ]
  end
end

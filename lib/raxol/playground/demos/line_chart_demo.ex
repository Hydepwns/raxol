defmodule Raxol.Playground.Demos.LineChartDemo do
  @moduledoc "Playground demo: streaming braille-resolution line chart."
  use Raxol.Core.Runtime.Application

  @data_points 30
  @chart_width 60
  @chart_height 15
  @tick_interval_ms 300

  @impl true
  def init(_context) do
    %{tick: 0, show_legend: true, show_axes: false}
  end

  @impl true
  def update(message, model) do
    case message do
      key_match("l") ->
        {%{model | show_legend: not model.show_legend}, []}

      key_match("a") ->
        {%{model | show_axes: not model.show_axes}, []}

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

    chart_element =
      line_chart(
        series: series,
        width: @chart_width,
        height: @chart_height,
        show_legend: model.show_legend,
        show_axes: model.show_axes
      )

    legend_label = if model.show_legend, do: "ON", else: "OFF"
    axes_label = if model.show_axes, do: "ON", else: "OFF"

    column style: %{gap: 1} do
      [
        text("LineChart Demo", style: [:bold]),
        divider(),
        chart_element,
        text(
          "Legend: #{legend_label}  Axes: #{axes_label}  Tick: #{model.tick}"
        ),
        text("[l] legend  [a] axes  [r] reset", style: [:dim])
      ]
    end
  end

  @impl true
  def subscribe(_model), do: [subscribe_interval(@tick_interval_ms, :tick)]

  defp build_series(tick) do
    range = 0..(@data_points - 1)
    data_a = for i <- range, do: round(50 + 40 * :math.sin((tick + i) * 0.2))
    data_b = for i <- range, do: round(50 + 25 * :math.cos((tick + i) * 0.15))

    [
      %{name: "Sine", data: data_a, color: :cyan},
      %{name: "Cosine", data: data_b, color: :magenta}
    ]
  end
end

defmodule Raxol.Playground.Demos.LineChartDemo do
  @moduledoc false
  use Raxol.Core.Runtime.Application

  @impl true
  def init(_context) do
    %{tick: 0, show_legend: true, show_axes: false}
  end

  @impl true
  def update(message, model) do
    case message do
      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "l"}} ->
        {%{model | show_legend: not model.show_legend}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "a"}} ->
        {%{model | show_axes: not model.show_axes}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "r"}} ->
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
        width: 60,
        height: 15,
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
  def subscribe(_model), do: [subscribe_interval(300, :tick)]

  defp build_series(tick) do
    data_a = for i <- 0..29, do: round(50 + 40 * :math.sin((tick + i) * 0.2))
    data_b = for i <- 0..29, do: round(50 + 25 * :math.cos((tick + i) * 0.15))

    [
      %{name: "Sine", data: data_a, color: :cyan},
      %{name: "Cosine", data: data_b, color: :magenta}
    ]
  end
end

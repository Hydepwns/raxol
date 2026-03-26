defmodule LineChartDemo do
  @moduledoc """
  Live braille line chart with 3 sine waves at different frequencies.
  200ms tick. Multicolor braille rendering with auto-scaling Y.
  """

  use Raxol.Core.Runtime.Application

  alias Raxol.UI.Charts.{LineChart, ViewBridge}

  @max_points 80

  @impl true
  def init(_context) do
    %{tick: 0, series_a: [], series_b: [], series_c: []}
  end

  @impl true
  def update(message, model) do
    case message do
      :tick ->
        t = model.tick * 0.1
        a = :math.sin(t) * 50 + 50
        b = :math.sin(t * 1.5 + 1.0) * 30 + 50
        c = :math.sin(t * 0.7 + 2.0) * 40 + 50

        {%{
           model
           | tick: model.tick + 1,
             series_a: [a | model.series_a] |> Enum.take(@max_points),
             series_b: [b | model.series_b] |> Enum.take(@max_points),
             series_c: [c | model.series_c] |> Enum.take(@max_points)
         }, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "q"}} ->
        {model, [command(:quit)]}

      _ ->
        {model, []}
    end
  end

  @impl true
  def view(model) do
    series = [
      %{name: "Alpha", data: Enum.reverse(model.series_a), color: :cyan},
      %{name: "Beta", data: Enum.reverse(model.series_b), color: :magenta},
      %{name: "Gamma", data: Enum.reverse(model.series_c), color: :yellow}
    ]

    cells = LineChart.render({1, 2, 78, 20}, series, show_legend: true)

    column style: %{padding: 1} do
      [
        text("Braille Line Chart - 3 Sine Waves", style: [:bold], fg: :cyan),
        ViewBridge.cells_to_view(cells),
        text("Press q to quit", style: [:dim])
      ]
    end
  end

  @impl true
  def subscribe(_model) do
    [subscribe_interval(200, :tick)]
  end
end

Raxol.start_link(LineChartDemo)

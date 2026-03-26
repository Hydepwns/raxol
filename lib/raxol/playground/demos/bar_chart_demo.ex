defmodule Raxol.Playground.Demos.BarChartDemo do
  @moduledoc false
  use Raxol.Core.Runtime.Application

  alias Raxol.UI.Charts.{BarChart, ViewBridge}

  @labels ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

  @impl true
  def init(_context) do
    %{
      orientation: :vertical,
      data: [45, 78, 32, 91, 56, 23, 67],
      show_values: true
    }
  end

  @impl true
  def update(message, model) do
    case message do
      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "o"}} ->
        new_orient =
          if model.orientation == :vertical, do: :horizontal, else: :vertical

        {%{model | orientation: new_orient}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "v"}} ->
        {%{model | show_values: not model.show_values}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "r"}} ->
        {%{model | data: Enum.map(1..7, fn _ -> :rand.uniform(100) end)}, []}

      _ ->
        {model, []}
    end
  end

  @impl true
  def view(model) do
    series = [%{name: "Weekly", data: model.data, color: :cyan}]

    cells =
      BarChart.render({0, 0, 50, 12}, series,
        orientation: model.orientation,
        show_values: model.show_values
      )

    chart_element = ViewBridge.cells_to_view(cells)
    values_label = if model.show_values, do: "ON", else: "OFF"

    labels_str =
      Enum.zip(@labels, model.data)
      |> Enum.map_join("  ", fn {l, v} -> "#{l}:#{v}" end)

    column style: %{gap: 1} do
      [
        text("BarChart Demo", style: [:bold]),
        divider(),
        chart_element,
        text("Orientation: #{model.orientation}  Values: #{values_label}"),
        text(labels_str, style: [:dim]),
        text("[o] orientation  [v] values  [r] randomize", style: [:dim])
      ]
    end
  end

  @impl true
  def subscribe(_model), do: []
end

defmodule Raxol.Playground.Demos.HeatmapDemo do
  @moduledoc false
  use Raxol.Core.Runtime.Application

  @scales [:warm, :cool, :diverging]

  @impl true
  def init(_context) do
    %{grid: random_grid(), color_scale: :warm}
  end

  @impl true
  def update(message, model) do
    case message do
      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "s"}} ->
        {%{model | color_scale: next_scale(model.color_scale)}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "r"}} ->
        {%{model | grid: random_grid()}, []}

      _ ->
        {model, []}
    end
  end

  @impl true
  def view(model) do
    rows = length(model.grid)
    cols = length(hd(model.grid))

    chart_element =
      heatmap(
        data: model.grid,
        width: 48,
        height: 16,
        color_scale: model.color_scale
      )

    column style: %{gap: 1} do
      [
        text("Heatmap Demo", style: [:bold]),
        divider(),
        chart_element,
        text("Scale: #{model.color_scale}  Grid: #{rows}x#{cols}"),
        text("[s] cycle scale  [r] randomize", style: [:dim])
      ]
    end
  end

  @impl true
  def subscribe(_model), do: []

  defp random_grid do
    for _r <- 1..8, do: for(_c <- 1..12, do: :rand.uniform())
  end

  defp next_scale(current) do
    idx = Enum.find_index(@scales, &(&1 == current))
    Enum.at(@scales, rem(idx + 1, length(@scales)))
  end
end

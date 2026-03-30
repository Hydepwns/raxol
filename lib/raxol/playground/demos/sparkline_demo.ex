defmodule Raxol.Playground.Demos.SparklineDemo do
  @moduledoc "Playground demo: compact sparkline with live data."
  use Raxol.Core.Runtime.Application

  @impl true
  def init(_context) do
    %{tick: 0, color: :cyan, colors: [:cyan, :green, :yellow, :magenta, :red]}
  end

  @impl true
  def update(message, model) do
    case message do
      key_match("c") ->
        idx = Enum.find_index(model.colors, &(&1 == model.color))
        next = Enum.at(model.colors, rem(idx + 1, length(model.colors)))
        {%{model | color: next}, []}

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
    data =
      for i <- 0..39, do: round(50 + 30 * :math.sin((model.tick + i) * 0.25))

    column style: %{gap: 1} do
      [
        text("Sparkline Demo", style: [:bold]),
        divider(),
        text("CPU Usage:", style: [:dim]),
        sparkline(data: data, width: 40, height: 5, color: model.color),
        text("Memory:", style: [:dim]),
        sparkline(
          data:
            for(
              i <- 0..39,
              do: round(60 + 20 * :math.cos((model.tick + i) * 0.18))
            ),
          width: 40,
          height: 5,
          color: :green
        ),
        text("Network I/O:", style: [:dim]),
        sparkline(
          data:
            for(
              i <- 0..39,
              do: round(30 + 25 * :math.sin((model.tick + i) * 0.3))
            ),
          width: 40,
          height: 5,
          color: :yellow
        ),
        text("Color: #{model.color}  Tick: #{model.tick}"),
        text("[c] cycle color  [r] reset", style: [:dim])
      ]
    end
  end

  @impl true
  def subscribe(_model), do: [subscribe_interval(200, :tick)]
end

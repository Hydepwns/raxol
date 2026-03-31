defmodule Raxol.Playground.Demos.SparklineDemo do
  @moduledoc "Playground demo: compact sparkline with live data."
  use Raxol.Core.Runtime.Application

  @data_points 40
  @spark_width 40
  @spark_height 5
  @tick_interval_ms 200

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
    range = 0..(@data_points - 1)

    cpu_data =
      for i <- range, do: round(50 + 30 * :math.sin((model.tick + i) * 0.25))

    mem_data =
      for i <- range, do: round(60 + 20 * :math.cos((model.tick + i) * 0.18))

    net_data =
      for i <- range, do: round(30 + 25 * :math.sin((model.tick + i) * 0.3))

    column style: %{gap: 1} do
      [
        text("Sparkline Demo", style: [:bold]),
        divider(),
        text("CPU Usage:", style: [:dim]),
        sparkline(data: cpu_data, width: @spark_width, height: @spark_height, color: model.color),
        text("Memory:", style: [:dim]),
        sparkline(data: mem_data, width: @spark_width, height: @spark_height, color: :green),
        text("Network I/O:", style: [:dim]),
        sparkline(data: net_data, width: @spark_width, height: @spark_height, color: :yellow),
        text("Color: #{model.color}  Tick: #{model.tick}"),
        text("[c] cycle color  [r] reset", style: [:dim])
      ]
    end
  end

  @impl true
  def subscribe(_model), do: [subscribe_interval(@tick_interval_ms, :tick)]
end

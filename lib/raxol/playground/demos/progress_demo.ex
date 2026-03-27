defmodule Raxol.Playground.Demos.ProgressDemo do
  @moduledoc "Playground demo: progress bar with value tracking."
  use Raxol.Core.Runtime.Application

  @impl true
  def init(_context) do
    %{value: 50, auto: false}
  end

  @impl true
  def update(message, model) do
    case message do
      key_match("+") ->
        {%{model | value: min(model.value + 5, 100)}, []}

      key_match("-") ->
        {%{model | value: max(model.value - 5, 0)}, []}

      key_match("a") ->
        {%{model | auto: not model.auto}, []}

      key_match("r") ->
        {%{model | value: 0}, []}

      :tick when model.auto ->
        new_val = if model.value >= 100, do: 0, else: model.value + 2
        {%{model | value: new_val}, []}

      _ ->
        {model, []}
    end
  end

  @impl true
  def view(model) do
    filled = round(model.value / 100 * 30)
    empty = 30 - filled
    bar = String.duplicate("#", filled) <> String.duplicate(".", empty)
    auto_label = if model.auto, do: "ON", else: "OFF"

    column style: %{gap: 1} do
      [
        text("Progress Demo", style: [:bold]),
        divider(),
        progress(value: model.value, max: 100),
        text("[#{bar}] #{model.value}%"),
        divider(),
        box style: %{border: :single, padding: 1, width: 35} do
          column style: %{gap: 0} do
            [
              text("Value: #{model.value}/100"),
              text("Auto-increment: #{auto_label}")
            ]
          end
        end,
        visual_bars(model.value),
        text("[+/-] adjust  [a] auto  [r] reset", style: [:dim])
      ]
    end
  end

  @impl true
  def subscribe(model) do
    if model.auto do
      [subscribe_interval(200, :tick)]
    else
      []
    end
  end

  defp visual_bars(value) do
    column style: %{gap: 0} do
      [
        bar_line("Default", value, 30),
        bar_line("Half", div(value, 2), 30),
        bar_line("Double", min(value * 2, 100), 30)
      ]
    end
  end

  defp bar_line(label, val, width) do
    filled = round(val / 100 * width)
    empty = width - filled
    bar = String.duplicate("=", filled) <> String.duplicate("-", empty)
    text("#{String.pad_trailing(label, 8)} [#{bar}] #{val}%")
  end
end

defmodule Raxol.Playground.Demos.SplitPaneDemo do
  @moduledoc "Playground demo: resizable split pane with direction toggle."
  use Raxol.Core.Runtime.Application

  @impl true
  def init(_context) do
    %{direction: :horizontal, ratio: 0.5, focus: :left}
  end

  @impl true
  def update(message, model) do
    case message do
      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "d"}} ->
        dir =
          if model.direction == :horizontal, do: :vertical, else: :horizontal

        {%{model | direction: dir}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :tab}} ->
        focus = if model.focus == :left, do: :right, else: :left
        {%{model | focus: focus}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "+"}} ->
        {%{model | ratio: min(model.ratio + 0.1, 0.9)}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "-"}} ->
        {%{model | ratio: max(model.ratio - 0.1, 0.1)}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "="}} ->
        {%{model | ratio: 0.5}, []}

      _ ->
        {model, []}
    end
  end

  @impl true
  def view(model) do
    left_indicator = if model.focus == :left, do: " [*]", else: ""
    right_indicator = if model.focus == :right, do: " [*]", else: ""
    left_style = if model.focus == :left, do: [:bold], else: []
    right_style = if model.focus == :right, do: [:bold], else: []
    pct = round(model.ratio * 100)

    left_pane =
      box style: %{border: :single, padding: 1} do
        column style: %{gap: 0} do
          [
            text("Left Pane#{left_indicator}", style: left_style),
            text("Ratio: #{pct}%")
          ]
        end
      end

    right_pane =
      box style: %{border: :single, padding: 1} do
        column style: %{gap: 0} do
          [
            text("Right Pane#{right_indicator}", style: right_style),
            text("Ratio: #{100 - pct}%")
          ]
        end
      end

    panes =
      if model.direction == :horizontal do
        row style: %{gap: 1} do
          [left_pane, right_pane]
        end
      else
        column style: %{gap: 1} do
          [left_pane, right_pane]
        end
      end

    column style: %{gap: 1} do
      [
        text("SplitPane Demo", style: [:bold]),
        divider(),
        panes,
        divider(),
        row style: %{gap: 2} do
          [
            text("Direction: #{model.direction}"),
            text("Ratio: #{pct}/#{100 - pct}"),
            text("Focus: #{model.focus}")
          ]
        end,
        text("[d] direction  [Tab] focus  [+/-] resize  [=] reset",
          style: [:dim]
        )
      ]
    end
  end

  @impl true
  def subscribe(_model), do: []
end

defmodule Raxol.Playground.Demos.StatusBarDemo do
  @moduledoc "Playground demo: status bar with live-updating fields."
  use Raxol.Core.Runtime.Application

  @impl true
  def init(_context) do
    %{mode: "NORMAL", file: "demo.ex", line: 1, col: 1, tick: 0}
  end

  @impl true
  def update(message, model) do
    case message do
      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "i"}} ->
        {%{model | mode: "INSERT"}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :escape}} ->
        {%{model | mode: "NORMAL"}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "j"}} ->
        {%{model | line: model.line + 1}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "k"}} ->
        {%{model | line: max(model.line - 1, 1)}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "h"}} ->
        {%{model | col: max(model.col - 1, 1)}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "l"}} ->
        {%{model | col: model.col + 1}, []}

      :tick ->
        {%{model | tick: model.tick + 1}, []}

      _ ->
        {model, []}
    end
  end

  @impl true
  def view(model) do
    mode_style =
      if model.mode == "INSERT", do: [:bold, :underline], else: [:bold]

    column style: %{gap: 1} do
      [
        text("StatusBar Demo", style: [:bold]),
        divider(),
        row style: %{gap: 1} do
          [
            text(" #{model.mode} ", style: mode_style),
            text("|"),
            text(model.file),
            text("|"),
            text("Ln #{model.line}, Col #{model.col}"),
            text("|"),
            text("T:#{model.tick}")
          ]
        end,
        divider(),
        box style: %{border: :single, padding: 1, width: 35} do
          column style: %{gap: 0} do
            [
              text("Mode: #{model.mode}"),
              text("File: #{model.file}"),
              text("Position: #{model.line}:#{model.col}"),
              text("Uptime: #{model.tick}s")
            ]
          end
        end,
        text("[i] insert  [Esc] normal  [hjkl] move", style: [:dim])
      ]
    end
  end

  @impl true
  def subscribe(_model) do
    [subscribe_interval(1000, :tick)]
  end
end

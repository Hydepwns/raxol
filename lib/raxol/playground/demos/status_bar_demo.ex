defmodule Raxol.Playground.Demos.StatusBarDemo do
  @moduledoc "Playground demo: status bar with live-updating fields."
  use Raxol.Core.Runtime.Application

  @tick_interval_ms 1000
  @info_box_width 35

  @impl true
  def init(_context) do
    %{mode: "NORMAL", file: "demo.ex", line: 1, col: 1, tick: 0}
  end

  @impl true
  def update(message, model) do
    case message do
      key_match("i") ->
        {%{model | mode: "INSERT"}, []}

      key_match(:escape) ->
        {%{model | mode: "NORMAL"}, []}

      key_match("j") ->
        {%{model | line: model.line + 1}, []}

      key_match("k") ->
        {%{model | line: max(model.line - 1, 1)}, []}

      key_match("h") ->
        {%{model | col: max(model.col - 1, 1)}, []}

      key_match("l") ->
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
        box style: %{border: :single, padding: 1, width: @info_box_width} do
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
    [subscribe_interval(@tick_interval_ms, :tick)]
  end
end

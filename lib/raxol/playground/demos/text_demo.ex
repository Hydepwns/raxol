defmodule Raxol.Playground.Demos.TextDemo do
  @moduledoc "Playground demo: text rendering with style variations."
  use Raxol.Core.Runtime.Application

  @styles [
    %{label: "Bold", style: [:bold]},
    %{label: "Italic", style: [:italic]},
    %{label: "Underline", style: [:underline]},
    %{label: "Bold + Italic", style: [:bold, :italic]},
    %{label: "Dim", style: [:dim]},
    %{label: "Bold + Underline", style: [:bold, :underline]}
  ]

  @impl true
  def init(_context) do
    %{style_index: 0}
  end

  @impl true
  def update(message, model) do
    max_idx = length(@styles) - 1

    case message do
      key_match("n") ->
        {%{model | style_index: min(model.style_index + 1, max_idx)}, []}

      key_match("p") ->
        {%{model | style_index: max(model.style_index - 1, 0)}, []}

      _ ->
        {model, []}
    end
  end

  @impl true
  def view(model) do
    current = Enum.at(@styles, model.style_index)

    style_list =
      @styles
      |> Enum.with_index()
      |> Enum.map(fn {s, idx} ->
        indicator = if idx == model.style_index, do: "> ", else: "  "
        text(indicator <> s.label)
      end)

    column style: %{gap: 1} do
      [
        text("Text Demo", style: [:bold]),
        divider(),
        text("Current style: #{current.label}", style: [:bold]),
        box style: %{border: :single, padding: 1, width: 40} do
          text("The quick brown fox jumps over the lazy dog",
            style: current.style
          )
        end,
        divider(),
        text("All styles:", style: [:underline]),
        column style: %{gap: 0} do
          style_list
        end,
        text("#{model.style_index + 1}/#{length(@styles)}"),
        text("[n] next  [p] previous", style: [:dim])
      ]
    end
  end

  @impl true
  def subscribe(_model), do: []
end

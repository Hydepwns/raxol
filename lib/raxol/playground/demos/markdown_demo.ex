defmodule Raxol.Playground.Demos.MarkdownDemo do
  @moduledoc "Playground demo: markdown rendering with raw toggle."
  use Raxol.Core.Runtime.Application

  @documents [
    %{
      title: "Getting Started",
      content:
        "# Welcome\n\nThis is a *simple* demo.\n\n- Item one\n- Item two\n\nUse `mix run` to start."
    },
    %{
      title: "Features",
      content:
        "# Features\n\n- *Bold* rendering\n- `Code` highlighting\n- Simple lists\n\nSee `README.md` for details."
    },
    %{
      title: "API Reference",
      content:
        "# API\n\nCall `init/1` to start.\n\n- Returns *ok* tuple\n- Accepts a *context* map\n\n# Examples\n\nSee the `examples/` folder."
    }
  ]

  @impl true
  def init(_context) do
    %{current: 0, raw: false}
  end

  @impl true
  def update(message, model) do
    max_idx = length(@documents) - 1

    case message do
      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "n"}} ->
        {%{model | current: min(model.current + 1, max_idx)}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "p"}} ->
        {%{model | current: max(model.current - 1, 0)}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "r"}} ->
        {%{model | raw: not model.raw}, []}

      _ ->
        {model, []}
    end
  end

  @impl true
  def view(model) do
    doc = Enum.at(@documents, model.current)
    mode_label = if model.raw, do: "RAW", else: "RENDERED"

    content_lines =
      doc.content
      |> String.split("\n")
      |> Enum.map(fn line ->
        if model.raw, do: text(line), else: render_line(line)
      end)

    column style: %{gap: 1} do
      [
        text("Markdown Demo", style: [:bold]),
        divider(),
        row style: %{gap: 2} do
          [
            text(doc.title, style: [:bold]),
            text("[#{mode_label}]", style: [:dim])
          ]
        end,
        box style: %{border: :single, padding: 1, width: 45} do
          column style: %{gap: 0} do
            content_lines
          end
        end,
        divider(),
        text("#{model.current + 1}/#{length(@documents)}"),
        text("[n] next  [p] previous  [r] toggle raw/rendered", style: [:dim])
      ]
    end
  end

  @impl true
  def subscribe(_model), do: []

  defp render_line(line) do
    cond do
      String.starts_with?(line, "# ") ->
        text(String.trim_leading(line, "# "), style: [:bold, :underline])

      String.starts_with?(line, "- ") ->
        body = String.trim_leading(line, "- ") |> render_inline()
        text("  * " <> body)

      line == "" ->
        text("")

      true ->
        text(render_inline(line))
    end
  end

  defp render_inline(str) do
    str
    |> String.replace(~r/\*([^*]+)\*/, "_\\1_")
    |> String.replace(~r/`([^`]+)`/, "[\\1]")
  end
end

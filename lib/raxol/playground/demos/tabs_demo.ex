defmodule Raxol.Playground.Demos.TabsDemo do
  @moduledoc "Playground demo: tab bar with keyboard switching and content panels."
  use Raxol.Core.Runtime.Application

  @tab_labels ["Overview", "Details", "Settings", "Help"]

  @tab_content %{
    0 => "Welcome to the overview panel.\nThis shows a summary.",
    1 => "Detailed information goes here.\nRow 1: value\nRow 2: value",
    2 => "Settings panel.\nTheme: dark\nFont: mono",
    3 => "Press h/l to switch tabs.\nPress 1-4 for direct access."
  }

  @impl true
  def init(_context) do
    %{active: 0}
  end

  @impl true
  def update(message, model) do
    case message do
      key_match(:char, char: c)
      when c in ["1", "2", "3", "4"] ->
        {%{model | active: String.to_integer(c) - 1}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: k}}
      when k in [:left] ->
        {%{model | active: rem(model.active - 1 + 4, 4)}, []}

      key_match("h") ->
        {%{model | active: rem(model.active - 1 + 4, 4)}, []}

      key_match(:right) ->
        {%{model | active: rem(model.active + 1, 4)}, []}

      key_match("l") ->
        {%{model | active: rem(model.active + 1, 4)}, []}

      _ ->
        {model, []}
    end
  end

  @impl true
  def view(model) do
    tabs =
      @tab_labels
      |> Enum.with_index()
      |> Enum.map(fn {label, idx} ->
        if idx == model.active do
          text("[ #{label} ]", style: [:bold, :underline])
        else
          text("  #{label}  ")
        end
      end)

    content_lines =
      @tab_content
      |> Map.get(model.active, "")
      |> String.split("\n")
      |> Enum.map(&text/1)

    column style: %{gap: 1} do
      [
        text("Tabs Demo", style: [:bold]),
        divider(),
        row style: %{gap: 0} do
          tabs
        end,
        box style: %{border: :single, padding: 1, width: 40} do
          column style: %{gap: 0} do
            content_lines
          end
        end,
        text("Tab #{model.active + 1}/#{length(@tab_labels)}"),
        text("[h/l] prev/next  [1-4] direct  [arrows] navigate", style: [:dim])
      ]
    end
  end

  @impl true
  def subscribe(_model), do: []
end

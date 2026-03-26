defmodule Raxol.Playground.Demos.ContainerDemo do
  @moduledoc "Playground demo: scrollable container with viewport controls."
  use Raxol.Core.Runtime.Application

  @total 30

  @impl true
  def init(_context) do
    items =
      Enum.map(
        1..@total,
        &"Item #{String.pad_leading(Integer.to_string(&1), 2, "0")}"
      )

    %{items: items, scroll_offset: 0, visible_count: 10}
  end

  @impl true
  def update(message, model) do
    max_offset = length(model.items) - model.visible_count

    case message do
      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "j"}} ->
        {%{model | scroll_offset: min(model.scroll_offset + 1, max_offset)}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :down}} ->
        {%{model | scroll_offset: min(model.scroll_offset + 1, max_offset)}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "k"}} ->
        {%{model | scroll_offset: max(model.scroll_offset - 1, 0)}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :up}} ->
        {%{model | scroll_offset: max(model.scroll_offset - 1, 0)}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "g"}} ->
        {%{model | scroll_offset: 0}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "G"}} ->
        {%{model | scroll_offset: max_offset}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "+"}} ->
        {%{model | visible_count: min(model.visible_count + 1, 20)}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "-"}} ->
        {%{model | visible_count: max(model.visible_count - 1, 3)}, []}

      _ ->
        {model, []}
    end
  end

  @impl true
  def view(model) do
    total = length(model.items)
    first = model.scroll_offset + 1
    last = min(model.scroll_offset + model.visible_count, total)

    visible =
      model.items
      |> Enum.slice(model.scroll_offset, model.visible_count)
      |> Enum.map(&text("  #{&1}"))

    scrollbar = build_scrollbar(model.scroll_offset, model.visible_count, total)

    column style: %{gap: 1} do
      [
        text("Container Demo", style: [:bold]),
        divider(),
        text("Showing #{first}-#{last} of #{total}"),
        box style: %{border: :single, padding: 1, width: 30} do
          column style: %{gap: 0} do
            visible
          end
        end,
        text(scrollbar),
        row style: %{gap: 2} do
          [
            text("Offset: #{model.scroll_offset}"),
            text("Visible: #{model.visible_count}")
          ]
        end,
        text("[j/k] scroll  [g/G] top/bottom  [+/-] visible count",
          style: [:dim]
        )
      ]
    end
  end

  @impl true
  def subscribe(_model), do: []

  defp build_scrollbar(offset, visible, total) do
    bar_len = 20
    thumb_size = max(1, round(visible / total * bar_len))
    thumb_pos = round(offset / max(total - visible, 1) * (bar_len - thumb_size))

    chars =
      Enum.map(0..(bar_len - 1), fn i ->
        if i >= thumb_pos and i < thumb_pos + thumb_size, do: "#", else: "-"
      end)

    "[" <> Enum.join(chars) <> "]"
  end
end

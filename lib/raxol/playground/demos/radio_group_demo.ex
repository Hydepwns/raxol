defmodule Raxol.Playground.Demos.RadioGroupDemo do
  @moduledoc "Playground demo: grouped radio buttons with tab switching."
  use Raxol.Core.Runtime.Application

  @impl true
  def init(_context) do
    %{
      groups: [
        %{name: "Theme", options: ["Light", "Dark", "Auto"], selected: 0},
        %{name: "Size", options: ["Small", "Medium", "Large"], selected: 0},
        %{name: "Speed", options: ["Slow", "Normal", "Fast"], selected: 0}
      ],
      active_group: 0
    }
  end

  @impl true
  def update(message, model) do
    case message do
      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "j"}} ->
        group = Enum.at(model.groups, model.active_group)
        max_idx = length(group.options) - 1
        new_group = %{group | selected: min(group.selected + 1, max_idx)}
        groups = List.replace_at(model.groups, model.active_group, new_group)
        {%{model | groups: groups}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "k"}} ->
        group = Enum.at(model.groups, model.active_group)
        new_group = %{group | selected: max(group.selected - 1, 0)}
        groups = List.replace_at(model.groups, model.active_group, new_group)
        {%{model | groups: groups}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :tab}} ->
        next = rem(model.active_group + 1, length(model.groups))
        {%{model | active_group: next}, []}

      _ ->
        {model, []}
    end
  end

  @impl true
  def view(model) do
    group_views =
      model.groups
      |> Enum.with_index()
      |> Enum.map(fn {group, gi} ->
        active? = gi == model.active_group
        title_style = if active?, do: [:bold], else: [:dim]

        options =
          group.options
          |> Enum.with_index()
          |> Enum.map(fn {opt, oi} ->
            mark = if oi == group.selected, do: "(o)", else: "( )"
            prefix = if active? and oi == group.selected, do: "> ", else: "  "
            text("#{prefix}#{mark} #{opt}")
          end)

        column style: %{gap: 0} do
          [text(group.name, style: title_style) | options]
        end
      end)

    summary =
      model.groups
      |> Enum.map(fn g -> "#{g.name}: #{Enum.at(g.options, g.selected)}" end)
      |> Enum.join("  ")

    column style: %{gap: 1} do
      [
        text("RadioGroup Demo", style: [:bold]),
        divider(),
        row(style: %{gap: 4}, do: group_views),
        divider(),
        text(summary, style: [:bold]),
        text("[j/k] navigate  [tab] switch group", style: [:dim])
      ]
    end
  end

  @impl true
  def subscribe(_model), do: []
end

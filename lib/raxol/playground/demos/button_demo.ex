defmodule Raxol.Playground.Demos.ButtonDemo do
  @moduledoc "Playground demo: interactive button with click handling."
  use Raxol.Core.Runtime.Application

  @impl true
  def init(_context) do
    %{clicks: 0, last_action: "none"}
  end

  @impl true
  def update(message, model) do
    case message do
      :primary ->
        {%{model | clicks: model.clicks + 1, last_action: "primary"}, []}

      :secondary ->
        {%{model | clicks: model.clicks + 1, last_action: "secondary"}, []}

      :danger ->
        {%{model | clicks: 0, last_action: "reset"}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "1"}} ->
        {%{model | clicks: model.clicks + 1, last_action: "primary"}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "2"}} ->
        {%{model | clicks: model.clicks + 1, last_action: "secondary"}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "r"}} ->
        {%{model | clicks: 0, last_action: "reset"}, []}

      _ ->
        {model, []}
    end
  end

  @impl true
  def view(model) do
    column style: %{gap: 1} do
      [
        text("Button Demo", style: [:bold]),
        divider(),
        row style: %{gap: 2} do
          [
            button("Primary [1]", on_click: :primary),
            button("Secondary [2]", on_click: :secondary),
            button("Reset [r]", on_click: :danger)
          ]
        end,
        divider(),
        box style: %{border: :single, padding: 1, width: 30} do
          column style: %{gap: 0} do
            [
              text("Clicks: #{model.clicks}", style: [:bold]),
              text("Last: #{model.last_action}")
            ]
          end
        end,
        text("[1/2] click  [r] reset", style: [:dim])
      ]
    end
  end

  @impl true
  def subscribe(_model), do: []
end

defmodule Raxol.Playground.Demos.TextInputDemo do
  @moduledoc "Playground demo: single-line text input with character counting."
  use Raxol.Core.Runtime.Application

  @impl true
  def init(_context) do
    %{value: "", char_count: 0}
  end

  @impl true
  def update(message, model) do
    case message do
      %Raxol.Core.Events.Event{type: :key, data: %{key: :backspace}} ->
        new_value = String.slice(model.value, 0..-2//1)
        {%{model | value: new_value, char_count: String.length(new_value)}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: ch}}
      when byte_size(ch) == 1 ->
        new_value = model.value <> ch
        {%{model | value: new_value, char_count: String.length(new_value)}, []}

      _ ->
        {model, []}
    end
  end

  @impl true
  def view(model) do
    display =
      if model.value == "", do: "(type to enter text)", else: model.value

    column style: %{gap: 1} do
      [
        text("TextInput Demo", style: [:bold]),
        divider(),
        text("Input:"),
        box style: %{border: :single, padding: 1, width: 40} do
          text(display <> "_")
        end,
        text_input(value: model.value, placeholder: "Type here..."),
        divider(),
        box style: %{border: :rounded, padding: 1, width: 40} do
          column style: %{gap: 0} do
            [
              text("Value: \"#{model.value}\""),
              text("Length: #{model.char_count} chars")
            ]
          end
        end,
        text("[type] to enter text  [backspace] to delete", style: [:dim])
      ]
    end
  end

  @impl true
  def subscribe(_model), do: []
end

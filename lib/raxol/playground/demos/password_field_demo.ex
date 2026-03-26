defmodule Raxol.Playground.Demos.PasswordFieldDemo do
  @moduledoc "Playground demo: password input with visibility toggle and strength meter."
  use Raxol.Core.Runtime.Application

  @impl true
  def init(_context) do
    %{value: "", visible: false, strength: :none}
  end

  @impl true
  def update(message, model) do
    case message do
      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "v"}} ->
        {%{model | visible: not model.visible}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "r"}} ->
        {%{model | value: "", strength: :none}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :backspace}} ->
        new_value = String.slice(model.value, 0..-2//1)
        {%{model | value: new_value, strength: strength(new_value)}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: ch}}
      when byte_size(ch) == 1 and ch not in ["v", "r"] ->
        new_value = model.value <> ch
        {%{model | value: new_value, strength: strength(new_value)}, []}

      _ ->
        {model, []}
    end
  end

  defp strength(""), do: :none
  defp strength(v) when byte_size(v) < 4, do: :weak
  defp strength(v) when byte_size(v) < 8, do: :medium
  defp strength(_v), do: :strong

  @impl true
  def view(model) do
    len = String.length(model.value)

    display =
      if model.visible, do: model.value, else: String.duplicate("*", len)

    display = if display == "", do: "(enter password)", else: display
    {strength_label, strength_bar} = strength_display(model.strength)

    column style: %{gap: 1} do
      [
        text("PasswordField Demo", style: [:bold]),
        divider(),
        text("Password:"),
        box style: %{border: :single, padding: 1, width: 40} do
          text(display <> "_")
        end,
        text("Strength: #{strength_label}"),
        text("[#{strength_bar}]"),
        text("Characters: #{len}", style: [:bold]),
        divider(),
        text("Visibility: #{if model.visible, do: "shown", else: "hidden"}"),
        text(
          "[type] enter chars  [backspace] delete  [v] toggle visibility  [r] reset",
          style: [:dim]
        )
      ]
    end
  end

  defp strength_display(:none), do: {"none", "          "}
  defp strength_display(:weak), do: {"weak", "##        "}
  defp strength_display(:medium), do: {"medium", "######    "}
  defp strength_display(:strong), do: {"strong", "##########"}

  @impl true
  def subscribe(_model), do: []
end

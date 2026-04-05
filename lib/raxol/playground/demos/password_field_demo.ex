defmodule Raxol.Playground.Demos.PasswordFieldDemo do
  @moduledoc "Playground demo: password input with visibility toggle and strength meter."
  use Raxol.Core.Runtime.Application

  import Raxol.Playground.DemoHelpers, only: [effective_width: 2]

  @default_input_box_width 40
  @min_medium_length 4
  @min_strong_length 8
  @strength_bar_width 10

  @impl true
  def init(_context) do
    %{value: "", visible: false, strength: :none}
  end

  @impl true
  def update(message, model) do
    case message do
      key_match("v") ->
        {%{model | visible: not model.visible}, []}

      key_match("r") ->
        {%{model | value: "", strength: :none}, []}

      key_match(:backspace) ->
        new_value = String.slice(model.value, 0..-2//1)
        {%{model | value: new_value, strength: strength(new_value)}, []}

      key_match(:char, char: ch)
      when byte_size(ch) == 1 and ch not in ["v", "r"] ->
        new_value = model.value <> ch
        {%{model | value: new_value, strength: strength(new_value)}, []}

      _ ->
        {model, []}
    end
  end

  defp strength(""), do: :none
  defp strength(v) when byte_size(v) < @min_medium_length, do: :weak
  defp strength(v) when byte_size(v) < @min_strong_length, do: :medium
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
        box style: %{
              border: :single,
              padding: 1,
              width: effective_width(model, @default_input_box_width)
            } do
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

  defp strength_display(:none), do: {"none", strength_bar(0)}
  defp strength_display(:weak), do: {"weak", strength_bar(2)}
  defp strength_display(:medium), do: {"medium", strength_bar(6)}

  defp strength_display(:strong),
    do: {"strong", strength_bar(@strength_bar_width)}

  defp strength_bar(filled) do
    String.duplicate("#", filled) <>
      String.duplicate(" ", @strength_bar_width - filled)
  end

  @impl true
  def subscribe(_model), do: []
end

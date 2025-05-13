defmodule Raxol.Components.Input.TextInput.Renderer do
  @moduledoc """
  Handles rendering logic for the TextInput component.
  This includes display value formatting, style management, and visual feedback.
  """

  import Raxol.View.Elements
  alias Raxol.UI.Theming.Theme
  use Phoenix.Component

  @doc """
  Renders the text input component with appropriate styling and visual feedback.
  """
  def render(assigns) do
    ~H"""
    <div class="text-input">
      <input
        type="text"
        value={@value}
        placeholder={@placeholder}
        class={[
          "text-input__field",
          @error && "text-input__field--error",
          @warning && "text-input__field--warning"
        ]}
        phx-keydown="keydown"
        phx-keyup="keyup"
        phx-blur="blur"
        phx-focus="focus"
      />
      <%= if @error do %>
        <div class="text-input__error">
          <%= @error %>
        </div>
      <% end %>
      <%= if @warning do %>
        <div class="text-input__warning">
          <%= @warning %>
        </div>
      <% end %>
    </div>
    """
  end

  # Private helpers

  defp get_box_style(base_style, theme, assigns) do
    cond do
      assigns.error ->
        Map.merge(base_style, %{
          border_color: Map.get(theme.colors, :error, :red)
        })

      assigns.focused ->
        Map.merge(base_style, %{
          border_color: Map.get(theme.colors, :primary, :blue)
        })

      true ->
        base_style
    end
  end

  defp render_focused_content(display_raw, assigns, text_style) do
    case assigns.selection do
      {start, len} ->
        # Split text around selection
        {before_selection, at_selection_and_after} =
          String.split_at(display_raw, start)

        {at_selection, after_selection} =
          String.split_at(at_selection_and_after, len)

        [
          label(content: before_selection, style: text_style),
          label(
            content: at_selection,
            style: Map.merge(text_style, %{inverse: true})
          ),
          label(content: after_selection, style: text_style)
        ]

      _ ->
        # Split text around cursor
        cursor_pos = assigns.cursor

        {before_cursor, at_cursor_and_after} =
          String.split_at(display_raw, cursor_pos)

        {at_cursor, after_cursor} = String.split_at(at_cursor_and_after, 1)

        [
          label(content: before_cursor, style: text_style),
          label(
            content: at_cursor,
            style: Map.merge(text_style, %{inverse: true})
          ),
          label(content: after_cursor, style: text_style)
        ]
    end
  end

  defp display_value(%{value: "", placeholder: placeholder})
       when not is_nil(placeholder) do
    placeholder
  end

  defp display_value(%{value: value, password: true}) do
    String.duplicate("*", String.length(value))
  end

  defp display_value(%{value: value}) do
    value
  end
end

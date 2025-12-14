# Raxol Menu - React-style pattern
# Uses props-based rendering with callbacks
import Raxol.HEEx.Components

defmodule MenuComponent do
  use Phoenix.Component

  attr :items, :list, required: true
  attr :selected, :string, default: nil
  attr :on_select, :any, required: true

  def render(assigns) do
    ~H"""
    <.terminal_box border="single" padding={1}>
      <.terminal_row gap={1}>
        <%= for item <- @items do %>
          <.terminal_button
            phx-click={@on_select}
            phx-value-item={item}
            role={if @selected == item, do: "primary", else: "secondary"}
          >
            <%= item %>
          </.terminal_button>
        <% end %>
      </.terminal_row>
    </.terminal_box>
    """
  end
end

# Usage:
# <MenuComponent.render
#   items={["File", "Edit", "View"]}
#   selected={@selected}
#   on_select="select_menu"
# />

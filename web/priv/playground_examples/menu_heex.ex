# Raxol Menu - Using HEEx Components
import Raxol.HEEx.Components

def mount(_params, _session, socket) do
  {:ok, assign(socket,
    menu_items: ["File", "Edit", "View", "Help"],
    selected: nil
  )}
end

def handle_event("select_menu", %{"item" => item}, socket) do
  {:noreply, assign(socket, selected: item)}
end

def render(assigns) do
  ~H"""
  <.terminal_box border="single" padding={1}>
    <.terminal_row gap={1}>
      <%= for item <- @menu_items do %>
        <.terminal_button
          phx-click="select_menu"
          phx-value-item={item}
          role={if @selected == item, do: "primary", else: "secondary"}
        >
          <%= item %>
        </.terminal_button>
      <% end %>
    </.terminal_row>
  </.terminal_box>

  <.terminal_text>
    Selected: <%= @selected || "None" %>
  </.terminal_text>
  """
end

# Vertical menu example:
# <.terminal_column gap={0}>
#   <%= for item <- @items do %>
#     <div phx-click="select" phx-value-item={item}
#          class={if @selected == item, do: "bg-blue-600", else: ""}>
#       <%= item %>
#     </div>
#   <% end %>
# </.terminal_column>

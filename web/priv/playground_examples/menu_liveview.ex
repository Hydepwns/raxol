# Raxol Menu - Full LiveView Component
defmodule MyAppWeb.MenuLive do
  use MyAppWeb, :live_view
  import Raxol.HEEx.Components

  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      items: ["File", "Edit", "View", "Help"],
      selected: nil,
      dropdown_open: false
    )}
  end

  def handle_event("toggle_dropdown", _, socket) do
    {:noreply, assign(socket, dropdown_open: !socket.assigns.dropdown_open)}
  end

  def handle_event("select_item", %{"item" => item}, socket) do
    {:noreply, assign(socket, selected: item, dropdown_open: false)}
  end

  def render(assigns) do
    ~H"""
    <div class="relative">
      <.terminal_button phx-click="toggle_dropdown" role="primary">
        Menu: <%= @selected || "Select..." %>
      </.terminal_button>

      <%= if @dropdown_open do %>
        <.terminal_box border="single" padding={0} class="absolute mt-1 z-10">
          <.terminal_column>
            <%= for item <- @items do %>
              <div
                phx-click="select_item"
                phx-value-item={item}
                class={"px-4 py-2 cursor-pointer " <>
                  if(@selected == item, do: "bg-blue-600 text-white", else: "hover:bg-gray-100")}
              >
                <%= item %>
              </div>
            <% end %>
          </.terminal_column>
        </.terminal_box>
      <% end %>
    </div>
    """
  end
end

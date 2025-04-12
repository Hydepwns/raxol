defmodule RaxolWeb.ThemeToggleComponent do
  use RaxolWeb, :live_component

  def render(assigns) do
    ~H"""
    <button
      type="button"
      class="theme-toggle"
      data-theme-toggle
      phx-click="toggle_theme"
      phx-target={@myself}
      aria-label="Toggle theme"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <circle cx="12" cy="12" r="5" />
        <line x1="12" y1="1" x2="12" y2="3" />
        <line x1="12" y1="21" x2="12" y2="23" />
        <line x1="4.22" y1="4.22" x2="5.64" y2="5.64" />
        <line x1="18.36" y1="18.36" x2="19.78" y2="19.78" />
        <line x1="1" y1="12" x2="3" y2="12" />
        <line x1="21" y1="12" x2="23" y2="12" />
        <line x1="4.22" y1="19.78" x2="5.64" y2="18.36" />
        <line x1="18.36" y1="5.64" x2="19.78" y2="4.22" />
      </svg>
    </button>
    """
  end

  def handle_event("toggle_theme", _params, socket) do
    current_theme = get_connect_params(socket)["theme"] || "light"
    new_theme = if current_theme == "light", do: "dark", else: "light"

    {:noreply,
     socket
     |> put_flash(:info, "Theme switched to #{new_theme}")
     |> push_event("theme_switched", %{theme: new_theme})}
  end
end

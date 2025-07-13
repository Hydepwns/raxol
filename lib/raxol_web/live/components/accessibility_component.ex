defmodule RaxolWeb.AccessibilityComponent do
  use RaxolWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="accessibility-menu"
         role="toolbar"
         aria-label="Accessibility options"
         aria-expanded={@expanded}>

      <button type="button"
              class="accessibility-toggle"
              phx-click="toggle_menu"
              phx-target={@myself}
              aria-controls="accessibility-options"
              aria-label="Toggle accessibility menu">
        <span class="sr-only">Accessibility Options</span>
        <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4" />
        </svg>
      </button>

      <div id="accessibility-options"
           class={["accessibility-options", @expanded && "expanded"]}
           aria-hidden={!@expanded}>

        <button type="button"
                class="accessibility-button"
                phx-click="toggle_high_contrast"
                phx-target={@myself}
                role="menuitem"
                aria-label="Toggle high contrast mode">
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <circle cx="12" cy="12" r="10" />
            <path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z" />
          </svg>
          High Contrast
        </button>

        <button type="button"
                class="accessibility-button"
                phx-click="toggle_reduced_motion"
                phx-target={@myself}
                role="menuitem"
                aria-label="Toggle reduced motion">
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path d="M18.6 6.62a1 1 0 0 0-1.4 0l-4.24 4.24a1 1 0 0 0 0 1.4l4.24 4.24a1 1 0 0 0 1.4-1.4L14.4 12l4.2-4.38a1 1 0 0 0 0-1.4z" />
          </svg>
          Reduced Motion
        </button>

        <button type="button"
                class="accessibility-button"
                phx-click="toggle_font_size"
                phx-target={@myself}
                role="menuitem"
                aria-label="Toggle font size">
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <text x="2" y="19" font-size="16">A</text>
            <text x="12" y="19" font-size="20">A</text>
            <text x="22" y="19" font-size="24">A</text>
          </svg>
          Font Size
        </button>
      </div>
    </div>
    """
  end

  def mount(socket) do
    {:ok, assign(socket, expanded: false)}
  end

  def handle_event("toggle_menu", _params, socket) do
    {:noreply, assign(socket, expanded: !socket.assigns.expanded)}
  end

  def handle_event("toggle_high_contrast", _params, socket) do
    {:noreply, push_event(socket, "toggle_high_contrast", %{})}
  end

  def handle_event("toggle_reduced_motion", _params, socket) do
    {:noreply, push_event(socket, "toggle_reduced_motion", %{})}
  end

  def handle_event("toggle_font_size", _params, socket) do
    {:noreply, push_event(socket, "toggle_font_size", %{})}
  end
end

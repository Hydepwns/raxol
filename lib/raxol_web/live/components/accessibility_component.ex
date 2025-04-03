defmodule RaxolWeb.AccessibilityComponent do
  use RaxolWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="accessibility-menu" role="menu" aria-label="Accessibility options">
      <button
        type="button"
        class="accessibility-button"
        phx-click="toggle_high_contrast"
        phx-target={@myself}
        role="menuitem"
        aria-label="Toggle high contrast mode"
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
          <circle cx="12" cy="12" r="10" />
          <path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z" />
        </svg>
        High Contrast
      </button>

      <button
        type="button"
        class="accessibility-button"
        phx-click="toggle_reduced_motion"
        phx-target={@myself}
        role="menuitem"
        aria-label="Toggle reduced motion"
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
          <path d="M18.6 6.62a1 1 0 0 0-1.4 0l-4.24 4.24a1 1 0 0 0 0 1.4l4.24 4.24a1 1 0 0 0 1.4-1.4L14.4 12l4.2-4.38a1 1 0 0 0 0-1.4z" />
          <path d="M7.4 6.62a1 1 0 0 1 1.4 0l4.24 4.24a1 1 0 0 1 0 1.4L8.8 16.5a1 1 0 0 1-1.4-1.4L9.6 12 5.4 7.62a1 1 0 0 1 0-1.4z" />
        </svg>
        Reduced Motion
      </button>

      <button
        type="button"
        class="accessibility-button"
        phx-click="toggle_font_size"
        phx-target={@myself}
        role="menuitem"
        aria-label="Toggle font size"
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
          <text x="2" y="19" font-size="16">A</text>
          <text x="12" y="19" font-size="20">A</text>
          <text x="22" y="19" font-size="24">A</text>
        </svg>
        Font Size
      </button>
    </div>
    """
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
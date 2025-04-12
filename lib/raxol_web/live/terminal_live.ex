defmodule RaxolWeb.TerminalLive do
  @moduledoc """
  LiveView component for the terminal interface.

  This component provides:
  - Terminal rendering
  - Input handling
  - Resize management
  - Theme customization
  - Scroll management
  - Session management
  """

  use RaxolWeb, :live_view
  # alias Phoenix.PubSub # Unused
  # alias Phoenix.LiveView.JS # Unused
  # alias Raxol.Core.KeyboardShortcuts # Unused
  # alias Raxol.Terminal.PTY           # Unused
  # alias Raxol.Terminal.Renderer

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      session_id = generate_session_id()

      socket =
        socket
        |> assign(:session_id, session_id)
        |> assign(:terminal_html, "")
        |> assign(:cursor, %{x: 0, y: 0, visible: true})
        |> assign(:dimensions, %{width: 80, height: 24})
        |> assign(:scroll_offset, 0)
        |> assign(:theme, default_theme())
        |> assign(:connected, false)

      {:ok, socket, temporary_assigns: [terminal_html: ""]}
    else
      {:ok, assign(socket, :connected, false)}
    end
  end

  @impl true
  def handle_event("connect", _params, socket) do
    socket =
      socket
      |> assign(:connected, true)
      |> push_event("js-exec", %{
        to: "#terminal",
        attr: "data-session-id",
        val: socket.assigns.session_id
      })

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "terminal_output",
        %{"html" => html, "cursor" => cursor},
        socket
      ) do
    {:noreply, assign(socket, terminal_html: html, cursor: cursor)}
  end

  @impl true
  def handle_event("resize", %{"width" => width, "height" => height}, socket) do
    socket = assign(socket, dimensions: %{width: width, height: height})

    {:noreply,
     push_event(socket, "terminal_resize", %{width: width, height: height})}
  end

  @impl true
  def handle_event("scroll", %{"offset" => offset}, socket) do
    socket = assign(socket, scroll_offset: offset)
    {:noreply, push_event(socket, "terminal_scroll", %{offset: offset})}
  end

  @impl true
  def handle_event("theme", %{"theme" => theme}, socket) do
    socket = assign(socket, theme: theme)
    {:noreply, push_event(socket, "terminal_theme", %{theme: theme})}
  end

  @impl true
  def handle_event("disconnect", _params, socket) do
    {:noreply, assign(socket, connected: false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="terminal-container" id="terminal-container">
      <div class="terminal-header">
        <div class="terminal-title">Terminal</div>
        <div class="terminal-controls">
          <button phx-click="resize" phx-value-width="80" phx-value-height="24">Reset Size</button>
          <button phx-click="theme" phx-value-theme="dark">Dark Theme</button>
          <button phx-click="theme" phx-value-theme="light">Light Theme</button>
        </div>
      </div>

      <div class="terminal-wrapper" id="terminal-wrapper">
        <div class="terminal" id="terminal" phx-hook="Terminal" data-session-id={@session_id}>
          <%= raw @terminal_html %>
        </div>
      </div>

      <div class="terminal-footer">
        <div class="terminal-status">
          <%= if @connected do %>
            <span class="status-connected">Connected</span>
          <% else %>
            <span class="status-disconnected">Disconnected</span>
            <button phx-click="connect">Connect</button>
          <% end %>
        </div>
        <div class="terminal-dimensions">
          <%= @dimensions.width %>x<%= @dimensions.height %>
        </div>
      </div>
    </div>
    """
  end

  # Private functions

  defp generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp default_theme do
    %{
      background: "#1e1e1e",
      foreground: "#d4d4d4",
      cursor: "#ffffff",
      black: "#000000",
      red: "#cd0000",
      green: "#00cd00",
      yellow: "#cdcd00",
      blue: "#0000cd",
      magenta: "#cd00cd",
      cyan: "#00cdcd",
      white: "#e5e5e5",
      bright_black: "#7f7f7f",
      bright_red: "#ff0000",
      bright_green: "#00ff00",
      bright_yellow: "#ffff00",
      bright_blue: "#0000ff",
      bright_magenta: "#ff00ff",
      bright_cyan: "#00ffff",
      bright_white: "#ffffff"
    }
  end
end

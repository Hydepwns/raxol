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
  alias RaxolWeb.Presence
  alias Phoenix.PubSub
  alias Raxol.UI.Theming.Theme

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      session_id = generate_session_id()
      # fallback to session_id if not logged in
      user_id = session["user_id"] || session_id
      topic = "terminal:" <> session_id

      # Restore scrollback from session if present
      saved_scrollback = Map.get(session, "scrollback_buffer", [])

      scrollback_limit =
        Application.get_env(:raxol, :terminal, [])
        |> Keyword.get(:scrollback_lines, 1000)

      emulator =
        Raxol.Terminal.Emulator.new(80, 24, scrollback: scrollback_limit)

      emulator = %{emulator | scrollback_buffer: saved_scrollback}
      renderer = Raxol.Terminal.Renderer.new(emulator.main_screen_buffer)

      # Subscribe to presence topic
      PubSub.subscribe(Raxol.PubSub, topic)

      # Track presence
      {:ok, _} =
        Presence.track(self(), topic, user_id, %{
          joined_at: System.system_time(:second)
        })

      presences = Presence.list(topic)
      users = Map.keys(presences)

      # Initialize cursors map with self
      cursors = %{user_id => %{x: 0, y: 0, visible: true}}

      socket =
        socket
        |> assign(:session_id, session_id)
        |> assign(:terminal_html, Raxol.Terminal.Renderer.render(renderer))
        |> assign(:cursor, %{x: 0, y: 0, visible: true})
        |> assign(:dimensions, %{width: 80, height: 24})
        |> assign(:scroll_offset, 0)
        |> assign(
          :theme,
          Raxol.UI.Theming.Theme.get(Raxol.UI.Theming.Theme.current())
        )
        |> assign(:connected, false)
        |> assign(:emulator, emulator)
        |> assign(:renderer, renderer)
        |> assign(:scrollback_size, length(saved_scrollback))
        |> assign(:scrollback_limit, scrollback_limit)
        |> assign(:users, users)
        |> assign(:presence_topic, topic)
        |> assign(:user_id, user_id)
        |> assign(:cursors, cursors)

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
  def handle_event("disconnect", _params, socket) do
    # Save scrollback to session (not possible in LiveView)
    _scrollback = socket.assigns.emulator.scrollback_buffer || []

    {
      :noreply,
      socket
      |> assign(:connected, false)
      # |> put_session("scrollback_buffer", scrollback) # Not available in LiveView
    }
  end

  @impl true
  def handle_event("key", %{"key" => _key, "modifiers" => _modifiers}, _socket) do
    # TODO: Implement this
  end

  @impl true
  def handle_event(
        "mouse",
        %{"x" => _x, "y" => _y, "button" => _button},
        _socket
      ) do
    # TODO: Implement this
  end

  @impl true
  def handle_event("resize", %{"width" => width, "height" => height}, socket) do
    socket = assign(socket, dimensions: %{width: width, height: height})

    {:noreply,
     push_event(socket, "terminal_resize", %{width: width, height: height})}
  end

  @impl true
  def handle_event("scroll", %{"offset" => offset}, socket) do
    offset =
      if is_integer(offset), do: offset, else: String.to_integer("#{offset}")

    emulator = socket.assigns.emulator
    scrollback_size = length(emulator.scrollback_buffer || [])
    # Edge guards
    cond do
      offset < 0 and scrollback_size == 0 ->
        # Already at top, do nothing
        {:noreply, socket}

      offset > 0 and scrollback_size == 0 ->
        # Already at bottom, do nothing
        {:noreply, socket}

      true ->
        new_emulator =
          cond do
            offset < 0 ->
              Raxol.Terminal.Commands.Screen.scroll_up(emulator, abs(offset))

            offset > 0 ->
              Raxol.Terminal.Commands.Screen.scroll_down(emulator, abs(offset))

            true ->
              emulator
          end

        renderer = %{
          socket.assigns.renderer
          | screen_buffer: new_emulator.main_screen_buffer
        }

        terminal_html = Raxol.Terminal.Renderer.render(renderer)
        new_scrollback_size = length(new_emulator.scrollback_buffer || [])
        at_bottom = new_scrollback_size == 0

        socket =
          socket
          |> assign(:emulator, new_emulator)
          |> assign(:renderer, renderer)
          |> assign(:terminal_html, terminal_html)
          |> assign(:scrollback_size, new_scrollback_size)
          |> assign(:at_bottom, at_bottom)

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("scroll_to_bottom", _params, socket) do
    emulator = socket.assigns.emulator
    scrollback_size = length(emulator.scrollback_buffer || [])

    new_emulator =
      if scrollback_size > 0 do
        Raxol.Terminal.Commands.Screen.scroll_down(emulator, scrollback_size)
      else
        emulator
      end

    renderer = %{
      socket.assigns.renderer
      | screen_buffer: new_emulator.main_screen_buffer
    }

    terminal_html = Raxol.Terminal.Renderer.render(renderer)

    socket =
      socket
      |> assign(:emulator, new_emulator)
      |> assign(:renderer, renderer)
      |> assign(:terminal_html, terminal_html)
      |> assign(:scrollback_size, length(new_emulator.scrollback_buffer || []))

    {:noreply, socket}
  end

  @impl true
  def handle_event("set_scrollback_limit", %{"limit" => limit}, socket) do
    limit = if is_integer(limit), do: limit, else: String.to_integer("#{limit}")
    emulator = %{socket.assigns.emulator | scrollback_limit: limit}
    {:noreply, assign(socket, emulator: emulator, scrollback_limit: limit)}
  end

  @impl true
  def handle_event("theme", %{"theme" => theme}, socket) do
    socket = assign(socket, theme: theme)
    {:noreply, push_event(socket, "terminal_theme", %{theme: theme})}
  end

  @impl true
  def handle_event(
        "terminal_output",
        %{"html" => html, "cursor" => cursor} = payload,
        socket
      ) do
    # Broadcast to all users in the session except the sender
    PubSub.broadcast(
      Raxol.PubSub,
      socket.assigns.presence_topic,
      {:collab_input, payload, socket.assigns.session_id}
    )

    {:noreply, assign(socket, terminal_html: html, cursor: cursor)}
  end

  @impl true
  def handle_event(
        "cursor_move",
        %{"x" => x, "y" => y, "visible" => visible},
        socket
      ) do
    cursor = %{x: x, y: y, visible: visible}

    PubSub.broadcast(
      Raxol.PubSub,
      socket.assigns.presence_topic,
      {:collab_cursor, socket.assigns.user_id, cursor}
    )

    # Also update own cursor immediately
    cursors = Map.put(socket.assigns.cursors, socket.assigns.user_id, cursor)
    {:noreply, assign(socket, cursor: cursor, cursors: cursors)}
  end

  @impl true
  def handle_info(
        {:collab_input, %{"html" => html, "cursor" => cursor},
         sender_session_id},
        socket
      ) do
    # Ignore if this message originated from this session
    if sender_session_id == socket.assigns.session_id do
      {:noreply, socket}
    else
      {:noreply, assign(socket, terminal_html: html, cursor: cursor)}
    end
  end

  @impl true
  def handle_info(%{event: "presence_diff"}, socket) do
    presences = Presence.list(socket.assigns.presence_topic)
    users = Map.keys(presences)
    {:noreply, assign(socket, users: users)}
  end

  @impl true
  def handle_info({:collab_cursor, user_id, cursor}, socket) do
    # Update the cursor for the given user
    cursors = Map.put(socket.assigns.cursors, user_id, cursor)
    {:noreply, assign(socket, cursors: cursors)}
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
        <div class="terminal" id="terminal" phx-hook="TerminalScroll" tabindex="0" data-session-id={@session_id}>
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
        <div class="terminal-scrollback-controls">
          <label for="scrollback-limit">Scrollback:</label>
          <select id="scrollback-limit" phx-hook="ScrollbackLimit" phx-update="ignore">
            <option value="500" selected={@scrollback_limit == 500}>500</option>
            <option value="1000" selected={@scrollback_limit == 1000}>1000</option>
            <option value="2000" selected={@scrollback_limit == 2000}>2000</option>
            <option value="5000" selected={@scrollback_limit == 5000}>5000</option>
          </select>
          <span>lines</span>
        </div>
        <div class="terminal-users">
          <span class="user-list-label">Users:</span>
          <%= for user <- @users do %>
            <span class="user-badge"><%= user %></span>
          <% end %>
        </div>
        <%= if @scrollback_size && @scrollback_size > 0 do %>
          <div class="terminal-scrollback-indicator">
            <span class="scrollback-badge">
              <%= @scrollback_size %> lines in scrollback
            </span>
            <button phx-click="scroll_to_bottom" class="scroll-to-bottom-btn" disabled={@at_bottom}>Scroll to Bottom</button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end

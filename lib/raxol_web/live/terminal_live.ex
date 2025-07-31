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
  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct
  import Raxol.Guards

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    # In test environment, always use connected mode to ensure assigns are available
    if Mix.env() == :test do
      require Logger

      Logger.debug(
        "RaxolWeb.TerminalLive: Using mount_connected for test environment"
      )

      mount_connected(session, socket)
    else
      if connected?(socket) do
        require Logger

        Logger.debug(
          "RaxolWeb.TerminalLive: Using mount_connected for connected socket"
        )

        mount_connected(session, socket)
      else
        require Logger

        Logger.debug(
          "RaxolWeb.TerminalLive: Using mount_disconnected for disconnected socket"
        )

        mount_disconnected(socket)
      end
    end
  end

  def index(assigns, _params) do
    assigns
  end

  defp mount_connected(session, socket) do
    require Logger

    Logger.debug(
      "RaxolWeb.TerminalLive: mount_connected called with session: #{inspect(session)}"
    )

    # Initialize cache table
    initialize_cache()

    session_id = generate_session_id()
    user_id = session["user_id"] || session_id
    topic = "terminal:" <> session_id

    Logger.debug("RaxolWeb.TerminalLive: Initializing emulator...")
    emulator = initialize_emulator(session)
    renderer = Raxol.Terminal.Renderer.new(emulator.main_screen_buffer)

    Logger.debug("RaxolWeb.TerminalLive: Setting up presence...")
    setup_presence(topic, user_id)
    presences = Presence.list(topic)
    users = Map.keys(presences)
    cursors = %{user_id => %{x: 0, y: 0, visible: true}}

    Logger.debug("RaxolWeb.TerminalLive: Initializing socket...")

    socket =
      initialize_socket(
        socket,
        session_id,
        emulator,
        renderer,
        topic,
        user_id,
        users,
        cursors
      )

    Logger.debug(
      "RaxolWeb.TerminalLive: mount_connected returning socket with assigns: #{inspect(socket.assigns)}"
    )

    {:ok, socket, temporary_assigns: [terminal_html: ""]}
  end

  defp mount_disconnected(socket) do
    session_id = "disconnected-session"
    emulator = EmulatorStruct.new(80, 24, scrollback: 1000)
    renderer = Raxol.Terminal.Renderer.new(emulator.main_screen_buffer)
    users = []
    cursors = %{}

    socket =
      socket
      |> assign(:session_id, session_id)
      |> assign(:terminal_html, "")
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
      |> assign(:scrollback_size, 0)
      |> assign(:scrollback_limit, 1000)
      |> assign(:users, users)
      |> assign(:presence_topic, nil)
      |> assign(:user_id, nil)
      |> assign(:cursors, cursors)

    {:ok, socket}
  end

  @impl Phoenix.LiveView
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

  def handle_event("disconnect", _params, socket) do
    _scrollback = socket.assigns.emulator.scrollback_buffer || []

    {
      :noreply,
      socket
      |> assign(:connected, false)
      # |> put_session("scrollback_buffer", scrollback) # Not available in LiveView
    }
  end

  def handle_event("key", %{"key" => key, "modifiers" => modifiers}, socket) do
    key_event = %Raxol.Terminal.Input.Event.KeyEvent{
      key: key,
      modifiers: Enum.map(modifiers, &String.to_atom/1),
      timestamp: System.monotonic_time()
    }

    process_input_event(socket, key_event)
  end

  def handle_event(
        "mouse",
        %{"x" => x, "y" => y, "button" => button},
        socket
      ) do
    mouse_event = %Raxol.Terminal.Input.Event.MouseEvent{
      button: String.to_atom(button),
      action: :press,
      x: x,
      y: y,
      modifiers: [],
      timestamp: System.monotonic_time()
    }

    process_input_event(socket, mouse_event)
  end

  def handle_event("resize", %{"width" => width, "height" => height}, socket) do
    socket = assign(socket, dimensions: %{width: width, height: height})

    {:noreply,
     push_event(socket, "terminal_resize", %{width: width, height: height})}
  end

  def handle_event("scroll", %{"offset" => offset}, socket) do
    offset =
      if integer?(offset), do: offset, else: String.to_integer("#{offset}")

    emulator = socket.assigns.emulator
    scrollback_size = length(emulator.scrollback_buffer || [])

    case {offset, scrollback_size} do
      {offset, 0} when offset != 0 -> {:noreply, socket}
      _ -> handle_scroll_update(socket, offset)
    end
  end

  def handle_event("scroll_to_bottom", _params, socket) do
    emulator = socket.assigns.emulator
    scrollback_size = length(emulator.scrollback_buffer || [])

    if scrollback_size > 0 do
      handle_scroll_update(socket, scrollback_size)
    else
      {:noreply, socket}
    end
  end

  def handle_event("scroll_to_top", _params, socket) do
    emulator = socket.assigns.emulator
    scrollback_size = length(emulator.scrollback_buffer || [])

    if scrollback_size > 0 do
      handle_scroll_update(socket, -scrollback_size)
    else
      {:noreply, socket}
    end
  end

  def handle_event("scroll_up", _params, socket) do
    emulator = socket.assigns.emulator
    page_size = emulator.height

    handle_scroll_update(socket, -page_size)
  end

  def handle_event("scroll_down", _params, socket) do
    emulator = socket.assigns.emulator
    page_size = emulator.height

    handle_scroll_update(socket, page_size)
  end

  def handle_event("set_scrollback_limit", %{"limit" => limit}, socket) do
    limit = if integer?(limit), do: limit, else: String.to_integer("#{limit}")
    emulator = %{socket.assigns.emulator | scrollback_limit: limit}
    {:noreply, assign(socket, emulator: emulator, scrollback_limit: limit)}
  end

  def handle_event("theme", %{"theme" => theme}, socket) do
    socket = assign(socket, theme: theme)
    {:noreply, push_event(socket, "terminal_theme", %{theme: theme})}
  end

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

  defp handle_scroll_update(socket, offset) do
    emulator = socket.assigns.emulator

    new_emulator =
      if offset < 0,
        do: Raxol.Terminal.Commands.Screen.scroll_up(emulator, abs(offset)),
        else: Raxol.Terminal.Commands.Screen.scroll_down(emulator, abs(offset))

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

  @impl Phoenix.LiveView
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

  @impl Phoenix.LiveView
  def handle_info(%{event: "presence_diff"}, socket) do
    presences = Presence.list(socket.assigns.presence_topic)
    users = Map.keys(presences)
    {:noreply, assign(socket, users: users)}
  end

  @impl Phoenix.LiveView
  def handle_info({:collab_cursor, user_id, cursor}, socket) do
    # Update the cursor for the given user
    cursors = Map.put(socket.assigns.cursors, user_id, cursor)
    {:noreply, assign(socket, cursors: cursors)}
  end

  @impl Phoenix.LiveView
  def handle_info(message, socket) do
    # Catch-all clause for unexpected messages
    require Logger

    Logger.debug(
      "RaxolWeb.TerminalLive received unexpected message: #{inspect(message)}"
    )

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def terminate(_reason, socket) do
    # Clean up Presence tracking and PubSub subscriptions
    if socket.assigns.presence_topic && socket.assigns.user_id do
      require Logger

      Logger.debug(
        "RaxolWeb.TerminalLive: Cleaning up presence and pubsub for topic: #{socket.assigns.presence_topic}"
      )

      # Untrack from Presence
      Presence.untrack(
        self(),
        socket.assigns.presence_topic,
        socket.assigns.user_id
      )

      # Unsubscribe from PubSub
      PubSub.unsubscribe(Raxol.PubSub, socket.assigns.presence_topic)
    end

    :ok
  end

  @impl Phoenix.LiveView
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
          <%= raw safe_terminal_html(@terminal_html) %>
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

  defp initialize_emulator(session) do
    scrollback_limit =
      Application.get_env(:raxol, :terminal, [])
      |> Keyword.get(:scrollback_lines, 1000)

    saved_scrollback = Map.get(session, "scrollback_buffer", [])
    emulator = EmulatorStruct.new(80, 24, scrollback: scrollback_limit)
    %{emulator | scrollback_buffer: saved_scrollback}
  end

  defp setup_presence(topic, user_id) do
    PubSub.subscribe(Raxol.PubSub, topic)

    {:ok, _} =
      Presence.track(self(), topic, user_id, %{
        joined_at: System.system_time(:second)
      })
  end

  defp initialize_socket(
         socket,
         session_id,
         emulator,
         renderer,
         topic,
         user_id,
         users,
         cursors
       ) do
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
    |> assign(:scrollback_size, length(emulator.scrollback_buffer))
    |> assign(:scrollback_limit, emulator.scrollback_limit)
    |> assign(:users, users)
    |> assign(:presence_topic, topic)
    |> assign(:user_id, user_id)
    |> assign(:cursors, cursors)
  end

  # Helper functions
  defp process_input_event(socket, event) do
    emulator = socket.assigns.emulator

    {updated_emulator, _output} =
      Raxol.Terminal.Emulator.process_input(emulator, event)

    {terminal_html, cursor} = update_terminal_state(socket, updated_emulator)
    broadcast_terminal_update(socket, terminal_html, cursor)

    {:noreply,
     update_socket_assigns(socket, updated_emulator, terminal_html, cursor)}
  end

  defp update_terminal_state(socket, emulator) do
    renderer = %{
      socket.assigns.renderer
      | screen_buffer: emulator.main_screen_buffer
    }

    # Use caching for terminal rendering
    terminal_html = render_terminal_with_cache(renderer, socket.assigns.theme)
    {cursor_x, cursor_y} = Raxol.Terminal.Emulator.get_cursor_position(emulator)
    cursor_visible = Raxol.Terminal.Emulator.get_cursor_visible(emulator)
    {terminal_html, %{x: cursor_x, y: cursor_y, visible: cursor_visible}}
  end

  # Add caching for terminal rendering
  defp render_terminal_with_cache(renderer, theme) do
    cache_key = generate_cache_key(renderer, theme)

    case :ets.lookup(:terminal_cache, cache_key) do
      [{^cache_key, rendered, timestamp}] ->
        # Cache is valid for 1 second
        if System.system_time(:second) - timestamp < 1 do
          rendered
        else
          render_and_cache(renderer, cache_key)
        end

      [] ->
        render_and_cache(renderer, cache_key)
    end
  end

  defp generate_cache_key(renderer, theme) do
    # Create a hash based on terminal state
    :crypto.hash(
      :sha256,
      :erlang.term_to_binary({
        renderer.screen_buffer,
        theme
      })
    )
  end

  defp render_and_cache(renderer, cache_key) do
    rendered = Raxol.Terminal.Renderer.render(renderer)

    :ets.insert(
      :terminal_cache,
      {cache_key, rendered, System.system_time(:second)}
    )

    rendered
  end

  # Initialize cache table in mount
  defp initialize_cache do
    case :ets.info(:terminal_cache) do
      :undefined ->
        :ets.new(:terminal_cache, [:set, :public, :named_table])

      _ ->
        :ok
    end
  end

  defp broadcast_terminal_update(socket, terminal_html, cursor) do
    PubSub.broadcast(
      Raxol.PubSub,
      socket.assigns.presence_topic,
      {:collab_input, %{"html" => terminal_html, "cursor" => cursor},
       socket.assigns.session_id}
    )
  end

  defp update_socket_assigns(socket, emulator, terminal_html, cursor) do
    socket
    |> assign(:emulator, emulator)
    |> assign(:renderer, %{
      socket.assigns.renderer
      | screen_buffer: emulator.main_screen_buffer
    })
    |> assign(:terminal_html, terminal_html)
    |> assign(:cursor, cursor)
  end

  defp safe_terminal_html({:ok, html}) when is_binary(html), do: html
  defp safe_terminal_html({:ok, _}), do: ""
  defp safe_terminal_html({:error, _}), do: ""
  defp safe_terminal_html(html) when is_binary(html), do: html
  defp safe_terminal_html(html) when is_list(html), do: html
  defp safe_terminal_html(_), do: ""
end

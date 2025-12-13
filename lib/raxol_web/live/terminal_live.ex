defmodule RaxolWeb.TerminalLive do
  @moduledoc """
  Phoenix LiveView for real-time terminal rendering.

  Provides a web-based terminal interface with:
  - Real-time bidirectional communication
  - Keyboard and mouse event handling
  - Collaborative cursor display
  - Session persistence via SessionBridge

  ## Usage

  Add to your router:

      live "/terminal", RaxolWeb.TerminalLive
      live "/terminal/:session_id", RaxolWeb.TerminalLive

  ## Features

  - 60fps capable rendering with efficient diffs
  - Multi-user collaboration with cursor sync
  - WASH-style session continuity
  - Customizable themes and appearance

  ## Example

      # Mount with custom options
      live "/terminal", RaxolWeb.TerminalLive,
        session: ["user_id"],
        layout: {RaxolWeb.LayoutView, "terminal.html"}
  """

  use Phoenix.LiveView

  import Phoenix.HTML, only: [raw: 1]

  alias Raxol.Core.Runtime.Log
  alias Raxol.LiveView.TerminalBridge
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Web.SessionBridge
  alias RaxolWeb.Presence

  @default_width 80
  @default_height 24
  @default_theme "synthwave84"
  @default_font_width 8
  @default_font_height 16

  # ============================================================================
  # LiveView Callbacks
  # ============================================================================

  @impl true
  def mount(params, session, socket) do
    session_id = Map.get(params, "session_id", generate_session_id())
    user_id = Map.get(session, "user_id", generate_user_id())
    bridge_token = Map.get(params, "token")

    socket =
      socket
      |> assign(:session_id, session_id)
      |> assign(:user_id, user_id)
      |> assign(:presence_topic, "terminal:#{session_id}")
      |> assign(:width, @default_width)
      |> assign(:height, @default_height)
      |> assign(:theme, @default_theme)
      |> assign(:buffer_html, "")
      |> assign(:cursors, %{})
      |> assign(:connected_users, [])
      |> assign(:font_width, @default_font_width)
      |> assign(:font_height, @default_font_height)
      |> assign(:container_offset, {0, 0})
      |> assign(:previous_buffer, nil)
      |> assign(:show_cursor, true)

    socket =
      if connected?(socket) do
        # Initialize terminal emulator
        emulator = initialize_emulator(socket, bridge_token)

        # Subscribe to session updates
        _ = Phoenix.PubSub.subscribe(Raxol.PubSub, "terminal:#{session_id}")

        # Track presence
        _ =
          Presence.track_user(socket, user_id, %{
            name: "User #{String.slice(user_id, 0..4)}",
            cursor: Emulator.get_cursor_position(emulator)
          })

        # Register session with bridge
        SessionBridge.register_session(session_id, %{emulator: emulator})

        socket
        |> assign(:emulator, emulator)
        |> assign(:connected_users, get_connected_users(socket))
        |> render_buffer()
      else
        assign(socket, :emulator, nil)
      end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    # Handle URL parameter changes (e.g., switching sessions)
    case Map.get(params, "session_id") do
      nil ->
        {:noreply, socket}

      new_session_id when new_session_id != socket.assigns.session_id ->
        # Switch to different session
        {:noreply, switch_session(socket, new_session_id)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="terminal-container"
         class={"terminal-theme-#{@theme}"}
         phx-hook="TerminalInput"
         phx-window-keydown="key"
         phx-window-keyup="key_up"
         tabindex="0">

      <div id="terminal-header" class="terminal-header">
        <span class="session-id">Session: <%= @session_id %></span>
        <span class="user-count">Users: <%= length(@connected_users) %></span>
      </div>

      <div id="terminal-display"
           class="terminal-display"
           style={"width: #{@width}ch; height: #{@height}em;"}
           phx-click="mouse_click"
           phx-value-x={0}
           phx-value-y={0}>
        <%= raw(@buffer_html) %>

        <%= for {user_id, {x, y}} <- @cursors, user_id != @user_id do %>
          <div class="remote-cursor"
               style={"left: #{x}ch; top: #{y}em;"}
               title={user_id}>
          </div>
        <% end %>
      </div>

      <div id="terminal-status" class="terminal-status">
        <span class="dimensions"><%= @width %>x<%= @height %></span>
        <span class="theme"><%= @theme %></span>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Event Handlers
  # ============================================================================

  @impl true
  def handle_event("key", %{"key" => key} = params, socket) do
    emulator = socket.assigns.emulator

    input = translate_key_event(key, params)

    case input do
      nil ->
        {:noreply, socket}

      data ->
        {new_emulator, _output} = Emulator.process_input(emulator, data)

        socket =
          socket
          |> assign(:emulator, new_emulator)
          |> render_buffer()
          |> broadcast_cursor_update()

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("key_up", _params, socket) do
    # Handle key release if needed for modifiers
    {:noreply, socket}
  end

  @impl true
  def handle_event("mouse_click", %{"x" => x, "y" => y}, socket) do
    emulator = socket.assigns.emulator

    # Convert click coordinates to terminal position
    {term_x, term_y} = screen_to_terminal(x, y, socket)

    # Generate mouse click escape sequence if mouse reporting is enabled
    mouse_sequence = "\e[M" <> <<32, term_x + 33, term_y + 33>>
    {new_emulator, _output} = Emulator.process_input(emulator, mouse_sequence)

    socket =
      socket
      |> assign(:emulator, new_emulator)
      |> render_buffer()

    {:noreply, socket}
  end

  @impl true
  def handle_event("resize", %{"width" => width, "height" => height}, socket) do
    emulator = socket.assigns.emulator
    new_emulator = Emulator.resize(emulator, width, height)

    socket =
      socket
      |> assign(:emulator, new_emulator)
      |> assign(:width, width)
      |> assign(:height, height)
      |> render_buffer()

    {:noreply, socket}
  end

  @impl true
  def handle_event("set_theme", %{"theme" => theme}, socket) do
    {:noreply, assign(socket, :theme, theme)}
  end

  @impl true
  def handle_event("paste", %{"text" => text}, socket) do
    emulator = socket.assigns.emulator
    {new_emulator, _output} = Emulator.process_input(emulator, text)

    socket =
      socket
      |> assign(:emulator, new_emulator)
      |> render_buffer()

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "font_metrics",
        %{"width" => width, "height" => height},
        socket
      ) do
    # Update font metrics from client-side measurement
    socket =
      socket
      |> assign(:font_width, width)
      |> assign(:font_height, height)

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "container_offset",
        %{"x" => x, "y" => y},
        socket
      ) do
    # Update container offset for mouse coordinate translation
    {:noreply, assign(socket, :container_offset, {x, y})}
  end

  @impl true
  def handle_event("toggle_cursor", _params, socket) do
    {:noreply, assign(socket, :show_cursor, !socket.assigns.show_cursor)}
  end

  # ============================================================================
  # PubSub Handlers
  # ============================================================================

  @impl true
  def handle_info({:terminal_output, data}, socket) do
    emulator = socket.assigns.emulator
    # Process output data through the emulator's input handler
    # This handles ANSI sequences and updates the terminal state
    {new_emulator, _output} = Emulator.process_input(emulator, data)

    socket =
      socket
      |> assign(:emulator, new_emulator)
      |> render_buffer()

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff},
        socket
      ) do
    socket =
      socket
      |> update_presence(diff)
      |> assign(:connected_users, get_connected_users(socket))
      |> assign(:cursors, Presence.get_cursors(socket.assigns.presence_topic))

    {:noreply, socket}
  end

  @impl true
  def handle_info({:cursor_update, user_id, position}, socket) do
    cursors = Map.put(socket.assigns.cursors, user_id, position)
    {:noreply, assign(socket, :cursors, cursors)}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp initialize_emulator(socket, bridge_token) do
    case bridge_token do
      nil ->
        # New session
        Emulator.new(socket.assigns.width, socket.assigns.height)

      token ->
        # Resume from bridge token
        case SessionBridge.resume_session(token) do
          {:ok, %{emulator: emulator}} ->
            Log.info("[TerminalLive] Resumed session from bridge token")
            emulator

          {:error, _reason} ->
            Log.warning(
              "[TerminalLive] Failed to resume session, starting fresh"
            )

            Emulator.new(socket.assigns.width, socket.assigns.height)
        end
    end
  end

  defp render_buffer(socket) do
    emulator = socket.assigns.emulator
    screen_buffer = Emulator.get_screen_buffer(emulator)

    # Convert ScreenBuffer to format expected by TerminalBridge
    buffer = screen_buffer_to_bridge_buffer(screen_buffer)

    # Get cursor position for display
    cursor_pos = Emulator.get_cursor_position(emulator)
    cursor_visible = get_cursor_visible(screen_buffer)

    # Build rendering options
    opts = [
      theme: String.to_atom(socket.assigns.theme),
      show_cursor: socket.assigns.show_cursor && cursor_visible,
      cursor_position: cursor_pos,
      cursor_style: get_cursor_style(screen_buffer),
      css_prefix: "terminal"
    ]

    html = TerminalBridge.buffer_to_html(buffer, opts)

    socket
    |> assign(:buffer_html, html)
    |> assign(:previous_buffer, buffer)
  end

  # Convert ScreenBuffer.t() to the Buffer.t() format expected by TerminalBridge
  defp screen_buffer_to_bridge_buffer(%ScreenBuffer{} = screen_buffer) do
    %{
      width: screen_buffer.width,
      height: screen_buffer.height,
      lines: Enum.map(screen_buffer.cells, &convert_row_to_line/1),
      cells: []
    }
  end

  # Handle case where screen_buffer might be a raw map (test scenarios)
  defp screen_buffer_to_bridge_buffer(%{
         cells: cells,
         width: width,
         height: height
       }) do
    %{
      width: width,
      height: height,
      lines: Enum.map(cells, &convert_map_row_to_line/1),
      cells: []
    }
  end

  # Fallback for any other buffer format
  defp screen_buffer_to_bridge_buffer(buffer) when is_list(buffer) do
    %{
      width: length(List.first(buffer) || []),
      height: length(buffer),
      lines: Enum.map(buffer, &convert_map_row_to_line/1),
      cells: []
    }
  end

  # Convert a row of cells to a line structure
  @spec convert_row_to_line(list()) :: %{
          cells: list(%{char: String.t(), style: map()})
        }
  defp convert_row_to_line(row) do
    %{cells: Enum.map(row, &convert_cell_to_buffer_cell/1)}
  end

  # Convert a cell to Buffer.cell() format
  @spec convert_cell_to_buffer_cell(term()) :: %{char: String.t(), style: map()}
  defp convert_cell_to_buffer_cell(cell) do
    char =
      case cell.char do
        nil -> " "
        c when is_binary(c) -> c
        c -> to_string(c)
      end

    %{
      char: char,
      style: cell_style_to_map(cell.style)
    }
  end

  # Convert a map-based row to a line structure
  @spec convert_map_row_to_line(list()) :: %{
          cells: list(%{char: String.t(), style: map()})
        }
  defp convert_map_row_to_line(row) do
    %{cells: Enum.map(row, &convert_map_cell_to_buffer_cell/1)}
  end

  # Convert a map-based cell to Buffer.cell() format
  @spec convert_map_cell_to_buffer_cell(map()) :: %{
          char: String.t(),
          style: map()
        }
  defp convert_map_cell_to_buffer_cell(cell) do
    char =
      case Map.get(cell, :char) do
        nil -> " "
        c when is_binary(c) -> c
        c -> to_string(c)
      end

    %{
      char: char,
      style: cell_style_to_map(Map.get(cell, :style, %{}))
    }
  end

  defp cell_style_to_map(nil), do: %{}

  defp cell_style_to_map(style) when is_map(style) do
    %{
      bold: Map.get(style, :bold, false),
      italic: Map.get(style, :italic, false),
      underline: Map.get(style, :underline, false),
      strikethrough: Map.get(style, :strikethrough, false),
      reverse: Map.get(style, :reverse, false),
      fg_color: Map.get(style, :fg_color) || Map.get(style, :fg),
      bg_color: Map.get(style, :bg_color) || Map.get(style, :bg)
    }
  end

  defp get_cursor_visible(%ScreenBuffer{cursor_visible: visible}), do: visible
  defp get_cursor_visible(%{cursor_visible: visible}), do: visible
  defp get_cursor_visible(_), do: true

  defp get_cursor_style(%ScreenBuffer{cursor_style: style}), do: style
  defp get_cursor_style(%{cursor_style: style}), do: style
  defp get_cursor_style(_), do: :block

  defp translate_key_event(key, params) do
    ctrl = Map.get(params, "ctrlKey", false)
    _alt = Map.get(params, "altKey", false)
    _shift = Map.get(params, "shiftKey", false)

    case key do
      "Enter" ->
        "\r"

      "Backspace" ->
        "\x7f"

      "Tab" ->
        "\t"

      "Escape" ->
        "\e"

      "ArrowUp" ->
        "\e[A"

      "ArrowDown" ->
        "\e[B"

      "ArrowRight" ->
        "\e[C"

      "ArrowLeft" ->
        "\e[D"

      "Home" ->
        "\e[H"

      "End" ->
        "\e[F"

      "PageUp" ->
        "\e[5~"

      "PageDown" ->
        "\e[6~"

      "Delete" ->
        "\e[3~"

      "Insert" ->
        "\e[2~"

      "F1" ->
        "\eOP"

      "F2" ->
        "\eOQ"

      "F3" ->
        "\eOR"

      "F4" ->
        "\eOS"

      "F5" ->
        "\e[15~"

      "F6" ->
        "\e[17~"

      "F7" ->
        "\e[18~"

      "F8" ->
        "\e[19~"

      "F9" ->
        "\e[20~"

      "F10" ->
        "\e[21~"

      "F11" ->
        "\e[23~"

      "F12" ->
        "\e[24~"

      char when byte_size(char) == 1 and ctrl ->
        # Ctrl+letter produces control character
        <<code>> = String.downcase(char)

        if code >= ?a and code <= ?z do
          <<code - ?a + 1>>
        else
          nil
        end

      char when byte_size(char) == 1 ->
        char

      _ ->
        nil
    end
  end

  defp screen_to_terminal(x, y, socket) do
    # Convert screen pixel coordinates to terminal cell position
    # accounting for font metrics and container offset
    font_width = socket.assigns.font_width
    font_height = socket.assigns.font_height
    {offset_x, offset_y} = socket.assigns.container_offset

    # Adjust for container offset
    adjusted_x = max(0, x - offset_x)
    adjusted_y = max(0, y - offset_y)

    # Convert to cell coordinates
    cell_x = trunc(adjusted_x / font_width)
    cell_y = trunc(adjusted_y / font_height)

    # Clamp to terminal bounds
    max_x = socket.assigns.width - 1
    max_y = socket.assigns.height - 1

    {min(cell_x, max_x), min(cell_y, max_y)}
  end

  defp broadcast_cursor_update(socket) do
    emulator = socket.assigns.emulator
    position = Emulator.get_cursor_position(emulator)

    _ =
      Phoenix.PubSub.broadcast(
        Raxol.PubSub,
        socket.assigns.presence_topic,
        {:cursor_update, socket.assigns.user_id, position}
      )

    _ = Presence.update_cursor(socket, position)
    socket
  end

  defp switch_session(socket, new_session_id) do
    # Save current session state
    case SessionBridge.restore_state(socket.assigns.session_id, %{
           emulator: socket.assigns.emulator
         }) do
      :ok ->
        :ok

      {:error, reason} ->
        Log.warning("Failed to restore session state: #{inspect(reason)}")
    end

    # Load new session
    emulator =
      case SessionBridge.capture_state(new_session_id) do
        %{emulator: em} -> em
        _ -> Emulator.new(socket.assigns.width, socket.assigns.height)
      end

    socket
    |> assign(:session_id, new_session_id)
    |> assign(:presence_topic, "terminal:#{new_session_id}")
    |> assign(:emulator, emulator)
    |> render_buffer()
  end

  defp update_presence(socket, %{joins: joins, leaves: leaves}) do
    Log.debug(
      "[TerminalLive] Presence update: #{map_size(joins)} joins, #{map_size(leaves)} leaves"
    )

    socket
  end

  defp get_connected_users(socket) do
    socket.assigns.presence_topic
    |> Presence.list_users()
    |> Map.keys()
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(8)
    |> Base.url_encode64(padding: false)
  end

  defp generate_user_id do
    :crypto.strong_rand_bytes(6)
    |> Base.url_encode64(padding: false)
  end
end

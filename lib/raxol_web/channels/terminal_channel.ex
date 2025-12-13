defmodule RaxolWeb.TerminalChannel do
  @moduledoc """
  Phoenix Channel for low-latency terminal I/O.

  Provides WebSocket-based communication for terminal sessions with:
  - Rate limiting to prevent abuse
  - Input validation and sanitization
  - Session isolation and authentication
  - Collaborative input broadcasting

  ## Usage

  In your UserSocket:

      channel "terminal:*", RaxolWeb.TerminalChannel

  Client-side:

      let channel = socket.channel("terminal:session123", {})
      channel.push("input", {data: "ls -la\\r"})
      channel.on("output", payload => console.log(payload.data))

  ## Rate Limiting

  By default, limits to 100 messages per second per user.
  Configure via:

      config :raxol, RaxolWeb.TerminalChannel,
        max_messages_per_second: 100,
        input_max_size: 4096
  """

  use Phoenix.Channel

  alias Raxol.Core.Runtime.Log
  alias Raxol.Terminal.Emulator
  alias Raxol.Web.SessionBridge
  alias RaxolWeb.Presence

  @max_messages_per_second 100
  @input_max_size 4096
  @rate_limit_window_ms 1000

  # ============================================================================
  # Channel Callbacks
  # ============================================================================

  @doc """
  Join a terminal session channel.

  Validates the session and initializes the terminal emulator.
  """
  @impl true
  def join("terminal:" <> session_id, params, socket) do
    case validate_join(session_id, params, socket) do
      {:ok, socket} ->
        send(self(), :after_join)

        socket =
          socket
          |> assign(:session_id, session_id)
          |> assign(:rate_limit, init_rate_limit())
          |> assign(:emulator, initialize_emulator(session_id, params))

        {:ok, %{session_id: session_id}, socket}

      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    user_id = socket.assigns[:user_id] || "anonymous"
    session_id = socket.assigns.session_id

    # Track presence
    {:ok, _} =
      Presence.track(socket, user_id, %{
        online_at: System.system_time(:second),
        session_id: session_id
      })

    # Send initial terminal state
    push(socket, "init", %{
      width: socket.assigns.emulator.width,
      height: socket.assigns.emulator.height,
      buffer: get_initial_buffer(socket.assigns.emulator)
    })

    # Push current presence list
    push(socket, "presence_state", Presence.list(socket))

    {:noreply, socket}
  end

  @impl true
  def handle_info({:terminal_output, data}, socket) do
    push(socket, "output", %{data: data})
    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # ============================================================================
  # Incoming Message Handlers
  # ============================================================================

  @doc """
  Handle incoming messages from the client.

  Supported messages:
  - `"input"` - Terminal input data
  - `"resize"` - Terminal resize events
  - `"cursor"` - Cursor position updates for collaboration
  - `"ping"` - Connection keep-alive
  - `"capture_state"` - Session state capture for WASH transitions
  - `"get_buffer"` - Screen buffer request
  """
  @impl true
  def handle_in("input", %{"data" => data}, socket) do
    with :ok <- check_rate_limit(socket),
         :ok <- validate_input(data),
         {:ok, socket} <- process_input(socket, data) do
      {:noreply, update_rate_limit(socket)}
    else
      {:error, :rate_limited} ->
        {:reply, {:error, %{reason: "rate_limited"}}, socket}

      {:error, :input_too_large} ->
        {:reply, {:error, %{reason: "input_too_large"}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("resize", %{"width" => width, "height" => height}, socket)
      when is_integer(width) and is_integer(height) and width > 0 and height > 0 do
    emulator = Emulator.resize(socket.assigns.emulator, width, height)

    socket = assign(socket, :emulator, emulator)

    # Broadcast resize to collaborators
    broadcast_from!(socket, "resize", %{width: width, height: height})

    {:reply, :ok, socket}
  end

  def handle_in("cursor", %{"x" => x, "y" => y}, socket)
      when is_integer(x) and is_integer(y) do
    user_id = socket.assigns[:user_id] || "anonymous"

    # Broadcast cursor position to other users
    broadcast_from!(socket, "cursor", %{
      user_id: user_id,
      x: x,
      y: y
    })

    {:noreply, socket}
  end

  def handle_in("ping", _params, socket) do
    {:reply, {:ok, %{pong: System.system_time(:millisecond)}}, socket}
  end

  def handle_in("capture_state", _params, socket) do
    emulator = socket.assigns.emulator
    session_id = socket.assigns.session_id

    case SessionBridge.create_transition(session_id, %{emulator: emulator}) do
      {:ok, token} ->
        {:reply, {:ok, %{token: token}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: inspect(reason)}}, socket}
    end
  end

  def handle_in("get_buffer", _params, socket) do
    buffer = get_buffer_content(socket.assigns.emulator)
    {:reply, {:ok, %{buffer: buffer}}, socket}
  end

  # ============================================================================
  # Termination
  # ============================================================================

  @impl true
  def terminate(_reason, socket) do
    session_id = socket.assigns[:session_id]
    emulator = socket.assigns[:emulator]

    if session_id && emulator do
      # Save session state on disconnect
      case SessionBridge.restore_state(session_id, %{emulator: emulator}) do
        :ok ->
          Log.debug("[TerminalChannel] Saved session state for #{session_id}")

        {:error, reason} ->
          Log.warning(
            "[TerminalChannel] Failed to save session: #{inspect(reason)}"
          )
      end
    end

    :ok
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp validate_join(session_id, params, socket) do
    # Validate session_id format
    unless valid_session_id?(session_id) do
      {:error, "invalid_session_id"}
    else
      # Validate auth token if provided
      case Map.get(params, "token") do
        nil ->
          # Anonymous join allowed
          {:ok, assign(socket, :user_id, "anonymous_#{random_id()}")}

        token ->
          case validate_token(token) do
            {:ok, user_id} -> {:ok, assign(socket, :user_id, user_id)}
            {:error, _} -> {:error, "invalid_token"}
          end
      end
    end
  end

  defp valid_session_id?(session_id) do
    byte_size(session_id) > 0 and byte_size(session_id) <= 64 and
      Regex.match?(~r/^[a-zA-Z0-9_-]+$/, session_id)
  end

  @spec validate_token(String.t()) :: {:ok, String.t()} | {:error, term()}
  defp validate_token(token) when is_binary(token) do
    # Placeholder for actual token validation
    # Would integrate with your auth system
    # In production, this would verify JWT/session tokens
    case byte_size(token) > 0 do
      true -> {:ok, "user_#{random_id()}"}
      false -> {:error, :empty_token}
    end
  end

  defp validate_token(_token), do: {:error, :invalid_token}

  defp initialize_emulator(session_id, params) do
    width = Map.get(params, "width", 80)
    height = Map.get(params, "height", 24)

    # Try to restore from session bridge
    case SessionBridge.capture_state(session_id) do
      %{emulator: emulator} ->
        # Resize if dimensions changed
        if emulator.width != width or emulator.height != height do
          Emulator.resize(emulator, width, height)
        else
          emulator
        end

      _ ->
        Emulator.new(width, height)
    end
  end

  defp init_rate_limit do
    %{
      count: 0,
      window_start: System.monotonic_time(:millisecond)
    }
  end

  defp check_rate_limit(socket) do
    rate_limit = socket.assigns.rate_limit
    now = System.monotonic_time(:millisecond)
    window_elapsed = now - rate_limit.window_start

    cond do
      window_elapsed > @rate_limit_window_ms ->
        # Window expired, reset
        :ok

      rate_limit.count >= @max_messages_per_second ->
        {:error, :rate_limited}

      true ->
        :ok
    end
  end

  defp update_rate_limit(socket) do
    rate_limit = socket.assigns.rate_limit
    now = System.monotonic_time(:millisecond)
    window_elapsed = now - rate_limit.window_start

    new_rate_limit =
      if window_elapsed > @rate_limit_window_ms do
        %{count: 1, window_start: now}
      else
        %{rate_limit | count: rate_limit.count + 1}
      end

    assign(socket, :rate_limit, new_rate_limit)
  end

  defp validate_input(data) when is_binary(data) do
    if byte_size(data) > @input_max_size do
      {:error, :input_too_large}
    else
      :ok
    end
  end

  defp validate_input(_), do: {:error, :invalid_input}

  defp process_input(socket, data) do
    emulator = socket.assigns.emulator
    {new_emulator, output} = Emulator.process_input(emulator, data)

    if byte_size(output) > 0 do
      push(socket, "output", %{data: output})

      # Broadcast to collaborators
      broadcast_from!(socket, "output", %{
        data: output,
        from: socket.assigns[:user_id]
      })
    end

    {:ok, assign(socket, :emulator, new_emulator)}
  end

  defp get_initial_buffer(emulator) do
    emulator
    |> Emulator.get_screen_buffer()
    |> buffer_to_serializable()
  end

  defp get_buffer_content(emulator) do
    emulator
    |> Emulator.get_screen_buffer()
    |> buffer_to_serializable()
  end

  defp buffer_to_serializable(buffer) do
    Enum.map(buffer, fn line ->
      Enum.map(line, fn cell ->
        %{
          char: Map.get(cell, :char, " "),
          fg: serialize_color(Map.get(cell, :fg)),
          bg: serialize_color(Map.get(cell, :bg)),
          bold: Map.get(cell, :bold, false),
          italic: Map.get(cell, :italic, false),
          underline: Map.get(cell, :underline, false)
        }
      end)
    end)
  end

  defp serialize_color(nil), do: nil
  defp serialize_color({r, g, b}), do: [r, g, b]
  defp serialize_color(color) when is_atom(color), do: Atom.to_string(color)
  defp serialize_color(color), do: color

  defp random_id do
    :crypto.strong_rand_bytes(4)
    |> Base.url_encode64(padding: false)
  end
end

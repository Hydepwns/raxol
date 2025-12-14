defmodule RaxolPlaygroundWeb.Presence do
  @moduledoc """
  Presence tracking for multi-user playground sessions.

  Enables collaborative features in the playground:
  - See who else is viewing the same component
  - Real-time cursor/selection sync
  - Broadcast code changes to collaborators
  - User activity indicators

  ## Topics

    - `playground:lobby` - All connected users
    - `playground:component:{name}` - Users viewing specific component

  ## Example

      # In PlaygroundLive mount
      if connected?(socket) do
        PlaygroundPresence.track_user(socket)
        PlaygroundPresence.subscribe()
      end
  """

  use Phoenix.Presence,
    otp_app: :raxol_playground,
    pubsub_server: RaxolPlayground.PubSub

  require Logger

  @lobby_topic "playground:lobby"

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Track a user in the playground.
  """
  def track_user(socket, user_id \\ nil, metadata \\ %{}) do
    user_id = user_id || generate_user_id()

    default_meta = %{
      user_id: user_id,
      name: "User #{String.slice(user_id, 0..3)}",
      color: generate_color(user_id),
      joined_at: System.system_time(:second),
      current_component: nil,
      is_editing: false,
      cursor_position: nil
    }

    full_meta = Map.merge(default_meta, metadata)

    case track(self(), @lobby_topic, user_id, full_meta) do
      {:ok, _} ->
        Logger.debug("[PlaygroundPresence] Tracked user #{user_id}")
        {:ok, user_id, full_meta}

      {:error, reason} = error ->
        Logger.warning("[PlaygroundPresence] Track failed: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Update user's current component.
  """
  def update_component(user_id, component_name) do
    update(self(), @lobby_topic, user_id, fn meta ->
      Map.put(meta, :current_component, component_name)
    end)
  end

  @doc """
  Update user's editing status.
  """
  def update_editing(user_id, is_editing) do
    update(self(), @lobby_topic, user_id, fn meta ->
      Map.put(meta, :is_editing, is_editing)
    end)
  end

  @doc """
  Update user's cursor position in code editor.
  """
  def update_cursor(user_id, line, column) do
    update(self(), @lobby_topic, user_id, fn meta ->
      Map.put(meta, :cursor_position, %{line: line, column: column})
    end)
  end

  @doc """
  List all users in the playground.
  """
  def list_users do
    list(@lobby_topic)
    |> Enum.map(fn {user_id, %{metas: [meta | _]}} ->
      Map.put(meta, :user_id, user_id)
    end)
  end

  @doc """
  Get count of online users.
  """
  def user_count do
    @lobby_topic
    |> list()
    |> map_size()
  end

  @doc """
  Subscribe to presence updates.
  """
  def subscribe do
    Phoenix.PubSub.subscribe(RaxolPlayground.PubSub, @lobby_topic)
  end

  @doc """
  Untrack the current user.
  """
  def untrack_user(user_id) do
    untrack(self(), @lobby_topic, user_id)
  end

  @doc """
  Broadcast a playground event to all users.
  """
  def broadcast_event(event, payload) do
    Phoenix.PubSub.broadcast(
      RaxolPlayground.PubSub,
      @lobby_topic,
      {:playground_event, event, payload}
    )
  end

  @doc """
  Broadcast event to all users except sender.
  """
  def broadcast_event_from(from_pid, event, payload) do
    Phoenix.PubSub.broadcast_from(
      RaxolPlayground.PubSub,
      from_pid,
      @lobby_topic,
      {:playground_event, event, payload}
    )
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp generate_user_id do
    :crypto.strong_rand_bytes(8)
    |> Base.url_encode64(padding: false)
  end

  defp generate_color(user_id) do
    # Generate consistent color from user_id
    colors = [
      "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4",
      "#FFEAA7", "#DDA0DD", "#98D8C8", "#F7DC6F",
      "#BB8FCE", "#85C1E9", "#F8B500", "#00CED1"
    ]

    hash = :erlang.phash2(user_id)
    Enum.at(colors, rem(hash, length(colors)))
  end
end

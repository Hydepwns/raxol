defmodule RaxolWeb.Presence do
  @moduledoc """
  Real-time user presence tracking for Raxol web sessions.

  Uses Phoenix.Presence to track connected users, their cursor
  positions, and online status for collaborative terminal sessions.

  ## Features

  - Track users joining/leaving terminal sessions
  - Real-time cursor position synchronization
  - User metadata (name, color, permissions)
  - Connection state monitoring

  ## Example

      # In your LiveView or Channel
      def mount(_params, _session, socket) do
        if connected?(socket) do
          RaxolWeb.Presence.track_user(socket, user_id, %{
            name: "User",
            cursor: {0, 0},
            joined_at: System.system_time(:second)
          })
        end
        {:ok, socket}
      end

      # List all users in a session
      users = RaxolWeb.Presence.list_users("terminal:session123")
  """

  use Phoenix.Presence,
    otp_app: :raxol,
    pubsub_server: Raxol.PubSub

  alias Raxol.Core.Runtime.Log

  @type user_id :: String.t()
  @type metadata :: map()
  @type cursor_position :: {non_neg_integer(), non_neg_integer()}

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Track a user in a terminal session.

  ## Parameters

    - `socket` - Phoenix socket (LiveView or Channel)
    - `user_id` - Unique user identifier
    - `metadata` - User metadata (name, cursor, etc.)

  ## Example

      RaxolWeb.Presence.track_user(socket, "user123", %{
        name: "Alice",
        cursor: {0, 0},
        color: "#ff0000"
      })
  """
  @spec track_user(
          Phoenix.Socket.t() | Phoenix.LiveView.Socket.t(),
          user_id(),
          metadata()
        ) ::
          {:ok, binary()} | {:error, term()}
  def track_user(socket, user_id, metadata \\ %{}) do
    topic = get_topic(socket)

    default_metadata = %{
      online_at: System.system_time(:second),
      cursor: {0, 0},
      name: "Anonymous",
      color: generate_user_color(user_id)
    }

    full_metadata = Map.merge(default_metadata, metadata)

    case track(socket, topic, user_id, full_metadata) do
      {:ok, _} = result ->
        Log.debug("[Presence] Tracked user #{user_id} in #{topic}")
        result

      {:error, reason} = error ->
        Log.warning(
          "[Presence] Failed to track user #{user_id}: #{inspect(reason)}"
        )

        error
    end
  end

  @doc """
  Update a user's cursor position.

  Broadcasts the cursor update to all connected users in the session.

  ## Example

      RaxolWeb.Presence.update_cursor(socket, {10, 5})
  """
  @spec update_cursor(
          Phoenix.Socket.t() | Phoenix.LiveView.Socket.t(),
          cursor_position()
        ) ::
          {:ok, binary()} | {:error, term()}
  def update_cursor(socket, {x, y} = position)
      when is_integer(x) and is_integer(y) do
    topic = get_topic(socket)
    user_id = get_user_id(socket)

    update(socket, topic, user_id, fn meta ->
      Map.put(meta, :cursor, position)
    end)
  end

  @doc """
  Update user metadata.

  ## Example

      RaxolWeb.Presence.update_metadata(socket, %{status: :typing})
  """
  @spec update_metadata(
          Phoenix.Socket.t() | Phoenix.LiveView.Socket.t(),
          metadata()
        ) ::
          {:ok, binary()} | {:error, term()}
  def update_metadata(socket, new_metadata) when is_map(new_metadata) do
    topic = get_topic(socket)
    user_id = get_user_id(socket)

    update(socket, topic, user_id, fn meta ->
      Map.merge(meta, new_metadata)
    end)
  end

  @doc """
  List all users in a terminal session.

  ## Example

      users = RaxolWeb.Presence.list_users("terminal:session123")
      # => %{
      #   "user1" => %{metas: [%{cursor: {0, 0}, name: "Alice", ...}]},
      #   "user2" => %{metas: [%{cursor: {5, 10}, name: "Bob", ...}]}
      # }
  """
  @spec list_users(String.t()) :: map()
  def list_users(topic) when is_binary(topic) do
    list(topic)
  end

  @doc """
  Get the count of users in a session.

  ## Example

      count = RaxolWeb.Presence.user_count("terminal:session123")
      # => 3
  """
  @spec user_count(String.t()) :: non_neg_integer()
  def user_count(topic) when is_binary(topic) do
    topic
    |> list()
    |> map_size()
  end

  @doc """
  Get all cursor positions in a session.

  Returns a map of user_id to cursor position.

  ## Example

      cursors = RaxolWeb.Presence.get_cursors("terminal:session123")
      # => %{"user1" => {0, 0}, "user2" => {5, 10}}
  """
  @spec get_cursors(String.t()) :: map()
  def get_cursors(topic) when is_binary(topic) do
    topic
    |> list()
    |> Enum.map(fn {user_id, %{metas: [meta | _]}} ->
      {user_id, Map.get(meta, :cursor, {0, 0})}
    end)
    |> Map.new()
  end

  @doc """
  Untrack a user from all sessions.

  Typically called on disconnect.

  ## Example

      RaxolWeb.Presence.untrack_user(socket)
  """
  @spec untrack_user(Phoenix.Socket.t() | Phoenix.LiveView.Socket.t()) :: :ok
  def untrack_user(socket) do
    topic = get_topic(socket)
    user_id = get_user_id(socket)

    untrack(socket, topic, user_id)
    Log.debug("[Presence] Untracked user #{user_id} from #{topic}")
    :ok
  end

  @doc """
  Check if a user is present in a session.

  ## Example

      true = RaxolWeb.Presence.user_present?("terminal:session123", "user1")
  """
  @spec user_present?(String.t(), user_id()) :: boolean()
  def user_present?(topic, user_id)
      when is_binary(topic) and is_binary(user_id) do
    topic
    |> list()
    |> Map.has_key?(user_id)
  end

  @doc """
  Get metadata for a specific user.

  ## Example

      {:ok, meta} = RaxolWeb.Presence.get_user("terminal:session123", "user1")
  """
  @spec get_user(String.t(), user_id()) ::
          {:ok, metadata()} | {:error, :not_found}
  def get_user(topic, user_id) when is_binary(topic) and is_binary(user_id) do
    case list(topic) do
      %{^user_id => %{metas: [meta | _]}} -> {:ok, meta}
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Subscribe to presence events for a topic.

  ## Example

      RaxolWeb.Presence.subscribe("terminal:session123")
  """
  @spec subscribe(String.t()) :: :ok | {:error, term()}
  def subscribe(topic) when is_binary(topic) do
    Phoenix.PubSub.subscribe(Raxol.PubSub, topic)
  end

  @doc """
  Format presence diff for display.

  Converts Phoenix.Presence diff format into a more usable structure.

  ## Example

      formatted = RaxolWeb.Presence.format_diff(diff)
      # => %{joins: [%{user_id: "user1", ...}], leaves: [%{user_id: "user2", ...}]}
  """
  @spec format_diff(map()) :: map()
  def format_diff(%{joins: joins, leaves: leaves}) do
    %{
      joins: format_presence_list(joins),
      leaves: format_presence_list(leaves)
    }
  end

  # ============================================================================
  # Phoenix.Presence Callbacks
  # ============================================================================

  @doc false
  def fetch(_topic, presences) do
    presences
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp get_topic(socket) do
    case socket do
      %Phoenix.LiveView.Socket{} = s ->
        Map.get(s.assigns, :presence_topic, "terminal:default")

      %Phoenix.Socket{topic: topic} ->
        topic

      _ ->
        "terminal:default"
    end
  end

  defp get_user_id(socket) do
    case socket do
      %Phoenix.LiveView.Socket{} = s ->
        Map.get(s.assigns, :user_id, "anonymous")

      %Phoenix.Socket{assigns: assigns} ->
        Map.get(assigns, :user_id, "anonymous")

      _ ->
        "anonymous"
    end
  end

  defp generate_user_color(user_id) do
    # Generate a consistent color based on user_id hash
    hash =
      :crypto.hash(:md5, user_id)
      |> :binary.bin_to_list()
      |> Enum.take(3)

    [r, g, b] = hash
    "#" <> Base.encode16(<<r, g, b>>, case: :lower)
  end

  defp format_presence_list(presences) do
    Enum.map(presences, fn {user_id, %{metas: metas}} ->
      meta = List.first(metas) || %{}
      Map.put(meta, :user_id, user_id)
    end)
  end
end

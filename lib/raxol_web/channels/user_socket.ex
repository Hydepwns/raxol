defmodule RaxolWeb.UserSocket do
  use Phoenix.Socket
  require Logger

  # Channels
  channel("terminal:*", RaxolWeb.TerminalChannel)

  # Transports
  transport :websocket, Phoenix.Transports.WebSocket
  # transport :longpoll, Phoenix.Transports.LongPoll

  @doc """
  Identifies the socket connections.

  Socket params are passed from the client and can
  be used to verify and authenticate a user.

  To connect, url: "ws://localhost:4000/socket/websocket?user_id=123"
  """
  def connect(%{"user_id" => user_id} = _params, socket, _connect_info) do
    Logger.info("Connecting user with string key user_id: #{user_id}")
    {:ok, assign(socket, :user_id, user_id)}
  end

  # Handle atom keys (e.g., from tests)
  def connect(%{user_id: user_id} = _params, socket, _connect_info) do
    Logger.info("Connecting user with atom key user_id: #{user_id}")
    {:ok, assign(socket, :user_id, user_id)}
  end

  def connect(_params, _socket, _connect_info) do
    # Deny connections if user_id is not present or for other auth failures
    :error
  end

  @doc """
  Identifies the socket connections.
  """
  def id(socket), do: "user_socket:" <> socket.assigns.user_id
end

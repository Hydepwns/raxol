defmodule RaxolWeb.UserSocket do
  use Phoenix.Socket
  require Raxol.Core.Runtime.Log

  # Channels
  channel("terminal:*", RaxolWeb.TerminalChannel)
  channel("user:*", RaxolWeb.UserChannel)

  # Socket configuration
  @impl true
  def connect(%{user_id: user_id} = _params, socket, _connect_info) do
    Raxol.Core.Runtime.Log.info(
      "Connecting user with atom key user_id: #{user_id}"
    )

    {:ok, assign(socket, :user_id, user_id)}
  end

  def connect(_params, socket, _connect_info) do
    # Allow anonymous connections
    {:ok, socket}
  end

  @doc """
  Identifies the socket connections.
  """
  @impl true
  def id(socket), do: "user_socket:" <> socket.assigns.user_id
end

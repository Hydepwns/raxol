defmodule RaxolWeb.UserSocket do
  use Phoenix.Socket

  channel("terminal:*", RaxolWeb.TerminalChannel)
  channel("demo:terminal:*", RaxolWeb.DemoTerminalChannel)

  @impl true
  def connect(_params, socket, connect_info) do
    socket = assign(socket, :peer_data, connect_info[:peer_data])
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil
end

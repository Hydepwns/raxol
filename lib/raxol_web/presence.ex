defmodule RaxolWeb.Presence do
  @moduledoc """
  Phoenix Presence implementation for Raxol web interface.

  Tracks user presence across terminal sessions and web connections,
  enabling real-time collaboration features.
  """
  use Phoenix.Presence,
    otp_app: :raxol,
    pubsub_server: Raxol.PubSub
end

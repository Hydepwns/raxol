defmodule RaxolWeb.Presence do
  use Phoenix.Presence,
    otp_app: :raxol,
    pubsub_server: Raxol.PubSub
end

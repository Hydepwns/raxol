defmodule RaxolWeb.Endpoint do
  @moduledoc """
  The endpoint for RaxolWeb.
  """

  use Phoenix.Endpoint, otp_app: :raxol

  # Session configuration
  @session_options [
    store: :cookie,
    key: "_raxol_key",
    signing_salt: "raxol_salt"
  ]

  # Socket configuration
  socket("/socket", RaxolWeb.UserSocket,
    websocket: true,
    longpoll: false
  )

  # Serve at "/" the static files from "priv/static" directory.
  plug Plug.Static,
    at: "/",
    from: :raxol,
    gzip: false,
    only: ~w(css fonts images js favicon.ico robots.txt)

  # Tidewave AI development assistant
  if Code.ensure_loaded?(Tidewave) do
    plug Tidewave,
      inspect_opts: [charlists: :as_lists, limit: 100, pretty: true]
  end

  # Code reloading for development
  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options

  # Simple router for now
  plug RaxolWeb.Router
end

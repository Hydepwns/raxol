defmodule RaxolPlaygroundWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :raxol_playground

  @session_options [
    store: :cookie,
    key: "_raxol_playground_key",
    signing_salt: "raxol_playground",
    same_site: "Lax"
  ]

  # Redirect www to non-www in production
  if Mix.env() == :prod do
    plug RaxolPlaygroundWeb.Plugs.WwwRedirect
  end

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  if Mix.env() in [:dev, :test] do
    plug Phoenix.LiveDashboard.RequestLogger,
      param_key: "request_logger",
      cookie_key: "request_logger"
  end

  plug Plug.Static,
    at: "/",
    from: :raxol_playground,
    gzip: false,
    only: RaxolPlaygroundWeb.static_paths()

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :raxol_playground
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
  plug RaxolPlaygroundWeb.Router
end

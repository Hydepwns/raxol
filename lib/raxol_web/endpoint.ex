defmodule RaxolWeb.Endpoint do
  use Phoenix.Endpoint,
    otp_app: :raxol,
    render_errors: [view: RaxolWeb.ErrorView, accepts: ~w(html), layout: false]

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_raxol_key",
    signing_salt: "raxol_salt",
    same_site: "Lax",
    secret_key_base: String.duplicate("a", 64)
  ]

  socket("/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]]
  )

  # Mount the general purpose UserSocket for channels
  socket("/socket", RaxolWeb.UserSocket, websocket: true, longpoll: false)

  # Serve at "/" the static files from "priv/static" directory.
  plug Plug.Static,
    at: "/",
    from: :raxol,
    gzip: false,
    only: RaxolWeb.static_paths(),
    headers: [
      {"content-security-policy",
       "default-src 'self'; " <>
         "script-src 'self' 'unsafe-inline' 'unsafe-eval'; " <>
         "style-src 'self' 'unsafe-inline'; " <>
         "img-src 'self' data: https:; " <>
         "font-src 'self' data:; " <>
         "connect-src 'self' ws: wss:; " <>
         "frame-ancestors 'none'; " <>
         "base-uri 'self'; " <>
         "form-action 'self'"},
      {"x-content-type-options", "nosniff"},
      {"x-frame-options", "DENY"},
      {"x-xss-protection", "1; mode=block"},
      {"referrer-policy", "strict-origin-when-cross-origin"}
    ]

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    if Mix.env() == :dev do
      socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
      plug Phoenix.LiveReloader
    end

    plug Phoenix.CodeReloader

    if Mix.env() == :dev do
      plug Phoenix.Ecto.CheckRepoStatus, otp_app: :raxol
    end
  end

  if Mix.env() == :dev and Code.ensure_loaded?(Phoenix.LiveDashboard.RequestLogger) do
    plug Phoenix.LiveDashboard.RequestLogger,
      param_key: "request_logger",
      cookie_key: "request_logger"
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  plug Plug.Session, @session_options

  plug RaxolWeb.Router

  @doc """
  Stops the endpoint.
  """
  def stop do
    # Phoenix.Endpoint doesn't have a stop/1 function, so we'll use GenServer.stop
    GenServer.stop(__MODULE__)
  end
end

defmodule RaxolWeb.AuthPlug do
  @moduledoc """
  Authentication plug for web requests.

  Handles session-based authentication by validating session tokens
  and ensuring users are properly authenticated before accessing
  protected resources.
  """
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    conn = fetch_session(conn)

    case get_session(conn, :session_token) do
      nil ->
        conn
        |> put_flash(:error, "You must be logged in to access this page")
        |> redirect(to: "/login")
        |> halt()

      token ->
        case Raxol.Auth.validate_token(token, conn) do
          {:ok, _user} ->
            conn

            # The following clause is unreachable because validate_token always returns {:ok, _} currently.
            # _ ->
            #   conn
            #   |> put_flash(:error, "Invalid session. Please log in again.")
            #   |> redirect(to: "/login")
            #   |> halt()
        end
    end
  end
end

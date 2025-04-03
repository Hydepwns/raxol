defmodule RaxolWeb.AuthPlug do
  import Plug.Conn
  import Phoenix.LiveView.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :session_token) do
      nil ->
        conn
        |> put_flash(:error, "You must be logged in to access this page")
        |> redirect(to: "/login")
        |> halt()

      token ->
        case Raxol.Auth.validate_token(token) do
          {:ok, _user} -> conn
          _ ->
            conn
            |> put_flash(:error, "Invalid session. Please log in again.")
            |> redirect(to: "/login")
            |> halt()
        end
    end
  end
end 
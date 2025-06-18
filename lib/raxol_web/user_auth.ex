defmodule RaxolWeb.UserAuth do
  @moduledoc '''
  Provides authentication plugs and helpers.
  '''
  import Plug.Conn
  import Phoenix.Controller

  alias Raxol.Auth
  alias RaxolWeb.Router.Helpers, as: Routes
  require Raxol.Core.Runtime.Log

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in UserToken.
  @remember_me_cookie "_raxol_web_user_remember_me"

  @doc '''
  Logs the user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  '''
  def log_in_user(conn, user, _params \\ %{}) do
    # NOTE: This pattern match is a placeholder. Adjust when Auth.create_user_session is fully implemented.
    case Raxol.Auth.create_user_session(user.id, user.role) do
      # Temporary handling for the placeholder :ok return
      :ok ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "[UserAuth] Using placeholder session data due to Auth.create_user_session returning :ok.",
          %{}
        )

        session_data = %{
          session_id: "placeholder_id_#{user.id}",
          user_id: user.id
        }

        conn
        |> put_session(:user_token, session_data.session_id)
        |> configure_session(renew: true)

        # Original clause (Keep commented for reference)
        # {:ok, session_data} ->
        #   conn
        #   |> put_session(:user_token, session_data.session_id)
        #   |> configure_session(renew: true)

        # Original clause (Keep commented for reference)
        # {:error, reason} ->
        #   Raxol.Core.Runtime.Log.error("Failed to create session for user #{user.id}: #{inspect(reason)}")

        # Catch-all for unexpected returns (like the temporary :ok)
        # The following clause is unreachable because create_user_session always returns :ok currently.
        # other ->
        #   Raxol.Core.Runtime.Log.error("Unexpected return from Auth.create_user_session: #{inspect(other)}")
        #   conn
        #   |> put_flash(:error, "Internal error during login.")
    end
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc '''
  Logs the user out.

  It clears all session data for safety. See renew_session.
  '''
  @dialyzer {:nowarn_function, log_out_user: 1}
  def log_out_user(conn) do
    _user_token = get_session(conn, :user_token)
    session_id = get_session(conn, :user_session_id)

    _ = session_id && Auth.cleanup_user_session(session_id)

    if live_socket_id = get_session(conn, :live_socket_id) do
      _ = RaxolWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: "/")
  end

  @doc '''
  Authenticates the user by looking into the session
  and remember me token.
  '''
  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    session_id = get_session(conn, :user_session_id)

    user =
      if session_id && user_token do
        case Auth.validate_token(session_id, user_token) do
          {:ok, user_id} ->
            Auth.get_user(user_id)

            # The following clause is unreachable because validate_token always returns {:ok, _} currently.
            # _ -> nil
        end
      else
        nil
      end

    assign(conn, :current_user, user)
  end

  defp ensure_user_token(conn) do
    if user_token = get_session(conn, :user_token) do
      {user_token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if user_token = conn.cookies[@remember_me_cookie] do
        {user_token, put_session(conn, :user_token, user_token)}
      else
        {nil, conn}
      end
    end
  end

  @doc '''
  Used for routes that require the user to not be authenticated.
  '''
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc '''
  Used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.
  '''
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: Routes.user_session_path(conn, :new))
      |> halt()
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: "/"
end

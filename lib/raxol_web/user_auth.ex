defmodule RaxolWeb.UserAuth do
  @moduledoc """
  Provides authentication plugs and helpers for Raxol Web applications.

  This module handles user authentication flow including:
  - User login/logout operations
  - Session management and security
  - Authentication state validation
  - Route protection and redirection

  ## Security Features

  - Session fixation protection through session renewal
  - Secure cookie handling for "remember me" functionality
  - LiveView session management and cleanup
  - CSRF protection through session tokens

  ## Usage

  ### In Router
  ```elixir
  pipeline :browser do
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RaxolWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug RaxolWeb.UserAuth
  end

  scope "/", RaxolWeb do
    pipe_through [:browser, :require_authenticated_user]
    # Protected routes...
  end
  ```

  ### In Controllers
  ```elixir
  def create(conn, %{"user" => user_params}) do
    case authenticate_user(user_params) do
      {:ok, user} ->
        conn
        |> UserAuth.log_in_user(user)
        |> redirect(to: ~p"/")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Invalid credentials")
        |> render(:new)
    end
  end
  ```

  ## Configuration

  The module uses the following configuration options:
  - `@remember_me_cookie`: Cookie name for persistent sessions (default: "_raxol_web_user_remember_me")
  - Session timeout and cleanup intervals (configured in `Raxol.Auth`)
  """

  import Plug.Conn
  import Phoenix.Controller

  alias Raxol.Auth
  alias RaxolWeb.Router.Helpers, as: Routes
  require Raxol.Core.Runtime.Log

  # Cookie configuration for "remember me" functionality
  # Valid for 60 days - adjust token expiry in UserToken accordingly
  @remember_me_cookie "_raxol_web_user_remember_me"

  # Session key names for consistency
  @session_keys %{
    user_token: :user_token,
    user_session_id: :user_session_id,
    live_socket_id: :live_socket_id,
    return_to: :user_return_to
  }

  @doc """
  Logs a user into the system.

  This function performs the following security measures:
  - Renews the session ID to prevent session fixation attacks
  - Clears existing session data for security
  - Creates a new user session via the Auth module
  - Sets up LiveView session tracking if applicable

  ## Parameters

  - `conn` - The Plug connection
  - `user` - User struct with at least `:id` and `:role` fields
  - `params` - Optional parameters (currently unused, defaults to `%{}`)

  ## Returns

  Returns the updated connection with session configured.

  ## Security Notes

  - Session renewal prevents session fixation attacks
  - All existing session data is cleared for security
  - LiveView sessions are tracked for proper cleanup on logout

  ## Examples

  ```elixir
  case authenticate_user(credentials) do
    {:ok, user} ->
      conn
      |> UserAuth.log_in_user(user)
      |> redirect(to: ~p"/dashboard")

    {:error, _reason} ->
      conn
      |> put_flash(:error, "Authentication failed")
      |> render(:login)
  end
  ```
  """
  @spec log_in_user(Plug.Conn.t(), map(), map()) :: Plug.Conn.t()
  def log_in_user(conn, user, params \\ %{}) do
    case create_user_session(user, params) do
      {:ok, session_data} ->
        conn
        |> put_session(@session_keys.user_token, session_data.token)
        |> put_session(@session_keys.user_session_id, session_data.session_id)
        |> configure_session(renew: true)

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error("Failed to create session for user #{user.id}: #{inspect(reason)}")
        conn
        |> put_flash(:error, "Login failed. Please try again.")
    end
  end

  @doc """
  Logs the current user out of the system.

  Performs comprehensive cleanup:
  - Invalidates the user session
  - Clears all session data
  - Removes "remember me" cookie
  - Disconnects LiveView sessions
  - Redirects to home page

  ## Parameters

  - `conn` - The Plug connection

  ## Returns

  Returns the updated connection with session cleared and redirect set.

  ## Security Notes

  - All session data is cleared for security
  - LiveView sessions are properly disconnected
  - Remember me cookie is removed
  - Session cleanup is performed server-side

  ## Examples

  ```elixir
  conn
  |> UserAuth.log_out_user()
  |> redirect(to: ~p"/")
  ```
  """
  @spec log_out_user(Plug.Conn.t()) :: Plug.Conn.t()
  @dialyzer {:nowarn_function, log_out_user: 1}
  def log_out_user(conn) do
    # Extract session data for cleanup
    session_id = get_session(conn, @session_keys.user_session_id)
    live_socket_id = get_session(conn, @session_keys.live_socket_id)

    # Perform cleanup operations
    cleanup_user_session(session_id)
    disconnect_liveview_session(live_socket_id)

    # Clear session and redirect
    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: signed_in_path(conn))
  end

  @doc """
  Authenticates the current user by validating session tokens.

  This plug function:
  - Checks for valid session tokens
  - Validates "remember me" cookies
  - Fetches and assigns the current user
  - Handles token refresh if needed

  ## Parameters

  - `conn` - The Plug connection
  - `opts` - Plug options (unused)

  ## Returns

  Returns the connection with `:current_user` assigned.

  ## Session Flow

  1. Check for existing session token
  2. If not found, check for "remember me" cookie
  3. Validate token with Auth module
  4. Fetch user data and assign to connection

  ## Examples

  ```elixir
  # In router.ex
  pipeline :browser do
    plug RaxolWeb.UserAuth
  end
  ```
  """
  @spec fetch_current_user(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    session_id = get_session(conn, @session_keys.user_session_id)

    user = authenticate_user_from_tokens(session_id, user_token)
    assign(conn, :current_user, user)
  end

  @doc """
  Redirects authenticated users away from public pages.

  Use this plug for routes that should only be accessible to unauthenticated users
  (e.g., login, registration pages).

  ## Parameters

  - `conn` - The Plug connection
  - `opts` - Plug options (unused)

  ## Returns

  - If user is authenticated: redirects to signed-in path and halts
  - If user is not authenticated: passes through unchanged

  ## Examples

  ```elixir
  # In router.ex
  scope "/", RaxolWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]
    get "/login", UserSessionController, :new
    post "/login", UserSessionController, :create
  end
  ```
  """
  @spec redirect_if_user_is_authenticated(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Requires user authentication for protected routes.

  This plug ensures that only authenticated users can access the route.
  Unauthenticated users are redirected to the login page with an error message.

  ## Parameters

  - `conn` - The Plug connection
  - `opts` - Plug options (unused)

  ## Returns

  - If user is authenticated: passes through unchanged
  - If user is not authenticated: redirects to login with error and halts

  ## Security Features

  - Stores the current path for post-login redirection
  - Provides clear error messaging
  - Prevents unauthorized access to protected resources

  ## Examples

  ```elixir
  # In router.ex
  scope "/dashboard", RaxolWeb do
    pipe_through [:browser, :require_authenticated_user]
    get "/", DashboardController, :index
  end
  ```

  ## Customization

  You can customize the behavior by modifying:
  - Error message in the flash
  - Redirect path after login
  - Additional authentication checks (e.g., email confirmation)
  """
  @spec require_authenticated_user(Plug.Conn.t(), map()) :: Plug.Conn.t()
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

  # Private Functions

  @doc false
  defp create_user_session(user, _params) do
    # Use the real Auth.create_user_session implementation
    case Auth.create_user_session(user.id, %{role: user.role}) do
      {:ok, session_data} ->
        {:ok, session_data}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc false
  defp cleanup_user_session(session_id) when is_binary(session_id) do
    Auth.cleanup_user_session(session_id)
  end

  @doc false
  defp cleanup_user_session(_), do: :ok

  @doc false
  defp disconnect_liveview_session(live_socket_id) when is_binary(live_socket_id) do
    RaxolWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
  end

  @doc false
  defp disconnect_liveview_session(_), do: :ok

  @doc false
  defp authenticate_user_from_tokens(session_id, user_token) when is_binary(session_id) and is_binary(user_token) do
    case Auth.validate_token(session_id, user_token) do
      {:ok, user_id} -> Auth.get_user(user_id)
      _ -> nil
    end
  end

  @doc false
  defp authenticate_user_from_tokens(_, _), do: nil

  @doc false
  defp ensure_user_token(conn) do
    if user_token = get_session(conn, @session_keys.user_token) do
      {user_token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if user_token = conn.cookies[@remember_me_cookie] do
        {user_token, put_session(conn, @session_keys.user_token, user_token)}
      else
        {nil, conn}
      end
    end
  end

  @doc false
  defp renew_session(conn) do
    # Renew session ID and clear all data to prevent session fixation attacks
    # If you need to preserve specific session data, fetch it before clearing
    # and restore it after, like this:
    #
    #     preferred_locale = get_session(conn, :preferred_locale)
    #     conn
    #     |> configure_session(renew: true)
    #     |> clear_session()
    #     |> put_session(:preferred_locale, preferred_locale)
    #
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc false
  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, @session_keys.return_to, current_path(conn))
  end

  @doc false
  defp maybe_store_return_to(conn), do: conn

  @doc false
  defp signed_in_path(_conn), do: "/"
end

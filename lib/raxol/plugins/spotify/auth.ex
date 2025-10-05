defmodule Raxol.Plugins.Spotify.Auth do
  @moduledoc """
  Spotify OAuth 2.0 authentication handler.

  Manages the OAuth flow for obtaining and refreshing access tokens.
  """

  @auth_url "https://accounts.spotify.com/authorize"
  @token_url "https://accounts.spotify.com/api/token"
  @default_scope "user-read-playback-state user-modify-playback-state user-read-currently-playing playlist-read-private"

  def start_auth(config) do
    scope = Map.get(config, :scope, @default_scope)
    scope_str = if is_list(scope), do: Enum.join(scope, " "), else: scope

    params = %{
      client_id: config.client_id,
      response_type: "code",
      redirect_uri: config.redirect_uri,
      scope: scope_str
    }

    query = URI.encode_query(params)
    auth_url = "#{@auth_url}?#{query}"

    {:ok, auth_url}
  end

  def complete_auth(code, config) do
    body = %{
      grant_type: "authorization_code",
      code: code,
      redirect_uri: config.redirect_uri,
      client_id: config.client_id,
      client_secret: config.client_secret
    }

    case Req.post(@token_url, form: body) do
      {:ok,
       %{
         status: 200,
         body: %{"access_token" => token, "refresh_token" => refresh}
       }} ->
        # Store tokens (simplified - in production use proper storage)
        :persistent_term.put({__MODULE__, :access_token}, token)
        :persistent_term.put({__MODULE__, :refresh_token}, refresh)
        {:ok, token}

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_access_token do
    case :persistent_term.get({__MODULE__, :access_token}, nil) do
      nil -> {:error, :not_authenticated}
      token -> {:ok, token}
    end
  end

  def refresh_token(config) do
    case :persistent_term.get({__MODULE__, :refresh_token}, nil) do
      nil ->
        {:error, :no_refresh_token}

      refresh_token ->
        body = %{
          grant_type: "refresh_token",
          refresh_token: refresh_token,
          client_id: config.client_id,
          client_secret: config.client_secret
        }

        case Req.post(@token_url, form: body) do
          {:ok, %{status: 200, body: %{"access_token" => new_token}}} ->
            :persistent_term.put({__MODULE__, :access_token}, new_token)
            {:ok, new_token}

          error ->
            {:error, error}
        end
    end
  end
end

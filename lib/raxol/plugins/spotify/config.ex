defmodule Raxol.Plugins.Spotify.Config do
  @moduledoc """
  Configuration validation for Spotify plugin.
  """

  def validate(opts) do
    client_id = get_config(opts, :client_id, "SPOTIFY_CLIENT_ID")
    client_secret = get_config(opts, :client_secret, "SPOTIFY_CLIENT_SECRET")
    redirect_uri = get_config(opts, :redirect_uri, "SPOTIFY_REDIRECT_URI")

    cond do
      !client_id ->
        {:error, "Missing required config: client_id"}

      !client_secret ->
        {:error, "Missing required config: client_secret"}

      !redirect_uri ->
        {:error, "Missing required config: redirect_uri"}

      true ->
        {:ok,
         [
           client_id: client_id,
           client_secret: client_secret,
           redirect_uri: redirect_uri
         ]}
    end
  end

  def validate!(opts) do
    case validate(opts) do
      {:ok, config} -> config
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  defp get_config(opts, key, env_var) do
    opts[key] ||
      (Application.get_env(:raxol, Raxol.Plugins.Spotify) || [])[key] ||
      System.get_env(env_var)
  end
end

defmodule Raxol.Plugins.Spotify.API do
  @moduledoc """
  Spotify Web API client.

  Provides functions to interact with Spotify's REST API including playback control,
  playlist management, and search capabilities.
  """

  alias Raxol.Plugins.Spotify.Auth

  @base_url "https://api.spotify.com/v1"

  defstruct [:access_token, :refresh_token, :expires_at]

  @type t :: %__MODULE__{
          access_token: String.t(),
          refresh_token: String.t() | nil,
          expires_at: integer() | nil
        }

  @doc """
  Creates a new API client with an access token.
  """
  def new(access_token, opts \\ []) do
    %__MODULE__{
      access_token: access_token,
      refresh_token: Keyword.get(opts, :refresh_token),
      expires_at: Keyword.get(opts, :expires_at)
    }
  end

  @doc """
  Generates Spotify authorization URL for OAuth flow.
  """
  def get_authorization_url(opts) do
    config = %{
      client_id: Keyword.fetch!(opts, :client_id),
      redirect_uri: Keyword.fetch!(opts, :redirect_uri)
    }

    config =
      if scope = Keyword.get(opts, :scope) do
        Map.put(config, :scope, scope)
      else
        config
      end

    # Auth.start_auth always returns {:ok, url}
    {:ok, url} = Auth.start_auth(config)
    url
  end

  # User & Profile
  def get_current_user do
    make_request(:get, "/me")
  end

  # Playback
  def get_currently_playing do
    make_request(:get, "/me/player/currently-playing")
  end

  def get_playback_state do
    make_request(:get, "/me/player")
  end

  def control_playback(action)
      when action in [:play, :pause, :next, :previous] do
    case action do
      :play -> make_request(:put, "/me/player/play")
      :pause -> make_request(:put, "/me/player/pause")
      :next -> make_request(:post, "/me/player/next")
      :previous -> make_request(:post, "/me/player/previous")
    end
  end

  def set_volume(volume) when volume >= 0 and volume <= 100 do
    make_request(:put, "/me/player/volume?volume_percent=#{volume}")
  end

  # Client-based API (for compatibility with tests)
  def set_volume(_client, volume) when volume >= 0 and volume <= 100 do
    set_volume(volume)
  end

  # Playlists
  def get_user_playlists(limit \\ 20) do
    make_request(:get, "/me/playlists?limit=#{limit}")
  end

  def get_playlist_tracks(playlist_id, limit \\ 50) do
    make_request(:get, "/playlists/#{playlist_id}/tracks?limit=#{limit}")
  end

  def play_playlist(uri) do
    make_request(:put, "/me/player/play", %{context_uri: uri})
  end

  # Devices
  def get_devices do
    case make_request(:get, "/me/player/devices") do
      {:ok, %{"devices" => devices}} -> {:ok, devices}
      error -> error
    end
  end

  def transfer_playback(device_id) do
    make_request(:put, "/me/player", %{device_ids: [device_id]})
  end

  # Search
  def search(query, types \\ [:track], opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    type_str = Enum.map_join(types, ",", &Atom.to_string/1)
    encoded_query = URI.encode(query)

    make_request(
      :get,
      "/search?q=#{encoded_query}&type=#{type_str}&limit=#{limit}"
    )
  end

  # HTTP Request Handler
  defp make_request(method, path, body \\ nil) do
    case Auth.get_access_token() do
      {:ok, token} ->
        headers = [{"Authorization", "Bearer #{token}"}]
        url = @base_url <> path

        opts = [
          method: method,
          url: url,
          headers: headers
        ]

        opts = if body, do: [{:json, body} | opts], else: opts

        case Req.request(opts) do
          {:ok, %{status: status, body: body}} when status in 200..299 ->
            {:ok, body}

          {:ok, %{status: 204}} ->
            :ok

          {:ok, %{status: status, body: body}} ->
            {:error, {status, body}}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, {:auth_error, reason}}
    end
  end
end

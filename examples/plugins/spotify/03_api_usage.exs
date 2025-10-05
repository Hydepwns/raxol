#!/usr/bin/env elixir

# Direct Spotify API Usage
#
# This example shows how to use the Spotify API module directly
# without the full plugin interface. Useful for custom integrations.
#
# Prerequisites:
# - SPOTIFY_CLIENT_ID and SPOTIFY_CLIENT_SECRET environment variables
# - Access token from previous authentication

Mix.install([
  {:raxol, path: Path.expand("../../..", __DIR__)},
  {:req, "~> 0.5"},
  {:oauth2, "~> 2.1"}
])

alias Raxol.Plugins.Spotify.{API, Auth, Config}

# Validate configuration
config = Config.validate!([])

# Check if we have an existing token
case Auth.get_access_token() do
  {:ok, _token} ->
    IO.puts("Authenticated! Fetching current track...")

    # Get currently playing track
    case API.get_currently_playing() do
      {:ok, %{body: %{"item" => track}}} ->
        artist = track["artists"] |> List.first() |> Map.get("name")
        song = track["name"]
        IO.puts("Now playing: #{song} by #{artist}")

        # Get user's playlists
        case API.get_user_playlists(5) do
          {:ok, %{body: %{"items" => playlists}}} ->
            IO.puts("\nYour playlists:")

            Enum.each(playlists, fn playlist ->
              IO.puts(
                "  - #{playlist["name"]} (#{playlist["tracks"]["total"]} tracks)"
              )
            end)

          {:error, reason} ->
            IO.puts("Error fetching playlists: #{inspect(reason)}")
        end

      {:ok, %{body: body}} ->
        IO.puts("Nothing currently playing")
        IO.inspect(body, label: "Response")

      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
    end

  {:error, :not_authenticated} ->
    IO.puts("""
    Not authenticated. Please run the Spotify plugin first to authenticate:

      Raxol.Plugin.run(Raxol.Plugins.Spotify.SpotifyPlugin)

    Then run this script again.
    """)
end

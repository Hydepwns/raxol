# Spotify Plugin

Control Spotify playback from your terminal.

## Features

- View currently playing track with ASCII album art and progress bar
- Full playback controls (play/pause/next/previous)
- Volume control
- Browse and play playlists
- Search for tracks, albums, and artists
- Device management (switch between speakers, phone, computer, etc.)
- Shuffle and repeat modes

## Prerequisites

1. **Spotify Premium Account** -- required for playback control via API
2. **Spotify Developer Account** -- free at [developer.spotify.com](https://developer.spotify.com)
3. **Elixir Dependencies** -- `req` and `oauth2` packages

## Setup

### 1. Create a Spotify Application

1. Go to the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Click "Create App"
3. Fill in the details:
   - App name: "Raxol Terminal"
   - App description: "Terminal-based Spotify control"
   - Redirect URI: `http://localhost:8888/callback`
4. Save your **Client ID** and **Client Secret**

### 2. Install Dependencies

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:raxol, "~> 2.0"},
    {:req, "~> 0.5"},
    {:oauth2, "~> 2.1"}
  ]
end
```

Then run `mix deps.get`.

### 3. Configure Credentials

**Environment variables (recommended for development):**

```bash
export SPOTIFY_CLIENT_ID="your_client_id_here"
export SPOTIFY_CLIENT_SECRET="your_client_secret_here"
export SPOTIFY_REDIRECT_URI="http://localhost:8888/callback"
```

**Application config:**

```elixir
# config/config.exs
config :raxol, Raxol.Plugins.Spotify,
  client_id: "your_client_id_here",
  client_secret: "your_client_secret_here",
  redirect_uri: "http://localhost:8888/callback"
```

**Runtime config (recommended for production):**

```elixir
# config/runtime.exs
config :raxol, Raxol.Plugins.Spotify,
  client_id: System.get_env("SPOTIFY_CLIENT_ID"),
  client_secret: System.get_env("SPOTIFY_CLIENT_SECRET"),
  redirect_uri: System.get_env("SPOTIFY_REDIRECT_URI")
```

### 4. Authenticate

On first run, you need to complete the OAuth flow:

```elixir
Raxol.Plugin.run(Raxol.Plugins.Spotify)

# Press 'a' to start OAuth flow
# Open the displayed URL in your browser
# Authorize the app
# Copy the authorization code from the redirect URL
# Paste it into the terminal
```

The access token is stored in memory for the session. For persistent tokens, see Advanced Usage below.

## Usage

### Standalone

```elixir
Raxol.Plugin.run(Raxol.Plugins.Spotify)
```

### Integrated into a Terminal App

```elixir
defmodule MyApp.Terminal do
  alias Raxol.Core.Buffer
  alias Raxol.Plugins.Spotify

  def run do
    {:ok, state} = Spotify.init([])
    buffer = Buffer.create_blank_buffer(80, 24)
    loop(buffer, state)
  end

  defp loop(buffer, state) do
    buffer = Spotify.render(buffer, state)
    IO.puts(Buffer.to_string(buffer))

    key = get_key()
    modifiers = %{ctrl: false, alt: false, shift: false, meta: false}

    case Spotify.handle_input(key, modifiers, state) do
      {:ok, new_state} -> loop(buffer, new_state)
      {:exit, _} -> :ok
    end
  end
end
```

## Controls

### Playback
- `SPACE` -- Play/pause
- `n` -- Next track
- `p` -- Previous track

### Volume
- `+` -- Increase volume by 10%
- `-` -- Decrease volume by 10%

### Modes
- `s` -- Toggle shuffle
- `r` -- Cycle repeat mode (off -> context -> track -> off)

### Navigation
- `l` -- View playlists
- `d` -- View devices
- `/` -- Search

### General
- `q` -- Quit plugin
- `ESC` -- Go back (from submenus)

## API Usage

The plugin can also be used programmatically:

```elixir
alias Raxol.Plugins.Spotify.API

client = API.new("your_access_token")

# Get currently playing
{:ok, track} = API.get_now_playing(client)

# Playback control
:ok = API.play(client)
:ok = API.pause(client)
:ok = API.next(client)
:ok = API.previous(client)

# Volume (0-100)
:ok = API.set_volume(client, 50)

# Playlists
{:ok, playlists} = API.get_playlists(client)

# Devices
{:ok, devices} = API.get_devices(client)

# Search
{:ok, results} = API.search(client, "The Beatles", type: "artist,track")
```

## Advanced Usage

### Persistent Token Storage

Store refresh tokens to avoid re-authenticating every session:

```elixir
defmodule MyApp.SpotifyAuth do
  alias Raxol.Plugins.Spotify.API

  def get_client do
    case load_refresh_token() do
      nil ->
        authenticate_new()

      refresh_token ->
        client = API.new("", refresh_token: refresh_token)

        case API.refresh_token(client, get_config()) do
          {:ok, new_client} -> {:ok, new_client}
          {:error, _} -> authenticate_new()
        end
    end
  end

  defp authenticate_new do
    config = get_config()
    auth_url = API.get_authorization_url(config)

    IO.puts("Open: #{auth_url}")
    code = IO.gets("Enter code: ") |> String.trim()

    case API.exchange_code(Keyword.put(config, :code, code)) do
      {:ok, client} ->
        save_refresh_token(client.refresh_token)
        {:ok, client}

      error ->
        error
    end
  end

  defp load_refresh_token do
    case File.read(".spotify_token") do
      {:ok, token} -> token
      _ -> nil
    end
  end

  defp save_refresh_token(token) do
    File.write(".spotify_token", token)
  end

  defp get_config do
    Application.get_env(:raxol, Raxol.Plugins.Spotify)
  end
end
```

### Custom Scopes

Request specific Spotify permissions:

```elixir
config = [
  client_id: "...",
  client_secret: "...",
  redirect_uri: "...",
  scope: [
    "user-read-playback-state",
    "user-modify-playback-state",
    "user-read-currently-playing",
    "playlist-read-private",
    "playlist-modify-public",
    "user-library-read",
    "user-library-modify"
  ]
]

auth_url = Raxol.Plugins.Spotify.API.get_authorization_url(config)
```

Full list of scopes: [Spotify Authorization Scopes](https://developer.spotify.com/documentation/web-api/concepts/scopes).

## Troubleshooting

**"Invalid client" error** -- Double-check your `client_id` and `client_secret`. Make sure the redirect URI in your config matches the one in your Spotify app settings exactly.

**"Premium required" error** -- The Spotify Web API requires a Premium account for playback control. Reading playback state works with free accounts.

**Token expired** -- Implement refresh token logic (see Advanced Usage). Tokens expire after 1 hour.

**No devices available** -- Spotify needs to be open on at least one device, and the device must have been recently active.

**Rate limiting** -- The Spotify API has rate limits (typically 1000 requests/hour). Use caching and batch requests where possible.

## Examples

See `examples/plugins/spotify/` for:

- `01_simple_playback.exs` -- Basic play/pause control
- `02_playlist_browser.exs` -- Browse and play playlists
- `03_search_and_play.exs` -- Search and play tracks
- `04_device_switcher.exs` -- Switch between devices

## Credits

Inspired by the implementation in [droodotfoo](https://droodotfoo.foo).

## License

MIT License -- See LICENSE file.

# Spotify Plugin

Control Spotify playback from your terminal using Raxol's Spotify plugin.

## Features

- View currently playing track with album art (ASCII) and progress bar
- Full playback controls (play/pause/next/previous)
- Volume control
- Browse and play playlists
- Search for tracks, albums, and artists
- Device management (switch between speakers, phone, computer, etc.)
- Shuffle and repeat modes

## Prerequisites

1. **Spotify Premium Account** - Required for playback control via API
2. **Spotify Developer Account** - Free at [developer.spotify.com](https://developer.spotify.com)
3. **Elixir Dependencies** - `req` and `oauth2` packages

## Setup

### 1. Create Spotify Application

1. Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
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
    {:req, "~> 0.5"},      # HTTP client
    {:oauth2, "~> 2.1"}     # OAuth2 flow
  ]
end
```

Run:

```bash
mix deps.get
```

### 3. Configure Credentials

**Option A: Environment Variables (Recommended for development)**

```bash
export SPOTIFY_CLIENT_ID="your_client_id_here"
export SPOTIFY_CLIENT_SECRET="your_client_secret_here"
export SPOTIFY_REDIRECT_URI="http://localhost:8888/callback"
```

**Option B: Application Config**

```elixir
# config/config.exs
config :raxol, Raxol.Plugins.Spotify,
  client_id: "your_client_id_here",
  client_secret: "your_client_secret_here",
  redirect_uri: "http://localhost:8888/callback"
```

**Option C: Runtime Config (Recommended for production)**

```elixir
# config/runtime.exs
config :raxol, Raxol.Plugins.Spotify,
  client_id: System.get_env("SPOTIFY_CLIENT_ID"),
  client_secret: System.get_env("SPOTIFY_CLIENT_SECRET"),
  redirect_uri: System.get_env("SPOTIFY_REDIRECT_URI")
```

### 4. Authenticate

First time running the plugin, you'll need to authenticate:

```elixir
# Run the plugin
Raxol.Plugin.run(Raxol.Plugins.Spotify)

# Press 'a' to start OAuth flow
# Open the displayed URL in your browser
# Authorize the app
# Copy the authorization code from the redirect URL
# Paste it into the terminal
```

The access token is stored in memory during the session. For persistent tokens, implement token storage (see Advanced Usage below).

## Usage

### Standalone Mode

```elixir
# Run the plugin directly
Raxol.Plugin.run(Raxol.Plugins.Spotify)
```

### Integrated Mode

```elixir
# In your terminal application
defmodule MyApp.Terminal do
  alias Raxol.Core.Buffer
  alias Raxol.Plugins.Spotify

  def run do
    {:ok, state} = Spotify.init([])
    buffer = Buffer.create_blank_buffer(80, 24)

    # Game loop
    loop(buffer, state)
  end

  defp loop(buffer, state) do
    # Render plugin
    buffer = Spotify.render(buffer, state)
    IO.puts(Buffer.to_string(buffer))

    # Handle input
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

- `SPACE` - Play/pause
- `n` - Next track
- `p` - Previous track

### Volume

- `+` - Increase volume by 10%
- `-` - Decrease volume by 10%

### Modes

- `s` - Toggle shuffle
- `r` - Cycle repeat mode (off → context → track → off)

### Navigation

- `l` - View playlists
- `d` - View devices
- `/` - Search

### General

- `q` - Quit plugin
- `ESC` - Go back (from submenus)

## API Usage

The Spotify plugin can also be used programmatically:

```elixir
alias Raxol.Plugins.Spotify.API

# Initialize with access token
client = API.new("your_access_token")

# Get currently playing
{:ok, track} = API.get_now_playing(client)

# Playback control
:ok = API.play(client)
:ok = API.pause(client)
:ok = API.next(client)
:ok = API.previous(client)

# Volume control (0-100)
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

Store refresh tokens to avoid re-authenticating:

```elixir
defmodule MyApp.SpotifyAuth do
  alias Raxol.Plugins.Spotify.API

  def get_client do
    case load_refresh_token() do
      nil ->
        # No saved token, start OAuth flow
        authenticate_new()

      refresh_token ->
        # Refresh existing token
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
    # Load from file, database, etc.
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

See [Spotify Authorization Scopes](https://developer.spotify.com/documentation/web-api/concepts/scopes) for full list.

## Troubleshooting

### "Invalid client" error

- Verify `client_id` and `client_secret` are correct
- Check that redirect URI in config matches your Spotify app settings exactly

### "Premium required" error

- Spotify Web API requires a Premium account for playback control
- Reading playback state works with free accounts

### Token expired

- Implement refresh token logic (see Advanced Usage)
- Tokens expire after 1 hour by default

### No devices available

- Make sure Spotify is open on at least one device
- Device must be actively playing or have been recently used

### Rate limiting

- Spotify API has rate limits (typically 1000 requests per hour)
- Implement caching and batch requests when possible

## Examples

See `examples/plugins/spotify/` for:

- `01_simple_playback.exs` - Basic play/pause control
- `02_playlist_browser.exs` - Browse and play playlists
- `03_search_and_play.exs` - Search and play tracks
- `04_device_switcher.exs` - Switch between devices

## Credits

This plugin was inspired by the implementation in [droodotfoo](https://droodotfoo.foo).

## License

MIT License - See LICENSE file for details

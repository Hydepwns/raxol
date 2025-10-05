# Spotify Plugin Examples

This directory contains practical examples demonstrating the Raxol Spotify plugin.

## Prerequisites

### 1. Spotify Developer Credentials

1. Create a Spotify Developer account at [developer.spotify.com](https://developer.spotify.com)
2. Create a new app in the [Dashboard](https://developer.spotify.com/dashboard)
3. Set the redirect URI to: `http://localhost:8888/callback`
4. Note your Client ID and Client Secret

### 2. Environment Setup

```bash
export SPOTIFY_CLIENT_ID="your_client_id_here"
export SPOTIFY_CLIENT_SECRET="your_client_secret_here"
export SPOTIFY_REDIRECT_URI="http://localhost:8888/callback"
```

Or add to your `.envrc` (if using direnv):

```bash
export SPOTIFY_CLIENT_ID=your_client_id_here
export SPOTIFY_CLIENT_SECRET=your_client_secret_here
```

### 3. Dependencies

The examples use `Mix.install` to automatically install dependencies:
- `raxol` - The Raxol framework
- `req` - HTTP client for Spotify API
- `oauth2` - OAuth 2.0 authentication

No manual installation needed!

## Examples

### 01_simple_playback.exs

**Simplest usage** - Run the Spotify plugin standalone.

```bash
./examples/plugins/spotify/01_simple_playback.exs
```

**Controls:**
- `a` - Authenticate (first time only)
- `SPACE` - Play/pause
- `n` - Next track
- `p` - Previous track
- `q` - Quit

**What it demonstrates:**
- Basic plugin execution with `Raxol.Plugin.run/1`
- OAuth authentication flow
- Simple playback controls

---

### 02_playlist_browser.exs

**Browse and play playlists** from your Spotify account.

```bash
./examples/plugins/spotify/02_playlist_browser.exs
```

**Controls:**
- `l` - View playlists
- `UP/DOWN` - Navigate playlists
- `ENTER` - Play selected playlist
- `ESC` - Back to main view
- `q` - Quit

**What it demonstrates:**
- Navigating plugin modes
- Playlist browsing interface
- Selection and playback

---

### 03_api_usage.exs

**Direct API usage** without the full plugin interface.

```bash
./examples/plugins/spotify/03_api_usage.exs
```

**What it demonstrates:**
- Using `Raxol.Plugins.Spotify.API` module directly
- Programmatic access to Spotify data
- Custom integrations without UI
- Useful for scripts and automation

---

### 04_custom_integration.exs

**Advanced**: Embed Spotify plugin in a custom terminal application.

```bash
./examples/plugins/spotify/04_custom_integration.exs
```

**Controls:**
- `TAB` - Switch between custom and Spotify modes
- `q` - Quit
- Spotify controls (when in Spotify mode)

**What it demonstrates:**
- Embedding plugin state in custom application state
- Combining plugin rendering with custom UI
- Forwarding input to plugins conditionally
- Building complex terminal applications with plugins

## Authentication Flow

On first run, you'll need to authenticate:

1. Press `a` in the plugin to start OAuth flow
2. Open the displayed URL in your browser
3. Authorize the application
4. You'll be redirected to `http://localhost:8888/callback?code=...`
5. Copy the `code` parameter from the URL
6. Paste it into the terminal

The access token is stored for the duration of your session.

### Persistent Authentication

For production use, implement token persistence:

```elixir
# Save refresh token
File.write(".spotify_refresh_token", refresh_token)

# Load and refresh on startup
refresh_token = File.read!(".spotify_refresh_token")
{:ok, client} = Raxol.Plugins.Spotify.Auth.refresh_token(config)
```

See `docs/plugins/SPOTIFY.md` for detailed implementation.

## Troubleshooting

### "Invalid client" error

- Verify `SPOTIFY_CLIENT_ID` and `SPOTIFY_CLIENT_SECRET` are correct
- Ensure redirect URI matches exactly: `http://localhost:8888/callback`

### "Premium required" error

- Spotify Web API requires Premium for playback control
- Reading playback state works with free accounts

### "No devices available"

- Open Spotify on at least one device (phone, computer, speakers)
- Device must be actively playing or recently used

### Token expired

- Tokens expire after 1 hour
- Re-authenticate or implement refresh token flow

## Next Steps

- Read the [Spotify Plugin Guide](../../../docs/plugins/SPOTIFY.md)
- Learn about [Building Plugins](../../../docs/plugins/BUILDING_PLUGINS.md)
- Explore the [API documentation](../../../lib/raxol/plugins/spotify/)

## Credits

Based on the Spotify integration from [droodotfoo](https://droodotfoo.foo).

#!/usr/bin/env elixir

# Spotify Playlist Browser
#
# This example demonstrates browsing and playing playlists.
# Shows how to navigate the plugin's playlist mode.
#
# Prerequisites:
# - Authentication setup (see 01_simple_playback.exs)
# - At least one playlist in your Spotify account

Mix.install([
  {:raxol, path: Path.expand("../../..", __DIR__)},
  {:req, "~> 0.5"},
  {:oauth2, "~> 2.1"}
])

alias Raxol.Plugins.Spotify

# Run the plugin
# 1. Authenticate if needed (press 'a')
# 2. Press 'l' to enter playlist mode
# 3. Use arrow keys to select a playlist
# 4. Press ENTER to start playing
# 5. Press ESC to go back to main view

IO.puts("""
Playlist Browser Controls:
- 'l' : View playlists
- UP/DOWN : Navigate playlists
- ENTER : Play selected playlist
- ESC : Back to main view
- 'q' : Quit
""")

Raxol.Plugin.run(Spotify)

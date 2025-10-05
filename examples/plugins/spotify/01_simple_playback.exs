#!/usr/bin/env elixir

# Simple Spotify Playback Control
#
# This example shows the most basic usage of the Spotify plugin:
# just play/pause control with the current track display.
#
# Prerequisites:
# - Set SPOTIFY_CLIENT_ID and SPOTIFY_CLIENT_SECRET environment variables
# - Have Spotify Premium account
# - Run: mix deps.get (to install req and oauth2)

Mix.install([
  {:raxol, path: Path.expand("../../..", __DIR__)},
  {:req, "~> 0.5"},
  {:oauth2, "~> 2.1"}
])

alias Raxol.Plugins.Spotify

# Run the plugin
# First time: press 'a' to authenticate
# Then use SPACE to play/pause, 'n' for next, 'p' for previous
Raxol.Plugin.run(Spotify)

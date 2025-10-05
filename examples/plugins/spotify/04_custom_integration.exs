#!/usr/bin/env elixir

# Custom Terminal Integration with Spotify
#
# This example demonstrates embedding the Spotify plugin in a custom
# terminal application with additional UI elements.
#
# Shows how to:
# - Integrate plugin state into your own state
# - Combine plugin rendering with custom UI
# - Forward specific inputs to the plugin

Mix.install([
  {:raxol, path: Path.expand("../../..", __DIR__)},
  {:req, "~> 0.5"},
  {:oauth2, "~> 2.1"}
])

defmodule CustomTerminalWithSpotify do
  alias Raxol.Core.{Buffer, Box}
  alias Raxol.Plugins.Spotify

  defstruct [
    :spotify_state,
    :custom_message,
    :mode
  ]

  def run do
    # Initialize Spotify plugin
    {:ok, spotify_state} = Spotify.init([])

    # Initialize our custom state
    state = %__MODULE__{
      spotify_state: spotify_state,
      custom_message: "Welcome to Custom Terminal with Spotify!",
      # :spotify or :custom
      mode: :spotify
    }

    # Main loop
    loop(state)
  end

  defp loop(state) do
    # Create buffer
    buffer = Buffer.create_blank_buffer(80, 30)

    # Render custom header
    buffer = render_header(buffer, state)

    # Render Spotify plugin in its section
    spotify_buffer = Buffer.create_blank_buffer(76, 20)
    spotify_buffer = Spotify.render(spotify_buffer, state.spotify_state)

    # Merge spotify buffer into main buffer at offset
    buffer = Buffer.merge(buffer, spotify_buffer, 2, 5)

    # Render custom footer
    buffer = render_footer(buffer, state)

    # Display
    # Clear screen and move cursor to top
    IO.write("\e[2J\e[H")
    IO.write(Buffer.to_string(buffer))

    # Handle input
    case get_input() do
      {:key, "q"} ->
        Spotify.cleanup(state.spotify_state)
        :ok

      {:key, "\t"} ->
        # Tab switches between modes
        new_mode = if state.mode == :spotify, do: :custom, else: :spotify
        loop(%{state | mode: new_mode})

      {:key, key} when state.mode == :spotify ->
        # Forward to Spotify plugin
        modifiers = %{ctrl: false, alt: false, shift: false, meta: false}

        case Spotify.handle_input(key, modifiers, state.spotify_state) do
          {:ok, new_spotify_state} ->
            loop(%{state | spotify_state: new_spotify_state})

          {:exit, _} ->
            :ok

          {:error, reason} ->
            loop(%{state | custom_message: "Error: #{inspect(reason)}"})
        end

      {:key, key} when state.mode == :custom ->
        # Handle custom mode input
        message =
          "Custom mode - pressed: #{key} (press TAB to switch to Spotify)"

        loop(%{state | custom_message: message})
    end
  end

  defp render_header(buffer, state) do
    # Draw header box
    buffer = Box.draw_box(buffer, 0, 0, 80, 3, :double)

    # Title
    title = " Custom Terminal with Spotify Integration "

    buffer =
      Buffer.write_at(buffer, 18, 0, title, %{bold: true, fg_color: :cyan})

    # Mode indicator
    mode_text = "Mode: #{state.mode} (TAB to switch)"
    buffer = Buffer.write_at(buffer, 2, 1, mode_text, %{fg_color: :yellow})

    buffer
  end

  defp render_footer(buffer, state) do
    # Draw footer box
    buffer = Box.draw_box(buffer, 0, 26, 80, 4, :single)

    # Custom message
    buffer =
      Buffer.write_at(buffer, 2, 27, state.custom_message, %{fg_color: :green})

    # Help text
    help =
      "[Q: Quit | TAB: Switch Mode | SPACE: Play/Pause | N: Next | P: Previous]"

    buffer = Buffer.write_at(buffer, 3, 28, help, %{fg_color: :bright_black})

    buffer
  end

  defp get_input do
    # Simple input - in production use proper terminal input handling
    char = IO.gets("") |> String.trim() |> String.first()
    {:key, char || ""}
  end
end

IO.puts("""
Custom Terminal with Spotify Integration
=========================================

This example shows a custom terminal app with embedded Spotify controls.

Controls:
  TAB   - Switch between Custom and Spotify modes
  Q     - Quit

Spotify Mode (when active):
  SPACE - Play/pause
  N     - Next track
  P     - Previous track
  L     - View playlists

Starting...
""")

Process.sleep(2000)
CustomTerminalWithSpotify.run()

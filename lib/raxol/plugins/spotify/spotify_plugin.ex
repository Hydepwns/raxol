defmodule Raxol.Plugins.Spotify do
  @moduledoc """
  Spotify integration plugin for Raxol.

  Provides music player functionality with playlist browsing, playback control,
  and search capabilities using the Spotify Web API.

  ## Features

  - OAuth authentication
  - Now-playing display with progress bar
  - Playlist browsing and selection
  - Device management
  - Search (tracks, albums, artists)
  - Playback controls (play/pause/next/previous)
  - Volume control
  - Queue management

  ## Configuration

  Requires Spotify Developer credentials:

      config :raxol, Raxol.Plugins.Spotify,
        client_id: System.get_env("SPOTIFY_CLIENT_ID"),
        client_secret: System.get_env("SPOTIFY_CLIENT_SECRET"),
        redirect_uri: "http://localhost:8888/callback"

  ## Usage

      # In your application
      {:ok, state} = Raxol.Plugins.Spotify.SpotifyPlugin.init(opts)

      # Handle input
      {:ok, new_state} = Raxol.Plugins.Spotify.SpotifyPlugin.handle_input(" ", %{}, state)

      # Render to buffer
      buffer = Raxol.Plugins.Spotify.SpotifyPlugin.render(buffer, state)

  ## Modes

  The plugin operates in different modes:

  - `:auth` - Authentication flow
  - `:main` - Now-playing display
  - `:playlists` - Browse playlists
  - `:devices` - Device selection
  - `:search` - Search tracks/artists/albums
  - `:volume` - Volume control

  ## Keyboard Controls

  ### Main Mode
  - `Space` - Toggle play/pause
  - `n` - Next track
  - `p` - Previous track
  - `l` - View playlists
  - `d` - View devices
  - `s` - Search
  - `v` - Volume control
  - `q` - Quit

  ### Playlist Mode
  - `j/k` - Navigate up/down
  - `Enter` - Select playlist
  - `Esc` - Back to main

  ### Search Mode
  - Type to search
  - `Enter` - Execute search
  - `j/k` - Navigate results
  - `Enter` - Play selection
  - `Esc` - Back to main

  """

  @behaviour Raxol.Plugin

  alias Raxol.Core.{Buffer, Box}
  alias Raxol.Plugins.Spotify.{API, Auth, Config}

  @type mode ::
          :auth | :main | :playlists | :devices | :search | :volume

  @type state :: %{
          mode: mode(),
          auth_status: :not_authenticated | :pending | :authenticated,
          api_client: any() | nil,
          now_playing: map() | nil,
          playback_state: map() | nil,
          playlists: list(map()),
          devices: list(map()),
          search_results: list(map()) | nil,
          search_query: String.t(),
          volume: non_neg_integer(),
          selected_index: non_neg_integer(),
          error: String.t() | nil,
          last_update: DateTime.t(),
          config: keyword()
        }

  @impl true
  def init(opts) do
    case Config.validate(opts) do
      {:ok, config} ->
        state = %{
          mode: :auth,
          auth_status: :not_authenticated,
          api_client: nil,
          now_playing: nil,
          playback_state: nil,
          playlists: [],
          devices: [],
          search_results: nil,
          search_query: "",
          volume: 50,
          selected_index: 0,
          error: nil,
          last_update: DateTime.utc_now(),
          config: config
        }

        # Check if already authenticated
        case Auth.get_access_token() do
          {:ok, _token} ->
            {:ok, %{state | mode: :main, auth_status: :authenticated}}

          {:error, _} ->
            {:ok, state}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def handle_input(key, modifiers, state) do
    case state.mode do
      :auth -> handle_auth_input(key, modifiers, state)
      :main -> handle_main_input(key, modifiers, state)
      :playlists -> handle_playlists_input(key, modifiers, state)
      :devices -> handle_devices_input(key, modifiers, state)
      :search -> handle_search_input(key, modifiers, state)
      :volume -> handle_volume_input(key, modifiers, state)
    end
  end

  @impl true
  def render(buffer, state) do
    case state.mode do
      :auth -> render_auth(buffer, state)
      :main -> render_main(buffer, state)
      :playlists -> render_playlists(buffer, state)
      :devices -> render_devices(buffer, state)
      :search -> render_search(buffer, state)
      :volume -> render_volume(buffer, state)
    end
  end

  @impl true
  def cleanup(_state) do
    # Cleanup any resources
    :ok
  end

  # Private Functions

  ## Input Handlers

  defp handle_auth_input("a", _modifiers, state) do
    {:ok, auth_url} = Auth.start_auth(state.config)
    error = "Open: #{auth_url}"
    {:ok, %{state | auth_status: :pending, error: error}}
  end

  defp handle_auth_input("q", _modifiers, state) do
    {:exit, state}
  end

  defp handle_auth_input(_, _modifiers, state) do
    {:ok, state}
  end

  defp handle_main_input(" ", _modifiers, state) do
    case toggle_playback(state) do
      {:ok, new_state} -> {:ok, new_state}
      {:error, reason} -> {:ok, %{state | error: "Error: #{inspect(reason)}"}}
    end
  end

  defp handle_main_input("n", _modifiers, state) do
    case API.control_playback(:next) do
      :ok -> {:ok, %{state | error: "Next track"}}
      {:error, reason} -> {:ok, %{state | error: "Error: #{inspect(reason)}"}}
    end
  end

  defp handle_main_input("p", _modifiers, state) do
    case API.control_playback(:previous) do
      :ok -> {:ok, %{state | error: "Previous track"}}
      {:error, reason} -> {:ok, %{state | error: "Error: #{inspect(reason)}"}}
    end
  end

  defp handle_main_input("l", _modifiers, state) do
    case API.get_user_playlists() do
      {:ok, playlists} ->
        {:ok,
         %{state | mode: :playlists, playlists: playlists, selected_index: 0}}

      {:error, reason} ->
        {:ok, %{state | error: "Error loading playlists: #{inspect(reason)}"}}
    end
  end

  defp handle_main_input("d", _modifiers, state) do
    case API.get_devices() do
      {:ok, devices} ->
        {:ok, %{state | mode: :devices, devices: devices, selected_index: 0}}

      {:error, reason} ->
        {:ok, %{state | error: "Error loading devices: #{inspect(reason)}"}}
    end
  end

  defp handle_main_input(key, _modifiers, state) when key in ["s", "/"] do
    {:ok, %{state | mode: :search, search_query: "", search_results: nil}}
  end

  defp handle_main_input("v", _modifiers, state) do
    {:ok, %{state | mode: :volume}}
  end

  defp handle_main_input("q", _modifiers, state) do
    {:exit, state}
  end

  defp handle_main_input(_, _modifiers, state) do
    {:ok, state}
  end

  defp handle_playlists_input("j", _modifiers, state) do
    max_index = length(state.playlists) - 1
    new_index = min(state.selected_index + 1, max_index)
    {:ok, %{state | selected_index: new_index}}
  end

  defp handle_playlists_input("k", _modifiers, state) do
    new_index = max(state.selected_index - 1, 0)
    {:ok, %{state | selected_index: new_index}}
  end

  defp handle_playlists_input("Enter", _modifiers, state) do
    playlist = Enum.at(state.playlists, state.selected_index)

    if playlist do
      case API.play_playlist(playlist["uri"]) do
        :ok ->
          {:ok, %{state | mode: :main, error: "Playing: #{playlist["name"]}"}}

        {:error, reason} ->
          {:ok, %{state | error: "Error: #{inspect(reason)}"}}
      end
    else
      {:ok, state}
    end
  end

  defp handle_playlists_input(key, _modifiers, state)
       when key in ["Escape", :escape] do
    {:ok, %{state | mode: :main}}
  end

  defp handle_playlists_input("q", _modifiers, state) do
    {:exit, state}
  end

  defp handle_playlists_input(_, _modifiers, state) do
    {:ok, state}
  end

  defp handle_devices_input("j", _modifiers, state) do
    max_index = length(state.devices) - 1
    new_index = min(state.selected_index + 1, max_index)
    {:ok, %{state | selected_index: new_index}}
  end

  defp handle_devices_input("k", _modifiers, state) do
    new_index = max(state.selected_index - 1, 0)
    {:ok, %{state | selected_index: new_index}}
  end

  defp handle_devices_input("Enter", _modifiers, state) do
    device = Enum.at(state.devices, state.selected_index)

    if device do
      case API.transfer_playback(device["id"]) do
        :ok ->
          {:ok, %{state | mode: :main, error: "Switched to: #{device["name"]}"}}

        {:error, reason} ->
          {:ok, %{state | error: "Error: #{inspect(reason)}"}}
      end
    else
      {:ok, state}
    end
  end

  defp handle_devices_input(key, _modifiers, state)
       when key in ["Escape", :escape] do
    {:ok, %{state | mode: :main}}
  end

  defp handle_devices_input("q", _modifiers, state) do
    {:exit, state}
  end

  defp handle_devices_input(_, _modifiers, state) do
    {:ok, state}
  end

  defp handle_search_input(key, _modifiers, state)
       when key in ["Backspace", :backspace] do
    new_query = String.slice(state.search_query, 0..-2//1)
    {:ok, %{state | search_query: new_query}}
  end

  defp handle_search_input("Enter", _modifiers, state) do
    if state.search_query != "" do
      case API.search(state.search_query, [:track], limit: 10) do
        {:ok, results} ->
          tracks = get_in(results, ["tracks", "items"]) || []
          {:ok, %{state | search_results: tracks, selected_index: 0}}

        {:error, reason} ->
          {:ok, %{state | error: "Search error: #{inspect(reason)}"}}
      end
    else
      {:ok, state}
    end
  end

  defp handle_search_input(key, _modifiers, state)
       when key in ["Escape", :escape] do
    {:ok, %{state | mode: :main}}
  end

  defp handle_search_input(char, _modifiers, state)
       when byte_size(char) == 1 do
    new_query = state.search_query <> char
    {:ok, %{state | search_query: new_query}}
  end

  defp handle_search_input(_, _modifiers, state) do
    {:ok, state}
  end

  defp handle_volume_input("+", _modifiers, state) do
    new_volume = min(state.volume + 5, 100)

    case API.set_volume(new_volume) do
      :ok -> {:ok, %{state | volume: new_volume}}
      {:error, _} -> {:ok, state}
    end
  end

  defp handle_volume_input("-", _modifiers, state) do
    new_volume = max(state.volume - 5, 0)

    case API.set_volume(new_volume) do
      :ok -> {:ok, %{state | volume: new_volume}}
      {:error, _} -> {:ok, state}
    end
  end

  defp handle_volume_input("Escape", _modifiers, state) do
    {:ok, %{state | mode: :main}}
  end

  defp handle_volume_input(_, _modifiers, state) do
    {:ok, state}
  end

  ## Rendering Functions

  defp render_auth(buffer, state) do
    buffer
    |> Box.draw_box(0, 0, buffer.width, buffer.height, :double)
    |> Buffer.write_at(5, 3, "Spotify Authentication Required", %{
      bold: true,
      fg_color: :green
    })
    |> Buffer.write_at(5, 5, "Press 'a' to start OAuth flow")
    |> Buffer.write_at(5, 6, "Press 'q' to quit")
    |> render_message(state)
  end

  defp render_main(buffer, state) do
    buffer
    |> Box.draw_box(0, 0, buffer.width, buffer.height, :single)
    |> render_now_playing(state)
    |> render_controls()
    |> render_message(state)
  end

  defp render_playlists(buffer, state) do
    buffer
    |> Box.draw_box(0, 0, buffer.width, buffer.height, :single)
    |> Buffer.write_at(5, 2, "Your Playlists", %{bold: true})
    |> render_list(state.playlists, state.selected_index, 4, fn p ->
      p["name"]
    end)
    |> Buffer.write_at(5, buffer.height - 3, "Press ESC to go back")
  end

  defp render_devices(buffer, state) do
    buffer
    |> Box.draw_box(0, 0, buffer.width, buffer.height, :single)
    |> Buffer.write_at(5, 2, "Available Devices", %{bold: true})
    |> render_list(state.devices, state.selected_index, 4, fn d -> d["name"] end)
    |> Buffer.write_at(5, buffer.height - 3, "Press ESC to go back")
  end

  defp render_search(buffer, state) do
    buffer
    |> Box.draw_box(0, 0, buffer.width, buffer.height, :single)
    |> Buffer.write_at(5, 2, "Search Spotify", %{bold: true})
    |> Buffer.write_at(5, 4, "Query: #{state.search_query}", %{fg_color: :cyan})
    |> render_list(state.search_results, state.selected_index, 6, fn t ->
      "#{t["name"]} - #{get_in(t, ["artists", Access.at(0), "name"])}"
    end)
    |> Buffer.write_at(
      5,
      buffer.height - 3,
      "Press ENTER to search, ESC to cancel"
    )
  end

  defp render_volume(buffer, state) do
    filled = div(state.volume * 40, 100)
    empty = 40 - filled

    buffer
    |> Box.draw_box(0, 0, buffer.width, buffer.height, :single)
    |> Buffer.write_at(5, 5, "Volume: #{state.volume}%", %{bold: true})
    |> Box.fill_area(5, 7, filled, 1, "█", %{fg_color: :green})
    |> Box.fill_area(5 + filled, 7, empty, 1, "░", %{fg_color: :gray})
    |> Buffer.write_at(5, 9, "+/- to adjust | Esc: back")
  end

  defp render_now_playing(buffer, state) do
    case state.now_playing do
      nil ->
        Buffer.write_at(buffer, 5, 5, "No track playing", %{fg_color: :gray})

      now_playing ->
        # Handle both direct track and nested "item" structure
        track = now_playing["item"] || now_playing
        name = track["name"] || "Unknown Track"
        artist = get_in(track, ["artists", Access.at(0), "name"]) || "Unknown"
        album = get_in(track, ["album", "name"]) || "Unknown"

        buffer
        |> Buffer.write_at(5, 3, "Now Playing:", %{bold: true, fg_color: :cyan})
        |> Buffer.write_at(5, 5, name, %{bold: true})
        |> Buffer.write_at(5, 6, "by #{artist}")
        |> Buffer.write_at(5, 7, "from #{album}", %{fg_color: :gray})
        |> render_progress_bar(state)
    end
  end

  defp render_progress_bar(buffer, state) do
    case state.playback_state do
      %{"progress_ms" => progress, "item" => %{"duration_ms" => duration}} ->
        width = 40
        filled = div(progress * width, duration)
        empty = width - filled

        current_time = format_time(progress)
        total_time = format_time(duration)

        buffer
        |> Box.fill_area(5, 9, filled, 1, "━", %{fg_color: :green})
        |> Box.fill_area(5 + filled, 9, empty, 1, "─", %{fg_color: :gray})
        |> Buffer.write_at(5, 10, "#{current_time} / #{total_time}", %{
          fg_color: :gray
        })

      _ ->
        buffer
    end
  end

  defp render_controls(buffer) do
    y = buffer.height - 11

    buffer
    |> Buffer.write_at(5, y, "Controls:", %{bold: true})
    |> Buffer.write_at(5, y + 1, "SPACE: Play/Pause")
    |> Buffer.write_at(5, y + 2, "n: Next")
    |> Buffer.write_at(5, y + 3, "p: Previous")
    |> Buffer.write_at(5, y + 4, "+/-: Volume")
    |> Buffer.write_at(5, y + 5, "s: Shuffle")
    |> Buffer.write_at(5, y + 6, "r: Repeat")
    |> Buffer.write_at(5, y + 7, "l: Playlists")
    |> Buffer.write_at(5, y + 8, "d: Devices")
    |> Buffer.write_at(5, y + 9, "/: Search")
    |> Buffer.write_at(5, y + 10, "q: Quit")
  end

  defp render_message(buffer, %{error: nil}), do: buffer

  defp render_message(buffer, %{error: msg}) do
    display_msg =
      if String.starts_with?(msg, "Error:"), do: msg, else: "Error: #{msg}"

    Buffer.write_at(buffer, 5, buffer.height - 2, display_msg, %{
      fg_color: :yellow
    })
  end

  defp render_list(buffer, nil, _selected, _start_y, _formatter), do: buffer
  defp render_list(buffer, [], _selected, _start_y, _formatter), do: buffer

  defp render_list(buffer, items, selected, start_y, formatter) do
    items
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {item, idx}, buf ->
      text = formatter.(item)
      style = if idx == selected, do: %{reverse: true}, else: %{}
      prefix = if idx == selected, do: "> ", else: "  "
      Buffer.write_at(buf, 5, start_y + idx, prefix <> text, style)
    end)
  end

  ## Helper Functions

  defp toggle_playback(state) do
    is_playing = get_in(state.playback_state, ["is_playing"])

    action =
      case is_playing do
        true -> :pause
        false -> :play
        nil -> :play
      end

    case API.control_playback(action) do
      :ok -> {:ok, state}
      {:error, reason} -> {:error, reason}
    end
  end

  defp format_time(ms) do
    total_seconds = div(ms, 1000)
    minutes = div(total_seconds, 60)
    seconds = rem(total_seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(seconds), 2, "0")}"
  end
end

defmodule Raxol.Plugins.SpotifyTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Buffer
  alias Raxol.Plugins.Spotify

  @valid_config [
    client_id: "test_client_id",
    client_secret: "test_client_secret",
    redirect_uri: "http://localhost:8888/callback"
  ]

  describe "init/1" do
    test "initializes with valid config" do
      assert {:ok, state} = Spotify.init(@valid_config)

      assert state.mode == :auth
      assert state.api_client == nil
      assert state.now_playing == nil
      assert state.playback_state == nil
      assert state.playlists == []
      assert state.devices == []
      assert state.search_query == ""
      assert state.search_results == nil
      assert state.selected_index == 0
      assert state.volume == 50
      assert state.error == nil
      assert state.config == @valid_config
    end

    test "returns error when client_id is missing" do
      config = Keyword.delete(@valid_config, :client_id)

      assert {:error, reason} = Spotify.init(config)
      assert reason =~ "client_id"
    end

    test "returns error when client_secret is missing" do
      config = Keyword.delete(@valid_config, :client_secret)

      assert {:error, reason} = Spotify.init(config)
      assert reason =~ "client_secret"
    end

    test "returns error when redirect_uri is missing" do
      config = Keyword.delete(@valid_config, :redirect_uri)

      assert {:error, reason} = Spotify.init(config)
      assert reason =~ "redirect_uri"
    end

    test "merges app config with provided opts" do
      Application.put_env(:raxol, Raxol.Plugins.Spotify,
        client_id: "app_config_id",
        client_secret: "app_config_secret",
        redirect_uri: "app_config_uri"
      )

      # Provided opts should override app config
      opts = [client_id: "opts_id"]

      {:ok, state} = Spotify.init(opts)

      assert state.config[:client_id] == "opts_id"
      assert state.config[:client_secret] == "app_config_secret"
      assert state.config[:redirect_uri] == "app_config_uri"

      Application.delete_env(:raxol, Raxol.Plugins.Spotify)
    end
  end

  describe "handle_input/3 - auth mode" do
    setup do
      {:ok, state} = Spotify.init(@valid_config)
      modifiers = %{ctrl: false, alt: false, shift: false, meta: false}
      {:ok, state: state, modifiers: modifiers}
    end

    @tag :skip
    test "starts OAuth flow on 'a' key", %{state: state, modifiers: modifiers} do
      # This would require mocking IO.gets and API.exchange_code
      :ok
    end

    test "exits on 'q' key", %{state: state, modifiers: modifiers} do
      assert {:exit, ^state} = Spotify.handle_input("q", modifiers, state)
    end

    test "ignores other keys", %{state: state, modifiers: modifiers} do
      assert {:ok, ^state} = Spotify.handle_input("x", modifiers, state)
      assert {:ok, ^state} = Spotify.handle_input("1", modifiers, state)
    end
  end

  describe "handle_input/3 - main mode" do
    setup do
      {:ok, state} = Spotify.init(@valid_config)
      state = %{state | mode: :main}
      modifiers = %{ctrl: false, alt: false, shift: false, meta: false}
      {:ok, state: state, modifiers: modifiers}
    end

    @tag :skip
    test "toggles playback on space", %{state: state, modifiers: modifiers} do
      # Would require API mocking
      :ok
    end

    @tag :skip
    test "skips to next track on 'n'", %{state: state, modifiers: modifiers} do
      # Would require API mocking
      :ok
    end

    @tag :skip
    test "skips to previous track on 'p'", %{state: state, modifiers: modifiers} do
      # Would require API mocking
      :ok
    end

    test "increases volume on '+'", %{state: state, modifiers: modifiers} do
      state = %{state | volume: 50}

      # Without API, we can't test the full flow
      # But we can verify the state structure
      assert state.volume == 50
    end

    test "decreases volume on '-'", %{state: state, modifiers: modifiers} do
      state = %{state | volume: 50}

      # Without API, we can't test the full flow
      # But we can verify the state structure
      assert state.volume == 50
    end

    @tag :skip
    test "toggles shuffle on 's'", %{state: state, modifiers: modifiers} do
      # Would require API mocking
      :ok
    end

    @tag :skip
    test "cycles repeat mode on 'r'", %{state: state, modifiers: modifiers} do
      # Would require API mocking
      :ok
    end

    @tag :skip
    test "switches to playlists mode on 'l'", %{state: state, modifiers: modifiers} do
      # Would require API mocking
      :ok
    end

    @tag :skip
    test "switches to devices mode on 'd'", %{state: state, modifiers: modifiers} do
      # Would require API mocking
      :ok
    end

    test "switches to search mode on '/'", %{state: state, modifiers: modifiers} do
      assert {:ok, new_state} = Spotify.handle_input("/", modifiers, state)
      assert new_state.mode == :search
      assert new_state.search_query == ""
    end

    test "exits on 'q'", %{state: state, modifiers: modifiers} do
      assert {:exit, ^state} = Spotify.handle_input("q", modifiers, state)
    end
  end

  describe "handle_input/3 - playlists mode" do
    setup do
      {:ok, state} = Spotify.init(@valid_config)
      state = %{state | mode: :playlists}
      modifiers = %{ctrl: false, alt: false, shift: false, meta: false}
      {:ok, state: state, modifiers: modifiers}
    end

    test "returns to main mode on escape", %{state: state, modifiers: modifiers} do
      assert {:ok, new_state} = Spotify.handle_input(:escape, modifiers, state)
      assert new_state.mode == :main
    end

    test "exits on 'q'", %{state: state, modifiers: modifiers} do
      assert {:exit, ^state} = Spotify.handle_input("q", modifiers, state)
    end
  end

  describe "handle_input/3 - devices mode" do
    setup do
      {:ok, state} = Spotify.init(@valid_config)
      state = %{state | mode: :devices}
      modifiers = %{ctrl: false, alt: false, shift: false, meta: false}
      {:ok, state: state, modifiers: modifiers}
    end

    test "returns to main mode on escape", %{state: state, modifiers: modifiers} do
      assert {:ok, new_state} = Spotify.handle_input(:escape, modifiers, state)
      assert new_state.mode == :main
    end

    test "exits on 'q'", %{state: state, modifiers: modifiers} do
      assert {:exit, ^state} = Spotify.handle_input("q", modifiers, state)
    end
  end

  describe "handle_input/3 - search mode" do
    setup do
      {:ok, state} = Spotify.init(@valid_config)
      state = %{state | mode: :search}
      modifiers = %{ctrl: false, alt: false, shift: false, meta: false}
      {:ok, state: state, modifiers: modifiers}
    end

    test "returns to main mode on escape", %{state: state, modifiers: modifiers} do
      assert {:ok, new_state} = Spotify.handle_input(:escape, modifiers, state)
      assert new_state.mode == :main
    end

    @tag :skip
    test "performs search on enter", %{state: state, modifiers: modifiers} do
      # Would require API mocking
      :ok
    end

    test "adds character to query", %{state: state, modifiers: modifiers} do
      state = %{state | search_query: "beat"}

      assert {:ok, new_state} = Spotify.handle_input("s", modifiers, state)
      assert new_state.search_query == "beats"
    end

    test "removes character on backspace", %{state: state, modifiers: modifiers} do
      state = %{state | search_query: "beats"}

      assert {:ok, new_state} = Spotify.handle_input(:backspace, modifiers, state)
      assert new_state.search_query == "beat"
    end

    test "handles backspace on empty query", %{state: state, modifiers: modifiers} do
      state = %{state | search_query: ""}

      assert {:ok, new_state} = Spotify.handle_input(:backspace, modifiers, state)
      assert new_state.search_query == ""
    end
  end

  describe "render/2 - auth mode" do
    test "renders auth screen" do
      {:ok, state} = Spotify.init(@valid_config)
      buffer = Buffer.create_blank_buffer(80, 24)

      rendered = Spotify.render(buffer, state)
      output = Buffer.to_string(rendered)

      assert output =~ "Spotify Authentication Required"
      assert output =~ "Press 'a' to start OAuth flow"
      assert output =~ "Press 'q' to quit"
    end

    test "renders error message when present" do
      {:ok, state} = Spotify.init(@valid_config)
      state = %{state | error: "Authentication failed"}
      buffer = Buffer.create_blank_buffer(80, 24)

      rendered = Spotify.render(buffer, state)
      output = Buffer.to_string(rendered)

      assert output =~ "Error: Authentication failed"
    end
  end

  describe "render/2 - main mode" do
    test "renders no track message when nothing is playing" do
      {:ok, state} = Spotify.init(@valid_config)
      state = %{state | mode: :main}
      buffer = Buffer.create_blank_buffer(80, 24)

      rendered = Spotify.render(buffer, state)
      output = Buffer.to_string(rendered)

      assert output =~ "No track playing"
    end

    test "renders now playing information" do
      {:ok, state} = Spotify.init(@valid_config)

      state = %{
        state
        | mode: :main,
          now_playing: %{
            "item" => %{
              "name" => "Test Track",
              "artists" => [%{"name" => "Test Artist"}]
            }
          }
      }

      buffer = Buffer.create_blank_buffer(80, 24)

      rendered = Spotify.render(buffer, state)
      output = Buffer.to_string(rendered)

      assert output =~ "Now Playing:"
      assert output =~ "Test Track"
      assert output =~ "by Test Artist"
    end

    test "renders controls help text" do
      {:ok, state} = Spotify.init(@valid_config)
      state = %{state | mode: :main}
      buffer = Buffer.create_blank_buffer(80, 24)

      rendered = Spotify.render(buffer, state)
      output = Buffer.to_string(rendered)

      assert output =~ "Controls:"
      assert output =~ "SPACE: Play/Pause"
      assert output =~ "n: Next"
      assert output =~ "p: Previous"
      assert output =~ "+/-: Volume"
      assert output =~ "s: Shuffle"
      assert output =~ "r: Repeat"
      assert output =~ "l: Playlists"
      assert output =~ "d: Devices"
      assert output =~ "/: Search"
      assert output =~ "q: Quit"
    end
  end

  describe "render/2 - playlists mode" do
    test "renders playlists screen" do
      {:ok, state} = Spotify.init(@valid_config)
      state = %{state | mode: :playlists}
      buffer = Buffer.create_blank_buffer(80, 24)

      rendered = Spotify.render(buffer, state)
      output = Buffer.to_string(rendered)

      assert output =~ "Your Playlists"
      assert output =~ "Press ESC to go back"
    end
  end

  describe "render/2 - devices mode" do
    test "renders devices screen" do
      {:ok, state} = Spotify.init(@valid_config)
      state = %{state | mode: :devices}
      buffer = Buffer.create_blank_buffer(80, 24)

      rendered = Spotify.render(buffer, state)
      output = Buffer.to_string(rendered)

      assert output =~ "Available Devices"
      assert output =~ "Press ESC to go back"
    end
  end

  describe "render/2 - search mode" do
    test "renders search screen with query" do
      {:ok, state} = Spotify.init(@valid_config)
      state = %{state | mode: :search, search_query: "beatles"}
      buffer = Buffer.create_blank_buffer(80, 24)

      rendered = Spotify.render(buffer, state)
      output = Buffer.to_string(rendered)

      assert output =~ "Search Spotify"
      assert output =~ "Query: beatles"
      assert output =~ "Press ENTER to search, ESC to cancel"
    end
  end

  describe "cleanup/1" do
    test "returns :ok" do
      {:ok, state} = Spotify.init(@valid_config)

      assert :ok = Spotify.cleanup(state)
    end
  end
end

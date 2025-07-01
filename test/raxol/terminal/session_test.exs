defmodule Raxol.Terminal.SessionTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Session
  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct
  alias Raxol.Terminal.Renderer
  alias Raxol.Terminal.ScreenBuffer

  setup do
    # Start the application
    Application.start(:raxol)

    # Clean up any existing session files
    File.rm_rf!("tmp/sessions")
    File.mkdir_p!("tmp/sessions")

    {:ok, pid} = Session.start_link(id: "test_session")
    %{pid: pid}
  end

  setup_all do
    # Ensure application is stopped after all tests
    on_exit(fn ->
      Application.stop(:raxol)
    end)
  end

  defp minimal_session_struct(id, width, height, title, theme) do
    # Create a minimal screen buffer with just 1x1 cells to avoid serialization issues
    minimal_cells = [
      [
        %Raxol.Terminal.Cell{
          char: " ",
          style: Raxol.Terminal.ANSI.TextFormatting.new(),
          dirty: false,
          wide_placeholder: false
        }
      ]
    ]

    minimal_screen_buffer = %ScreenBuffer{
      width: 1,
      height: 1,
      cells: minimal_cells,
      cursor_position: {0, 0}
    }

    # Create minimal emulator
    minimal_emulator = %EmulatorStruct{
      main_screen_buffer: minimal_screen_buffer,
      alternate_screen_buffer: minimal_screen_buffer,
      active_buffer: minimal_screen_buffer,
      active_buffer_type: :main,
      scrollback_buffer: [],
      scrollback_limit: 1000,
      width: 1,
      height: 1,
      cursor: %{
        position: {0, 0},
        style: :block,
        visible: true,
        blink_state: true
      },
      cursor_style: :block,
      saved_cursor: nil,
      charset_state: %{
        g0: :us_ascii,
        g1: :us_ascii,
        g2: :us_ascii,
        g3: :us_ascii,
        gl: :g0,
        gr: :g1,
        single_shift: nil
      },
      style: %{},
      color_palette: %{},
      tab_stops: [],
      command_history: [],
      current_command_buffer: "",
      max_command_history: 100,
      memory_limit: 100_000,
      plugin_manager: nil,
      session_id: id,
      client_options: %{},
      state: :normal,
      window_manager: nil,
      window_title: title,
      icon_name: nil,
      current_hyperlink_url: nil,
      current_hyperlink: nil,
      scroll_region: nil,
      last_col_exceeded: false,
      last_key_event: nil,
      output_buffer: "",
      parser_state: %{state: :ground},
      state_stack: [],
      command: nil,
      cursor_manager: nil,
      mode_manager: Raxol.Terminal.ModeManager.new()
    }

    # Create minimal renderer
    minimal_renderer = %Renderer{
      screen_buffer: minimal_screen_buffer,
      theme: theme
    }

    # Create the session struct
    %Raxol.Terminal.Session{
      id: id,
      emulator: minimal_emulator,
      renderer: minimal_renderer,
      width: width,
      height: height,
      title: title,
      theme: theme,
      auto_save: true
    }
  end

  describe "session persistence" do
    test "can save and load a session", %{pid: pid} do
      # Create a minimal session state for testing
      minimal_state =
        minimal_session_struct("test_session", 1, 1, "Test Session", %{
          background: :black
        })

      # Inject the minimal state into the GenServer
      :sys.replace_state(pid, fn _current_state -> minimal_state end)

      # Save the session
      assert :ok = Session.save_session(pid)

      # Load the session
      assert {:ok, new_pid} = Session.load_session("test_session")
      assert Process.alive?(new_pid)

      # Clean up
      Session.stop(new_pid)
    end

    test "can disable auto-save", %{pid: pid} do
      # Create a minimal session state
      minimal_state =
        minimal_session_struct("test_session", 1, 1, "Test Session", %{
          background: :black
        })

      minimal_state = %{minimal_state | auto_save: false}

      # Inject the minimal state into the GenServer
      :sys.replace_state(pid, fn _current_state -> minimal_state end)

      # Save the session
      assert :ok = Session.save_session(pid)

      # Load the session and verify auto_save is false
      assert {:ok, new_pid} = Session.load_session("test_session")
      new_state = :sys.get_state(new_pid)
      assert new_state.auto_save == false

      # Clean up
      Session.stop(new_pid)
    end

    test "can recover from saved state", %{pid: pid} do
      # Create a minimal session state with some content
      minimal_state =
        minimal_session_struct("test_session", 1, 1, "Test Session", %{
          background: :blue
        })

      # Inject the minimal state into the GenServer
      :sys.replace_state(pid, fn _current_state -> minimal_state end)

      # Save the session
      assert :ok = Session.save_session(pid)

      # Load the session and verify the state is preserved
      assert {:ok, new_pid} = Session.load_session("test_session")
      loaded_state = :sys.get_state(new_pid)

      assert loaded_state.id == "test_session"
      assert loaded_state.width == 1
      assert loaded_state.height == 1
      assert loaded_state.title == "Test Session"
      assert loaded_state.theme == %{background: :blue}

      # Clean up
      Session.stop(new_pid)
    end

    test "session persistence handles invalid session data gracefully" do
      # Test loading non-existent session
      assert {:error, :enoent} = Session.load_session("non_existent_session")
    end
  end
end

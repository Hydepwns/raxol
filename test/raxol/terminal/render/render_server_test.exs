defmodule Raxol.Terminal.Render.RenderServerTest do
  use ExUnit.Case, async: false

  alias Raxol.Terminal.{
    Buffer.BufferManager,
    Cursor.Manager,
    Integration.State,
    Render.RenderServer
  }

  setup do
    # Start the renderer with the default name (module name)
    {:ok, pid} = RenderServer.start_link(name: RenderServer)
    %{pid: pid}
  end

  describe "initialization" do
    test "starts with default configuration", %{pid: pid} do
      state = :sys.get_state(pid)
      assert state.fps == 60
      assert state.theme == %{}
      assert state.font_settings == %{}
      assert state.termbox_initialized == false
      assert state.cache == %{}
    end

    test ~c"initializes with custom configuration" do
      opts = [
        fps: 30,
        theme: %{foreground: :white, background: :black},
        font_settings: %{size: 12},
        name: :"unified_renderer_custom_#{System.unique_integer([:positive])}"
      ]

      {:ok, pid} = RenderServer.start_link(opts)
      state = :sys.get_state(pid)

      assert state.fps == 30
      assert state.theme == %{foreground: :white, background: :black}
      assert state.font_settings == %{size: 12}
    end
  end

  describe "terminal operations" do
    test "initializes and shuts down terminal", %{pid: pid} do
      assert RenderServer.init_terminal() == :ok
      state = :sys.get_state(pid)
      assert state.termbox_initialized == true

      assert RenderServer.shutdown_terminal() == :ok
      state = :sys.get_state(pid)
      assert state.termbox_initialized == false
    end
  end

  describe "configuration" do
    test "updates configuration", %{pid: pid} do
      config = %{
        fps: 30,
        theme: %{foreground: :white},
        font_settings: %{size: 14}
      }

      assert RenderServer.update_config(config) == :ok
      state = :sys.get_state(pid)

      assert state.fps == 30
      assert state.theme == %{foreground: :white}
      assert state.font_settings == %{size: 14}
    end

    test "sets individual configuration values", %{pid: pid} do
      assert RenderServer.set_config_value(:fps, 30) == :ok
      state = :sys.get_state(pid)
      assert state.fps == 30

      assert RenderServer.set_config_value(:theme, %{foreground: :white}) ==
               :ok

      state = :sys.get_state(pid)
      assert state.theme == %{foreground: :white}
    end

    test "resets configuration to defaults", %{pid: pid} do
      # First set some custom values
      RenderServer.update_config(%{
        fps: 30,
        theme: %{foreground: :white},
        font_settings: %{size: 14}
      })

      # Then reset
      assert RenderServer.reset_config() == :ok
      state = :sys.get_state(pid)

      assert state.fps == 60
      assert state.theme == %{}
      assert state.font_settings == %{}
    end
  end

  describe "rendering" do
    setup %{pid: _pid} do
      # Initialize terminal for rendering tests
      RenderServer.init_terminal()

      # Create a test state with PID-based buffer manager
      {:ok, buffer_manager_pid} =
        BufferManager.start_link(width: 80, height: 24)

      cursor_manager = Manager.new(0, 0)

      state = %State{
        buffer_manager: buffer_manager_pid,
        cursor_manager: cursor_manager
      }

      %{state: state}
    end

    test "renders empty buffer", %{pid: _pid, state: state} do
      assert RenderServer.render(state) == :ok
    end

    test "renders buffer with content", %{pid: _pid, state: state} do
      # Add some content to the buffer
      {:ok, _buffer_pid} = BufferManager.write(state.buffer_manager, "Hello, World!")

      assert RenderServer.render(state) == :ok
    end

    test "handles rendering errors", %{pid: _pid, state: state} do
      # Shutdown terminal to force an error
      RenderServer.shutdown_terminal()

      assert RenderServer.render(state) == {:error, :not_initialized}
    end
  end

  describe "cursor operations" do
    test "sets cursor visibility", %{pid: _pid} do
      assert RenderServer.set_cursor_visibility(true) == :ok
      assert RenderServer.set_cursor_visibility(false) == :ok
    end
  end

  describe "window operations" do
    test "sets and gets terminal title", %{pid: _pid} do
      title = "Test Terminal"
      assert RenderServer.set_title(title) == :ok
      assert RenderServer.get_title() == title
    end

    test "resizes terminal", %{pid: pid} do
      assert RenderServer.resize(100, 50) == :ok
      state = :sys.get_state(pid)
      assert state.screen.width == 100
      assert state.screen.height == 50
    end
  end
end

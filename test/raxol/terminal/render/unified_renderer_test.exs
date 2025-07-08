defmodule Raxol.Terminal.Render.UnifiedRendererTest do
  use ExUnit.Case, async: false

  alias Raxol.Terminal.{
    Render.UnifiedRenderer,
    Buffer.UnifiedManager,
    Cursor.Manager,
    Integration.State
  }

  setup do
    # Start the renderer with the default name (module name)
    {:ok, pid} = UnifiedRenderer.start_link()
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
        font_settings: %{size: 12}
      ]

      {:ok, pid} = UnifiedRenderer.start_link(opts)
      state = :sys.get_state(pid)

      assert state.fps == 30
      assert state.theme == %{foreground: :white, background: :black}
      assert state.font_settings == %{size: 12}
    end
  end

  describe "terminal operations" do
    test "initializes and shuts down terminal", %{pid: pid} do
      assert UnifiedRenderer.init_terminal() == :ok
      state = :sys.get_state(pid)
      assert state.termbox_initialized == true

      assert UnifiedRenderer.shutdown_terminal() == :ok
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

      assert UnifiedRenderer.update_config(config) == :ok
      state = :sys.get_state(pid)

      assert state.fps == 30
      assert state.theme == %{foreground: :white}
      assert state.font_settings == %{size: 14}
    end

    test "sets individual configuration values", %{pid: pid} do
      assert UnifiedRenderer.set_config_value(:fps, 30) == :ok
      state = :sys.get_state(pid)
      assert state.fps == 30

      assert UnifiedRenderer.set_config_value(:theme, %{foreground: :white}) ==
               :ok

      state = :sys.get_state(pid)
      assert state.theme == %{foreground: :white}
    end

    test "resets configuration to defaults", %{pid: pid} do
      # First set some custom values
      UnifiedRenderer.update_config(%{
        fps: 30,
        theme: %{foreground: :white},
        font_settings: %{size: 14}
      })

      # Then reset
      assert UnifiedRenderer.reset_config() == :ok
      state = :sys.get_state(pid)

      assert state.fps == 60
      assert state.theme == %{}
      assert state.font_settings == %{}
    end
  end

  describe "rendering" do
    setup %{pid: pid} do
      # Initialize terminal for rendering tests
      UnifiedRenderer.init_terminal()

      # Create a test state with PID-based buffer manager
      {:ok, buffer_manager_pid} =
        UnifiedManager.start_link(width: 80, height: 24)

      cursor_manager = Manager.new(0, 0)

      state = %State{
        buffer_manager: buffer_manager_pid,
        cursor_manager: cursor_manager
      }

      %{state: state}
    end

    test "renders empty buffer", %{pid: pid, state: state} do
      assert UnifiedRenderer.render(state) == :ok
    end

    test "renders buffer with content", %{pid: pid, state: state} do
      # Add some content to the buffer
      {:ok, buffer_manager} =
        UnifiedManager.write(state.buffer_manager, "Hello, World!")

      state = %{state | buffer_manager: buffer_manager}

      assert UnifiedRenderer.render(state) == :ok
    end

    test "handles rendering errors", %{pid: pid, state: state} do
      # Shutdown terminal to force an error
      UnifiedRenderer.shutdown_terminal()

      assert UnifiedRenderer.render(state) == {:error, :not_initialized}
    end
  end

  describe "cursor operations" do
    test "sets cursor visibility", %{pid: pid} do
      assert UnifiedRenderer.set_cursor_visibility(true) == :ok
      assert UnifiedRenderer.set_cursor_visibility(false) == :ok
    end
  end

  describe "window operations" do
    test "sets and gets terminal title", %{pid: pid} do
      title = "Test Terminal"
      assert UnifiedRenderer.set_title(title) == :ok
      assert UnifiedRenderer.get_title() == title
    end

    test "resizes terminal", %{pid: pid} do
      assert UnifiedRenderer.resize(100, 50) == :ok
      state = :sys.get_state(pid)
      assert state.screen.width == 100
      assert state.screen.height == 50
    end
  end
end

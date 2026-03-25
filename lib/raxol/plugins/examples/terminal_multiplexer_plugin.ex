defmodule Raxol.Plugins.Examples.TerminalMultiplexerPlugin do
  @moduledoc """
  Terminal Multiplexer Plugin for Raxol Terminal

  Provides tmux/screen-like terminal multiplexing with panes and windows.
  Demonstrates:
  - Multiple terminal management
  - Pane splitting and navigation
  - Session management
  - Layout persistence
  - Command routing
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Core.Runtime.Log

  alias Raxol.Plugins.Examples.TerminalMultiplexer.{
    CommandHandler,
    PaneManager,
    Renderer,
    WindowManager
  }

  @compile {:no_warn_undefined,
            Raxol.Plugins.Examples.TerminalMultiplexer.CommandHandler}
  @compile {:no_warn_undefined,
            Raxol.Plugins.Examples.TerminalMultiplexer.PaneManager}
  @compile {:no_warn_undefined,
            Raxol.Plugins.Examples.TerminalMultiplexer.Renderer}
  @compile {:no_warn_undefined,
            Raxol.Plugins.Examples.TerminalMultiplexer.WindowManager}

  # Plugin Manifest
  def manifest do
    %{
      name: "terminal-multiplexer",
      version: "1.0.0",
      description: "Terminal multiplexing with panes and windows",
      author: "Raxol Team",
      dependencies: %{"raxol-core" => "~> 1.5"},
      capabilities: [
        :terminal_management,
        :pane_splitting,
        :session_management,
        :keyboard_input
      ],
      config_schema: %{
        prefix_key: %{type: :string, default: "ctrl+a"},
        default_shell: %{type: :string, default: "/bin/bash"},
        save_layout: %{type: :boolean, default: true},
        status_bar: %{type: :boolean, default: true},
        mouse_support: %{type: :boolean, default: true}
      }
    }
  end

  # State structures

  defmodule Pane do
    @moduledoc "Terminal pane within a multiplexer window."
    defstruct [
      :id,
      :pid,
      :buffer,
      :cursor,
      :title,
      :active,
      :width,
      :height,
      :x,
      :y
    ]
  end

  defmodule Window do
    @moduledoc "Window containing multiple panes."
    defstruct [:id, :name, :panes, :active_pane, :layout, :index]
  end

  defmodule Session do
    @moduledoc "Multiplexer session containing multiple windows."
    defstruct [:id, :name, :windows, :active_window, :created_at]
  end

  defstruct [
    :config,
    :sessions,
    :active_session,
    :prefix_active,
    :emulator_pid,
    :command_mode,
    :last_command_time
  ]

  # Initialization

  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(config) do
    Log.info("Initializing with config: #{inspect(config)}")

    default_session = WindowManager.create_session("main")
    default_window = WindowManager.create_window("shell", config.default_shell)

    session = %{
      default_session
      | windows: [default_window],
        active_window: default_window.id
    }

    state = %__MODULE__{
      config: config,
      sessions: %{session.id => session},
      active_session: session.id,
      prefix_active: false,
      emulator_pid: nil,
      command_mode: false,
      last_command_time: nil
    }

    {:ok, state}
  end

  # Hot-reload support

  def preserve_state(state) do
    %{sessions: state.sessions, active_session: state.active_session}
  end

  def restore_state(preserved_state, new_config) do
    %__MODULE__{
      config: new_config,
      sessions: preserved_state.sessions || %{},
      active_session: preserved_state.active_session,
      prefix_active: false,
      emulator_pid: nil,
      command_mode: false,
      last_command_time: nil
    }
  end

  # Event Handlers

  def handle_event({:keyboard, key}, state)
      when key == state.config.prefix_key do
    CommandHandler.activate_prefix(state)
  end

  def handle_event({:keyboard, key}, %{prefix_active: true} = state) do
    CommandHandler.handle_prefixed_command(key, state)
  end

  def handle_event({:keyboard, key}, %{command_mode: true} = state) do
    CommandHandler.handle_command_mode(key, state)
  end

  def handle_event({:keyboard, key}, state) do
    CommandHandler.route_to_active_pane(state, {:input, key})
    {:ok, state}
  end

  def handle_event({:mouse, action, x, y}, state)
      when state.config.mouse_support do
    Log.info("Mouse event: #{action} at (#{x}, #{y})")
    {:ok, state}
  end

  def handle_event({:terminal_resize, {width, height}}, state) do
    Log.info("Resizing layout to #{width}x#{height}")
    {:ok, state}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  # Rendering delegation

  def render_layout(state), do: Renderer.render_layout(state)

  # BaseManager callbacks

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_cast({:set_emulator, pid}, state) do
    {:noreply, %{state | emulator_pid: pid}}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_info(msg, state) do
    Log.debug("Received message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Expose pane ops for use by submodules needing the struct alias
  defdelegate create_pane(shell), to: PaneManager
end

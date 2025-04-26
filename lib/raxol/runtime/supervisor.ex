defmodule Raxol.Runtime.Supervisor do
  @moduledoc """
  Supervises the core Raxol runtime processes.
  """
  use Supervisor

  require Logger

  alias Raxol.Core.Runtime.Plugins.Manager, as: PluginManager
  alias Raxol.Core.Runtime.Events.Dispatcher
  alias Raxol.Core.Runtime.Rendering.Engine, as: RenderingEngine
  alias Raxol.Terminal.Driver, as: TerminalDriver
  alias Raxol.Core.UserPreferences

  def start_link(init_args) do
    Supervisor.start_link(__MODULE__, init_args, name: __MODULE__)
  end

  @impl true
  def init(init_args) do
    # Expect init_args to be a map like:
    # %{
    #   app_module: MyApp,
    #   initial_model: %{},
    #   initial_commands: [],
    #   initial_term_size: %{width: w, height: h}
    # }
    app_module = init_args.app_module
    initial_model = init_args.initial_model
    initial_commands = init_args.initial_commands
    initial_term_size = init_args.initial_term_size
    # Runtime PID is needed by Dispatcher
    runtime_pid = init_args.runtime_pid

    children = [
      # 0. User Preferences (needs to start early)
      {Raxol.Core.UserPreferences, []},

      # 1. Plugin Manager (needed by Dispatcher)
      {PluginManager, []},
      # 2. Dispatcher (needs PluginManager, app_module, model, runtime_pid, commands)
      %{
        id: Dispatcher,
        start:
          {Dispatcher, :start_link,
           [
             runtime_pid,
             %{
               app_module: app_module,
               model: initial_model,
               initial_commands: initial_commands,
               width: initial_term_size.width,
               height: initial_term_size.height,
               # Uses registered name
               plugin_manager: PluginManager,
               command_registry_table: :raxol_command_registry
             }
           ]},
        restart: :permanent,
        type: :worker
      },
      # 3. Rendering Engine (needs Dispatcher PID, app_module, size)
      %{
        id: RenderingEngine,
        start:
          {RenderingEngine, :start_link,
           [
             %{
               # Assume terminal for now
               environment: :terminal,
               width: initial_term_size.width,
               height: initial_term_size.height,
               buffer: nil,
               app_module: app_module,
               # Uses registered name
               dispatcher_pid: Dispatcher
             }
           ]},
        restart: :permanent,
        type: :worker
      },
      # 4. Terminal Driver (needs Dispatcher PID)
      %{
        id: TerminalDriver,
        # Passes registered name
        start: {TerminalDriver, :start_link, [Dispatcher]},
        restart: :permanent,
        type: :worker
      }
    ]

    opts = [strategy: :one_for_one, name: Raxol.Runtime.Supervisor]
    Supervisor.init(children, opts)
  end
end

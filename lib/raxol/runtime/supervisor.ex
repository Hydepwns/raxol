defmodule Raxol.Runtime.Supervisor do
  @moduledoc """
  The main supervisor for the Raxol application runtime.
  Manages core processes like Dispatcher, Plugin system, etc.
  """
  use Supervisor

  require Logger

  alias Raxol.Core.Runtime.Events.Dispatcher
  alias Raxol.Core.Runtime.Plugins.Manager

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
    app_module =
      case Map.get(init_args, :app_module) do
        nil ->
          raise ArgumentError,
                "Missing required :app_module in init_args: #{inspect(init_args)}"

        value ->
          value
      end

    initial_model =
      case Map.get(init_args, :initial_model) do
        nil ->
          raise ArgumentError,
                "Missing required :initial_model in init_args: #{inspect(init_args)}"

        value ->
          value
      end

    initial_commands =
      case Map.get(init_args, :initial_commands) do
        nil ->
          raise ArgumentError,
                "Missing required :initial_commands in init_args: #{inspect(init_args)}"

        value ->
          value
      end

    initial_term_size =
      case Map.get(init_args, :initial_term_size) do
        nil ->
          raise ArgumentError,
                "Missing required :initial_term_size in init_args: #{inspect(init_args)}"

        value ->
          value
      end

    runtime_pid =
      case Map.get(init_args, :runtime_pid) do
        nil ->
          raise ArgumentError,
                "Missing required :runtime_pid in init_args: #{inspect(init_args)}"

        value ->
          value
      end

    debug_mode = Map.get(init_args, :debug_mode, false)

    children =
      [
        # 0. User Preferences (needs to start early)
        {Raxol.Core.UserPreferences, []},

        # ADDED: Start the Registry under supervision
        {Registry, keys: :duplicate, name: :raxol_event_subscriptions},

        # NEW: Start the Rendering Renderer GenServer
        {Raxol.UI.Rendering.Renderer, []},

        # NEW: Start the Plugin Registry GenServer
        {Raxol.Core.Runtime.Plugins.Registry, []},

        # 1. Plugin Manager (needed by Dispatcher)
        {Manager, [runtime_pid: runtime_pid]},
        # 2. Dispatcher (needs plugin manager, app_module, model, runtime_pid, commands)
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
                 plugin_manager: Manager,
                 command_registry_table: :raxol_command_registry,
                 debug_mode: debug_mode
               }
             ]},
          restart: :permanent,
          type: :worker
        },
        # 3. Rendering Engine (needs Dispatcher PID, app_module, size)
        %{
          id: RenderingEngine,
          start:
            {Raxol.Core.Runtime.Rendering.Engine, :start_link,
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
        }
      ] ++
        if IO.ANSI.enabled?() do
          [
            # 4. Terminal Driver (needs Dispatcher PID)
            %{
              id: TerminalDriver,
              # Passes registered name
              start: {Raxol.Terminal.Driver, :start_link, [Dispatcher]},
              restart: :permanent,
              type: :worker
            }
          ]
        else
          Logger.warning(
            "[Raxol.Runtime.Supervisor] Not attached to a TTY. Terminal driver will not be started."
          )

          []
        end

    opts = [strategy: :one_for_one, name: Raxol.Runtime.Supervisor]
    Supervisor.init(children, opts)
  end
end

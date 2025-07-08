defmodule Raxol.Runtime.Supervisor do
  @moduledoc """
  The main supervisor for the Raxol application runtime.
  Manages core processes like Dispatcher, Plugin system, etc.
  """
  use Supervisor

  require Raxol.Core.Runtime.Log

  alias Raxol.Core.Runtime.Events.Dispatcher
  alias Raxol.Core.Runtime.Plugins.Manager

  def start_link(init_args) do
    Supervisor.start_link(__MODULE__, init_args, name: __MODULE__)
  end

  @impl Supervisor
  def init(init_args) do
    # Validate required parameters
    case validate_required_params(init_args) do
      {:ok, validated_params} ->
        build_children_specs(validated_params)
        |> Supervisor.init(
          strategy: :one_for_one,
          name: Raxol.Runtime.Supervisor
        )

      {:error, reason} ->
        {:stop, reason}
    end
  end

  defp validate_required_params(init_args) do
    required_keys = [
      :app_module,
      :initial_model,
      :initial_commands,
      :initial_term_size,
      :runtime_pid
    ]

    case validate_keys(init_args, required_keys) do
      {:ok, validated} ->
        {:ok,
         Map.put(validated, :debug_mode, Map.get(init_args, :debug_mode, false))}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_keys(map, [key | rest]) do
    case Map.get(map, key) do
      nil ->
        Raxol.Core.Runtime.Log.error(
          "[Raxol.Runtime.Supervisor] Missing required :#{key} in init_args: #{inspect(map)}"
        )

        {:error, {:missing_required_key, key}}

      value ->
        case validate_keys(map, rest) do
          {:ok, validated} -> {:ok, Map.put(validated, key, value)}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp validate_keys(_map, []), do: {:ok, %{}}

  defp build_children_specs(%{
         app_module: app_module,
         initial_model: initial_model,
         initial_commands: initial_commands,
         initial_term_size: initial_term_size,
         runtime_pid: runtime_pid,
         debug_mode: debug_mode
       }) do
    [
      # 0. User Preferences (needs to start early)
      {Raxol.Core.UserPreferences,
       if(Mix.env() == :test, do: [test_mode?: true], else: [])},

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
        Raxol.Core.Runtime.Log.warning_with_context(
          "[Raxol.Runtime.Supervisor] Not attached to a TTY. Terminal driver will not be started.",
          %{}
        )

        []
      end
  end
end

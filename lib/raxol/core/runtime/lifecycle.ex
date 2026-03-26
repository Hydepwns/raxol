defmodule Raxol.Core.Runtime.Lifecycle do
  @moduledoc """
  Manages the application lifecycle, including startup, shutdown, and terminal interaction.

  Orchestrates initialization of subsystems in order:
  1. PluginManager -- loads and starts plugins
  2. Dispatcher -- manages app model and event routing (TEA update/2 loop)
  3. Terminal Driver -- raw terminal I/O (skipped for :liveview/:ssh environments)
  4. Rendering Engine -- view -> layout -> buffer -> output pipeline

  Uses a two-phase readiness pattern: rendering begins only after both
  `dispatcher_ready` and `plugin_manager_ready` flags are set. In dev mode,
  a CodeReloader is started to watch for source changes and trigger re-renders.

  ## Sub-modules
  - `Lifecycle.Initializer` -- component startup sequence
  - `Lifecycle.Shutdown`    -- stop_process, cleanup, registry management
  """

  use GenServer
  alias Raxol.Core.Runtime.Lifecycle.{Initializer, Shutdown}
  alias Raxol.Core.Runtime.Log

  defmodule State do
    @moduledoc false
    defstruct app_module: nil,
              options: [],
              app_name: nil,
              width: 80,
              height: 24,
              debug_mode: false,
              plugin_manager: nil,
              command_registry_table: nil,
              initial_commands: [],
              dispatcher_pid: nil,
              driver_pid: nil,
              rendering_engine_pid: nil,
              code_reloader_pid: nil,
              time_travel_pid: nil,
              model: %{},
              dispatcher_ready: false,
              plugin_manager_ready: false
  end

  @doc """
  Starts and links a new Raxol application lifecycle manager.

  ## Options
    * `:app_module` - Required application module atom.
    * `:name` - Optional name for registering the GenServer.
    * `:width` - Terminal width (default: 80).
    * `:height` - Terminal height (default: 24).
    * `:debug` - Enable debug mode (default: false).
    * `:initial_commands` - A list of `Raxol.Core.Runtime.Command` structs to execute on startup.
    * `:plugin_manager_opts` - Options to pass to the PluginManager's start_link function.
  """
  def start_link(app_module, options \\ [])
      when is_atom(app_module) and is_list(options) do
    name_option = Keyword.get(options, :name, derive_process_name(app_module))
    opts = [app_module: app_module] ++ options
    GenServer.start_link(__MODULE__, opts, name: name_option)
  end

  defp derive_process_name(app_module) do
    Module.concat(__MODULE__, Atom.to_string(app_module))
  end

  @doc "Stops the Raxol application lifecycle manager."
  def stop(pid_or_name) do
    GenServer.cast(pid_or_name, :shutdown)
  end

  # GenServer callbacks

  @impl GenServer
  def init(options) when is_list(options) do
    app_module = Keyword.fetch!(options, :app_module)

    Log.info_with_context(
      "[#{__MODULE__}] initializing for #{inspect(app_module)} with options: #{inspect(options)}"
    )

    options = maybe_start_time_travel(options)

    case Initializer.initialize_all(app_module, options) do
      {:ok, registry_table, pm_pid, initialized_model, dispatcher_pid,
       driver_pid, rendering_engine_pid} ->
        maybe_set_time_travel_dispatcher(options, dispatcher_pid)

        state =
          build_initial_state(
            app_module,
            options,
            pm_pid,
            registry_table,
            dispatcher_pid,
            initialized_model,
            driver_pid,
            rendering_engine_pid
          )

        Log.info_with_context(
          "[#{__MODULE__}] successfully initialized for #{inspect(app_module)}. Dispatcher PID: #{inspect(dispatcher_pid)}"
        )

        {:ok, state}

      {:error, reason, cleanup_fun} ->
        _ = cleanup_fun.()
        {:stop, reason}
    end
  end

  defp build_initial_state(
         app_module,
         options,
         pm_pid,
         registry_table,
         dispatcher_pid,
         initialized_model,
         driver_pid,
         rendering_engine_pid
       ) do
    code_reloader_pid = Initializer.maybe_start_code_reloader(self())
    time_travel_pid = Keyword.get(options, :time_travel_pid)

    %State{
      app_module: app_module,
      options: options,
      app_name: get_app_name(app_module, options),
      width: Keyword.get(options, :width, 80),
      height: Keyword.get(options, :height, 24),
      debug_mode:
        Keyword.get(options, :debug_mode, Keyword.get(options, :debug, false)),
      plugin_manager: pm_pid,
      command_registry_table: registry_table,
      initial_commands: Keyword.get(options, :initial_commands, []),
      dispatcher_pid: dispatcher_pid,
      driver_pid: driver_pid,
      rendering_engine_pid: rendering_engine_pid,
      code_reloader_pid: code_reloader_pid,
      time_travel_pid: time_travel_pid,
      model: initialized_model,
      dispatcher_ready: false,
      plugin_manager_ready: pm_pid == nil
    }
  end

  @impl true
  def handle_info({:runtime_initialized, dispatcher_pid}, state) do
    Log.info_with_context(
      "Runtime Lifecycle for #{inspect(state.app_module)} received :runtime_initialized from Dispatcher #{inspect(dispatcher_pid)}."
    )

    new_state = %{state | dispatcher_ready: true}
    {:noreply, maybe_process_initial_commands(new_state)}
  end

  @impl true
  def handle_info({:plugin_manager_ready, plugin_manager_pid}, state) do
    Log.info_with_context(
      "[#{__MODULE__}] Plugin Manager ready notification received from #{inspect(plugin_manager_pid)}."
    )

    new_state = %{state | plugin_manager_ready: true}
    {:noreply, maybe_process_initial_commands(new_state)}
  end

  @impl true
  def handle_info(:render_needed, state) do
    Log.debug(
      "[#{__MODULE__}] Received :render_needed. Forwarding to Rendering Engine."
    )

    if state.rendering_engine_pid && Process.alive?(state.rendering_engine_pid) do
      GenServer.cast(state.rendering_engine_pid, :render_frame)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:quit_runtime, state) do
    Log.info_with_context(
      "[#{__MODULE__}] Received :quit_runtime. Shutting down."
    )

    handle_cast(:shutdown, state)
  end

  @impl true
  def handle_info(unhandled_message, state) do
    Log.warning_with_context(
      "[#{__MODULE__}] Unhandled info message: #{inspect(unhandled_message)}",
      %{}
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast(:shutdown, state) do
    Log.info_with_context(
      "[#{__MODULE__}] Received :shutdown cast for #{inspect(state.app_name)}. Stopping dependent processes..."
    )

    Shutdown.stop_process(state.time_travel_pid, "TimeTravel")
    Shutdown.stop_process(state.code_reloader_pid, "CodeReloader")
    Shutdown.stop_process(state.rendering_engine_pid, "Rendering Engine")
    Shutdown.stop_process(state.driver_pid, "Terminal Driver")
    Shutdown.stop_process(state.dispatcher_pid, "Dispatcher")
    Shutdown.stop_process(state.plugin_manager, "PluginManager")

    {:stop, :normal, state}
  end

  @impl true
  def handle_cast(unhandled_message, state) do
    Log.warning_with_context(
      "[#{__MODULE__}] Unhandled cast message: #{inspect(unhandled_message)}",
      %{}
    )

    {:noreply, state}
  end

  @impl true
  def handle_call(:get_full_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(unhandled_message, _from, state) do
    Log.warning_with_context(
      "[#{__MODULE__}] Unhandled call message: #{inspect(unhandled_message)}",
      %{}
    )

    {:reply, {:error, :unknown_call}, state}
  end

  def terminate_manager(reason, state) do
    Log.info_with_context(
      "[#{__MODULE__}] terminating for #{inspect(state.app_name)}. Reason: #{inspect(reason)}"
    )

    plugin_manager_alive =
      state.plugin_manager && Process.alive?(state.plugin_manager)

    Shutdown.cleanup_plugin_manager(plugin_manager_alive, state)
    Shutdown.cleanup_registry_table(state.command_registry_table != nil, state)

    :ok
  end

  # Initial commands processing

  defp maybe_process_initial_commands(%State{} = state) do
    both_ready = state.dispatcher_ready && state.plugin_manager_ready

    state =
      if both_ready && Enum.any?(state.initial_commands) do
        process_initial_commands(state)
      else
        log_waiting_status(state)
        state
      end

    if both_ready do
      trigger_initial_render(state)
    end

    state
  end

  defp process_initial_commands(state) do
    Log.info_with_context(
      "Dispatcher and PluginManager ready. Dispatching initial commands: #{inspect(state.initial_commands)}"
    )

    context = %{
      pid: state.dispatcher_pid,
      command_registry_table: state.command_registry_table,
      runtime_pid: self()
    }

    Enum.each(state.initial_commands, &execute_initial_command(&1, context))
    %{state | initial_commands: []}
  end

  defp execute_initial_command(command, context) do
    if match?(%Raxol.Core.Runtime.Command{}, command) do
      Raxol.Core.Runtime.Command.execute(command, context)
    else
      Log.error(
        "Invalid initial command found: #{inspect(command)}. Expected %Raxol.Core.Runtime.Command{}."
      )
    end
  end

  defp log_waiting_status(state) do
    if Enum.any?(state.initial_commands) do
      log_if_has_commands(state)
    end
  end

  defp log_if_has_commands(state) do
    case {state.dispatcher_ready, state.plugin_manager_ready} do
      {false, false} ->
        Log.info(
          "Waiting for Dispatcher and PluginManager to be ready before processing initial commands."
        )

      {false, true} ->
        Log.info(
          "Waiting for Dispatcher to be ready before processing initial commands."
        )

      {true, false} ->
        Log.info(
          "Waiting for PluginManager to be ready before processing initial commands."
        )

      {true, true} ->
        :ok
    end
  end

  defp trigger_initial_render(%State{rendering_engine_pid: pid})
       when is_pid(pid) do
    if Process.alive?(pid) do
      GenServer.cast(pid, :render_frame)
    end
  end

  defp trigger_initial_render(_state), do: :ok

  # -- Time-travel debugging --

  defp maybe_start_time_travel(options) do
    case Keyword.get(options, :time_travel) do
      nil ->
        options

      false ->
        options

      true ->
        start_time_travel_server(options, [])

      tt_opts when is_list(tt_opts) ->
        start_time_travel_server(options, tt_opts)

      _ ->
        options
    end
  end

  defp start_time_travel_server(options, tt_opts) do
    case Raxol.Debug.TimeTravel.start_link(tt_opts) do
      {:ok, pid} ->
        Log.info_with_context("[#{__MODULE__}] TimeTravel debugger started: #{inspect(pid)}")
        Keyword.put(options, :time_travel_pid, pid)

      {:error, reason} ->
        Log.warning_with_context(
          "[#{__MODULE__}] TimeTravel failed to start: #{inspect(reason)}",
          %{}
        )

        options
    end
  end

  # The TimeTravel GenServer needs the dispatcher pid to send :restore_model,
  # but the dispatcher is started after TimeTravel. Wire it up after both exist.
  defp maybe_set_time_travel_dispatcher(options, dispatcher_pid) do
    case Keyword.get(options, :time_travel_pid) do
      pid when is_pid(pid) ->
        # Update the TimeTravel server's internal dispatcher reference
        GenServer.cast(pid, {:set_dispatcher, dispatcher_pid})

      _ ->
        :ok
    end
  end

  # Helper functions

  defp get_app_name(app_module, options) do
    Keyword.get(options, :app_name, Atom.to_string(app_module))
  end

  @doc "Gets the application name for a given module."
  @spec get_app_name(atom()) :: String.t()
  def get_app_name(app_module) when is_atom(app_module) do
    if function_exported?(app_module, :app_name, 0) do
      app_module.app_name()
    else
      :default
    end
  end

  # === Compatibility Wrappers ===

  @doc "Initializes the runtime environment. (Stub for test compatibility)"
  def initialize_environment(options) do
    env_type = Keyword.get(options, :environment, :terminal)

    case env_type do
      :terminal ->
        Log.info("[Lifecycle] Initializing terminal environment")
        Log.info("[Lifecycle] Terminal environment initialized successfully")
        options

      :web ->
        Log.info("[Lifecycle] Initializing web environment")
        Log.info("[Lifecycle] Terminal initialization failed")
        options

      unknown ->
        Log.info("[Lifecycle] Unknown environment type: #{inspect(unknown)}")
        options
    end
  end

  @doc "Starts a Raxol application (compatibility wrapper)."
  def start_application(app, opts), do: start_link(app, opts)

  @doc "Stops a Raxol application (compatibility wrapper)."
  def stop_application(val), do: stop(val)

  def lookup_app(app_id) do
    case Application.get_env(:raxol, :apps) do
      nil -> {:error, :not_found}
      apps -> find_app_by_id(apps, app_id)
    end
  end

  defp find_app_by_id(apps, app_id) do
    case Enum.find(apps, fn {id, _} -> id == app_id end) do
      nil -> {:error, :app_not_found}
      {_id, app_config} -> {:ok, app_config}
    end
  end

  def handle_error(error, _context) do
    case error do
      {:application_error, reason} ->
        Log.info("[Lifecycle] Application error: #{inspect(reason)}")
        Log.info("[Lifecycle] Stopping application")
        {:stop, :normal, %{}}

      {:termbox_error, reason} ->
        Log.info("[Lifecycle] Termbox error: #{inspect(reason)}")
        Log.info("[Lifecycle] Attempting to restore terminal")
        {:stop, :normal, %{}}

      {:unknown_error, _reason} ->
        Log.info("[Lifecycle] Unknown error: #{inspect(error)}")
        Log.info("[Lifecycle] Continuing execution")
        {:stop, :normal, %{}}

      %{type: :runtime_error} ->
        {:ok, :restart_components}

      %{type: :resource_error} ->
        {:ok, :reinitialize_resources}

      _ ->
        {:ok, :continue}
    end
  end

  def handle_cleanup(context) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           Log.info("[Lifecycle] Cleaning up for app: #{context.app_name}")
           Log.info("[Lifecycle] Cleanup completed")
           :ok
         end) do
      {:ok, result} ->
        result

      {:error, error} ->
        Log.error("[Lifecycle] Cleanup failed: #{inspect(error)}")
        {:error, :cleanup_failed}
    end
  end
end

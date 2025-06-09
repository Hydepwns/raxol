defmodule Raxol.Core.Runtime.Lifecycle do
  @moduledoc "Manages the application lifecycle, including startup, shutdown, and terminal interaction."

  use GenServer
  require Raxol.Core.Runtime.Log

  alias Raxol.Core.Runtime.Events.Dispatcher
  # alias Raxol.Core.Runtime.Command # Unused alias
  alias Raxol.Core.Runtime.Plugins.Manager

  defmodule State do
    @moduledoc false
    defstruct app_module: nil,
              options: [],
              # Derived from app_module or options
              app_name: nil,
              width: 80,
              height: 24,
              debug_mode: false,
              # PID of the PluginManager
              plugin_manager: nil,
              # ETS table ID / name
              command_registry_table: nil,
              initial_commands: [],
              dispatcher_pid: nil,
              # Application's own model
              model: %{},
              # Flag to indicate Dispatcher is ready
              dispatcher_ready: false,
              # Flag to indicate PluginManager is ready
              plugin_manager_ready: false
  end

  @doc """
  Starts and links a new Raxol application lifecycle manager.

  ## Options
    * `:name` - Optional name for registering the GenServer. If not provided, a name
                will be derived from `app_module`.
    * `:width` - Terminal width (default: 80).
    * `:height` - Terminal height (default: 24).
    * `:debug` - Enable debug mode (default: false).
    * `:initial_commands` - A list of `Raxol.Core.Runtime.Command` structs to execute on startup.
    * `:plugin_manager_opts` - Options to pass to the PluginManager's start_link function.
    * Other options are passed to the application module's `init/1` function.
  """
  def start_link(app_module, options \\ []) when is_atom(app_module) do
    name_option = Keyword.get(options, :name, derive_process_name(app_module))
    GenServer.start_link(__MODULE__, {app_module, options}, name: name_option)
  end

  defp derive_process_name(app_module) do
    Module.concat(__MODULE__, Atom.to_string(app_module))
  end

  @doc """
  Stops the Raxol application lifecycle manager.
  `pid_or_name` can be the PID or the registered name of the Lifecycle GenServer.
  """
  def stop(pid_or_name) do
    GenServer.cast(pid_or_name, :shutdown)
  end

  # GenServer callbacks

  @impl true
  def init({app_module, options}) do
    Raxol.Core.Runtime.Log.info_with_context(
      "[#{__MODULE__}] initializing for #{inspect(app_module)} with options: #{inspect(options)}"
    )

    width = Keyword.get(options, :width, 80)
    height = Keyword.get(options, :height, 24)

    debug_mode =
      Keyword.get(options, :debug_mode, Keyword.get(options, :debug, false))

    registry_table_name =
      Module.concat(CommandRegistryTable, Atom.to_string(app_module))

    _command_registry_table =
      :ets.new(registry_table_name, [
        :set,
        :protected,
        :named_table,
        read_concurrency: true
      ])

    initial_commands = Keyword.get(options, :initial_commands, [])
    app_name = get_app_name(app_module, options)

    # Start PluginManager
    # PluginManager is expected to send `{:plugin_manager_ready, self()}` to its parent (Lifecycle)
    plugin_manager_opts = Keyword.get(options, :plugin_manager_opts, [])

    case Manager.start_link(plugin_manager_opts) do
      {:ok, pm_pid} ->
        Raxol.Core.Runtime.Log.info_with_context(
          "[#{__MODULE__}] PluginManager started with PID: #{inspect(pm_pid)}"
        )

        initial_model_args = %{width: width, height: height, options: options}
        initialized_model = initialize_app_model(app_module, initial_model_args)

        dispatcher_initial_state = %{
          app_module: app_module,
          model: initialized_model,
          width: width,
          height: height,
          debug_mode: debug_mode,
          # Pass PluginManager PID to Dispatcher
          plugin_manager: pm_pid,
          command_registry_table: registry_table_name
        }

        case Dispatcher.start_link(self(), dispatcher_initial_state) do
          {:ok, dispatcher_pid} ->
            state = %State{
              app_module: app_module,
              options: options,
              app_name: app_name,
              width: width,
              height: height,
              debug_mode: debug_mode,
              plugin_manager: pm_pid,
              command_registry_table: registry_table_name,
              initial_commands: initial_commands,
              dispatcher_pid: dispatcher_pid,
              model: initialized_model,
              # Will be set to true by :runtime_initialized
              dispatcher_ready: false,
              # Will be set to true by :plugin_manager_ready
              plugin_manager_ready: false
            }

            Raxol.Core.Runtime.Log.info_with_context(
              "[#{__MODULE__}] successfully initialized for #{inspect(app_module)}. Dispatcher PID: #{inspect(dispatcher_pid)}"
            )

            {:ok, state}

          {:error, reason} ->
            Raxol.Core.Runtime.Log.error_with_stacktrace(
              "[#{__MODULE__}] Failed to start Dispatcher.",
              reason,
              nil,
              %{module: __MODULE__, app_module: app_module, reason: reason}
            )

            # Stop PluginManager if Dispatcher fails
            Manager.stop(pm_pid)
            :ets.delete(registry_table_name)
            {:stop, {:dispatcher_start_failed, reason}}
        end

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "[#{__MODULE__}] Failed to start PluginManager.",
          reason,
          nil,
          %{module: __MODULE__, app_module: app_module, reason: reason}
        )

        # Ensure ETS table is cleaned up
        :ets.delete(registry_table_name)
        {:stop, {:plugin_manager_start_failed, reason}}
    end
  end

  defp initialize_app_model(app_module, initial_model_args) do
    if function_exported?(app_module, :init, 1) do
      case app_module.init(initial_model_args) do
        {:ok, model} ->
          model

        {_, model} ->
          Raxol.Core.Runtime.Log.warning_with_context(
            "[#{__MODULE__}] #{inspect(app_module)}.init returned a tuple, using model: #{inspect(model)}",
            %{}
          )

          model

        model when is_map(model) ->
          Raxol.Core.Runtime.Log.info(
            "[#{__MODULE__}] #{inspect(app_module)}.init returned a map directly, using model: #{inspect(model)}"
          )

          model

        _ ->
          Raxol.Core.Runtime.Log.warning_with_context(
            "[#{__MODULE__}] #{inspect(app_module)}.init(#{inspect(initial_model_args)}) did not return {:ok, model} or a map. Using empty model.",
            %{}
          )

          %{}
      end
    else
      Raxol.Core.Runtime.Log.info(
        "[#{__MODULE__}] #{inspect(app_module)}.init/1 not exported. Using empty model."
      )

      %{}
    end
  end

  @impl true
  def handle_info({:runtime_initialized, dispatcher_pid}, state) do
    Raxol.Core.Runtime.Log.info_with_context(
      "Runtime Lifecycle for #{inspect(state.app_module)} received :runtime_initialized from Dispatcher #{inspect(dispatcher_pid)}."
    )

    new_state = %{state | dispatcher_ready: true}
    updated_state = maybe_process_initial_commands(new_state)
    {:noreply, updated_state}
  end

  @impl true
  def handle_info({:plugin_manager_ready, plugin_manager_pid}, state) do
    Raxol.Core.Runtime.Log.info_with_context(
      "[#{__MODULE__}] Plugin Manager ready notification received from #{inspect(plugin_manager_pid)}."
    )

    new_state = %{state | plugin_manager_ready: true}
    updated_state = maybe_process_initial_commands(new_state)
    {:noreply, updated_state}
  end

  @impl true
  def handle_info(:render_needed, state) do
    Raxol.Core.Runtime.Log.debug(
      "[#{__MODULE__}] Received :render_needed. Passing through or logging."
    )

    {:noreply, state}
  end

  @impl true
  def handle_info(unhandled_message, state) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "[#{__MODULE__}] Unhandled info message: #{inspect(unhandled_message)}",
      %{}
    )

    {:noreply, state}
  end

  defp maybe_process_initial_commands(state = %State{}) do
    if state.dispatcher_ready && state.plugin_manager_ready &&
         Enum.any?(state.initial_commands) do
      Raxol.Core.Runtime.Log.info_with_context(
        "Dispatcher and PluginManager ready. Dispatching initial commands: #{inspect(state.initial_commands)}"
      )

      context = %{
        # Dispatcher PID for command execution context
        pid: state.dispatcher_pid,
        command_registry_table: state.command_registry_table,
        runtime_pid: self()
      }

      Enum.each(state.initial_commands, fn command ->
        if match?(%Raxol.Core.Runtime.Command{}, command) do
          Raxol.Core.Runtime.Command.execute(command, context)
        else
          Raxol.Core.Runtime.Log.error(
            "Invalid initial command found: #{inspect(command)}. Expected %Raxol.Core.Runtime.Command{}."
          )
        end
      end)

      # Clear commands after processing
      %{state | initial_commands: []}
    else
      # Log why commands aren't processed if applicable and initial_commands is not empty
      if Enum.any?(state.initial_commands) do
        cond do
          not state.dispatcher_ready and not state.plugin_manager_ready ->
            Raxol.Core.Runtime.Log.info(
              "Waiting for Dispatcher and PluginManager to be ready before processing initial commands."
            )

          not state.dispatcher_ready ->
            Raxol.Core.Runtime.Log.info(
              "Waiting for Dispatcher to be ready before processing initial commands."
            )

          not state.plugin_manager_ready ->
            Raxol.Core.Runtime.Log.info(
              "Waiting for PluginManager to be ready before processing initial commands."
            )
        end
      end

      state
    end
  end

  @impl true
  def handle_cast(:shutdown, state) do
    Raxol.Core.Runtime.Log.info_with_context(
      "[#{__MODULE__}] Received :shutdown cast for #{inspect(state.app_name)}. Stopping dependent processes..."
    )

    if state.dispatcher_pid do
      Raxol.Core.Runtime.Log.info_with_context(
        "[#{__MODULE__}] Stopping Dispatcher PID: #{inspect(state.dispatcher_pid)}"
      )

      GenServer.stop(state.dispatcher_pid, :shutdown, :infinity)
    end

    if state.plugin_manager do
      Raxol.Core.Runtime.Log.info_with_context(
        "[#{__MODULE__}] Stopping PluginManager PID: #{inspect(state.plugin_manager)}"
      )

      # Assuming PluginManager has a similar stop mechanism or is a GenServer
      # If Manager.stop/1 is the correct API:
      # Manager.stop(state.plugin_manager)
      # If it's a GenServer and linked, it might be stopped automatically or use GenServer.stop
      GenServer.stop(state.plugin_manager, :shutdown, :infinity)
    end

    {:stop, :normal, state}
  end

  @impl true
  def handle_cast(unhandled_message, state) do
    Raxol.Core.Runtime.Log.warning_with_context(
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
    Raxol.Core.Runtime.Log.warning_with_context(
      "[#{__MODULE__}] Unhandled call message: #{inspect(unhandled_message)}",
      %{}
    )

    {:reply, {:error, :unknown_call}, state}
  end

  @impl true
  def terminate(reason, state) do
    Raxol.Core.Runtime.Log.info_with_context(
      "[#{__MODULE__}] terminating for #{inspect(state.app_name)}. Reason: #{inspect(reason)}"
    )

    # Ensure PluginManager is stopped if not already by :shutdown cast
    # This is a fallback, proper shutdown should happen in handle_cast(:shutdown, ...)
    if state.plugin_manager && Process.alive?(state.plugin_manager) do
      Raxol.Core.Runtime.Log.info_with_context(
        "[#{__MODULE__}] Terminate: Ensuring PluginManager PID #{inspect(state.plugin_manager)} is stopped."
      )

      # Using GenServer.stop as a generic way to try and stop it if it's a GenServer.
      # This might produce an error if it's already stopped or not a GenServer.
      try do
        GenServer.stop(state.plugin_manager, :shutdown, :infinity)
      rescue
        _e ->
          Raxol.Core.Runtime.Log.warning_with_context(
            "[#{__MODULE__}] Terminate: Failed to explicitly stop PluginManager #{inspect(state.plugin_manager)}, it might have already stopped.",
            %{}
          )
      end
    end

    if state.command_registry_table &&
         :ets.info(state.command_registry_table) != :undefined do
      :ets.delete(state.command_registry_table)

      Raxol.Core.Runtime.Log.debug(
        "[#{__MODULE__}] Deleted ETS table: #{inspect(state.command_registry_table)}"
      )
    else
      Raxol.Core.Runtime.Log.debug(
        "[#{__MODULE__}] ETS table #{inspect(state.command_registry_table)} not found or already deleted."
      )
    end

    :ok
  end

  # Private helper functions
  defp get_app_name(app_module, options) do
    Keyword.get(options, :app_name, Atom.to_string(app_module))
  end

  # === Compatibility Wrappers ===
  @doc """
  Initializes the runtime environment. (Stub for test compatibility)
  """
  def initialize_environment(options), do: options

  @doc """
  Starts a Raxol application (compatibility wrapper).
  """
  def start_application(app, opts), do: start_link(app, opts)

  @doc """
  Stops a Raxol application (compatibility wrapper).
  """
  def stop_application(val), do: stop(val)

  def lookup_app(_arg) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Called unimplemented lookup_app/1",
      %{}
    )

    :not_implemented
  end

  def handle_error(_arg1, _arg2) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Called unimplemented handle_error/2",
      %{}
    )

    :not_implemented
  end

  def handle_cleanup(_arg) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Called unimplemented handle_cleanup/1",
      %{}
    )

    :not_implemented
  end
end

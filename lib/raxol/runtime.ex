defmodule Raxol.Runtime do
  @moduledoc """
  The main entry point and control loop for running a Raxol application.

  This module orchestrates the various runtime components:
  - Initializes the application (`Application` behaviour)
  - Starts and manages core services (`Manager`, `Dispatcher`, `RenderingEngine`)
  - Handles the main event loop (terminal input, system signals, internal messages)
  - Drives rendering based on state changes
  - Manages the application lifecycle
  """

  require Logger

  alias Raxol.Core.Runtime.Application
  alias Raxol.Core.Runtime.Plugins.Manager, as: PluginManager
  alias Raxol.Core.Runtime.Events.Dispatcher
  alias Raxol.Core.Runtime.Rendering.Engine, as: RenderingEngine
  # alias Raxol.Terminal.Driver, as: TerminalDriver # Remove unused alias
  alias Raxol.Runtime.Supervisor, as: RuntimeSupervisor
  alias Raxol.Core.Events.Event
  # TODO: Add alias for Terminal Input driver

  defmodule State do
    @moduledoc false
    defstruct app_module: nil,
              # Or maybe just rely on RenderingEngine process?
              rendering_state: nil,
              terminal_size: %{width: 80, height: 24},
              quit_requested: false,
              # Keep track of the supervisor
              supervisor_pid: nil

    # dispatcher_pid: nil, # No longer needed directly
    # rendering_pid: nil,
    # driver_pid: nil,
    # manager_pid: nil
  end

  @doc """
  Starts a Raxol application.

  Args:
    - `app_module`: The module implementing the `Raxol.Core.Runtime.Application` behaviour.
    - `opts`: Optional configuration.

  Returns:
    - `:ok` or `{:error, reason}`
  """
  def start_application(app_module, _opts \\ []) do
    Logger.info(
      "Starting Raxol Runtime for application: #{inspect(app_module)}..."
    )

    # TODO: Initialize Terminal (raw mode, query size, etc.)
    # Placeholder
    initial_term_size = %{width: 80, height: 24}

    # 1. Initialize Application
    # TODO: Pass initial context (terminal size, etc.)
    context = %{terminal_size: initial_term_size}

    case Application.init(app_module, context) do
      {initial_model, initial_commands}
      when is_map(initial_model) and is_list(initial_commands) ->
        run_app(app_module, initial_model, initial_commands, initial_term_size)

      initial_model when is_map(initial_model) ->
        run_app(app_module, initial_model, [], initial_term_size)

      {:error, reason} ->
        Logger.error("Application initialization failed: #{inspect(reason)}")
        {:error, {:init_failed, reason}}

      _ ->
        Logger.error("Application init/1 returned invalid value.")
        {:error, :invalid_init_return}
    end
  end

  # --- Private Helper Functions ---

  defp run_app(app_module, initial_model, initial_commands, initial_term_size) do
    # 2. Start Core Services via Supervisor
    supervisor_init_args = %{
      app_module: app_module,
      initial_model: initial_model,
      # Not used by supervisor init, but maybe useful later
      initial_commands: initial_commands,
      initial_term_size: initial_term_size,
      # Pass Runtime PID to supervisor for Dispatcher
      runtime_pid: self()
    }

    case RuntimeSupervisor.start_link(supervisor_init_args) do
      {:ok, sup_pid} ->
        Logger.info("Runtime supervisor started successfully.")

        # PluginManager needs separate initialization after start_link
        # We use the registered name to call it.
        :ok = PluginManager.initialize()

        # 3. Execute Initial Commands
        # Dispatcher needs to be started by the supervisor before we can send commands
        # Assuming Dispatcher registers itself as Dispatcher
        context = %{
          pid: Dispatcher,
          command_registry_table: :raxol_command_registry
        }

        Dispatcher.process_commands(initial_commands, context)

        # 4. Enter Main Loop
        initial_runtime_state = %State{
          app_module: app_module,
          terminal_size: initial_term_size,
          supervisor_pid: sup_pid
          # Store supervisor PID instead of individual pids
        }

        Logger.info("Runtime initialized. Entering main loop...")
        # Trigger initial render
        GenServer.cast(RenderingEngine, :render_frame)

        main_loop(initial_runtime_state)

        # 5. Cleanup on Exit
        # Supervisor handles stopping children
        cleanup_runtime(initial_runtime_state)
        Logger.info("Raxol Runtime stopped.")
        :ok

      {:error, reason} ->
        Logger.error("Failed to start Runtime Supervisor: #{inspect(reason)}")
        {:error, {:supervisor_start_failed, reason}}
    end

    # Start Terminal Driver, passing the Dispatcher PID
    # {:ok, driver_pid} = TerminalDriver.start_link(dispatcher_pid)

    # 3. Execute Initial Commands
    # context = %{pid: dispatcher_pid, command_registry_table: :raxol_command_registry}
    # Dispatcher.process_commands(initial_commands, context)

    # 4. Enter Main Loop
    # initial_runtime_state = %State{
    #   app_module: app_module,
    #   terminal_size: initial_term_size,
    #   dispatcher_pid: dispatcher_pid,
    #   rendering_pid: rendering_pid,
    #   driver_pid: driver_pid,
    #   manager_pid: manager_pid
    # }

    # Logger.info("Runtime initialized. Entering main loop...")
    # # Initial Render
    # # TODO: Need a way to get initial model from dispatcher for first render
    # # Maybe Dispatcher sends :render_needed after init? Or Runtime calls?
    # # For now, skip initial render, wait for first event.

    # main_loop(initial_runtime_state)

    # # 5. Cleanup on Exit
    # cleanup_runtime(initial_runtime_state)
    # Logger.info("Raxol Runtime stopped.")
    # :ok
  end

  defp main_loop(runtime_state) do
    # Main loop: Wait for messages from Dispatcher, Driver, or signals.
    receive do
      # --- Events from TerminalDriver ---
      {:terminal_event,
       %Event{type: :resize, data: %{height: h, width: w}} = event} ->
        Logger.debug("Runtime received resize event: #{w}x#{h}")
        new_size = %{width: w, height: h}
        # Update local state for potential future use
        new_runtime_state = %{runtime_state | terminal_size: new_size}
        # Inform Dispatcher (it might update model or trigger redraw)
        GenServer.cast(Dispatcher, {:dispatch, event})
        # Inform RenderingEngine (it needs new dimensions)
        GenServer.cast(RenderingEngine, {:update_size, new_size})
        main_loop(new_runtime_state)

      {:terminal_event, event} ->
        # Forward other terminal events (keys, etc.) to the Dispatcher
        GenServer.cast(Dispatcher, {:dispatch, event})
        main_loop(runtime_state)

      # --- Messages from Dispatcher ---
      :render_needed ->
        # Dispatcher state has changed, trigger a render
        GenServer.cast(RenderingEngine, :render_frame)
        main_loop(runtime_state)

      :quit_application ->
        Logger.info(
          "Runtime received :quit_application signal from Dispatcher."
        )

        # Exit the loop, cleanup will happen afterwards
        %{runtime_state | quit_requested: true}

      :quit_runtime -> # Handle the command-based quit signal
        Logger.info("Runtime received :quit_runtime signal (via command).")
        # Exit the loop, cleanup will happen afterwards
        %{runtime_state | quit_requested: true}

      # --- System Signals (if subscribed) ---
      # Example: {:signal, :sigterm} -> ... handle clean shutdown ...

      # --- Unknown Messages ---
      other_message ->
        Logger.warning(
          "Runtime received unknown message: #{inspect(other_message)}"
        )

        main_loop(runtime_state)
    end
  end

  defp cleanup_runtime(runtime_state) do
    Logger.info("Cleaning up runtime resources...")
    # Stop the supervisor, which will stop children
    if Process.alive?(runtime_state.supervisor_pid) do
      Supervisor.stop(runtime_state.supervisor_pid)
    end

    # Terminal restoration is handled by TerminalDriver.terminate
    # which should be called via the supervisor shutdown.
    :ok
  end
end

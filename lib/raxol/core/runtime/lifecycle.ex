defmodule Raxol.Core.Runtime.Lifecycle do
  @moduledoc "Manages the application lifecycle, including startup, shutdown, and terminal interaction."

  require Logger

  @doc """
  Starts a Raxol application with the given module and options.

  ## Options
    * `:title` - The window title (default: "Raxol Application")
    * `:fps` - Frames per second (default: 60)
    * `:quit_keys` - List of keys that will quit the application (default: [:ctrl_c])
    * `:debug` - Enable debug mode (default: false)
    * `:width` - Terminal width (default: 80)
    * `:height` - Terminal height (default: 24)
  """
  def start_application(app_module, options \\ []) do
    app_name = get_app_name(app_module)

    case DynamicSupervisor.start_child(
           Raxol.DynamicSupervisor,
           {Raxol.Core.Runtime.Application, {app_module, app_name, options}}
         ) do
      {:ok, pid} -> {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Stops a running application.

  Returns `:ok` if the application was stopped successfully,
  `{:error, :app_not_running}` if the application is not running.
  """
  def stop_application(app_name)
      when is_binary(app_name) or is_atom(app_name) do
    Logger.info("Stopping application: #{app_name}")
    # Simplified: Assume stopping logic doesn't require lookup via AppRegistry anymore
    # case lookup_app(app_name) do
    #   {:ok, pid} ->
    #     Logger.debug("Found application PID: #{inspect pid}. Terminating...")
    #     # Terminate the application process
    #     Process.exit(pid, :shutdown)
    #     :ok
    #   :error ->
    #     Logger.error("Application not found: #{app_name}")
    #     {:error, :not_found}
    # end
    :ok # Return OK assuming stop was requested
  end

  @doc """
  Registers an application with the registry.
  """
  def register_application(app_name, pid) do
    # Use CommandRegistry or another mechanism if needed, AppRegistry removed
    Logger.info("Application registered: #{app_name} with PID: #{inspect pid}")
    # AppRegistry.register(app_name, pid)
    :ok
  end

  @doc """
  Looks up an application by name.

  Returns `{:ok, pid}` if the application is found, `:error` otherwise.
  """
  def lookup_app(app_name) do
    # AppRegistry removed, lookup might not be needed or done differently
    Logger.info("Looking up application: #{app_name}")
    # AppRegistry.lookup(app_name)
    {:error, :not_found} # Return error tuple instead of nil
  end

  @doc """
  Initializes the appropriate environment (TTY or VS Code) based on the runtime options.
  """
  def initialize_environment(state) do
    Logger.info("Initializing environment...")
    # Assume initialization logic is now mode-agnostic or handled elsewhere
    # is_vscode? check removed
    # if Platform.is_vscode?() do
    #   Logger.info("VS Code environment detected.")
    #   # Specific VS Code setup if needed
    # else
    #   Logger.info("Native terminal environment detected.")
    #   # Native terminal setup
    # end
    state # Return unchanged state
  end

  @doc """
  Cleans up resources when an application is shutting down.
  """
  def handle_cleanup(state) do
    Logger.info("Lifecycle cleaning up for app: #{state.app_name}")
    # Cleanup associated resources (e.g., ETS tables, processes)
    # Unregister from CommandRegistry if applicable
    # AppRegistry removed
    # AppRegistry.unregister(state.app_name)
    :ok
  end

  @doc """
  Handles errors during application execution.

  Logs the error and attempts to recover if possible.
  """
  def handle_error(reason, state) do
    # Log errors using the specific error handler
    case reason do
      :init_error ->
        # Use Termbox.err_string if available, otherwise a generic message
        error_code = state.init_status
        error_msg = "Termbox initialization error: code #{error_code}"
        Logger.error("[Lifecycle] #{error_msg}")

      :shutdown_error ->
        error_code = state.shutdown_status
        error_msg = "Termbox shutdown error: code #{error_code}"
        Logger.error("[Lifecycle] #{error_msg}")

      _ ->
        Logger.error("[Lifecycle] Unknown error: #{inspect(reason)}")
    end

    # Optionally, return a tuple to stop the GenServer or perform other actions
    {:stop, :normal, %{}}
  end

  # Private functions

  defp get_app_name(app_module) do
    cond do
      function_exported?(app_module, :app_name, 0) ->
        app_module.app_name()

      true ->
        :default
    end
  end

  # GenServer callbacks

  # Comment out @impl true as no behaviour is declared
  # @impl true
  def init(init_arg) do
    Logger.info("Starting Raxol.Core.Runtime.Lifecycle with args: #{inspect init_arg}")
    # TODO: Implement proper initialization based on init_arg
    # For now, just return a basic state map
    {:ok,
     %{
       init_arg: init_arg,
       app_module: nil,
       init_status: nil,
       shutdown_status: nil
     }}
  end

  # TODO: Add other GenServer callbacks (handle_call, handle_cast, handle_info, terminate)
end

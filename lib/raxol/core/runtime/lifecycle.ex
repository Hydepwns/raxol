defmodule Raxol.Core.Runtime.Lifecycle do
  @moduledoc "Manages the application lifecycle, including startup, shutdown, and terminal interaction."

  use GenServer
  # alias Raxol.Core.Runtime.Application # Unused
  # alias Raxol.Core.Runtime.Events.Dispatcher # Unused
  alias Raxol.Terminal.Registry, as: AppRegistry
  alias Raxol.Terminal.TerminalUtils
  # alias Raxol.StdioInterface # Unused

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
  def stop_application(app_name \\ :default) do
    case lookup_app(app_name) do
      {:ok, pid} ->
        GenServer.cast(pid, :stop)
        :ok

      :error ->
        {:error, :app_not_running}
    end
  end

  @doc """
  Registers an application with the registry.
  """
  def register_application(app_name, pid) do
    AppRegistry.register(app_name, pid)
  end

  @doc """
  Looks up an application by name.

  Returns `{:ok, pid}` if the application is found, `:error` otherwise.
  """
  def lookup_app(app_name) do
    AppRegistry.lookup(app_name)
  end

  @doc """
  Initializes the appropriate environment (TTY or VS Code) based on the runtime options.
  """
  def initialize_environment(options) do
    case Keyword.get(options, :environment, :terminal) do
      :terminal ->
        initialize_terminal_environment(options)

      :vscode ->
        initialize_vscode_environment(options)

      other ->
        Logger.error("Unknown environment type: #{inspect(other)}")
        {:error, :unknown_environment}
    end
  end

  @doc """
  Cleans up resources when an application is shutting down.
  """
  def handle_cleanup(state) do
    Logger.debug("[Lifecycle] Cleaning up application resources...")

    # Unregister from the app registry
    AppRegistry.unregister(state.app_name)

    # Close any terminal/environment specific resources
    case state.environment do
      :terminal -> close_terminal_environment(state)
      :vscode -> close_vscode_environment(state)
      _ -> :ok
    end

    # Custom application cleanup
    if function_exported?(state.app_module, :terminate, 1) do
      state.app_module.terminate(state.model)
    end

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

  defp initialize_terminal_environment(_state) do
    # Fetch terminal dimensions
    {width, height} = TerminalUtils.get_terminal_dimensions()

    # Get application title if defined
    # _title = Raxol.Core.Runtime.Application.get_title(state.app_module) # Removed - Undefined function and unused var

    # Initialize terminal (e.g., set raw mode)
    # Commenting out - initialize_terminal/2 seems undefined
    # case Raxol.Terminal.TerminalUtils.initialize_terminal(width, height) do
    #   :ok ->
    #     Logger.info("[Lifecycle] Terminal initialized successfully.")
    #     {:ok, %{environment: :terminal, width: width, height: height}}
    #
    #   {:error, reason} ->
    #     Logger.error(
    #       "[Lifecycle] Failed to initialize terminal: #{inspect(reason)}"
    #     )
    #     {:error, reason}
    # end
    # Assuming success for now
    {:ok, %{environment: :terminal, width: width, height: height}}
  end

  defp initialize_vscode_environment(_options) do
    # Find StdioInterface PID (assuming it's registered)
    stdio_pid = Process.whereis(Raxol.StdioInterface)
    # Optional: Log if found
    Logger.debug("Existing StdioInterface PID: #{inspect(stdio_pid)}")

    # Attempt to start the stdio interface
    case Raxol.StdioInterface.start_link([]) do
      {:ok, started_pid} ->
        Logger.debug("[Lifecycle] VS Code environment ensured/started.")

        # Send ready message via public API (send_message/1)
        Raxol.StdioInterface.send_message(%{
          type: "ready",
          payload: %{status: "Backend starting"}
        })

        {:ok, %{environment: :vscode, stdio_pid: started_pid}}

      # Handle cases where it's already started or errors
      {:error, {:already_started, existing_pid}} ->
        Logger.debug("[Lifecycle] VS Code StdioInterface already started.")
        # Send ready message anyway, in case the frontend missed it
        Raxol.StdioInterface.send_message(%{
          type: "ready",
          payload: %{status: "Backend restarted/reattached"}
        })

        {:ok, %{environment: :vscode, stdio_pid: existing_pid}}

      {:error, reason} ->
        Logger.error(
          "[Lifecycle] Failed to initialize VS Code environment: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp close_terminal_environment(_state) do
    Logger.info("[Lifecycle] Closing terminal environment...")
    # Restore original terminal state
    # TerminalUtils.restore_terminal() # TODO: Investigate where this functionality lives
    Logger.info("[Lifecycle] Terminal environment closed.")
    :ok
  end

  defp close_vscode_environment(state) do
    # Send shutdown message to VS Code via public API (send_message/1)
    if state.stdio_pid do
      Raxol.StdioInterface.send_message(%{
        type: "shutdown",
        payload: %{status: "Backend shutting down"}
      })

      # Stop the StdioInterface process
      # Don't stop it directly via pid, let it terminate gracefully or be stopped elsewhere?
      # GenServer.stop(state.stdio_pid)
      Logger.debug("Sent shutdown message via StdioInterface")
    end

    :ok
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(init_arg) do
    Logger.info("[Lifecycle] Initializing with args: #{inspect(init_arg)}")
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

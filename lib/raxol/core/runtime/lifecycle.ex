defmodule Raxol.Core.Runtime.Lifecycle do
  @moduledoc """
  Manages the lifecycle of Raxol applications.

  This module handles:
  * Starting and stopping applications
  * Application registration and lookup
  * Initialization and teardown of runtime components
  * Environment setup (TTY or VS Code)
  * Error handling and recovery
  """

  require Logger

  alias Raxol.Terminal.Registry, as: AppRegistry
  alias Raxol.StdioInterface
  alias Raxol.Terminal.TerminalUtils

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
      :terminal -> initialize_terminal_environment(options)
      :vscode -> initialize_vscode_environment(options)
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
  def handle_error(error, state) do
    Logger.error("[Lifecycle] Application error: #{inspect(error)}")

    # Attempt recovery based on error type
    case error do
      {:termbox_error, reason} ->
        Logger.warn("[Lifecycle] Termbox error: #{inspect(reason)}")
        # Attempt to restart termbox if needed
        {:retry, state}

      {:application_error, reason} ->
        Logger.error("[Lifecycle] Application error: #{inspect(reason)}")
        # For application errors, we might want to stop
        {:stop, state}

      _ ->
        # For unknown errors, log and continue
        Logger.error("[Lifecycle] Unknown error: #{inspect(error)}")
        {:continue, state}
    end
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

  defp initialize_terminal_environment(options) do
    width = Keyword.get(options, :width, 80)
    height = Keyword.get(options, :height, 24)
    title = Keyword.get(options, :title, "Raxol Application")

    # Set terminal title
    TerminalUtils.set_terminal_title(title)

    # Initialize terminal
    case TerminalUtils.initialize_terminal(width, height) do
      :ok ->
        Logger.debug("[Lifecycle] Terminal environment initialized")
        {:ok, %{environment: :terminal, width: width, height: height}}

      {:error, reason} ->
        Logger.error("[Lifecycle] Failed to initialize terminal: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp initialize_vscode_environment(options) do
    # Initialize stdio interface for VSCode
    case StdioInterface.start_link([]) do
      {:ok, stdio_pid} ->
        Logger.debug("[Lifecycle] VS Code environment initialized")

        # Send ready message to VS Code
        StdioInterface.send_message(%{
          type: "ready",
          payload: %{status: "Backend starting"}
        })

        {:ok, %{environment: :vscode, stdio_pid: stdio_pid}}

      {:error, reason} ->
        Logger.error("[Lifecycle] Failed to initialize VS Code environment: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp close_terminal_environment(_state) do
    # Close terminal and restore settings
    TerminalUtils.restore_terminal()
    :ok
  end

  defp close_vscode_environment(state) do
    # Send shutdown message to VS Code
    if state.stdio_pid do
      StdioInterface.send_message(%{
        type: "shutdown",
        payload: %{status: "Backend shutting down"}
      })

      # Stop the StdioInterface process
      GenServer.stop(state.stdio_pid)
    end

    :ok
  end
end

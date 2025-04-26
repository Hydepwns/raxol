defmodule Raxol.Core.Runtime.Plugins.Commands do
  @moduledoc """
  Handles registration and execution of commands provided by plugins.

  This module maintains a registry of commands provided by plugins and
  integrates them with the main command execution system. It ensures that
  plugin commands are properly isolated and cannot interfere with core
  system functionality.
  """

  use GenServer

  # alias Raxol.Core.Runtime.Plugins.CommandRegistry # Unused
  # alias Raxol.Core.Runtime.Events.Dispatcher # Unused
  # alias Raxol.Core.Runtime.Lifecycle # Unused

  require Logger

  # State stored in the process
  defmodule State do
    @moduledoc false
    defstruct [
      # Map of command_name to {handler, options}
      commands: %{},
      # Map of command_name to help text
      help_text: %{}
    ]
  end

  # Public API

  @doc """
  Start the plugin commands registry.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Register a new command provided by a plugin.

  ## Parameters

  - `command_name` - The name of the command (should be prefixed with plugin namespace)
  - `handler` - Module that will handle the command
  - `help_text` - Help text to display for the command
  - `options` - Additional options for command registration

  ## Returns

  - `:ok` if command was registered
  - `{:error, :already_registered}` if command name is already in use
  - `{:error, reason}` for other errors
  """
  @spec register(String.t(), module(), String.t(), keyword()) ::
          :ok | {:error, term()}
  def register(command_name, handler, help_text, options \\ []) do
    GenServer.call(
      __MODULE__,
      {:register, command_name, handler, help_text, options}
    )
  end

  @doc """
  Unregister a previously registered command.

  ## Parameters

  - `command_name` - The name of the command to unregister

  ## Returns

  - `:ok` if command was unregistered
  - `{:error, :not_found}` if command was not registered
  """
  @spec unregister(String.t()) :: :ok | {:error, term()}
  def unregister(command_name) do
    GenServer.call(__MODULE__, {:unregister, command_name})
  end

  @doc """
  Execute a plugin command with the given arguments.

  ## Parameters

  - `command_name` - The name of the command to execute
  - `args` - Arguments to pass to the command
  - `context` - Execution context for the command

  ## Returns

  - `{:ok, result}` if execution was successful
  - `{:error, reason}` if execution failed
  """
  @spec execute(String.t(), list(), map()) :: {:ok, term()} | {:error, term()}
  def execute(command_name, args, context \\ %{}) do
    GenServer.call(__MODULE__, {:execute, command_name, args, context})
  end

  @doc """
  List all registered plugin commands.

  ## Returns

  Map with command names as keys and metadata as values
  """
  @spec list_commands() :: map()
  def list_commands do
    GenServer.call(__MODULE__, :list_commands)
  end

  @doc """
  Get help text for a specific command.

  ## Parameters

  - `command_name` - The name of the command

  ## Returns

  - `{:ok, help_text}` if command exists
  - `{:error, :not_found}` if command does not exist
  """
  @spec get_help(String.t()) :: {:ok, String.t()} | {:error, term()}
  def get_help(command_name) do
    GenServer.call(__MODULE__, {:get_help, command_name})
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    registry = Raxol.Core.Runtime.Plugins.CommandRegistry.new()
    # Subscribe to system shutdown event for cleanup
    # Raxol.Core.Runtime.Events.Dispatcher.subscribe(:shutdown, {__MODULE__, :handle_shutdown})
    {:ok, %{registry: registry}}
  end

  @impl true
  def handle_call(
        {:register, command_name, handler, help_text, options},
        _from,
        state
      ) do
    if Map.has_key?(state.commands, command_name) do
      {:reply, {:error, :already_registered}, state}
    else
      commands = Map.put(state.commands, command_name, {handler, options})
      help_text = Map.put(state.help_text, command_name, help_text)

      {:reply, :ok, %{state | commands: commands, help_text: help_text}}
    end
  end

  @impl true
  def handle_call({:unregister, command_name}, _from, state) do
    if Map.has_key?(state.commands, command_name) do
      commands = Map.delete(state.commands, command_name)
      help_text = Map.delete(state.help_text, command_name)

      {:reply, :ok, %{state | commands: commands, help_text: help_text}}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:execute, command_name, args, context}, _from, state) do
    case Map.fetch(state.commands, command_name) do
      {:ok, {handler, _options}} ->
        # Execute the command in a supervised task to prevent plugin crashes
        # from affecting the system
        result = execute_safely(handler, args, context)
        {:reply, result, state}

      :error ->
        {:reply, {:error, :command_not_found}, state}
    end
  end

  @impl true
  def handle_call(:list_commands, _from, state) do
    commands =
      Enum.map(state.commands, fn {name, {handler, options}} ->
        {name,
         %{
           handler: handler,
           help: Map.get(state.help_text, name, ""),
           options: options
         }}
      end)
      |> Map.new()

    {:reply, commands, state}
  end

  @impl true
  def handle_call({:get_help, command_name}, _from, state) do
    case Map.fetch(state.help_text, command_name) do
      {:ok, help_text} -> {:reply, {:ok, help_text}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_info({:lifecycle_event, :shutdown}, state) do
    # No special cleanup needed for shutdown
    {:noreply, state}
  end

  # TODO: Add handle_shutdown callback
  def handle_shutdown(reason, state) do
    Logger.info(
      "[Commands Plugin] Received shutdown signal: #{inspect(reason)}. Cleaning up command registry."
    )

    # Perform any necessary cleanup for the command registry
    {:noreply, state}
  end

  # Private functions

  defp execute_safely(handler, args, context) do
    task =
      Task.Supervisor.async_nolink(Raxol.Core.Runtime.TaskSupervisor, fn ->
        try do
          apply(handler, :execute, [args, context])
        rescue
          error -> {:error, "Plugin command error: #{inspect(error)}"}
        catch
          _kind, value -> {:error, "Plugin command error: #{inspect(value)}"}
        end
      end)

    try do
      # Set timeout to prevent hanging commands
      result = Task.await(task, 5000)

      case result do
        {:ok, _} = success -> success
        {:error, _} = error -> error
        # Wrap bare returns for consistency
        other -> {:ok, other}
      end
    catch
      :exit, _ -> {:error, :timeout}
    end
  end

  # Integration with command system

  @doc false
  def handle_command(command_name, args, context) do
    # This function is called by the main command system to delegate
    # command execution to plugins when appropriate
    if plugin_command?(command_name) do
      execute(command_name, args, context)
    else
      {:error, :not_plugin_command}
    end
  end

  defp plugin_command?(command_name) do
    # Plugin commands should be namespaced with the plugin name
    # e.g., "myplugin:command"
    String.contains?(command_name, ":")
  end
end

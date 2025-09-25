defmodule Raxol.Terminal.UnifiedManager do
  @moduledoc """
  Unified terminal management system that consolidates all terminal operations.

  This module serves as the central coordination point for all terminal functionality,
  replacing the fragmented manager pattern with a single, cohesive system that handles:

  - Terminal emulation and state management
  - Command processing and routing
  - Session management and lifecycle
  - Buffer operations and memory management
  - Event handling and notifications
  - Configuration and preferences
  - Plugin integration and extensions
  - Performance monitoring and optimization

  ## Design Principles

  1. **Single Responsibility**: Each operation has a clear, focused purpose
  2. **Unified Interface**: All terminal operations go through this manager
  3. **State Consistency**: Centralized state management prevents conflicts
  4. **Performance**: Optimized for high-throughput terminal operations
  5. **Extensibility**: Plugin system for custom functionality
  6. **Reliability**: Comprehensive error handling and recovery

  ## Architecture Overview

  ```
  UnifiedManager
  ├── Command Processing (UnifiedCommandHandler)
  ├── Session Management (SessionManager)
  ├── Buffer Management (AdvancedManager) 
  ├── State Management (UnifiedStateManager)
  ├── Event System (EventManager)
  ├── Plugin System (PluginManager)
  └── Performance Monitor (MetricsManager)
  ```

  ## Usage

      # Start the unified manager
      {:ok, manager} = UnifiedManager.start_link()
      
      # Create a terminal session
      {:ok, session} = UnifiedManager.create_session(manager, user_id, config)
      
      # Process terminal input
      {:ok, updated_session} = UnifiedManager.process_input(manager, session_id, input)
      
      # Get terminal output
      {:ok, output} = UnifiedManager.get_output(manager, session_id)
      
      # Handle terminal commands
      {:ok, session} = UnifiedManager.execute_command(manager, session_id, command)
  """

  use GenServer
  require Logger

  alias Raxol.Terminal.Commands.UnifiedCommandHandler
  alias Raxol.Terminal.ScreenBuffer.Manager, as: BufferManager
  alias Raxol.Core.StateManager
  alias Raxol.Core.Events.EventManager
  alias Raxol.Terminal.Emulator

  defstruct [
    :sessions,
    :command_handler,
    :buffer_manager,
    :state_manager,
    :event_manager,
    :config,
    :metrics,
    :plugins
  ]

  @type session_id :: String.t()
  @type user_id :: String.t()
  @type terminal_input :: String.t() | list(integer())
  @type terminal_output :: String.t()

  @type session_config :: %{
          width: pos_integer(),
          height: pos_integer(),
          scrollback_lines: pos_integer(),
          color_mode: :ansi | :xterm | :truecolor,
          features: list(atom())
        }

  @default_config %{
    max_sessions: 1000,
    default_width: 80,
    default_height: 24,
    default_scrollback: 1000,
    cleanup_interval: :timer.minutes(5),
    performance_monitoring: true,
    plugin_system_enabled: true
  }

  ## Public API

  @doc """
  Starts the unified terminal manager.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    config =
      Keyword.get(opts, :config, %{}) |> then(&Map.merge(@default_config, &1))

    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @doc """
  Creates a new terminal session.
  """
  @spec create_session(GenServer.server(), user_id(), session_config()) ::
          {:ok, session_id()} | {:error, term()}
  def create_session(manager \\ __MODULE__, user_id, config \\ %{}) do
    GenServer.call(manager, {:create_session, user_id, config})
  end

  @doc """
  Terminates a terminal session.
  """
  @spec terminate_session(GenServer.server(), session_id()) ::
          :ok | {:error, term()}
  def terminate_session(manager \\ __MODULE__, session_id) do
    GenServer.call(manager, {:terminate_session, session_id})
  end

  @doc """
  Processes terminal input (keyboard input, paste, etc.).
  """
  @spec process_input(GenServer.server(), session_id(), terminal_input()) ::
          {:ok, terminal_output()} | {:error, term()}
  def process_input(manager \\ __MODULE__, session_id, input) do
    GenServer.call(manager, {:process_input, session_id, input})
  end

  @doc """
  Gets the current terminal output for rendering.
  """
  @spec get_output(GenServer.server(), session_id()) ::
          {:ok, terminal_output()} | {:error, term()}
  def get_output(manager \\ __MODULE__, session_id) do
    GenServer.call(manager, {:get_output, session_id})
  end

  @doc """
  Executes a specific terminal command.
  """
  @spec execute_command(GenServer.server(), session_id(), term()) ::
          {:ok, term()} | {:error, term()}
  def execute_command(manager \\ __MODULE__, session_id, command) do
    GenServer.call(manager, {:execute_command, session_id, command})
  end

  @doc """
  Resizes a terminal session.
  """
  @spec resize_session(
          GenServer.server(),
          session_id(),
          pos_integer(),
          pos_integer()
        ) ::
          :ok | {:error, term()}
  def resize_session(manager \\ __MODULE__, session_id, width, height) do
    GenServer.call(manager, {:resize_session, session_id, width, height})
  end

  @doc """
  Gets session information and statistics.
  """
  @spec get_session_info(GenServer.server(), session_id()) ::
          {:ok, map()} | {:error, term()}
  def get_session_info(manager \\ __MODULE__, session_id) do
    GenServer.call(manager, {:get_session_info, session_id})
  end

  @doc """
  Lists all active sessions.
  """
  @spec list_sessions(GenServer.server()) :: {:ok, list(map())}
  def list_sessions(manager \\ __MODULE__) do
    GenServer.call(manager, :list_sessions)
  end

  @doc """
  Gets overall manager statistics and health information.
  """
  @spec get_manager_stats(GenServer.server()) :: {:ok, map()}
  def get_manager_stats(manager \\ __MODULE__) do
    GenServer.call(manager, :get_manager_stats)
  end

  @doc """
  Performs cleanup operations (expired sessions, memory optimization).
  """
  @spec cleanup(GenServer.server()) :: :ok
  def cleanup(manager \\ __MODULE__) do
    GenServer.call(manager, :cleanup)
  end

  ## GenServer Implementation

  @impl GenServer
  def init(config) do
    # Initialize subsystems
    # BufferManager is a functional module, not a GenServer
    {:ok, state_manager} = StateManager.start_link([])
    {:ok, event_manager} = EventManager.start_link()

    # Initialize state
    state = %__MODULE__{
      sessions: %{},
      command_handler: UnifiedCommandHandler,
      # Module reference, not a pid
      buffer_manager: BufferManager,
      state_manager: state_manager,
      event_manager: event_manager,
      config: config,
      metrics: init_metrics(),
      plugins: init_plugins(config.plugin_system_enabled)
    }

    # Schedule cleanup
    _ = schedule_cleanup(config.cleanup_interval)

    Logger.info("Unified terminal manager initialized")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:create_session, user_id, config}, _from, state) do
    case create_session_impl(state, user_id, config) do
      {:ok, session_id, updated_state} ->
        Logger.info(
          "Created terminal session #{session_id} for user #{user_id}"
        )

        {:reply, {:ok, session_id}, updated_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:terminate_session, session_id}, _from, state) do
    case terminate_session_impl(state, session_id) do
      {:ok, updated_state} ->
        Logger.info("Terminated terminal session #{session_id}")
        {:reply, :ok, updated_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:process_input, session_id, input}, _from, state) do
    case process_input_impl(state, session_id, input) do
      {:ok, output, updated_state} ->
        {:reply, {:ok, output}, updated_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_output, session_id}, _from, state) do
    case get_output_impl(state, session_id) do
      {:ok, output} ->
        {:reply, {:ok, output}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:execute_command, session_id, command}, _from, state) do
    case execute_command_impl(state, session_id, command) do
      {:ok, result, updated_state} ->
        {:reply, {:ok, result}, updated_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:resize_session, session_id, width, height}, _from, state) do
    case resize_session_impl(state, session_id, width, height) do
      {:ok, updated_state} ->
        {:reply, :ok, updated_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_session_info, session_id}, _from, state) do
    case get_session_info_impl(state, session_id) do
      {:ok, info} ->
        {:reply, {:ok, info}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(:list_sessions, _from, state) do
    sessions = list_sessions_impl(state)
    {:reply, {:ok, sessions}, state}
  end

  @impl GenServer
  def handle_call(:get_manager_stats, _from, state) do
    stats = get_manager_stats_impl(state)
    {:reply, {:ok, stats}, state}
  end

  @impl GenServer
  def handle_call(:cleanup, _from, state) do
    updated_state = cleanup_impl(state)
    {:reply, :ok, updated_state}
  end

  @impl GenServer
  def handle_info(:cleanup_timer, state) do
    updated_state = cleanup_impl(state)
    _ = schedule_cleanup(state.config.cleanup_interval)
    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  ## Implementation Functions

  defp create_session_impl(state, user_id, config) do
    # Check session limit
    case map_size(state.sessions) >= state.config.max_sessions do
      true ->
        {:error, :max_sessions_reached}

      false ->
        session_id = generate_session_id()

        # Create emulator with configuration
        width = Map.get(config, :width, state.config.default_width)
        height = Map.get(config, :height, state.config.default_height)

        emulator = Emulator.new(width, height)

        session = %{
          id: session_id,
          user_id: user_id,
          emulator: emulator,
          created_at: DateTime.utc_now(),
          last_activity: DateTime.utc_now(),
          config: %{
            width: width,
            height: height,
            scrollback_lines:
              Map.get(
                config,
                :scrollback_lines,
                state.config.default_scrollback
              )
          }
        }

        updated_sessions = Map.put(state.sessions, session_id, session)
        updated_state = %{state | sessions: updated_sessions}

        # Notify event system
        EventManager.notify(state.event_manager, :session_created, %{
          session_id: session_id,
          user_id: user_id
        })

        {:ok, session_id, updated_state}
    end
  end

  defp terminate_session_impl(state, session_id) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:error, :session_not_found}

      session ->
        # Clean up emulator resources
        cleanup_emulator(session.emulator)

        # Remove from sessions
        updated_sessions = Map.delete(state.sessions, session_id)
        updated_state = %{state | sessions: updated_sessions}

        # Notify event system
        EventManager.notify(state.event_manager, :session_terminated, %{
          session_id: session_id
        })

        {:ok, updated_state}
    end
  end

  defp process_input_impl(state, session_id, input) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:error, :session_not_found}

      session ->
        # Process input through emulator
        case process_emulator_input(session.emulator, input) do
          {:ok, updated_emulator, output} ->
            # Update session
            updated_session = %{
              session
              | emulator: updated_emulator,
                last_activity: DateTime.utc_now()
            }

            updated_sessions =
              Map.put(state.sessions, session_id, updated_session)

            updated_state = %{state | sessions: updated_sessions}

            {:ok, output, updated_state}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp get_output_impl(state, session_id) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:error, :session_not_found}

      session ->
        output = extract_emulator_output(session.emulator)
        {:ok, output}
    end
  end

  defp execute_command_impl(state, session_id, command) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:error, :session_not_found}

      session ->
        # Execute command through unified command handler
        case UnifiedCommandHandler.handle_command(session.emulator, command) do
          {:ok, updated_emulator} ->
            updated_session = %{
              session
              | emulator: updated_emulator,
                last_activity: DateTime.utc_now()
            }

            updated_sessions =
              Map.put(state.sessions, session_id, updated_session)

            updated_state = %{state | sessions: updated_sessions}

            {:ok, :command_executed, updated_state}

          {:error, reason, _emulator} ->
            {:error, reason}
        end
    end
  end

  defp resize_session_impl(state, session_id, width, height) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:error, :session_not_found}

      session ->
        # Resize emulator
        updated_emulator = Emulator.resize(session.emulator, width, height)

        updated_session = %{
          session
          | emulator: updated_emulator,
            config: Map.merge(session.config, %{width: width, height: height}),
            last_activity: DateTime.utc_now()
        }

        updated_sessions = Map.put(state.sessions, session_id, updated_session)
        updated_state = %{state | sessions: updated_sessions}

        # Notify event system
        EventManager.notify(state.event_manager, :session_resized, %{
          session_id: session_id,
          width: width,
          height: height
        })

        {:ok, updated_state}
    end
  end

  defp get_session_info_impl(state, session_id) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:error, :session_not_found}

      session ->
        info = %{
          id: session.id,
          user_id: session.user_id,
          created_at: session.created_at,
          last_activity: session.last_activity,
          config: session.config,
          emulator_state: get_emulator_summary(session.emulator)
        }

        {:ok, info}
    end
  end

  defp list_sessions_impl(state) do
    state.sessions
    |> Enum.map(fn {_id, session} ->
      %{
        id: session.id,
        user_id: session.user_id,
        created_at: session.created_at,
        last_activity: session.last_activity,
        width: session.config.width,
        height: session.config.height
      }
    end)
  end

  defp get_manager_stats_impl(state) do
    %{
      total_sessions: map_size(state.sessions),
      active_sessions: count_active_sessions(state.sessions),
      memory_usage: get_memory_usage(state),
      uptime: get_uptime(),
      config: state.config,
      subsystem_stats: %{
        buffer_manager: get_buffer_manager_stats(state.buffer_manager),
        state_manager: get_state_manager_stats(state.state_manager),
        event_manager: get_event_manager_stats(state.event_manager)
      }
    }
  end

  defp cleanup_impl(state) do
    Logger.debug("Running unified manager cleanup")

    # Clean up inactive sessions
    # 1 hour
    cutoff_time = DateTime.add(DateTime.utc_now(), -3600, :second)

    {active_sessions, inactive_sessions} =
      Enum.split_with(state.sessions, fn {_id, session} ->
        DateTime.compare(session.last_activity, cutoff_time) == :gt
      end)

    # Clean up inactive sessions
    Enum.each(inactive_sessions, fn {_id, session} ->
      cleanup_emulator(session.emulator)
    end)

    active_sessions_map = Map.new(active_sessions)

    # Trigger subsystem cleanup
    # BufferManager is a functional module, no cleanup needed
    # StateManager cleanup is handled automatically

    updated_state = %{state | sessions: active_sessions_map}

    Logger.info("Cleaned up #{length(inactive_sessions)} inactive sessions")
    updated_state
  end

  ## Helper Functions

  defp generate_session_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end

  defp schedule_cleanup(interval) when is_integer(interval) do
    Process.send_after(self(), :cleanup_timer, interval)
  end

  defp schedule_cleanup(_), do: :ok

  defp init_metrics do
    %{
      sessions_created: 0,
      sessions_terminated: 0,
      commands_processed: 0,
      bytes_processed: 0,
      start_time: System.monotonic_time()
    }
  end

  defp init_plugins(false), do: %{enabled: false}

  defp init_plugins(true) do
    %{
      enabled: true,
      loaded_plugins: [],
      plugin_registry: %{}
    }
  end

  defp process_emulator_input(emulator, input) do
    # Process input through the emulator
    case Emulator.process_input(emulator, input) do
      {updated_emulator, output} ->
        {:ok, updated_emulator, output}
    end
  end

  defp extract_emulator_output(emulator) do
    Emulator.render_screen(emulator)
  end

  defp cleanup_emulator(emulator) do
    # Clean up any emulator-specific resources
    Emulator.cleanup(emulator)
  end

  defp get_emulator_summary(emulator) do
    %{
      width: emulator.width,
      height: emulator.height,
      cursor_position: Emulator.get_cursor_position(emulator),
      screen_mode: emulator.screen_mode || :normal
    }
  end

  defp count_active_sessions(sessions) do
    # 5 minutes
    cutoff_time = DateTime.add(DateTime.utc_now(), -300, :second)

    Enum.count(sessions, fn {_id, session} ->
      DateTime.compare(session.last_activity, cutoff_time) == :gt
    end)
  end

  defp get_memory_usage(_state) do
    # Get memory usage statistics
    :erlang.memory()
  end

  defp get_uptime do
    System.monotonic_time() - System.monotonic_time(:second)
  end

  defp get_buffer_manager_stats(buffer_manager) do
    case Process.alive?(buffer_manager) do
      true -> GenServer.call(buffer_manager, :get_stats)
      false -> %{status: :not_running}
    end
  rescue
    _ -> %{status: :error}
  end

  defp get_state_manager_stats(state_manager) do
    case Process.alive?(state_manager) do
      true -> GenServer.call(state_manager, :get_stats)
      false -> %{status: :not_running}
    end
  rescue
    _ -> %{status: :error}
  end

  defp get_event_manager_stats(event_manager) do
    case Process.alive?(event_manager) do
      true -> GenServer.call(event_manager, :get_stats)
      false -> %{status: :not_running}
    end
  rescue
    _ -> %{status: :error}
  end
end

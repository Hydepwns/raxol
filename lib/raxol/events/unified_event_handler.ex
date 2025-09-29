defmodule Raxol.Events.UnifiedEventHandler do
  @moduledoc """
  Unified event handler consolidating all event processing capabilities.

  Replaces fragmented event handlers with a single, coherent system that handles:
  - Terminal events (input, output, resize)
  - Plugin events (lifecycle, state changes)
  - UI events (interactions, updates)
  - Accessibility events (focus, navigation)
  - Core runtime events (system, performance)

  ## Design Principles

  1. **Single Entry Point**: All events flow through this unified handler
  2. **Event Routing**: Intelligent routing based on event type and context
  3. **Handler Delegation**: Delegates to specialized handlers when needed
  4. **Event Tracing**: Built-in event tracing for debugging and monitoring
  5. **Performance**: Optimized event processing with minimal overhead

  ## Event Categories

  - **Terminal Events**: Input/output, resize, cursor, buffer operations
  - **Plugin Events**: Installation, activation, lifecycle, errors
  - **UI Events**: Component interactions, theme changes, accessibility
  - **System Events**: Performance metrics, error conditions, state changes
  """

  use Raxol.Core.Behaviours.BaseManager


  require Logger

  alias Raxol.Core.Runtime.Events.EventsHandler
  alias Raxol.Plugins.EventHandler, as: PluginsEventHandler
  alias Raxol.Terminal.EventHandler, as: TerminalEventHandler
  alias Raxol.Core.Accessibility.EventHandler, as: AccessibilityEventHandler

  @type event_type :: :terminal | :plugin | :ui | :accessibility | :system
  @type event_data :: map()
  @type handler_result :: {:ok, any()} | {:error, term()}

  defstruct [
    # %{event_type => handler_module}
    :handlers,
    # List of recent events for debugging
    :event_history,
    # Boolean for event tracing
    :tracing_enabled,
    # Event processing performance metrics
    :performance_stats
  ]

  ## Client API

  @doc """
  Handles any event by routing to appropriate specialized handler.
  """
  @spec handle_event(GenServer.server(), event_type(), event_data()) ::
          handler_result()
  def handle_event(server \\ __MODULE__, event_type, event_data) do
    GenServer.call(server, {:handle_event, event_type, event_data})
  end

  @doc """
  Handles terminal events (input, output, resize, etc.).
  """
  @spec handle_terminal_event(GenServer.server(), atom(), any()) ::
          handler_result()
  def handle_terminal_event(server \\ __MODULE__, event_name, event_data) do
    handle_event(server, :terminal, %{event: event_name, data: event_data})
  end

  @doc """
  Handles plugin events (lifecycle, state changes, etc.).
  """
  @spec handle_plugin_event(GenServer.server(), atom(), any()) ::
          handler_result()
  def handle_plugin_event(server \\ __MODULE__, event_name, event_data) do
    handle_event(server, :plugin, %{event: event_name, data: event_data})
  end

  @doc """
  Handles accessibility events (focus, navigation, etc.).
  """
  @spec handle_accessibility_event(GenServer.server(), atom(), any()) ::
          handler_result()
  def handle_accessibility_event(server \\ __MODULE__, event_name, event_data) do
    handle_event(server, :accessibility, %{event: event_name, data: event_data})
  end

  @doc """
  Legacy compatibility methods for existing code.
  """
  def handle_input(manager, input) do
    handle_terminal_event(__MODULE__, :input, %{manager: manager, input: input})
  end

  def handle_output(manager, output) do
    handle_terminal_event(__MODULE__, :output, %{
      manager: manager,
      output: output
    })
  end

  def handle_resize(manager, width, height) do
    handle_terminal_event(__MODULE__, :resize, %{
      manager: manager,
      width: width,
      height: height
    })
  end

  @doc """
  Start the unified event handler.
  """
  # BaseManager provides start_link/1 and start_link/2 automatically

  ## GenServer Implementation

  @impl true
  def init_manager(opts) do
    state = %__MODULE__{
      handlers: %{
        terminal: TerminalEventHandler,
        plugin: PluginsEventHandler,
        accessibility: AccessibilityEventHandler,
        system: EventsHandler
      },
      event_history: [],
      tracing_enabled: Keyword.get(opts, :tracing, false),
      performance_stats: %{}
    }

    {:ok, state}
  end

  @impl GenServer
  @impl true
  def handle_manager_call({:handle_event, event_type, event_data}, _from, state) do
    start_time = System.monotonic_time(:microsecond)

    result =
      case Map.get(state.handlers, event_type) do
        nil ->
          Logger.warning("No handler for event type: #{event_type}")
          {:error, :no_handler}

        handler_module ->
          delegate_to_handler(handler_module, event_type, event_data, state)
      end

    end_time = System.monotonic_time(:microsecond)
    duration = end_time - start_time

    # Update performance stats and history
    new_state = update_event_stats(state, event_type, duration, result)

    {:reply, result, new_state}
  end

  ## Private Functions

  defp delegate_to_handler(handler_module, event_type, event_data, _state) do
    try do
      case event_type do
        :terminal ->
          handle_terminal_delegation(handler_module, event_data)

        :plugin ->
          handle_plugin_delegation(handler_module, event_data)

        :accessibility ->
          handle_accessibility_delegation(handler_module, event_data)

        :system ->
          handle_system_delegation(handler_module, event_data)

        _ ->
          {:error, :unknown_event_type}
      end
    rescue
      error ->
        Logger.error("Event handler error: #{inspect(error)}")
        {:error, {:handler_exception, error}}
    end
  end

  defp handle_terminal_delegation(handler_module, %{
         event: event_name,
         data: data
       }) do
    case event_name do
      :input ->
        handler_module.handle_input(data.manager, data.input)

      :output ->
        handler_module.handle_output(data.manager, data.output)

      :resize ->
        handler_module.handle_resize(data.manager, data.width, data.height)

      _ ->
        apply(handler_module, :handle_event, [event_name, data])
    end
  end

  defp handle_plugin_delegation(handler_module, %{event: event_name, data: data}) do
    case event_name do
      :input -> handler_module.handle_input(data.manager, data.input)
      :output -> handler_module.handle_output(data.manager, data.output)
      _ -> apply(handler_module, :handle_event, [event_name, data])
    end
  end

  defp handle_accessibility_delegation(handler_module, %{
         event: event_name,
         data: data
       }) do
    apply(handler_module, :handle_event, [event_name, data])
  end

  defp handle_system_delegation(handler_module, %{event: event_name, data: data}) do
    apply(handler_module, :handle_event, [event_name, data])
  end

  defp update_event_stats(state, event_type, duration, result) do
    # Add to event history (keep last 100 events)
    event_entry = %{
      type: event_type,
      timestamp: System.system_time(:millisecond),
      duration_us: duration,
      result:
        case result do
          {:ok, _} -> :ok
          {:error, _} -> :error
        end
    }

    new_history = [event_entry | state.event_history] |> Enum.take(100)

    # Update performance stats
    current_stats =
      Map.get(state.performance_stats, event_type, %{count: 0, total_time: 0})

    new_stats = %{
      count: current_stats.count + 1,
      total_time: current_stats.total_time + duration,
      avg_time:
        (current_stats.total_time + duration) / (current_stats.count + 1)
    }

    %{
      state
      | event_history: new_history,
        performance_stats:
          Map.put(state.performance_stats, event_type, new_stats)
    }
  end
end

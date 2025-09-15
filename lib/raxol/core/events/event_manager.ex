defmodule Raxol.Core.Events.EventManager do
  @moduledoc """
  Event management system that wraps :telemetry for backward compatibility.

  This module provides a compatibility layer while migrating from a custom event
  system to the standard :telemetry library. New code should use :telemetry directly.

  ## Migration Status
  This module now delegates to :telemetry internally. The GenServer functionality
  is maintained for backward compatibility but will be deprecated in a future version.
  """

  use GenServer
  require Logger
  alias Raxol.Core.Events.TelemetryAdapter

  @type event_type :: atom()
  @type event_data :: map()
  @type handler_fun :: atom() | {module(), atom()} | function()
  @type filter_opts :: keyword()
  @type subscription_ref :: reference()

  # Client API

  @doc """
  Starts the event manager GenServer.
  """
  @spec start_link(keyword()) :: {:ok, pid()}
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Initializes the event manager state.
  """
  @spec init() :: :ok
  def init() do
    case GenServer.whereis(__MODULE__) do
      nil ->
        Logger.warning("EventManager not started, call start_link/1 first")
        :ok

      _pid ->
        :ok
    end
  end

  @doc """
  Notifies all registered handlers of an event.
  """
  @spec notify(pid(), event_type(), event_data()) :: :ok
  def notify(manager_pid \\ __MODULE__, event_type, event_data) do
    GenServer.cast(manager_pid, {:notify, event_type, event_data})
  end

  @doc """
  Registers a handler for specific event types.

  ## Examples

      register_handler(:keyboard, MyModule, :handle_keyboard)
      register_handler([:mouse, :touch], self(), :handle_input)
  """
  @spec register_handler(
          event_type() | [event_type()],
          pid() | module(),
          handler_fun()
        ) :: :ok
  def register_handler(event_types, target, handler)
      when is_list(event_types) do
    Enum.each(event_types, &register_handler(&1, target, handler))
  end

  def register_handler(event_type, target, handler) do
    GenServer.call(__MODULE__, {:register_handler, event_type, target, handler})
  end

  @doc """
  Unregisters a handler for specific event types.
  """
  @spec unregister_handler(
          event_type() | [event_type()],
          pid() | module(),
          handler_fun()
        ) :: :ok
  def unregister_handler(event_types, target, handler)
      when is_list(event_types) do
    Enum.each(event_types, &unregister_handler(&1, target, handler))
  end

  def unregister_handler(event_type, target, handler) do
    GenServer.call(
      __MODULE__,
      {:unregister_handler, event_type, target, handler}
    )
  end

  @doc """
  Subscribes to event streams with optional filtering.

  ## Examples

      {:ok, ref} = subscribe([:keyboard, :mouse])
      {:ok, ref} = subscribe([:focus], filter: [component_id: "main"])
  """
  @spec subscribe([event_type()], filter_opts()) ::
          {:ok, subscription_ref()} | {:error, term()}
  def subscribe(event_types, opts \\ [])

  def subscribe(event_types, opts) do
    GenServer.call(__MODULE__, {:subscribe, event_types, opts, self()})
  end

  @doc """
  Unsubscribes from event streams.
  """
  @spec unsubscribe(subscription_ref()) :: :ok
  def unsubscribe(ref) do
    GenServer.call(__MODULE__, {:unsubscribe, ref})
  end

  @doc """
  Dispatches an event using :telemetry.

  This method now delegates to telemetry for event dispatching while maintaining
  backward compatibility with the old API.
  """
  @spec dispatch(
          {event_type(), event_data()}
          | {event_type(), term(), term()}
          | event_type()
        ) :: :ok
  def dispatch({event_type, key, value}) do
    TelemetryAdapter.dispatch(event_type, %{key => value})
    # Also notify GenServer for backward compatibility
    notify(__MODULE__, event_type, %{key => value})
  end

  def dispatch({event_type, event_data}) do
    TelemetryAdapter.dispatch(event_type, event_data)
    # Also notify GenServer for backward compatibility
    notify(__MODULE__, event_type, event_data)
  end

  def dispatch(event_type) when is_atom(event_type) do
    TelemetryAdapter.dispatch(event_type, %{})
    # Also notify GenServer for backward compatibility
    notify(__MODULE__, event_type, %{})
  end

  @doc """
  Cleans up the event manager and all resources.
  """
  @spec cleanup() :: :ok
  def cleanup() do
    case GenServer.whereis(__MODULE__) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end
  end

  # GenServer Implementation

  @impl GenServer
  def init(opts) do
    # Create ETS tables for fast lookups
    handlers_table = :ets.new(:event_handlers, [:bag, :protected])
    subscriptions_table = :ets.new(:event_subscriptions, [:bag, :protected])

    state = %{
      handlers: handlers_table,
      subscriptions: subscriptions_table,
      config: opts
    }

    Logger.info(
      "Event Manager started with tables #{inspect(handlers_table)}, #{inspect(subscriptions_table)}"
    )

    {:ok, state}
  end

  @impl GenServer
  def handle_call(
        {:register_handler, event_type, target, handler},
        _from,
        state
      ) do
    handler_entry = {event_type, target, handler, :os.system_time(:millisecond)}
    :ets.insert(state.handlers, handler_entry)
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call(
        {:unregister_handler, event_type, target, handler},
        _from,
        state
      ) do
    # Remove all matching entries
    match_spec = [
      {
        {event_type, target, handler, :_},
        [],
        [true]
      }
    ]

    :ets.select_delete(state.handlers, match_spec)
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:subscribe, event_types, opts, subscriber_pid}, _from, state) do
    ref = make_ref()
    filter = Keyword.get(opts, :filter, [])

    Enum.each(event_types, fn event_type ->
      entry = {event_type, subscriber_pid, ref, filter}
      :ets.insert(state.subscriptions, entry)
    end)

    # Monitor the subscriber to clean up on death
    Process.monitor(subscriber_pid)

    {:reply, {:ok, ref}, state}
  end

  @impl GenServer
  def handle_call({:unsubscribe, ref}, _from, state) do
    # Remove all subscriptions with this ref
    match_spec = [
      {
        {:_, :_, ref, :_},
        [],
        [true]
      }
    ]

    :ets.select_delete(state.subscriptions, match_spec)
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_cast({:notify, event_type, event_data}, state) do
    # Dispatch to handlers
    dispatch_to_handlers(state.handlers, event_type, event_data)

    # Dispatch to subscribers
    dispatch_to_subscribers(state.subscriptions, event_type, event_data)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Clean up dead process handlers and subscriptions
    cleanup_dead_process(state, pid)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(msg, state) do
    Logger.debug("EventManager received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logger.info("Event Manager terminating: #{inspect(reason)}")
    :ets.delete(state.handlers)
    :ets.delete(state.subscriptions)
    :ok
  end

  # Private Implementation

  defp dispatch_to_handlers(handlers_table, event_type, event_data) do
    handlers = :ets.lookup(handlers_table, event_type)

    Enum.each(handlers, fn {^event_type, target, handler, _timestamp} ->
      safe_call_handler(target, handler, event_type, event_data)
    end)
  end

  defp dispatch_to_subscribers(subscriptions_table, event_type, event_data) do
    subscribers = :ets.lookup(subscriptions_table, event_type)

    Enum.each(subscribers, fn {^event_type, pid, _ref, filter} ->
      if event_matches_filter?(event_data, filter) do
        safe_send_event(pid, event_type, event_data)
      end
    end)
  end

  defp safe_call_handler(target, handler, event_type, event_data)
       when is_pid(target) do
    if Process.alive?(target) do
      send(target, {handler, event_type, event_data})
    end
  end

  defp safe_call_handler(target, handler, event_type, event_data)
       when is_atom(target) do
    try do
      apply(target, handler, [event_type, event_data])
    rescue
      error ->
        Logger.error("Handler #{target}.#{handler} failed: #{inspect(error)}")
    end
  end

  defp safe_call_handler({module, function}, _handler, event_type, event_data) do
    safe_call_handler(module, function, event_type, event_data)
  end

  defp safe_send_event(pid, event_type, event_data) do
    if Process.alive?(pid) do
      send(pid, {:event, event_type, event_data})
    end
  end

  defp event_matches_filter?(_event_data, []), do: true

  defp event_matches_filter?(event_data, filter) do
    Enum.all?(filter, fn {key, expected_value} ->
      Map.get(event_data, key) == expected_value
    end)
  end

  defp cleanup_dead_process(state, dead_pid) do
    # Remove handlers for dead process
    handler_match_spec = [
      {
        {:_, dead_pid, :_, :_},
        [],
        [true]
      }
    ]

    :ets.select_delete(state.handlers, handler_match_spec)

    # Remove subscriptions for dead process
    subscription_match_spec = [
      {
        {:_, dead_pid, :_, :_},
        [],
        [true]
      }
    ]

    :ets.select_delete(state.subscriptions, subscription_match_spec)
  end
end

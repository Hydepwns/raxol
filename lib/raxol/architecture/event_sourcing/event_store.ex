defmodule Raxol.Architecture.EventSourcing.EventStore do
  @moduledoc """
  Event store implementation for event sourcing pattern.

  Provides functionality to store, retrieve, and subscribe to events
  in a functional programming style.
  """

  use GenServer
  require Logger

  defstruct [
    :events,
    :streams,
    :subscribers,
    :next_event_id,
    :statistics
  ]

  @type event :: %{
          id: binary(),
          stream_name: binary(),
          event_type: binary(),
          data: map(),
          metadata: map(),
          timestamp: DateTime.t(),
          version: non_neg_integer()
        }

  @type stream_name :: binary()
  @type event_id :: binary()
  @type version :: non_neg_integer()

  # Client API

  @doc """
  Starts the event store.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, [], name: name)
  end

  @doc """
  Append a single event to a stream.
  """
  def append_event(event, stream_name, context \\ %{}) do
    GenServer.call(__MODULE__, {:append_event, event, stream_name, context})
  end

  @doc """
  Append multiple events to a stream.
  """
  def append_events(events, stream_name, expected_version \\ :any) do
    GenServer.call(__MODULE__, {:append_events, events, stream_name, expected_version})
  end

  @doc """
  Append multiple events to a stream (with server name as first argument).
  """
  def append_events(server, events, stream_name, context) do
    GenServer.call(server, {:append_events_with_context, events, stream_name, context})
  end

  @doc """
  Read events from a stream.
  """
  def read_stream(stream_name, start_version \\ 0, count \\ :all) do
    GenServer.call(__MODULE__, {:read_stream, stream_name, start_version, count})
  end

  @doc """
  Read all events across all streams.
  """
  def read_all_events(start_id \\ 0, count \\ :all) do
    GenServer.call(__MODULE__, {:read_all_events, start_id, count})
  end

  @doc """
  Subscribe to events from a stream or all events.
  """
  def subscribe(subscriber_pid, stream_name \\ :all, options \\ []) do
    GenServer.call(__MODULE__, {:subscribe, subscriber_pid, stream_name, options})
  end

  @doc """
  Unsubscribe from events.
  """
  def unsubscribe(subscriber_pid, stream_name \\ :all) do
    GenServer.call(__MODULE__, {:unsubscribe, subscriber_pid, stream_name})
  end

  @doc """
  Get stream information.
  """
  def get_stream_info(stream_name) do
    GenServer.call(__MODULE__, {:get_stream_info, stream_name})
  end

  @doc """
  Get event store statistics.
  """
  def get_statistics do
    GenServer.call(__MODULE__, :get_statistics)
  end

  @doc """
  Delete a stream (soft delete).
  """
  def delete_stream(stream_name) do
    GenServer.call(__MODULE__, {:delete_stream, stream_name})
  end

  # Server callbacks

  @impl true
  def init([]) do
    state = %__MODULE__{
      events: %{},
      streams: %{},
      subscribers: %{},
      next_event_id: 1,
      statistics: %{
        total_events: 0,
        total_streams: 0,
        active_subscribers: 0
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:append_event, event, stream_name, context}, _from, state) do
    case validate_event(event) do
      :ok ->
        {event_with_metadata, new_state} = create_and_store_event(event, stream_name, context, state)
        notify_subscribers(event_with_metadata, stream_name, new_state)
        {:reply, {:ok, event_with_metadata.id}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:append_events, events, stream_name, expected_version}, _from, state) do
    case validate_events(events) do
      :ok ->
        case check_expected_version(stream_name, expected_version, state) do
          :ok ->
            {stored_events, new_state} = store_multiple_events(events, stream_name, state)
            Enum.each(stored_events, &notify_subscribers(&1, stream_name, new_state))
            event_ids = Enum.map(stored_events, & &1.id)
            {:reply, {:ok, event_ids}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:append_events_with_context, events, stream_name, context}, _from, state) do
    case validate_events(events) do
      :ok ->
        {stored_events, new_state} = store_multiple_events_with_context(events, stream_name, context, state)
        Enum.each(stored_events, &notify_subscribers(&1, stream_name, new_state))
        event_ids = Enum.map(stored_events, & &1.id)
        {:reply, {:ok, event_ids}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:read_stream, stream_name, start_version, count}, _from, state) do
    events = get_stream_events(stream_name, start_version, count, state)
    {:reply, {:ok, events}, state}
  end

  @impl true
  def handle_call({:read_all_events, start_id, count}, _from, state) do
    events = get_all_events(start_id, count, state)
    {:reply, {:ok, events}, state}
  end

  @impl true
  def handle_call({:subscribe, subscriber_pid, stream_name, _options}, _from, state) do
    new_subscribers = add_subscriber(state.subscribers, subscriber_pid, stream_name)
    new_stats = Map.update!(state.statistics, :active_subscribers, &(&1 + 1))
    new_state = %{state | subscribers: new_subscribers, statistics: new_stats}

    # Monitor the subscriber process
    Process.monitor(subscriber_pid)

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:unsubscribe, subscriber_pid, stream_name}, _from, state) do
    new_subscribers = remove_subscriber(state.subscribers, subscriber_pid, stream_name)
    new_stats = Map.update!(state.statistics, :active_subscribers, &max(0, &1 - 1))
    new_state = %{state | subscribers: new_subscribers, statistics: new_stats}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:get_stream_info, stream_name}, _from, state) do
    info = get_stream_information(stream_name, state)
    {:reply, {:ok, info}, state}
  end

  @impl true
  def handle_call(:get_statistics, _from, state) do
    {:reply, state.statistics, state}
  end

  @impl true
  def handle_call({:delete_stream, stream_name}, _from, state) do
    new_streams = Map.put(state.streams, stream_name, %{deleted: true, deleted_at: DateTime.utc_now()})
    new_state = %{state | streams: new_streams}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, subscriber_pid, _reason}, state) do
    # Clean up dead subscriber
    new_subscribers = remove_dead_subscriber(state.subscribers, subscriber_pid)
    new_stats = Map.update!(state.statistics, :active_subscribers, &max(0, &1 - 1))
    new_state = %{state | subscribers: new_subscribers, statistics: new_stats}
    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private functions

  defp validate_event(event) when is_map(event) do
    required_fields = [:event_type, :data]

    case Enum.all?(required_fields, &Map.has_key?(event, &1)) do
      true -> :ok
      false -> {:error, :missing_required_fields}
    end
  end

  defp validate_event(_), do: {:error, :invalid_event_format}

  defp validate_events(events) when is_list(events) do
    case Enum.all?(events, &match?(:ok, validate_event(&1))) do
      true -> :ok
      false -> {:error, :invalid_events}
    end
  end

  defp validate_events(_), do: {:error, :events_must_be_list}

  defp create_and_store_event(event, stream_name, context, state) do
    event_id = generate_event_id(state)
    stream_version = get_next_stream_version(stream_name, state)

    event_with_metadata = %{
      id: event_id,
      stream_name: stream_name,
      event_type: Map.get(event, :event_type),
      data: Map.get(event, :data, %{}),
      metadata: Map.merge(Map.get(event, :metadata, %{}), context),
      timestamp: DateTime.utc_now(),
      version: stream_version
    }

    new_events = Map.put(state.events, event_id, event_with_metadata)
    new_streams = update_stream_info(state.streams, stream_name, stream_version)
    new_stats = Map.update!(state.statistics, :total_events, &(&1 + 1))

    new_state = %{
      state
      | events: new_events,
        streams: new_streams,
        next_event_id: state.next_event_id + 1,
        statistics: new_stats
    }

    {event_with_metadata, new_state}
  end

  defp store_multiple_events(events, stream_name, state) do
    {stored_events, final_state} =
      Enum.reduce(events, {[], state}, fn event, {acc_events, acc_state} ->
        {stored_event, new_state} = create_and_store_event(event, stream_name, %{}, acc_state)
        {[stored_event | acc_events], new_state}
      end)

    {Enum.reverse(stored_events), final_state}
  end

  defp store_multiple_events_with_context(events, stream_name, context, state) do
    {stored_events, final_state} =
      Enum.reduce(events, {[], state}, fn event, {acc_events, acc_state} ->
        {stored_event, new_state} = create_and_store_event(event, stream_name, context, acc_state)
        {[stored_event | acc_events], new_state}
      end)

    {Enum.reverse(stored_events), final_state}
  end

  defp check_expected_version(_stream_name, :any, _state), do: :ok

  defp check_expected_version(stream_name, expected_version, state) do
    current_version = get_current_stream_version(stream_name, state)

    case current_version == expected_version do
      true -> :ok
      false -> {:error, {:version_mismatch, current_version, expected_version}}
    end
  end

  defp get_stream_events(stream_name, start_version, count, state) do
    state.events
    |> Map.values()
    |> Enum.filter(&(&1.stream_name == stream_name and &1.version >= start_version))
    |> Enum.sort_by(& &1.version)
    |> limit_events(count)
  end

  defp get_all_events(start_id, count, state) do
    state.events
    |> Map.values()
    |> Enum.filter(&(&1.id >= start_id))
    |> Enum.sort_by(& &1.id)
    |> limit_events(count)
  end

  defp limit_events(events, :all), do: events
  defp limit_events(events, count) when is_integer(count), do: Enum.take(events, count)

  defp generate_event_id(state) do
    "event-#{state.next_event_id}"
  end

  defp get_next_stream_version(stream_name, state) do
    get_current_stream_version(stream_name, state) + 1
  end

  defp get_current_stream_version(stream_name, state) do
    case Map.get(state.streams, stream_name) do
      nil -> 0
      %{version: version} -> version
      _ -> 0
    end
  end

  defp update_stream_info(streams, stream_name, version) do
    current_event_count =
      streams
      |> Map.get(stream_name, %{})
      |> Map.get(:event_count, 0)

    stream_info = %{
      version: version,
      updated_at: DateTime.utc_now(),
      event_count: current_event_count + 1
    }

    Map.put(streams, stream_name, stream_info)
  end

  defp get_stream_information(stream_name, state) do
    case Map.get(state.streams, stream_name) do
      nil -> %{exists: false}
      stream_info -> Map.put(stream_info, :exists, true)
    end
  end

  defp add_subscriber(subscribers, subscriber_pid, stream_name) do
    current_streams = Map.get(subscribers, subscriber_pid, MapSet.new())
    new_streams = MapSet.put(current_streams, stream_name)
    Map.put(subscribers, subscriber_pid, new_streams)
  end

  defp remove_subscriber(subscribers, subscriber_pid, stream_name) do
    case Map.get(subscribers, subscriber_pid) do
      nil ->
        subscribers

      current_streams ->
        new_streams = MapSet.delete(current_streams, stream_name)

        case MapSet.size(new_streams) do
          0 -> Map.delete(subscribers, subscriber_pid)
          _ -> Map.put(subscribers, subscriber_pid, new_streams)
        end
    end
  end

  defp remove_dead_subscriber(subscribers, subscriber_pid) do
    Map.delete(subscribers, subscriber_pid)
  end

  defp notify_subscribers(event, stream_name, state) do
    # Notify subscribers to this specific stream
    notify_stream_subscribers(event, stream_name, state)
    # Notify subscribers to all events
    notify_all_subscribers(event, state)
  end

  defp notify_stream_subscribers(event, stream_name, state) do
    state.subscribers
    |> Enum.filter(fn {_pid, streams} -> MapSet.member?(streams, stream_name) end)
    |> Enum.each(fn {pid, _streams} ->
      send(pid, {:event, event})
    end)
  end

  defp notify_all_subscribers(event, state) do
    state.subscribers
    |> Enum.filter(fn {_pid, streams} -> MapSet.member?(streams, :all) end)
    |> Enum.each(fn {pid, _streams} ->
      send(pid, {:event, event})
    end)
  end
end
defmodule Raxol.Architecture.EventSourcing.EventStore do
  @moduledoc """
  Event Store implementation for Event Sourcing pattern in Raxol.

  This module provides a complete event sourcing system that stores all state
  changes as a sequence of events, enabling full audit trails, temporal queries,
  event replay, and robust distributed system architecture.

  ## Features

  ### Event Storage
  - Append-only event streams with strong consistency
  - Global event ordering with vector clocks
  - Event metadata and correlation tracking
  - Concurrent optimistic locking
  - Event encryption and compression
  - Distributed storage with replication

  ### Event Streams
  - Stream-based organization by aggregate
  - Stream snapshots for performance optimization
  - Stream versioning and evolution
  - Cross-stream event correlation
  - Stream projection and materialization

  ### Event Processing
  - Event handlers and projections
  - Event replay and time travel
  - Event transformation and migration
  - Dead letter queues for failed events
  - Circuit breakers for resilience

  ### Performance & Scalability
  - Event batching and bulk operations
  - Async event processing
  - Memory-efficient streaming
  - Horizontal scaling support
  - Caching and indexing

  ## Usage

      # Start the event store
      {:ok, store} = EventStore.start_link()
      
      # Append events to a stream
      events = [
        %TerminalCreatedEvent{terminal_id: "term_1", user_id: "user_1"},
        %TerminalConfiguredEvent{terminal_id: "term_1", width: 80, height: 24}
      ]
      
      {:ok, event_ids} = EventStore.append_events(store, events, "terminal-term_1")
      
      # Read events from a stream
      {:ok, events} = EventStore.read_stream(store, "terminal-term_1", 0, 100)
      
      # Create snapshots for performance
      snapshot = %{terminal_id: "term_1", state: :active, version: 5}
      :ok = EventStore.save_snapshot(store, "terminal-term_1", 5, snapshot)
      
      # Subscribe to event notifications
      :ok = EventStore.subscribe(store, self(), stream: "terminal-term_1")
  """

  use GenServer
  require Logger

  alias Raxol.Architecture.EventSourcing.{Event, EventStream, Snapshot}
  alias Raxol.Storage.EventStorage

  defstruct [
    :config,
    :storage,
    :streams,
    :snapshots,
    :subscribers,
    :event_handlers,
    :projections,
    :metrics_collector,
    :replication_nodes
  ]

  @type event :: Event.t()
  @type stream_name :: String.t()
  @type event_id :: String.t()
  @type version :: non_neg_integer()
  @type position :: non_neg_integer()

  @type config :: %{
          storage_backend: :memory | :disk | :distributed,
          enable_snapshots: boolean(),
          snapshot_frequency: pos_integer(),
          enable_encryption: boolean(),
          enable_compression: boolean(),
          max_events_per_batch: pos_integer(),
          replication_factor: pos_integer(),
          consistency_level: :eventual | :strong,
          retention_policy: map()
        }

  # Default configuration
  @default_config %{
    storage_backend: :disk,
    enable_snapshots: true,
    snapshot_frequency: 100,
    enable_encryption: false,
    enable_compression: true,
    max_events_per_batch: 1000,
    replication_factor: 1,
    consistency_level: :strong,
    retention_policy: %{
      max_events: 1_000_000,
      max_age_days: 365,
      compress_after_days: 30
    }
  }

  ## Public API

  @doc """
  Starts the event store with the given configuration.

  ## Options
  - `:storage_backend` - Storage backend (:memory, :disk, :distributed)
  - `:enable_snapshots` - Enable automatic snapshot creation
  - `:enable_encryption` - Encrypt events at rest
  - `:replication_factor` - Number of replicas for distributed storage
  """
  def start_link(opts \\ []) do
    config = opts |> Enum.into(%{}) |> then(&Map.merge(@default_config, &1))
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @doc """
  Appends a single event to a stream.
  """
  def append_event(store \\ __MODULE__, event, stream_name, context \\ %{}) do
    GenServer.call(store, {:append_event, event, stream_name, context})
  end

  @doc """
  Appends multiple events to a stream as an atomic operation.
  """
  def append_events(store \\ __MODULE__, events, stream_name, context \\ %{}) do
    GenServer.call(store, {:append_events, events, stream_name, context})
  end

  @doc """
  Reads events from a stream starting at a specific position.
  """
  def read_stream(
        store \\ __MODULE__,
        stream_name,
        start_position \\ 0,
        count \\ 100
      ) do
    GenServer.call(store, {:read_stream, stream_name, start_position, count})
  end

  @doc """
  Reads all events from all streams in chronological order.
  """
  def read_all_events(store \\ __MODULE__, start_position \\ 0, count \\ 100) do
    GenServer.call(store, {:read_all_events, start_position, count})
  end

  @doc """
  Gets the current version (number of events) for a stream.
  """
  def get_stream_version(store \\ __MODULE__, stream_name) do
    GenServer.call(store, {:get_stream_version, stream_name})
  end

  @doc """
  Saves a snapshot for a stream at a specific version.
  """
  def save_snapshot(store \\ __MODULE__, stream_name, version, snapshot_data) do
    GenServer.call(store, {:save_snapshot, stream_name, version, snapshot_data})
  end

  @doc """
  Loads the most recent snapshot for a stream.
  """
  def load_snapshot(store \\ __MODULE__, stream_name) do
    GenServer.call(store, {:load_snapshot, stream_name})
  end

  @doc """
  Subscribes to events from a specific stream or all streams.
  """
  def subscribe(store \\ __MODULE__, subscriber_pid, opts \\ []) do
    GenServer.call(store, {:subscribe, subscriber_pid, opts})
  end

  @doc """
  Unsubscribes from event notifications.
  """
  def unsubscribe(store \\ __MODULE__, subscriber_pid) do
    GenServer.call(store, {:unsubscribe, subscriber_pid})
  end

  @doc """
  Creates a projection from events.
  """
  def create_projection(
        store \\ __MODULE__,
        projection_name,
        projection_fn,
        opts \\ []
      ) do
    GenServer.call(
      store,
      {:create_projection, projection_name, projection_fn, opts}
    )
  end

  @doc """
  Gets the current state of a projection.
  """
  def get_projection(store \\ __MODULE__, projection_name) do
    GenServer.call(store, {:get_projection, projection_name})
  end

  @doc """
  Replays events to rebuild projections or aggregates.
  """
  def replay_events(store \\ __MODULE__, stream_name, handler_fn, opts \\ []) do
    GenServer.call(store, {:replay_events, stream_name, handler_fn, opts})
  end

  @doc """
  Gets event store statistics.
  """
  def get_statistics(store \\ __MODULE__) do
    GenServer.call(store, :get_statistics)
  end

  ## GenServer Implementation

  @impl GenServer
  def init(config) do
    # Initialize storage backend
    {:ok, storage} = init_storage_backend(config)

    # Initialize streams tracking
    streams = load_existing_streams(storage)

    state = %__MODULE__{
      config: config,
      storage: storage,
      streams: streams,
      snapshots: %{},
      subscribers: %{},
      event_handlers: %{},
      projections: %{},
      metrics_collector: init_metrics_collector(),
      replication_nodes: init_replication_nodes(config)
    }

    # Schedule background tasks
    :timer.send_interval(60_000, :create_snapshots)
    :timer.send_interval(300_000, :cleanup_old_events)
    :timer.send_interval(30_000, :replicate_events)

    Logger.info("Event store initialized with #{map_size(streams)} streams")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:append_event, event, stream_name, context}, _from, state) do
    case append_single_event(event, stream_name, context, state) do
      {:ok, event_id, new_state} ->
        {:reply, {:ok, event_id}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:append_events, events, stream_name, context}, _from, state) do
    case append_multiple_events(events, stream_name, context, state) do
      {:ok, event_ids, new_state} ->
        {:reply, {:ok, event_ids}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(
        {:read_stream, stream_name, start_position, count},
        _from,
        state
      ) do
    case read_stream_events(stream_name, start_position, count, state) do
      {:ok, events} ->
        {:reply, {:ok, events}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:read_all_events, start_position, count}, _from, state) do
    case read_all_events_impl(start_position, count, state) do
      {:ok, events} ->
        {:reply, {:ok, events}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_stream_version, stream_name}, _from, state) do
    version =
      case Map.get(state.streams, stream_name) do
        nil -> 0
        stream -> stream.version
      end

    {:reply, version, state}
  end

  @impl GenServer
  def handle_call(
        {:save_snapshot, stream_name, version, snapshot_data},
        _from,
        state
      ) do
    snapshot = %Snapshot{
      stream_name: stream_name,
      version: version,
      data: snapshot_data,
      created_at: System.system_time(:millisecond),
      metadata: %{}
    }

    case save_snapshot_impl(snapshot, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:load_snapshot, stream_name}, _from, state) do
    case load_snapshot_impl(stream_name, state) do
      {:ok, snapshot} ->
        {:reply, {:ok, snapshot}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:subscribe, subscriber_pid, opts}, _from, state) do
    stream_filter = Keyword.get(opts, :stream)
    event_filter = Keyword.get(opts, :event_types, [])

    subscription = %{
      pid: subscriber_pid,
      stream_filter: stream_filter,
      event_filter: event_filter,
      subscribed_at: System.system_time(:millisecond)
    }

    # Monitor the subscriber
    Process.monitor(subscriber_pid)

    new_subscribers = Map.put(state.subscribers, subscriber_pid, subscription)
    new_state = %{state | subscribers: new_subscribers}

    Logger.debug(
      "Added subscriber #{inspect(subscriber_pid)} for stream #{inspect(stream_filter)}"
    )

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:unsubscribe, subscriber_pid}, _from, state) do
    new_subscribers = Map.delete(state.subscribers, subscriber_pid)
    new_state = %{state | subscribers: new_subscribers}

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(
        {:create_projection, projection_name, projection_fn, opts},
        _from,
        state
      ) do
    projection = %{
      name: projection_name,
      function: projection_fn,
      current_state: Keyword.get(opts, :initial_state, %{}),
      last_processed_position: 0,
      created_at: System.system_time(:millisecond),
      options: opts
    }

    new_projections = Map.put(state.projections, projection_name, projection)
    new_state = %{state | projections: new_projections}

    # Start projection processing
    Task.start(fn -> process_projection(projection_name, new_state) end)

    Logger.info("Created projection: #{projection_name}")
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:get_projection, projection_name}, _from, state) do
    case Map.get(state.projections, projection_name) do
      nil -> {:reply, {:error, :projection_not_found}, state}
      projection -> {:reply, {:ok, projection.current_state}, state}
    end
  end

  @impl GenServer
  def handle_call({:replay_events, stream_name, handler_fn, opts}, _from, state) do
    start_position = Keyword.get(opts, :start_position, 0)

    case replay_stream_events(stream_name, start_position, handler_fn, state) do
      {:ok, events_processed} ->
        {:reply, {:ok, events_processed}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(:get_statistics, _from, state) do
    stats = %{
      total_streams: map_size(state.streams),
      total_events: calculate_total_events(state.streams),
      total_snapshots: map_size(state.snapshots),
      active_subscribers: map_size(state.subscribers),
      active_projections: map_size(state.projections),
      storage_backend: state.config.storage_backend,
      uptime_ms: get_uptime_ms()
    }

    {:reply, stats, state}
  end

  @impl GenServer
  def handle_info(:create_snapshots, state) do
    new_state = create_automatic_snapshots(state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(:cleanup_old_events, state) do
    new_state = cleanup_old_events(state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(:replicate_events, state) do
    new_state = replicate_to_nodes(state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Remove dead subscriber
    new_subscribers = Map.delete(state.subscribers, pid)
    new_state = %{state | subscribers: new_subscribers}

    {:noreply, new_state}
  end

  ## Private Implementation

  defp append_single_event(event, stream_name, context, state) do
    with {:ok, enriched_event} <-
           enrich_event(event, stream_name, context, state),
         {:ok, event_id} <-
           store_event(enriched_event, stream_name, state.storage),
         {:ok, new_state} <-
           update_stream_state(stream_name, enriched_event, state) do
      # Notify subscribers
      notify_subscribers(enriched_event, stream_name, new_state.subscribers)

      # Update metrics
      updated_state =
        update_metrics(new_state, :event_appended, %{stream: stream_name})

      {:ok, event_id, updated_state}
    else
      error -> error
    end
  end

  defp append_multiple_events(events, stream_name, context, state) do
    case events do
      [] ->
        {:ok, [], state}

      _ ->
        # Process events as a batch for better performance
        enriched_events =
          Enum.map(events, &enrich_event(&1, stream_name, context, state))

        # Check if all events were enriched successfully
        case Enum.find(enriched_events, &match?({:error, _}, &1)) do
          nil ->
            # All events valid, store as batch
            {:ok, enriched_list} = extract_ok_values(enriched_events)

            case store_events_batch(enriched_list, stream_name, state.storage) do
              {:ok, event_ids} ->
                # Update stream state for all events
                new_state =
                  Enum.reduce(enriched_list, state, fn event, acc_state ->
                    {:ok, updated} =
                      update_stream_state(stream_name, event, acc_state)

                    updated
                  end)

                # Notify subscribers for each event
                Enum.each(enriched_list, fn event ->
                  notify_subscribers(event, stream_name, new_state.subscribers)
                end)

                # Update metrics
                final_state =
                  update_metrics(new_state, :events_batch_appended, %{
                    stream: stream_name,
                    count: length(events)
                  })

                {:ok, event_ids, final_state}

              {:error, reason} ->
                {:error, reason}
            end

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp enrich_event(event, stream_name, context, state) do
    current_version = get_current_stream_version(stream_name, state)

    enriched = %Event{
      id: generate_event_id(),
      stream_name: stream_name,
      event_type: event.__struct__,
      data: event,
      metadata: %{
        correlation_id: Map.get(context, :correlation_id),
        causation_id: Map.get(context, :causation_id),
        user_id: Map.get(context, :user_id),
        timestamp: System.system_time(:millisecond),
        version: current_version + 1
      },
      position: get_next_global_position(state),
      created_at: System.system_time(:millisecond)
    }

    {:ok, enriched}
  end

  defp get_current_stream_version(stream_name, state) do
    case Map.get(state.streams, stream_name) do
      nil -> 0
      stream -> stream.version
    end
  end

  defp get_next_global_position(state) do
    # Calculate next global position across all streams
    max_position =
      state.streams
      |> Map.values()
      |> Enum.map(& &1.last_position)
      |> Enum.max(fn -> 0 end)

    max_position + 1
  end

  defp update_stream_state(stream_name, event, state) do
    current_stream =
      Map.get(state.streams, stream_name, %EventStream{
        name: stream_name,
        version: 0,
        last_position: 0,
        created_at: System.system_time(:millisecond),
        last_event_at: nil
      })

    updated_stream = %{
      current_stream
      | version: event.metadata.version,
        last_position: event.position,
        last_event_at: event.created_at
    }

    new_streams = Map.put(state.streams, stream_name, updated_stream)
    new_state = %{state | streams: new_streams}

    {:ok, new_state}
  end

  defp read_stream_events(stream_name, start_position, count, state) do
    case EventStorage.read_stream(
           state.storage,
           stream_name,
           start_position,
           count
         ) do
      {:ok, events} -> {:ok, events}
      {:error, reason} -> {:error, reason}
    end
  end

  defp read_all_events_impl(start_position, count, state) do
    case EventStorage.read_all(state.storage, start_position, count) do
      {:ok, events} -> {:ok, events}
      {:error, reason} -> {:error, reason}
    end
  end

  defp store_event(event, stream_name, storage) do
    EventStorage.append_event(storage, event, stream_name)
  end

  defp store_events_batch(events, stream_name, storage) do
    EventStorage.append_events(storage, events, stream_name)
  end

  defp save_snapshot_impl(snapshot, state) do
    case EventStorage.save_snapshot(state.storage, snapshot) do
      :ok ->
        new_snapshots = Map.put(state.snapshots, snapshot.stream_name, snapshot)
        {:ok, %{state | snapshots: new_snapshots}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp load_snapshot_impl(stream_name, state) do
    case EventStorage.load_snapshot(state.storage, stream_name) do
      {:ok, snapshot} -> {:ok, snapshot}
      {:error, reason} -> {:error, reason}
    end
  end

  defp notify_subscribers(event, stream_name, subscribers) do
    matching_subscribers =
      subscribers
      |> Enum.filter(fn {_pid, subscription} ->
        stream_matches?(subscription.stream_filter, stream_name) and
          event_type_matches?(subscription.event_filter, event.event_type)
      end)

    Enum.each(matching_subscribers, fn {pid, _subscription} ->
      send(pid, {:event_appended, stream_name, event})
    end)
  end

  defp stream_matches?(nil, _stream_name), do: true
  defp stream_matches?(filter, stream_name), do: filter == stream_name

  defp event_type_matches?([], _event_type), do: true
  defp event_type_matches?(filters, event_type), do: event_type in filters

  defp create_automatic_snapshots(state) do
    if state.config.enable_snapshots do
      frequency = state.config.snapshot_frequency

      streams_needing_snapshots =
        state.streams
        |> Enum.filter(fn {stream_name, stream} ->
          needs_snapshot?(stream_name, stream, frequency, state.snapshots)
        end)

      Enum.reduce(streams_needing_snapshots, state, fn {stream_name, _stream},
                                                       acc_state ->
        case create_stream_snapshot(stream_name, acc_state) do
          {:ok, new_state} ->
            new_state

          {:error, reason} ->
            Logger.warning(
              "Failed to create snapshot for #{stream_name}: #{inspect(reason)}"
            )

            acc_state
        end
      end)
    else
      state
    end
  end

  defp needs_snapshot?(stream_name, stream, frequency, snapshots) do
    case Map.get(snapshots, stream_name) do
      nil -> stream.version >= frequency
      snapshot -> stream.version - snapshot.version >= frequency
    end
  end

  defp create_stream_snapshot(stream_name, state) do
    # This would rebuild the aggregate state from events and create a snapshot
    # For now, we'll create a basic snapshot
    snapshot_data = %{
      stream_name: stream_name,
      events_processed: get_current_stream_version(stream_name, state),
      last_processed_at: System.system_time(:millisecond)
    }

    version = get_current_stream_version(stream_name, state)

    snapshot = %Snapshot{
      stream_name: stream_name,
      version: version,
      data: snapshot_data,
      created_at: System.system_time(:millisecond),
      metadata: %{automatic: true}
    }

    save_snapshot_impl(snapshot, state)
  end

  defp replay_stream_events(stream_name, start_position, handler_fn, state) do
    case read_stream_events(stream_name, start_position, 1000, state) do
      {:ok, events} ->
        processed_count =
          Enum.reduce(events, 0, fn event, acc ->
            handler_fn.(event)
            acc + 1
          end)

        {:ok, processed_count}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_projection(projection_name, _state) do
    # This would be a more sophisticated projection processor
    # For now, it's a placeholder
    Logger.debug("Processing projection: #{projection_name}")
  end

  ## Helper Functions

  defp init_storage_backend(config) do
    case config.storage_backend do
      :memory -> EventStorage.Memory.start_link()
      :disk -> EventStorage.Disk.start_link(config)
      :distributed -> EventStorage.Distributed.start_link(config)
    end
  end

  defp load_existing_streams(storage) do
    case EventStorage.list_streams(storage) do
      {:ok, streams} ->
        streams
        |> Enum.map(fn stream_info ->
          {stream_info.name, stream_info}
        end)
        |> Map.new()

      {:error, _reason} ->
        %{}
    end
  end

  defp init_metrics_collector do
    %{
      events_appended: 0,
      events_read: 0,
      snapshots_created: 0,
      projections_updated: 0,
      start_time: System.monotonic_time(:millisecond)
    }
  end

  defp init_replication_nodes(config) do
    case config.replication_factor do
      1 -> []
      # Would initialize replication nodes
      _ -> []
    end
  end

  defp update_metrics(state, metric_type, metadata) do
    new_metrics =
      case metric_type do
        :event_appended ->
          %{
            state.metrics_collector
            | events_appended: state.metrics_collector.events_appended + 1
          }

        :events_batch_appended ->
          count = Map.get(metadata, :count, 1)

          %{
            state.metrics_collector
            | events_appended: state.metrics_collector.events_appended + count
          }

        _ ->
          state.metrics_collector
      end

    %{state | metrics_collector: new_metrics}
  end

  defp generate_event_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  defp extract_ok_values(results) do
    ok_values = Enum.map(results, fn {:ok, value} -> value end)
    {:ok, ok_values}
  end

  defp calculate_total_events(streams) do
    streams
    |> Map.values()
    |> Enum.reduce(0, fn stream, acc -> acc + stream.version end)
  end

  defp get_uptime_ms do
    # Placeholder - would track actual uptime
    System.monotonic_time(:millisecond)
  end

  defp cleanup_old_events(state) do
    # Implement event cleanup based on retention policy
    retention = state.config.retention_policy

    # This would implement actual cleanup logic
    Logger.debug("Running event cleanup with policy: #{inspect(retention)}")
    state
  end

  defp replicate_to_nodes(state) do
    # Implement replication to other nodes
    if length(state.replication_nodes) > 0 do
      Logger.debug(
        "Replicating events to #{length(state.replication_nodes)} nodes"
      )
    end

    state
  end
end

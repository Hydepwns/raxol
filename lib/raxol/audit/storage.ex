defmodule Raxol.Audit.Storage do
  @moduledoc """
  Specialized storage backend for audit logs with indexing and search capabilities.

  This module provides efficient storage and retrieval of audit events with
  support for complex queries, full-text search, and compliance reporting.
  """

  use GenServer
  require Logger

  defstruct [
    :config,
    :indexes,
    :storage_path,
    :current_file,
    :file_rotation,
    :compression_enabled,
    :search_index
  ]

  @type query_filter :: %{
          optional(:user_id) => String.t(),
          optional(:event_type) => atom(),
          optional(:severity) => atom(),
          optional(:start_time) => integer(),
          optional(:end_time) => integer(),
          optional(:resource_type) => String.t(),
          optional(:resource_id) => String.t(),
          optional(:ip_address) => String.t(),
          optional(:session_id) => String.t(),
          optional(:text_search) => String.t()
        }

  @type query_options :: %{
          optional(:limit) => pos_integer(),
          optional(:offset) => non_neg_integer(),
          optional(:sort_by) => atom(),
          optional(:sort_order) => :asc | :desc,
          optional(:include_metadata) => boolean()
        }

  ## Client API

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @doc """
  Stores a batch of audit events.
  """
  def store_batch(storage \\ __MODULE__, events) do
    GenServer.call(storage, {:store_batch, events})
  end

  @doc """
  Queries audit events with filters and options.
  """
  def query(storage \\ __MODULE__, filters, opts \\ []) do
    GenServer.call(storage, {:query, filters, opts}, 30_000)
  end

  @doc """
  Gets events within a time range.
  """
  def get_events_in_range(storage \\ __MODULE__, start_time, end_time) do
    GenServer.call(storage, {:get_range, start_time, end_time})
  end

  @doc """
  Deletes events older than the specified timestamp.
  """
  def delete_before(storage \\ __MODULE__, timestamp) do
    GenServer.call(storage, {:delete_before, timestamp})
  end

  @doc """
  Creates an index on a specific field for faster queries.
  """
  def create_index(storage \\ __MODULE__, field) do
    GenServer.call(storage, {:create_index, field})
  end

  @doc """
  Gets storage statistics.
  """
  def get_statistics(storage \\ __MODULE__) do
    GenServer.call(storage, :get_statistics)
  end

  ## GenServer Implementation

  @impl GenServer
  def init(config) do
    storage_path = config[:storage_path] || "data/audit"

    # Ensure storage directory exists
    File.mkdir_p!(storage_path)

    state = %__MODULE__{
      config: config,
      indexes: init_indexes(),
      storage_path: storage_path,
      current_file: init_current_file(storage_path),
      file_rotation: init_rotation_config(config),
      compression_enabled: Map.get(config, :compress_logs, true),
      search_index: init_search_index()
    }

    # Load existing indexes
    load_existing_indexes(state)

    # Schedule file rotation
    # Hourly
    :timer.send_interval(3_600_000, :rotate_file)

    Logger.info("Audit storage initialized at #{storage_path}")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:store_batch, events}, _from, state) do
    case store_events(events, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:query, filters, opts}, _from, state) do
    result = execute_query(filters, opts, state)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:get_range, start_time, end_time}, _from, state) do
    filters = %{start_time: start_time, end_time: end_time}
    result = execute_query(filters, [], state)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:delete_before, timestamp}, _from, state) do
    case delete_old_events(timestamp, state) do
      {:ok, count, new_state} ->
        {:reply, {:ok, count}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:create_index, field}, _from, state) do
    new_indexes = create_field_index(field, state.indexes)
    new_state = %{state | indexes: new_indexes}

    # Rebuild index for existing data
    rebuild_index(field, new_state)

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_statistics, _from, state) do
    stats = calculate_statistics(state)
    {:reply, {:ok, stats}, state}
  end

  @impl GenServer
  def handle_info(:rotate_file, state) do
    case rotate_log_file(state) do
      {:ok, new_state} -> {:noreply, new_state}
      {:error, _reason} -> {:noreply, state}
    end
  end

  ## Private Functions

  defp store_events(events, state) do
    # Update indexes
    new_indexes =
      Enum.reduce(events, state.indexes, fn event, acc_indexes ->
        update_indexes(event, acc_indexes)
      end)

    # Write to file
    case write_events_to_file(events, state) do
      :ok ->
        # Update search index
        new_search_index = update_search_index(events, state.search_index)

        new_state = %{
          state
          | indexes: new_indexes,
            search_index: new_search_index
        }

        {:ok, new_state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp write_events_to_file(events, state) do
    file_path = get_current_file_path(state)

    # Serialize events
    lines =
      Enum.map(events, fn event ->
        Jason.encode!(event) <> "\n"
      end)

    # Write to file
    case File.open(file_path, [:append, :binary]) do
      {:ok, file} ->
        try do
          Enum.each(lines, fn line ->
            IO.write(file, line)
          end)

          :ok
        after
          File.close(file)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute_query(filters, opts, state) do
    try do
      # Start with all events or use index if available
      base_events =
        if Map.has_key?(filters, :user_id) and
             Map.has_key?(state.indexes.user_id, filters.user_id) do
          get_events_by_ids(state.indexes.user_id[filters.user_id], state)
        else
          load_all_events(state)
        end

      # Apply filters
      filtered =
        base_events
        |> filter_by_time(filters)
        |> filter_by_severity(filters)
        |> filter_by_event_type(filters)
        |> filter_by_resource(filters)
        |> filter_by_text_search(filters, state)

      # Apply sorting
      sorted =
        sort_events(
          filtered,
          Keyword.get(opts, :sort_by, :timestamp),
          Keyword.get(opts, :sort_order, :desc)
        )

      # Apply pagination
      paginated =
        sorted
        |> Enum.drop(Keyword.get(opts, :offset, 0))
        |> Enum.take(Keyword.get(opts, :limit, 100))

      {:ok, paginated}
    rescue
      error ->
        Logger.error("Query execution failed: #{inspect(error)}")
        {:error, :query_failed}
    end
  end

  defp filter_by_time(events, %{start_time: start_time, end_time: end_time}) do
    Enum.filter(events, fn event ->
      event.timestamp >= start_time and event.timestamp <= end_time
    end)
  end

  defp filter_by_time(events, %{start_time: start_time}) do
    Enum.filter(events, &(&1.timestamp >= start_time))
  end

  defp filter_by_time(events, %{end_time: end_time}) do
    Enum.filter(events, &(&1.timestamp <= end_time))
  end

  defp filter_by_time(events, _), do: events

  defp filter_by_severity(events, %{severity: severity}) do
    Enum.filter(events, &(&1[:severity] == severity))
  end

  defp filter_by_severity(events, _), do: events

  defp filter_by_event_type(events, %{event_type: type}) do
    Enum.filter(events, &(&1[:event_type] == type))
  end

  defp filter_by_event_type(events, _), do: events

  defp filter_by_resource(events, %{resource_type: type, resource_id: id}) do
    Enum.filter(events, fn event ->
      Map.get(event, :resource_type) == type and
        Map.get(event, :resource_id) == id
    end)
  end

  defp filter_by_resource(events, %{resource_type: type}) do
    Enum.filter(events, &(Map.get(&1, :resource_type) == type))
  end

  defp filter_by_resource(events, _), do: events

  defp filter_by_text_search(events, %{text_search: query}, state) do
    # Use search index for full-text search
    matching_ids = search_in_index(query, state.search_index)
    Enum.filter(events, &(&1.event_id in matching_ids))
  end

  defp filter_by_text_search(events, _, _), do: events

  defp sort_events(events, field, order) do
    Enum.sort_by(events, &Map.get(&1, field), order)
  end

  defp delete_old_events(timestamp, state) do
    # Load all events
    all_events = load_all_events(state)

    # Separate events to keep and delete
    {to_delete, to_keep} =
      Enum.split_with(all_events, &(&1.timestamp < timestamp))

    # Rewrite file with events to keep
    case rewrite_events_file(to_keep, state) do
      :ok ->
        # Update indexes
        new_indexes = rebuild_all_indexes(to_keep)
        new_state = %{state | indexes: new_indexes}

        {:ok, length(to_delete), new_state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp rotate_log_file(state) do
    current_file = get_current_file_path(state)

    if File.exists?(current_file) do
      # Generate archive name
      timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
      archive_name = "#{current_file}.#{timestamp}"

      # Rename current file
      File.rename!(current_file, archive_name)

      # Compress if enabled
      if state.compression_enabled do
        Task.start(fn -> compress_file(archive_name) end)
      end

      # Update state with new file
      {:ok, %{state | current_file: init_current_file(state.storage_path)}}
    else
      {:ok, state}
    end
  end

  defp compress_file(file_path) do
    compressed_path = "#{file_path}.gz"

    case :zlib.gzip(File.read!(file_path)) do
      compressed when is_binary(compressed) ->
        File.write!(compressed_path, compressed)
        File.rm!(file_path)
        Logger.info("Compressed audit log: #{compressed_path}")

      _ ->
        Logger.error("Failed to compress audit log: #{file_path}")
    end
  end

  defp load_all_events(state) do
    file_pattern = Path.join(state.storage_path, "audit*.log")

    Path.wildcard(file_pattern)
    |> Enum.flat_map(&load_events_from_file/1)
  end

  defp load_events_from_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n", trim: true)
        |> Enum.map(&decode_event/1)
        |> Enum.filter(&(&1 != nil))

      {:error, _} ->
        []
    end
  end

  defp decode_event(line) do
    case Jason.decode(line, keys: :atoms) do
      {:ok, event} -> event
      {:error, _} -> nil
    end
  end

  defp get_events_by_ids(ids, state) do
    all_events = load_all_events(state)
    Enum.filter(all_events, &(&1.event_id in ids))
  end

  defp rewrite_events_file(events, state) do
    file_path = get_current_file_path(state)
    temp_path = "#{file_path}.tmp"

    # Write to temp file
    lines =
      Enum.map(events, fn event ->
        Jason.encode!(event) <> "\n"
      end)

    File.write!(temp_path, lines)

    # Atomic rename
    File.rename!(temp_path, file_path)
    :ok
  end

  defp init_indexes do
    %{
      user_id: %{},
      session_id: %{},
      resource_id: %{},
      severity: %{},
      event_type: %{}
    }
  end

  defp update_indexes(event, indexes) do
    indexes
    |> update_index(:user_id, event)
    |> update_index(:session_id, event)
    |> update_index(:resource_id, event)
    |> update_index(:severity, event)
    |> update_index(:event_type, event)
  end

  defp update_index(indexes, field, event) do
    case Map.get(event, field) do
      nil ->
        indexes

      value ->
        field_index = Map.get(indexes, field, %{})
        event_ids = MapSet.new([event.event_id])

        updated_field_index =
          Map.update(field_index, value, event_ids, fn existing ->
            MapSet.put(existing, event.event_id)
          end)

        Map.put(indexes, field, updated_field_index)
    end
  end

  defp create_field_index(field, indexes) do
    Map.put_new(indexes, field, %{})
  end

  defp rebuild_index(field, state) do
    all_events = load_all_events(state)

    new_index =
      Enum.reduce(all_events, %{}, fn event, acc ->
        case Map.get(event, field) do
          nil ->
            acc

          value ->
            Map.update(acc, value, MapSet.new([event.event_id]), fn existing ->
              MapSet.put(existing, event.event_id)
            end)
        end
      end)

    put_in(state.indexes[field], new_index)
  end

  defp rebuild_all_indexes(events) do
    Enum.reduce(events, init_indexes(), fn event, acc ->
      update_indexes(event, acc)
    end)
  end

  defp init_search_index do
    # Simple inverted index for text search
    %{terms: %{}}
  end

  defp update_search_index(events, search_index) do
    Enum.reduce(events, search_index, fn event, acc ->
      terms = extract_searchable_terms(event)

      Enum.reduce(terms, acc, fn term, acc_index ->
        put_in(
          acc_index,
          [:terms, term],
          MapSet.put(
            get_in(acc_index, [:terms, term]) || MapSet.new(),
            event.event_id
          )
        )
      end)
    end)
  end

  defp extract_searchable_terms(event) do
    # Extract searchable text from event
    text_fields = [
      Map.get(event, :description),
      Map.get(event, :command),
      Map.get(event, :error_message),
      Map.get(event, :denial_reason)
    ]

    text_fields
    |> Enum.filter(&(&1 != nil))
    |> Enum.flat_map(&String.split(&1, ~r/\W+/))
    |> Enum.map(&String.downcase/1)
    |> Enum.filter(&(String.length(&1) > 2))
    |> Enum.uniq()
  end

  defp search_in_index(query, search_index) do
    terms =
      query
      |> String.downcase()
      |> String.split(~r/\W+/)
      |> Enum.filter(&(String.length(&1) > 2))

    # Find events matching all terms
    Enum.reduce(terms, nil, fn term, acc ->
      matching = get_in(search_index, [:terms, term]) || MapSet.new()

      if acc == nil do
        matching
      else
        MapSet.intersection(acc, matching)
      end
    end) || MapSet.new()
  end

  defp init_current_file(storage_path) do
    date = Date.utc_today() |> Date.to_iso8601()
    Path.join(storage_path, "audit_#{date}.log")
  end

  defp get_current_file_path(state) do
    state.current_file || init_current_file(state.storage_path)
  end

  defp init_rotation_config(config) do
    %{
      # 100MB
      max_file_size: Map.get(config, :max_file_size, 100_000_000),
      rotation_period: Map.get(config, :rotation_period, :daily),
      keep_files: Map.get(config, :keep_files, 365)
    }
  end

  defp load_existing_indexes(state) do
    index_file = Path.join(state.storage_path, "indexes.dat")

    if File.exists?(index_file) do
      case File.read(index_file) do
        {:ok, binary} ->
          try do
            indexes = :erlang.binary_to_term(binary)
            %{state | indexes: indexes}
          rescue
            _ -> state
          end

        _ ->
          state
      end
    else
      state
    end
  end

  defp calculate_statistics(state) do
    all_events = load_all_events(state)

    %{
      total_events: length(all_events),
      storage_size_bytes: calculate_storage_size(state),
      indexed_fields: Map.keys(state.indexes),
      file_count:
        length(Path.wildcard(Path.join(state.storage_path, "*.log*"))),
      compression_enabled: state.compression_enabled,
      oldest_event: find_oldest_event(all_events),
      newest_event: find_newest_event(all_events)
    }
  end

  defp calculate_storage_size(state) do
    Path.wildcard(Path.join(state.storage_path, "*"))
    |> Enum.map(&File.stat!/1)
    |> Enum.map(& &1.size)
    |> Enum.sum()
  end

  defp find_oldest_event([]), do: nil

  defp find_oldest_event(events) do
    Enum.min_by(events, & &1.timestamp)
  end

  defp find_newest_event([]), do: nil

  defp find_newest_event(events) do
    Enum.max_by(events, & &1.timestamp)
  end
end

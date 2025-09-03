defmodule Raxol.Audit.Storage do
  @moduledoc """
  Functional version of the specialized storage backend for audit logs with indexing and search capabilities.

  This module provides efficient storage and retrieval of audit events with
  support for complex queries, full-text search, and compliance reporting,
  using pure functional error handling patterns instead of try/catch blocks.
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
  def query(filters, opts \\ []) do
    GenServer.call(__MODULE__, {:query, filters, opts}, 30_000)
  end

  @doc """
  Queries audit events with filters and options from a specific storage.
  """
  def query(storage, filters, opts) when is_atom(storage) or is_pid(storage) do
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

    # Write to file using functional approach
    with {:ok, file} <- File.open(file_path, [:append, :binary]),
         :ok <- safe_write_lines(file, lines),
         :ok <- File.close(file) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp safe_write_lines(file, lines) do
    # Use Task to safely write lines with timeout
    task =
      Task.async(fn ->
        Enum.each(lines, fn line ->
          IO.write(file, line)
        end)

        :ok
      end)

    case Task.yield(task, 5000) || Task.shutdown(task) do
      {:ok, :ok} -> :ok
      nil -> {:error, :write_timeout}
      {:exit, reason} -> {:error, {:write_failed, reason}}
    end
  end

  defp execute_query(filters, opts, state) do
    # Functional approach to query execution
    with {:ok, base_events} <- get_base_events(filters, state),
         {:ok, filtered} <- apply_filters(base_events, filters, state),
         {:ok, sorted} <- safe_sort_events(filtered, opts),
         {:ok, paginated} <- apply_pagination(sorted, opts) do
      {:ok, paginated}
    else
      {:error, reason} ->
        Logger.error("Query execution failed: #{inspect(reason)}")
        {:error, :query_failed}
    end
  end

  defp get_base_events(filters, state) do
    task =
      Task.async(fn ->
        if Map.has_key?(filters, :user_id) and
             Map.has_key?(state.indexes.user_id, filters.user_id) do
          get_events_by_ids(state.indexes.user_id[filters.user_id], state)
        else
          load_all_events(state)
        end
      end)

    case Task.yield(task, 10000) || Task.shutdown(task) do
      {:ok, events} -> {:ok, events}
      nil -> {:error, :load_events_timeout}
      {:exit, reason} -> {:error, {:load_events_failed, reason}}
    end
  end

  defp apply_filters(events, filters, state) do
    task =
      Task.async(fn ->
        events
        |> filter_by_time(filters)
        |> filter_by_severity(filters)
        |> filter_by_event_type(filters)
        |> filter_by_resource(filters)
        |> filter_by_session_id(filters)
        |> filter_by_text_search(filters, state)
      end)

    case Task.yield(task, 5000) || Task.shutdown(task) do
      {:ok, filtered} -> {:ok, filtered}
      nil -> {:error, :filter_timeout}
      {:exit, reason} -> {:error, {:filter_failed, reason}}
    end
  end

  defp safe_sort_events(events, opts) do
    task =
      Task.async(fn ->
        sort_events(
          events,
          Keyword.get(opts, :sort_by, :timestamp),
          Keyword.get(opts, :sort_order, :desc)
        )
      end)

    case Task.yield(task, 3000) || Task.shutdown(task) do
      {:ok, sorted} -> {:ok, sorted}
      # Return unsorted on timeout
      nil -> {:ok, events}
      # Return unsorted on error
      {:exit, _reason} -> {:ok, events}
    end
  end

  defp apply_pagination(events, opts) do
    task =
      Task.async(fn ->
        events
        |> Enum.drop(Keyword.get(opts, :offset, 0))
        |> Enum.take(Keyword.get(opts, :limit, 100))
      end)

    case Task.yield(task, 1000) || Task.shutdown(task) do
      {:ok, paginated} -> {:ok, paginated}
      # Return first 100 on timeout
      nil -> {:ok, Enum.take(events, 100)}
      {:exit, _reason} -> {:ok, Enum.take(events, 100)}
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
    # Handle both atom and string comparisons
    Enum.filter(events, fn event ->
      event_severity = event[:severity]

      event_severity == severity or
        event_severity == to_string(severity) or
        (is_binary(event_severity) and
           safe_string_to_atom(event_severity) == severity)
    end)
  end

  defp filter_by_severity(events, _), do: events

  defp filter_by_event_type(events, %{event_type: type}) do
    # Handle both atom and string comparisons
    Enum.filter(events, fn event ->
      event_type = event[:event_type]

      event_type == type or
        event_type == to_string(type) or
        (is_binary(event_type) and safe_string_to_atom(event_type) == type)
    end)
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

  defp filter_by_session_id(events, %{session_id: session_id}) do
    Enum.filter(events, &(Map.get(&1, :session_id) == session_id))
  end

  defp filter_by_session_id(events, _), do: events

  defp filter_by_text_search(events, %{text_search: query}, state) do
    # Try search index first
    matching_ids =
      query
      |> search_in_index(state.search_index)
      |> MapSet.to_list()

    indexed_results = Enum.filter(events, &(&1.event_id in matching_ids))

    # Fallback to direct text search if index returns no results
    if Enum.empty?(indexed_results) do
      query_lower = String.downcase(query)

      Enum.filter(events, fn event ->
        searchable_text =
          [
            Map.get(event, :description, ""),
            Map.get(event, :command, ""),
            Map.get(event, :error_message, ""),
            Map.get(event, :denial_reason, "")
          ]
          |> Enum.join(" ")
          |> String.downcase()

        String.contains?(searchable_text, query_lower)
      end)
    else
      indexed_results
    end
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
      {:ok, event} ->
        # Convert common string values to atoms for consistency
        event
        |> convert_value(:event_type)
        |> convert_value(:severity)
        |> convert_value(:outcome)

      {:error, _} ->
        nil
    end
  end

  defp convert_value(event, key) do
    case Map.get(event, key) do
      value when is_binary(value) ->
        with atom <- safe_string_to_atom(value) do
          if atom != nil do
            Map.put(event, key, atom)
          else
            event
          end
        end

      _ ->
        event
    end
  end

  defp safe_string_to_atom(string) when is_binary(string) do
    # Safe conversion without try/catch
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           String.to_existing_atom(string)
         end) do
      {:ok, result} -> result
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
      with {:ok, binary} <- File.read(index_file),
           {:ok, indexes} <- safe_binary_to_term(binary) do
        %{state | indexes: indexes}
      else
        _ -> state
      end
    else
      state
    end
  end

  defp safe_binary_to_term(binary) do
    # Safe deserialization with Task timeout
    task =
      Task.async(fn ->
        :erlang.binary_to_term(binary)
      end)

    case Task.yield(task, 1000) || Task.shutdown(task) do
      {:ok, term} -> {:ok, term}
      _ -> {:error, :deserialize_failed}
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

defmodule Raxol.Storage.EventStorage do
  @moduledoc """
  Storage interface for event sourcing system.

  This module defines the behavior for event storage implementations
  and provides a unified interface for storing and retrieving events.
  """

  alias Raxol.Architecture.EventSourcing.{Event, EventStream}

  @type event :: Event.t()
  @type stream_name :: String.t()
  @type position :: non_neg_integer()
  @type version :: non_neg_integer()

  @callback append_event(
              storage :: term(),
              event :: event(),
              stream_name :: stream_name()
            ) ::
              {:ok, String.t()} | {:error, term()}

  @callback append_events(
              storage :: term(),
              events :: [event()],
              stream_name :: stream_name()
            ) ::
              {:ok, [String.t()]} | {:error, term()}

  @callback read_stream(
              storage :: term(),
              stream_name :: stream_name(),
              start_position :: position(),
              count :: pos_integer()
            ) ::
              {:ok, [event()]} | {:error, term()}

  @callback read_all(
              storage :: term(),
              start_position :: position(),
              count :: pos_integer()
            ) ::
              {:ok, [event()]} | {:error, term()}

  @callback list_streams(storage :: term()) ::
              {:ok, [EventStream.t()]} | {:error, term()}

  @callback save_snapshot(storage :: term(), snapshot :: term()) ::
              :ok | {:error, term()}

  @callback load_snapshot(storage :: term(), stream_name :: stream_name()) ::
              {:ok, term()} | {:error, term()}

  # Default implementation delegation functions

  @doc """
  Appends an event to the specified stream.
  """
  def append_event(storage, event, stream_name) do
    case storage do
      pid when is_pid(pid) ->
        GenServer.call(pid, {:append_event, event, stream_name})

      module when is_atom(module) ->
        module.append_event(module, event, stream_name)

      _ ->
        {:error, :invalid_storage}
    end
  end

  @doc """
  Appends multiple events to the specified stream.
  """
  def append_events(storage, events, stream_name) do
    case storage do
      pid when is_pid(pid) ->
        GenServer.call(pid, {:append_events, events, stream_name})

      module when is_atom(module) ->
        module.append_events(module, events, stream_name)

      _ ->
        {:error, :invalid_storage}
    end
  end

  @doc """
  Reads events from a specific stream.
  """
  def read_stream(storage, stream_name, start_position, count) do
    case storage do
      pid when is_pid(pid) ->
        GenServer.call(pid, {:read_stream, stream_name, start_position, count})

      module when is_atom(module) ->
        module.read_stream(module, stream_name, start_position, count)

      _ ->
        {:error, :invalid_storage}
    end
  end

  @doc """
  Reads all events across all streams.
  """
  def read_all(storage, start_position, count) do
    case storage do
      pid when is_pid(pid) ->
        GenServer.call(pid, {:read_all, start_position, count})

      module when is_atom(module) ->
        module.read_all(module, start_position, count)

      _ ->
        {:error, :invalid_storage}
    end
  end

  @doc """
  Lists all available streams.
  """
  def list_streams(storage) do
    case storage do
      pid when is_pid(pid) ->
        GenServer.call(pid, :list_streams)

      module when is_atom(module) ->
        module.list_streams(module)

      _ ->
        {:error, :invalid_storage}
    end
  end

  @doc """
  Saves a snapshot for a stream.
  """
  def save_snapshot(storage, snapshot) do
    case storage do
      pid when is_pid(pid) ->
        GenServer.call(pid, {:save_snapshot, snapshot})

      module when is_atom(module) ->
        module.save_snapshot(module, snapshot)

      _ ->
        {:error, :invalid_storage}
    end
  end

  @doc """
  Loads the latest snapshot for a stream.
  """
  def load_snapshot(storage, stream_name) do
    case storage do
      pid when is_pid(pid) ->
        GenServer.call(pid, {:load_snapshot, stream_name})

      module when is_atom(module) ->
        module.load_snapshot(module, stream_name)

      _ ->
        {:error, :invalid_storage}
    end
  end
end

defmodule Raxol.Storage.EventStorage.Memory do
  @moduledoc """
  In-memory event storage implementation for development and testing.
  """

  @behaviour Raxol.Storage.EventStorage

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Architecture.EventSourcing.{Event, EventStream}

  defstruct [
    :events,
    :streams,
    :snapshots,
    :global_position,
    :config
  ]

  ## Client API

  #  def start_link(opts \\ []) do
  #    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  #  end

  @impl Raxol.Storage.EventStorage
  def append_event(storage \\ __MODULE__, event, stream_name) do
    GenServer.call(storage, {:append_event, event, stream_name})
  end

  @impl Raxol.Storage.EventStorage
  def append_events(storage \\ __MODULE__, events, stream_name) do
    GenServer.call(storage, {:append_events, events, stream_name})
  end

  @impl Raxol.Storage.EventStorage
  def read_stream(storage \\ __MODULE__, stream_name, start_position, count) do
    GenServer.call(storage, {:read_stream, stream_name, start_position, count})
  end

  @impl Raxol.Storage.EventStorage
  def read_all(storage \\ __MODULE__, start_position, count) do
    GenServer.call(storage, {:read_all, start_position, count})
  end

  @impl Raxol.Storage.EventStorage
  def list_streams(storage \\ __MODULE__) do
    GenServer.call(storage, :list_streams)
  end

  @impl Raxol.Storage.EventStorage
  def save_snapshot(storage \\ __MODULE__, snapshot) do
    GenServer.call(storage, {:save_snapshot, snapshot})
  end

  @impl Raxol.Storage.EventStorage
  def load_snapshot(storage \\ __MODULE__, stream_name) do
    GenServer.call(storage, {:load_snapshot, stream_name})
  end

  ## GenServer Implementation

  @impl true
  def init_manager(_opts) do
    state = %__MODULE__{
      events: [],
      streams: %{},
      snapshots: %{},
      global_position: 0,
      config: %{}
    }

    Log.info("Memory event storage initialized")
    {:ok, state}
  end

  @impl true
  def handle_manager_call({:append_event, event, stream_name}, _from, state) do
    # do_append_event/3 always returns {:ok, event_id, new_state}, no error case possible
    {:ok, event_id, new_state} = do_append_event(event, stream_name, state)
    {:reply, {:ok, event_id}, new_state}
  end

  @impl true
  def handle_manager_call({:append_events, events, stream_name}, _from, state) do
    case do_append_events(events, stream_name, state) do
      {:ok, event_ids, new_state} ->
        {:reply, {:ok, event_ids}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call(
        {:read_stream, stream_name, start_position, count},
        _from,
        state
      ) do
    events =
      state.events
      |> Enum.filter(fn event -> event.stream_name == stream_name end)
      |> Enum.filter(fn event -> event.position >= start_position end)
      |> Enum.sort_by(& &1.position)
      |> Enum.take(count)

    {:reply, {:ok, events}, state}
  end

  @impl true
  def handle_manager_call({:read_all, start_position, count}, _from, state) do
    events =
      state.events
      |> Enum.filter(fn event -> event.position >= start_position end)
      |> Enum.sort_by(& &1.position)
      |> Enum.take(count)

    {:reply, {:ok, events}, state}
  end

  @impl true
  def handle_manager_call(:list_streams, _from, state) do
    streams = Map.values(state.streams)
    {:reply, {:ok, streams}, state}
  end

  @impl true
  def handle_manager_call({:save_snapshot, snapshot}, _from, state) do
    new_snapshots = Map.put(state.snapshots, snapshot.stream_name, snapshot)
    new_state = %{state | snapshots: new_snapshots}

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call({:load_snapshot, stream_name}, _from, state) do
    case Map.get(state.snapshots, stream_name) do
      nil -> {:reply, {:error, :not_found}, state}
      snapshot -> {:reply, {:ok, snapshot}, state}
    end
  end

  ## Private Implementation

  defp do_append_event(event, stream_name, state) do
    # Assign global position and stream position
    global_position = state.global_position + 1
    stream = get_or_create_stream(stream_name, state.streams)
    stream_position = stream.last_position + 1

    # Create the stored event
    stored_event = %{
      event
      | position: global_position,
        metadata:
          Map.put(event.metadata || %{}, :stream_position, stream_position)
    }

    # Update state
    new_events = [stored_event | state.events]

    updated_stream = %{
      stream
      | version: stream.version + 1,
        last_position: stream_position,
        last_event_at: System.system_time(:millisecond)
    }

    new_streams = Map.put(state.streams, stream_name, updated_stream)

    new_state = %{
      state
      | events: new_events,
        streams: new_streams,
        global_position: global_position
    }

    {:ok, stored_event.id, new_state}
  end

  defp do_append_events(events, stream_name, state) do
    case events do
      [] ->
        {:ok, [], state}

      _ ->
        # Process all events in batch - Memory.do_append_event/3 never returns errors
        Raxol.Core.ErrorHandling.safe_call(fn ->
          process_event_batch(events, stream_name, state)
        end)
        |> case do
          {:ok, result} -> result
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp get_or_create_stream(stream_name, streams) do
    Map.get(streams, stream_name, %EventStream{
      name: stream_name,
      version: 0,
      last_position: 0,
      created_at: System.system_time(:millisecond),
      last_event_at: nil,
      metadata: %{}
    })
  end

  defp append_event_to_accumulator(event, stream_name, {acc_ids, acc_state}) do
    {:ok, event_id, new_state} = do_append_event(event, stream_name, acc_state)
    {[event_id | acc_ids], new_state}
  end

  defp process_event_batch(events, stream_name, state) do
    {event_ids, final_state} =
      Enum.reduce(events, {[], state}, fn event, acc ->
        append_event_to_accumulator(event, stream_name, acc)
      end)

    {:ok, Enum.reverse(event_ids), final_state}
  end
end

defmodule Raxol.Storage.EventStorage.Disk do
  @moduledoc """
  Disk-based event storage implementation for production use.
  """

  @behaviour Raxol.Storage.EventStorage

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Architecture.EventSourcing.{Event, EventStream}
  alias Raxol.Core.Runtime.Log

  defstruct [
    :config,
    :data_directory,
    :streams_index,
    :global_position,
    :file_handles
  ]

  # @default_config %{
  #   data_directory: "priv/data/events",
  #   # 100MB
  #   max_file_size: 100_000_000,
  #   compression_enabled: true,
  #   fsync_every_write: false
  # }

  ## Client API

  #  def start_link(opts \\ []) do
  #    config =
  #      Keyword.get(opts, :config, %{})
  #      |> then(&Map.merge(@default_config, &1))
  #
  #    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  #  end

  @impl Raxol.Storage.EventStorage
  def append_event(storage \\ __MODULE__, event, stream_name) do
    GenServer.call(storage, {:append_event, event, stream_name})
  end

  @impl Raxol.Storage.EventStorage
  def append_events(storage \\ __MODULE__, events, stream_name) do
    GenServer.call(storage, {:append_events, events, stream_name})
  end

  @impl Raxol.Storage.EventStorage
  def read_stream(storage \\ __MODULE__, stream_name, start_position, count) do
    GenServer.call(storage, {:read_stream, stream_name, start_position, count})
  end

  @impl Raxol.Storage.EventStorage
  def read_all(storage \\ __MODULE__, start_position, count) do
    GenServer.call(storage, {:read_all, start_position, count})
  end

  @impl Raxol.Storage.EventStorage
  def list_streams(storage \\ __MODULE__) do
    GenServer.call(storage, :list_streams)
  end

  @impl Raxol.Storage.EventStorage
  def save_snapshot(storage \\ __MODULE__, snapshot) do
    GenServer.call(storage, {:save_snapshot, snapshot})
  end

  @impl Raxol.Storage.EventStorage
  def load_snapshot(storage \\ __MODULE__, stream_name) do
    GenServer.call(storage, {:load_snapshot, stream_name})
  end

  ## GenServer Implementation

  @impl true
  def init_manager(config) do
    data_dir = config.data_directory

    # Ensure data directory exists
    case File.mkdir_p(data_dir) do
      :ok ->
        Log.info("Disk event storage initialized at #{data_dir}")

        # Load existing streams index
        streams_index = load_streams_index(data_dir)
        global_position = calculate_global_position(streams_index)

        state = %__MODULE__{
          config: config,
          data_directory: data_dir,
          streams_index: streams_index,
          global_position: global_position,
          file_handles: %{}
        }

        {:ok, state}

      {:error, reason} ->
        Log.error(
          "Failed to create data directory #{data_dir}: #{inspect(reason)}"
        )

        {:stop, {:data_directory_creation_failed, reason}}
    end
  end

  @impl true
  def handle_manager_call({:append_event, event, stream_name}, _from, state) do
    case do_append_event(event, stream_name, state) do
      {:ok, event_id, new_state} ->
        {:reply, {:ok, event_id}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call({:append_events, events, stream_name}, _from, state) do
    case do_append_events(events, stream_name, state) do
      {:ok, event_ids, new_state} ->
        {:reply, {:ok, event_ids}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call(
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

  @impl true
  def handle_manager_call({:read_all, start_position, count}, _from, state) do
    {:ok, events} = read_all_events(start_position, count, state)
    {:reply, {:ok, events}, state}
  end

  @impl true
  def handle_manager_call(:list_streams, _from, state) do
    streams = Map.values(state.streams_index)
    {:reply, {:ok, streams}, state}
  end

  @impl true
  def handle_manager_call({:save_snapshot, snapshot}, _from, state) do
    case write_snapshot_to_disk(snapshot, state) do
      :ok ->
        {:reply, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call({:load_snapshot, stream_name}, _from, state) do
    case read_snapshot_from_disk(stream_name, state) do
      {:ok, snapshot} ->
        {:reply, {:ok, snapshot}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    # Close all file handles
    Enum.each(state.file_handles, fn {_stream, handle} ->
      File.close(handle)
    end)

    :ok
  end

  ## Private Implementation

  defp do_append_event(event, stream_name, state) do
    # Assign positions
    global_position = state.global_position + 1
    stream = get_or_create_stream(stream_name, state.streams_index)
    stream_position = stream.last_position + 1

    # Create stored event
    stored_event = %{
      event
      | position: global_position,
        metadata:
          Map.put(event.metadata || %{}, :stream_position, stream_position)
    }

    # Write to disk
    case write_event_to_disk(stored_event, stream_name, state) do
      :ok ->
        # Update streams index
        updated_stream = %{
          stream
          | version: stream.version + 1,
            last_position: stream_position,
            last_event_at: System.system_time(:millisecond)
        }

        new_streams_index =
          Map.put(state.streams_index, stream_name, updated_stream)

        # Update state
        new_state = %{
          state
          | streams_index: new_streams_index,
            global_position: global_position
        }

        # Persist streams index
        case persist_streams_index(new_streams_index, state) do
          :ok ->
            {:ok, stored_event.id, new_state}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_append_events(events, stream_name, state) when is_list(events) do
    case events do
      [] ->
        {:ok, [], state}

      _ ->
        # Process all events in batch using functional error handling
        Raxol.Core.ErrorHandling.safe_call(fn ->
          process_event_batch_with_errors(events, stream_name, state)
        end)
        |> case do
          {:ok, result} -> result
          {:error, {:throw, {:error, reason}}} -> {:error, reason}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp write_event_to_disk(event, stream_name, state) do
    file_path = stream_file_path(stream_name, state.data_directory)

    event_data = Event.to_json(event)

    case event_data do
      {:ok, json} ->
        line = json <> "\n"
        File.write(file_path, line, [:append])

      {:error, reason} ->
        {:error, {:json_encoding_failed, reason}}
    end
  end

  defp read_stream_events(stream_name, start_position, count, state) do
    file_path = stream_file_path(stream_name, state.data_directory)

    case File.exists?(file_path) do
      true ->
        case File.read(file_path) do
          {:ok, content} ->
            events =
              content
              |> String.split("\n", trim: true)
              |> Enum.map(&parse_event_json/1)
              |> Enum.filter(&filter_ok/1)
              |> Enum.map(&elem(&1, 1))
              |> Enum.filter(&filter_by_position(&1, start_position))
              |> Enum.take(count)

            {:ok, events}

          {:error, reason} ->
            {:error, reason}
        end

      false ->
        {:ok, []}
    end
  end

  defp read_all_events(start_position, count, state) do
    # This is a simplified implementation - in production you'd want
    # better indexing and streaming for large datasets
    all_events =
      state.streams_index
      |> Map.keys()
      |> Enum.flat_map(fn stream_name ->
        case read_stream_events(stream_name, 0, 100_000, state) do
          {:ok, events} -> events
          {:error, _} -> []
        end
      end)
      |> Enum.filter(fn event -> event.position >= start_position end)
      |> Enum.sort_by(& &1.position)
      |> Enum.take(count)

    {:ok, all_events}
  end

  defp write_snapshot_to_disk(snapshot, state) do
    file_path = snapshot_file_path(snapshot.stream_name, state.data_directory)

    case :erlang.term_to_binary(snapshot) do
      binary_data ->
        File.write(file_path, binary_data)
    end
  end

  defp read_snapshot_from_disk(stream_name, state) do
    file_path = snapshot_file_path(stream_name, state.data_directory)

    case File.read(file_path) do
      {:ok, binary_data} ->
        Raxol.Core.ErrorHandling.safe_call(fn ->
          snapshot = :erlang.binary_to_term(binary_data)
          {:ok, snapshot}
        end)
        |> case do
          {:ok, result} -> result
          {:error, _} -> {:error, :corrupt_snapshot}
        end

      {:error, :enoent} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_or_create_stream(stream_name, streams_index) do
    Map.get(streams_index, stream_name, %EventStream{
      name: stream_name,
      version: 0,
      last_position: 0,
      created_at: System.system_time(:millisecond),
      last_event_at: nil,
      metadata: %{}
    })
  end

  defp load_streams_index(data_dir) do
    index_file = Path.join(data_dir, "streams.index")

    case File.read(index_file) do
      {:ok, binary_data} ->
        Raxol.Core.ErrorHandling.safe_call_with_default(
          fn ->
            :erlang.binary_to_term(binary_data)
          end,
          %{}
        )

      {:error, :enoent} ->
        %{}

      {:error, _reason} ->
        %{}
    end
  end

  defp persist_streams_index(streams_index, state) do
    index_file = Path.join(state.data_directory, "streams.index")
    binary_data = :erlang.term_to_binary(streams_index)

    File.write(index_file, binary_data)
  end

  defp calculate_global_position(streams_index) do
    streams_index
    |> Map.values()
    |> Enum.map(& &1.last_position)
    |> Enum.max(fn -> 0 end)
  end

  defp stream_file_path(stream_name, data_dir) do
    safe_name = String.replace(stream_name, ~r/[^a-zA-Z0-9_-]/, "_")
    Path.join(data_dir, "#{safe_name}.events")
  end

  defp snapshot_file_path(stream_name, data_dir) do
    safe_name = String.replace(stream_name, ~r/[^a-zA-Z0-9_-]/, "_")
    snapshots_dir = Path.join(data_dir, "snapshots")
    _ = File.mkdir_p(snapshots_dir)
    Path.join(snapshots_dir, "#{safe_name}.snapshot")
  end

  defp parse_event_json(json) do
    case Jason.decode(json, keys: :atoms) do
      {:ok, data} -> Event.from_map(data)
      {:error, reason} -> {:error, reason}
    end
  end

  defp filter_ok({:ok, _}), do: true
  defp filter_ok(_), do: false

  defp append_event_with_error_check(event, stream_name, {acc_ids, acc_state}) do
    case do_append_event(event, stream_name, acc_state) do
      {:ok, event_id, new_state} ->
        {[event_id | acc_ids], new_state}

      {:error, reason} ->
        throw({:error, reason})
    end
  end

  defp filter_by_position(event, start_position) do
    stream_position = get_in(event.metadata, [:stream_position]) || 0
    stream_position >= start_position
  end

  defp process_event_batch_with_errors(events, stream_name, state) do
    {event_ids, final_state} =
      Enum.reduce(events, {[], state}, fn event, acc ->
        append_event_with_error_check(event, stream_name, acc)
      end)

    {:ok, Enum.reverse(event_ids), final_state}
  end
end

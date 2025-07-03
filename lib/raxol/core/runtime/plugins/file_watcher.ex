defmodule Raxol.Core.Runtime.Plugins.FileWatcher do
  @moduledoc """
  Manages file watching operations for plugins.
  """

  use GenServer
  require Logger
  import Raxol.Guards

  @behaviour Raxol.Core.Runtime.Plugins.FileWatcherBehaviour

  defstruct [
    :watched_files,
    :event_queue,
    :debounce_interval,
    :last_event_time,
    :callback
  ]

  @type t :: %__MODULE__{
          watched_files: map(),
          event_queue: list(map()),
          debounce_interval: integer(),
          last_event_time: integer(),
          callback: function()
        }

  # Client API

  @doc """
  Starts the file watcher.
  """
  @impl Raxol.Core.Runtime.Plugins.FileWatcherBehaviour
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Stops the file watcher.
  """
  @impl Raxol.Core.Runtime.Plugins.FileWatcherBehaviour
  def stop(pid) do
    GenServer.stop(pid)
  end

  @doc """
  Adds a file to watch.
  """
  @impl Raxol.Core.Runtime.Plugins.FileWatcherBehaviour
  def watch_file(pid, file_path, callback)
      when binary?(file_path) and function?(callback, 1) do
    GenServer.call(pid, {:watch_file, file_path, callback})
  end

  @doc """
  Removes a file from watching.
  """
  @impl Raxol.Core.Runtime.Plugins.FileWatcherBehaviour
  def unwatch_file(pid, file_path) when binary?(file_path) do
    GenServer.call(pid, {:unwatch_file, file_path})
  end

  @doc """
  Gets the list of watched files.
  """
  @impl Raxol.Core.Runtime.Plugins.FileWatcherBehaviour
  def get_watched_files(pid) do
    GenServer.call(pid, :get_watched_files)
  end

  @doc """
  Sets up file watching for a directory.
  """
  @impl Raxol.Core.Runtime.Plugins.FileWatcherBehaviour
  def setup_file_watching(pid) do
    GenServer.call(pid, :setup_file_watching)
  end

  # Server Callbacks

  @impl GenServer
  def init(opts) do
    state = %__MODULE__{
      watched_files: %{},
      event_queue: [],
      debounce_interval: Keyword.get(opts, :debounce_interval, 100),
      last_event_time: System.monotonic_time(),
      callback: Keyword.get(opts, :callback, fn _ -> :ok end)
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:watch_file, file_path, callback}, _from, state) do
    case File.exists?(file_path) do
      true ->
        new_state = %{
          state
          | watched_files: Map.put(state.watched_files, file_path, callback)
        }

        {:reply, :ok, new_state}

      false ->
        {:reply, {:error, :file_not_found}, state}
    end
  end

  @impl GenServer
  def handle_call({:unwatch_file, file_path}, _from, state) do
    new_state = %{
      state
      | watched_files: Map.delete(state.watched_files, file_path)
    }

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_watched_files, _from, state) do
    {:reply, Map.keys(state.watched_files), state}
  end

  @impl GenServer
  def handle_call(:setup_file_watching, _from, state) do
    # Implementation would depend on the file watching library being used
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_info({:file_event, file_path, event}, state) do
    new_state = handle_file_event(state, file_path, event)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(:process_events, state) do
    new_state = process_events(state)
    {:noreply, new_state}
  end

  # Private Functions

  defp handle_file_event(state, file_path, event) do
    case Map.get(state.watched_files, file_path) do
      nil ->
        state

      _callback ->
        event_data = %{
          path: file_path,
          event: event,
          timestamp: System.monotonic_time()
        }

        new_queue = [event_data | state.event_queue]
        schedule_event_processing(state.debounce_interval)
        %{state | event_queue: new_queue}
    end
  end

  defp process_events(state) do
    now = System.monotonic_time()

    if now - state.last_event_time >= state.debounce_interval do
      events = Enum.reverse(state.event_queue)
      state.callback.(events)
      %{state | event_queue: [], last_event_time: now}
    else
      state
    end
  end

  defp schedule_event_processing(interval) do
    timer_id = System.unique_integer([:positive])
    Process.send_after(self(), {:process_events, timer_id}, interval)
  end

  @doc """
  Handles a file event from the file system watcher.
  """
  def handle_file_event(path, state) do
    # This is a simplified implementation
    # In a real implementation, this would process the file event and trigger reloads
    case String.ends_with?(path, ".ex") or String.ends_with?(path, ".exs") do
      true ->
        # This is a plugin file, trigger reload
        {:ok, state}

      false ->
        # Not a plugin file, ignore
        {:ok, state}
    end
  end

  @doc """
  Handles debounced file events.
  """
  def handle_debounced_events(_plugin_id, plugin_path, state) do
    # This is a simplified implementation
    # In a real implementation, this would process multiple events and trigger reloads
    case String.ends_with?(plugin_path, ".ex") or
           String.ends_with?(plugin_path, ".exs") do
      true ->
        # This is a plugin file, trigger reload
        {:ok, state}

      false ->
        # Not a plugin file, ignore
        {:ok, state}
    end
  end
end

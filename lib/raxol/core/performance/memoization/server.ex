defmodule Raxol.Core.Performance.Memoization.Server do
  @moduledoc """
  GenServer implementation for function memoization cache.

  This server manages memoized function results, eliminating Process dictionary usage
  in favor of supervised state management with automatic cache expiry.

  ## Features
  - Per-process memoization cache
  - Automatic cache expiry
  - Memory-efficient storage
  - Cache hit/miss tracking
  """

  use GenServer
  require Logger

  # Client API

  @doc """
  Starts the Memoization server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns a child specification for this server.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  @doc """
  Gets a memoized value or computes and stores it.
  """
  def get_or_compute(key, fun) do
    GenServer.call(__MODULE__, {:get_or_compute, self(), key, fun})
  end

  @doc """
  Gets a memoized value if it exists.
  """
  def get(key) do
    GenServer.call(__MODULE__, {:get, self(), key})
  end

  @doc """
  Stores a memoized value.
  """
  def put(key, value) do
    GenServer.call(__MODULE__, {:put, self(), key, value})
  end

  @doc """
  Clears memoization cache for the calling process.
  """
  def clear do
    GenServer.call(__MODULE__, {:clear, self()})
  end

  @doc """
  Clears a specific key from the memoization cache.
  """
  def clear_key(key) do
    GenServer.call(__MODULE__, {:clear_key, self(), key})
  end

  @doc """
  Gets cache statistics.
  """
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    # Start a timer to clean up expired entries periodically
    schedule_cleanup()

    state = %{
      # Map of {pid, key} -> {value, timestamp}
      cache: %{},
      # Map of pid -> monitor ref
      monitors: %{},
      # Statistics
      hits: 0,
      misses: 0,
      # Configuration
      ttl: Keyword.get(opts, :ttl, :infinity),
      max_entries_per_process:
        Keyword.get(opts, :max_entries_per_process, 1000),
      cleanup_interval: Keyword.get(opts, :cleanup_interval, 60_000)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:get_or_compute, pid, key, fun}, _from, state) do
    cache_key = {pid, key}

    case Map.get(state.cache, cache_key) do
      nil ->
        # Cache miss - compute and store
        value = fun.()
        timestamp = System.monotonic_time(:millisecond)

        # Monitor the process if not already monitored
        state = ensure_monitored(pid, state)

        # Store in cache
        cache = Map.put(state.cache, cache_key, {value, timestamp})

        # Check if we need to evict entries for this process
        cache = maybe_evict_entries(cache, pid, state.max_entries_per_process)

        updated_state = %{state | cache: cache, misses: state.misses + 1}

        {:reply, value, updated_state}

      {value, timestamp} ->
        # Cache hit - check if expired
        if expired?(timestamp, state.ttl) do
          # Expired - recompute
          value = fun.()
          new_timestamp = System.monotonic_time(:millisecond)
          cache = Map.put(state.cache, cache_key, {value, new_timestamp})

          updated_state = %{state | cache: cache, misses: state.misses + 1}

          {:reply, value, updated_state}
        else
          # Valid cache hit
          {:reply, value, %{state | hits: state.hits + 1}}
        end
    end
  end

  @impl true
  def handle_call({:get, pid, key}, _from, state) do
    cache_key = {pid, key}

    case Map.get(state.cache, cache_key) do
      nil ->
        {:reply, :miss, %{state | misses: state.misses + 1}}

      {value, timestamp} ->
        if expired?(timestamp, state.ttl) do
          # Expired - remove from cache
          cache = Map.delete(state.cache, cache_key)
          {:reply, :miss, %{state | cache: cache, misses: state.misses + 1}}
        else
          {:reply, {:ok, value}, %{state | hits: state.hits + 1}}
        end
    end
  end

  @impl true
  def handle_call({:put, pid, key, value}, _from, state) do
    cache_key = {pid, key}
    timestamp = System.monotonic_time(:millisecond)

    # Monitor the process if not already monitored
    state = ensure_monitored(pid, state)

    # Store in cache
    cache = Map.put(state.cache, cache_key, {value, timestamp})

    # Check if we need to evict entries for this process
    cache = maybe_evict_entries(cache, pid, state.max_entries_per_process)

    {:reply, :ok, %{state | cache: cache}}
  end

  @impl true
  def handle_call({:clear, pid}, _from, state) do
    # Remove all entries for this process
    cache =
      state.cache
      |> Enum.reject(fn {{p, _}, _} -> p == pid end)
      |> Enum.into(%{})

    {:reply, :ok, %{state | cache: cache}}
  end

  @impl true
  def handle_call({:clear_key, pid, key}, _from, state) do
    cache_key = {pid, key}
    cache = Map.delete(state.cache, cache_key)

    {:reply, :ok, %{state | cache: cache}}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    total_entries = map_size(state.cache)

    processes_count =
      state.cache
      |> Enum.map(fn {{pid, _}, _} -> pid end)
      |> Enum.uniq()
      |> length()

    stats = %{
      hits: state.hits,
      misses: state.misses,
      hit_rate:
        if state.hits + state.misses > 0 do
          state.hits / (state.hits + state.misses) * 100
        else
          0.0
        end,
      total_entries: total_entries,
      processes_count: processes_count
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Clean up cache for dead process
    cache =
      state.cache
      |> Enum.reject(fn {{p, _}, _} -> p == pid end)
      |> Enum.into(%{})

    monitors = Map.delete(state.monitors, pid)

    {:noreply, %{state | cache: cache, monitors: monitors}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    # Remove expired entries
    now = System.monotonic_time(:millisecond)

    cache =
      if state.ttl != :infinity do
        state.cache
        |> Enum.reject(fn {_, {_, timestamp}} ->
          expired?(timestamp, state.ttl)
        end)
        |> Enum.into(%{})
      else
        state.cache
      end

    # Schedule next cleanup
    schedule_cleanup()

    {:noreply, %{state | cache: cache}}
  end

  # Private helpers

  defp ensure_monitored(pid, state) do
    if Map.has_key?(state.monitors, pid) do
      state
    else
      ref = Process.monitor(pid)
      %{state | monitors: Map.put(state.monitors, pid, ref)}
    end
  end

  defp expired?(_timestamp, :infinity), do: false

  defp expired?(timestamp, ttl) do
    now = System.monotonic_time(:millisecond)
    now - timestamp > ttl
  end

  defp maybe_evict_entries(cache, pid, max_entries) do
    # Count entries for this process
    process_entries =
      cache
      |> Enum.filter(fn {{p, _}, _} -> p == pid end)

    if length(process_entries) > max_entries do
      # Evict oldest entries
      entries_to_keep =
        process_entries
        |> Enum.sort_by(fn {_, {_, timestamp}} -> timestamp end, :desc)
        |> Enum.take(max_entries)
        |> Enum.into(%{})

      # Remove all entries for this process and add back the ones to keep
      cache
      |> Enum.reject(fn {{p, _}, _} -> p == pid end)
      |> Enum.into(%{})
      |> Map.merge(entries_to_keep)
    else
      cache
    end
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, 60_000)
  end
end

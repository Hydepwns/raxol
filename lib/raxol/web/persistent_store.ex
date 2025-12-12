defmodule Raxol.Web.PersistentStore do
  @moduledoc """
  Multi-tier persistent storage for Raxol web sessions.

  Implements a tiered storage strategy:
  - **ETS (Hot)**: Active session data, <1ms access
  - **DETS (Warm)**: Recent session data, <10ms access
  - **Database (Cold)**: Long-term persistence (optional)

  Data automatically moves between tiers based on access patterns
  and age. This ensures optimal performance while maintaining
  durability.

  ## Example

      # Store data
      :ok = PersistentStore.store("session:123", %{buffer: buffer_data})

      # Retrieve data
      {:ok, data} = PersistentStore.fetch("session:123")

      # Delete data
      :ok = PersistentStore.delete("session:123")

  ## Configuration

  Configure in your application:

      config :raxol, Raxol.Web.PersistentStore,
        ets_table: :raxol_hot_store,
        dets_file: "priv/data/warm_store.dets",
        warm_threshold_seconds: 300,
        cold_threshold_seconds: 3600
  """

  use GenServer

  alias Raxol.Core.Runtime.Log

  @ets_table :raxol_persistent_store
  @dets_file ~c"priv/data/raxol_warm_store.dets"
  @warm_threshold_seconds 300
  @cold_threshold_seconds 3600
  @cleanup_interval_ms 60_000

  defmodule Entry do
    @moduledoc false
    defstruct [:key, :value, :created_at, :accessed_at, :tier]
  end

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Start the PersistentStore server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Store a value with the given key.

  ## Options

    - `:ttl` - Time-to-live in seconds (default: nil, no expiration)
    - `:tier` - Initial storage tier (:hot, :warm) (default: :hot)

  ## Example

      :ok = PersistentStore.store("key", "value")
      :ok = PersistentStore.store("key", "value", ttl: 3600)
  """
  @spec store(String.t(), term(), keyword()) :: :ok | {:error, term()}
  def store(key, value, opts \\ []) when is_binary(key) do
    GenServer.call(__MODULE__, {:store, key, value, opts})
  end

  @doc """
  Fetch a value by key.

  Automatically promotes data from warm to hot tier on access.

  ## Example

      {:ok, value} = PersistentStore.fetch("key")
      {:error, :not_found} = PersistentStore.fetch("nonexistent")
  """
  @spec fetch(String.t()) :: {:ok, term()} | {:error, :not_found}
  def fetch(key) when is_binary(key) do
    GenServer.call(__MODULE__, {:fetch, key})
  end

  @doc """
  Delete a value by key.

  Removes from all tiers.

  ## Example

      :ok = PersistentStore.delete("key")
  """
  @spec delete(String.t()) :: :ok
  def delete(key) when is_binary(key) do
    GenServer.call(__MODULE__, {:delete, key})
  end

  @doc """
  Check if a key exists in any tier.

  ## Example

      true = PersistentStore.exists?("key")
  """
  @spec exists?(String.t()) :: boolean()
  def exists?(key) when is_binary(key) do
    GenServer.call(__MODULE__, {:exists?, key})
  end

  @doc """
  Promote a key to the hot tier.

  ## Example

      :ok = PersistentStore.promote("key")
  """
  @spec promote(String.t()) :: :ok | {:error, :not_found}
  def promote(key) when is_binary(key) do
    GenServer.call(__MODULE__, {:promote, key})
  end

  @doc """
  Demote a key to the warm tier.

  ## Example

      :ok = PersistentStore.demote("key")
  """
  @spec demote(String.t()) :: :ok | {:error, :not_found}
  def demote(key) when is_binary(key) do
    GenServer.call(__MODULE__, {:demote, key})
  end

  @doc """
  Clean up expired entries.

  Returns the count of entries cleaned up.

  ## Example

      {:ok, 5} = PersistentStore.cleanup_expired()
  """
  @spec cleanup_expired() :: {:ok, non_neg_integer()}
  def cleanup_expired do
    GenServer.call(__MODULE__, :cleanup_expired)
  end

  @doc """
  Get statistics about the store.

  ## Example

      stats = PersistentStore.stats()
      # => %{hot_count: 100, warm_count: 50, total_size: 1024}
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  List all keys in the store.

  ## Options

    - `:tier` - Filter by tier (:hot, :warm, :all) (default: :all)
    - `:prefix` - Filter by key prefix

  ## Example

      keys = PersistentStore.keys(prefix: "session:")
  """
  @spec keys(keyword()) :: [String.t()]
  def keys(opts \\ []) do
    GenServer.call(__MODULE__, {:keys, opts})
  end

  @doc """
  Clear all data from the store.

  Use with caution - this is destructive.

  ## Example

      :ok = PersistentStore.clear()
  """
  @spec clear() :: :ok
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  @doc """
  Fetch an existing value or compute and store a new one.

  If the key exists, returns its value. Otherwise, calls the compute
  function, stores the result, and returns it.

  ## Parameters

    - `key` - The key to fetch or store
    - `compute_fn` - Zero-arity function called if key doesn't exist

  ## Example

      value = PersistentStore.fetch_or_store("key", fn -> expensive_computation() end)
  """
  @spec fetch_or_store(String.t(), (-> term())) :: term()
  def fetch_or_store(key, compute_fn)
      when is_binary(key) and is_function(compute_fn, 0) do
    GenServer.call(__MODULE__, {:fetch_or_store, key, compute_fn})
  end

  @doc """
  Update an existing value using a function.

  Applies the update function to the current value and stores the result.
  Returns an error if the key doesn't exist.

  ## Parameters

    - `key` - The key to update
    - `update_fn` - Function that receives the current value and returns the new value

  ## Example

      :ok = PersistentStore.update("counter", fn count -> count + 1 end)
  """
  @spec update(String.t(), (term() -> term())) :: :ok | {:error, :not_found}
  def update(key, update_fn)
      when is_binary(key) and is_function(update_fn, 1) do
    GenServer.call(__MODULE__, {:update, key, update_fn})
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    ets_table = Keyword.get(opts, :ets_table, @ets_table)
    dets_file = Keyword.get(opts, :dets_file, @dets_file)

    # Create ETS table for hot storage
    :ets.new(ets_table, [:named_table, :set, :public, read_concurrency: true])

    # Ensure directory exists for DETS
    dets_dir = Path.dirname(to_string(dets_file))
    File.mkdir_p!(dets_dir)

    # Open DETS file for warm storage
    {:ok, _} = :dets.open_file(dets_file, type: :set, auto_save: 60_000)

    schedule_cleanup()
    schedule_tiering()

    state = %{
      ets_table: ets_table,
      dets_file: dets_file,
      warm_threshold:
        Keyword.get(opts, :warm_threshold_seconds, @warm_threshold_seconds),
      cold_threshold:
        Keyword.get(opts, :cold_threshold_seconds, @cold_threshold_seconds)
    }

    Log.info("[PersistentStore] Initialized with ETS table #{ets_table}")
    {:ok, state}
  end

  @impl true
  def handle_call({:store, key, value, opts}, _from, state) do
    now = System.system_time(:second)
    tier = Keyword.get(opts, :tier, :hot)
    ttl = Keyword.get(opts, :ttl)

    entry = %Entry{
      key: key,
      value: value,
      created_at: now,
      accessed_at: now,
      tier: tier
    }

    entry_with_ttl =
      if ttl do
        Map.put(entry, :expires_at, now + ttl)
      else
        entry
      end

    case tier do
      :hot -> :ets.insert(state.ets_table, {key, entry_with_ttl})
      :warm -> :dets.insert(state.dets_file, {key, entry_with_ttl})
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:fetch, key}, _from, state) do
    result =
      case :ets.lookup(state.ets_table, key) do
        [{^key, entry}] ->
          # Update access time
          updated = %{entry | accessed_at: System.system_time(:second)}
          :ets.insert(state.ets_table, {key, updated})
          {:ok, entry.value}

        [] ->
          # Check warm storage
          case :dets.lookup(state.dets_file, key) do
            [{^key, entry}] ->
              # Promote to hot
              updated = %{
                entry
                | accessed_at: System.system_time(:second),
                  tier: :hot
              }

              :ets.insert(state.ets_table, {key, updated})
              :dets.delete(state.dets_file, key)
              {:ok, entry.value}

            [] ->
              {:error, :not_found}
          end
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:delete, key}, _from, state) do
    :ets.delete(state.ets_table, key)
    :dets.delete(state.dets_file, key)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:exists?, key}, _from, state) do
    exists =
      case :ets.lookup(state.ets_table, key) do
        [{^key, _}] ->
          true

        [] ->
          case :dets.lookup(state.dets_file, key) do
            [{^key, _}] -> true
            [] -> false
          end
      end

    {:reply, exists, state}
  end

  @impl true
  def handle_call({:promote, key}, _from, state) do
    result =
      case :dets.lookup(state.dets_file, key) do
        [{^key, entry}] ->
          updated = %{
            entry
            | tier: :hot,
              accessed_at: System.system_time(:second)
          }

          :ets.insert(state.ets_table, {key, updated})
          :dets.delete(state.dets_file, key)
          :ok

        [] ->
          case :ets.lookup(state.ets_table, key) do
            [{^key, _}] -> :ok
            [] -> {:error, :not_found}
          end
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:demote, key}, _from, state) do
    result =
      case :ets.lookup(state.ets_table, key) do
        [{^key, entry}] ->
          updated = %{entry | tier: :warm}
          :dets.insert(state.dets_file, {key, updated})
          :ets.delete(state.ets_table, key)
          :ok

        [] ->
          case :dets.lookup(state.dets_file, key) do
            [{^key, _}] -> :ok
            [] -> {:error, :not_found}
          end
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:cleanup_expired, _from, state) do
    now = System.system_time(:second)
    count = do_cleanup_expired(state, now)
    {:reply, {:ok, count}, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    hot_entries = :ets.tab2list(state.ets_table)

    warm_entries =
      :dets.foldl(fn entry, acc -> [entry | acc] end, [], state.dets_file)

    stats = %{
      hot_count: length(hot_entries),
      warm_count: length(warm_entries),
      total_count: length(hot_entries) + length(warm_entries),
      ets_memory:
        :ets.info(state.ets_table, :memory) * :erlang.system_info(:wordsize),
      dets_file_size: get_dets_size(state.dets_file)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call({:keys, opts}, _from, state) do
    tier = Keyword.get(opts, :tier, :all)
    prefix = Keyword.get(opts, :prefix)

    hot_keys =
      if tier in [:all, :hot] do
        :ets.tab2list(state.ets_table)
        |> Enum.map(fn {key, _} -> key end)
      else
        []
      end

    warm_keys =
      if tier in [:all, :warm] do
        :dets.foldl(fn {key, _}, acc -> [key | acc] end, [], state.dets_file)
      else
        []
      end

    all_keys = hot_keys ++ warm_keys

    filtered =
      if prefix do
        Enum.filter(all_keys, &String.starts_with?(&1, prefix))
      else
        all_keys
      end

    {:reply, Enum.uniq(filtered), state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(state.ets_table)
    :dets.delete_all_objects(state.dets_file)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:fetch_or_store, key, compute_fn}, _from, state) do
    result =
      case :ets.lookup(state.ets_table, key) do
        [{^key, entry}] ->
          updated = %{entry | accessed_at: System.system_time(:second)}
          :ets.insert(state.ets_table, {key, updated})
          entry.value

        [] ->
          case :dets.lookup(state.dets_file, key) do
            [{^key, entry}] ->
              updated = %{
                entry
                | accessed_at: System.system_time(:second),
                  tier: :hot
              }

              :ets.insert(state.ets_table, {key, updated})
              :dets.delete(state.dets_file, key)
              entry.value

            [] ->
              value = compute_fn.()
              now = System.system_time(:second)

              entry = %Entry{
                key: key,
                value: value,
                created_at: now,
                accessed_at: now,
                tier: :hot
              }

              :ets.insert(state.ets_table, {key, entry})
              value
          end
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:update, key, update_fn}, _from, state) do
    result =
      case :ets.lookup(state.ets_table, key) do
        [{^key, entry}] ->
          new_value = update_fn.(entry.value)

          updated = %{
            entry
            | value: new_value,
              accessed_at: System.system_time(:second)
          }

          :ets.insert(state.ets_table, {key, updated})
          :ok

        [] ->
          case :dets.lookup(state.dets_file, key) do
            [{^key, entry}] ->
              new_value = update_fn.(entry.value)

              updated = %{
                entry
                | value: new_value,
                  accessed_at: System.system_time(:second),
                  tier: :hot
              }

              :ets.insert(state.ets_table, {key, updated})
              :dets.delete(state.dets_file, key)
              :ok

            [] ->
              {:error, :not_found}
          end
      end

    {:reply, result, state}
  end

  @impl true
  def handle_info(:cleanup_expired, state) do
    now = System.system_time(:second)
    count = do_cleanup_expired(state, now)

    if count > 0 do
      Log.debug("[PersistentStore] Cleaned up #{count} expired entries")
    end

    schedule_cleanup()
    {:noreply, state}
  end

  @impl true
  def handle_info(:auto_tier, state) do
    count = do_auto_tiering(state)

    if count > 0 do
      Log.debug("[PersistentStore] Auto-tiered #{count} entries")
    end

    schedule_tiering()
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    :dets.close(state.dets_file)
    :ok
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_expired, @cleanup_interval_ms)
  end

  defp schedule_tiering do
    Process.send_after(self(), :auto_tier, @cleanup_interval_ms * 2)
  end

  defp do_cleanup_expired(state, now) do
    # Cleanup ETS
    hot_expired =
      :ets.tab2list(state.ets_table)
      |> Enum.filter(fn {_key, entry} ->
        Map.get(entry, :expires_at, :infinity) < now
      end)
      |> Enum.map(fn {key, _} ->
        :ets.delete(state.ets_table, key)
        key
      end)

    # Cleanup DETS
    warm_expired =
      :dets.foldl(
        fn {key, entry}, acc ->
          if Map.get(entry, :expires_at, :infinity) < now do
            [key | acc]
          else
            acc
          end
        end,
        [],
        state.dets_file
      )

    Enum.each(warm_expired, fn key ->
      :dets.delete(state.dets_file, key)
    end)

    length(hot_expired) + length(warm_expired)
  end

  defp do_auto_tiering(state) do
    now = System.system_time(:second)
    threshold = now - state.warm_threshold

    # Find hot entries that should be demoted
    to_demote =
      :ets.tab2list(state.ets_table)
      |> Enum.filter(fn {_key, entry} ->
        entry.accessed_at < threshold
      end)

    Enum.each(to_demote, fn {key, entry} ->
      demoted = %{entry | tier: :warm}
      :dets.insert(state.dets_file, {key, demoted})
      :ets.delete(state.ets_table, key)
    end)

    length(to_demote)
  end

  defp get_dets_size(dets_file) do
    case :dets.info(dets_file, :file_size) do
      :undefined -> 0
      size -> size
    end
  end
end

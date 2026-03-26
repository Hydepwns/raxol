defmodule Raxol.Terminal.ImageCache do
  @moduledoc """
  ETS-backed cache for decoded and encoded terminal images.

  Caches expensive operations:
  - PNG decode results (raw pixel data)
  - Sixel/Kitty encoded output for given parameters

  Keys are `{content_hash, opts_hash}` tuples. Entries expire after a
  configurable TTL (default 5 minutes). The cache is created lazily on
  first access and owned by the calling process (or an explicit owner).

  ## Usage

      ImageCache.start()
      ImageCache.put("img.png", png_bytes, %{max_colors: 64})
      {:ok, cached} = ImageCache.get("img.png", %{max_colors: 64})
      ImageCache.evict("img.png")
  """

  @table :raxol_image_cache
  @default_ttl_ms 5 * 60 * 1000
  @max_entries 256

  @type cache_key :: {binary(), binary()}
  @type cache_entry :: {cache_key(), term(), integer()}

  @doc """
  Creates the ETS table if it doesn't already exist.
  Safe to call multiple times.
  """
  @spec start() :: :ok
  def start do
    case :ets.whereis(@table) do
      :undefined ->
        _ = :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
        :ok

      _ref ->
        :ok
    end
  end

  @doc """
  Stores a value in the cache keyed by source identifier and options.
  """
  @spec put(binary(), term(), map()) :: :ok
  def put(source_id, value, opts \\ %{}) do
    ensure_table()
    key = cache_key(source_id, opts)
    now = System.monotonic_time(:millisecond)
    :ets.insert(@table, {key, value, now})
    maybe_evict_oldest()
    :ok
  end

  @doc """
  Retrieves a cached value. Returns `{:ok, value}` or `:miss`.
  Expired entries are transparently deleted.
  """
  @spec get(binary(), map()) :: {:ok, term()} | :miss
  def get(source_id, opts \\ %{}) do
    ensure_table()
    key = cache_key(source_id, opts)

    case :ets.lookup(@table, key) do
      [{^key, value, inserted_at}] ->
        if expired?(inserted_at) do
          :ets.delete(@table, key)
          :miss
        else
          {:ok, value}
        end

      [] ->
        :miss
    end
  end

  @doc """
  Fetches from cache or computes and caches the value.

  The `compute_fn` is called only on cache miss and must return
  `{:ok, value}` or `{:error, reason}`.
  """
  @spec fetch(binary(), map(), (-> {:ok, term()} | {:error, term()})) ::
          {:ok, term()} | {:error, term()}
  def fetch(source_id, opts, compute_fn) do
    case get(source_id, opts) do
      {:ok, value} ->
        {:ok, value}

      :miss ->
        case compute_fn.() do
          {:ok, value} = ok ->
            put(source_id, value, opts)
            ok

          {:error, _} = err ->
            err
        end
    end
  end

  @doc """
  Removes all entries matching a source identifier (any opts).
  """
  @spec evict(binary()) :: :ok
  def evict(source_id) do
    ensure_table()
    hash = content_hash(source_id)

    :ets.foldl(
      fn {key, _value, _ts}, acc ->
        case key do
          {^hash, _} -> :ets.delete(@table, key)
          _ -> :ok
        end

        acc
      end,
      :ok,
      @table
    )
  end

  @doc """
  Removes all expired entries from the cache.
  """
  @spec prune() :: non_neg_integer()
  def prune do
    ensure_table()
    now = System.monotonic_time(:millisecond)
    ttl = ttl_ms()

    :ets.foldl(
      fn {key, _value, inserted_at}, count ->
        if now - inserted_at > ttl do
          :ets.delete(@table, key)
          count + 1
        else
          count
        end
      end,
      0,
      @table
    )
  end

  @doc """
  Deletes all entries from the cache.
  """
  @spec clear() :: :ok
  def clear do
    ensure_table()
    :ets.delete_all_objects(@table)
    :ok
  end

  @doc """
  Returns the number of entries currently in the cache.
  """
  @spec size() :: non_neg_integer()
  def size do
    ensure_table()
    :ets.info(@table, :size)
  end

  # -- Private --

  defp cache_key(source_id, opts) do
    {content_hash(source_id), opts_hash(opts)}
  end

  defp content_hash(source_id) when is_binary(source_id) do
    :crypto.hash(:sha256, source_id)
  end

  defp opts_hash(opts) when is_map(opts) do
    opts
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:md5, &1))
  end

  defp expired?(inserted_at) do
    System.monotonic_time(:millisecond) - inserted_at > ttl_ms()
  end

  defp ttl_ms do
    Application.get_env(:raxol, :image_cache_ttl_ms, @default_ttl_ms)
  end

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined -> start()
      _ref -> :ok
    end
  end

  defp maybe_evict_oldest do
    if :ets.info(@table, :size) > @max_entries do
      # Find and delete the oldest entry
      {oldest_key, _} =
        :ets.foldl(
          fn {key, _value, ts}, {_best_key, best_ts} = best ->
            if ts < best_ts, do: {key, ts}, else: best
          end,
          {nil, System.monotonic_time(:millisecond)},
          @table
        )

      if oldest_key, do: :ets.delete(@table, oldest_key)
    end
  end
end

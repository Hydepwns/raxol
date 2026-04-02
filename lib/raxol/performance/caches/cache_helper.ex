defmodule Raxol.Performance.Caches.CacheHelper do
  @moduledoc """
  Shared cache get-or-compute pattern and telemetry for performance caches.

  Eliminates the repeated pattern of checking ETS cache, emitting
  hit/miss telemetry, computing on miss, and storing the result.
  """

  alias Raxol.Performance.ETSCacheManager

  @doc """
  Gets a value from cache or computes and caches it.

  On cache hit, emits a `:hit` telemetry event and returns the cached value.
  On cache miss, emits a `:miss` event, calls `compute_fn`, caches the result,
  and returns it.

  ## Parameters
    - `key` - The cache key string
    - `telemetry_prefix` - e.g. `[:raxol, :performance, :font_metrics_cache]`
    - `telemetry_metadata` - e.g. `%{key_type: :char_width}`
    - `compute_fn` - Zero-arity function that computes the value on miss
  """
  @spec cache_through(String.t(), list(atom()), map(), (-> term())) :: term()
  def cache_through(key, telemetry_prefix, telemetry_metadata, compute_fn) do
    case ETSCacheManager.get_font_metrics(key) do
      {:ok, value} ->
        emit_telemetry(telemetry_prefix, :hit, telemetry_metadata)
        value

      :miss ->
        emit_telemetry(telemetry_prefix, :miss, telemetry_metadata)
        value = compute_fn.()
        ETSCacheManager.cache_font_metrics(key, value)
        value
    end
  end

  @doc """
  Emits a telemetry event with a standard `%{count: 1}` measurement.
  """
  @spec emit_telemetry(list(atom()), atom(), map()) :: :ok
  def emit_telemetry(prefix, event, metadata) do
    # credo:disable-for-next-line Credo.Check.Refactor.AppendSingleItem
    :telemetry.execute(prefix ++ [event], %{count: 1}, metadata)
  end
end

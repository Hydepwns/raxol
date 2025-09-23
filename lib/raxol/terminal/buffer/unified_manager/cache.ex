defmodule Raxol.Terminal.Buffer.UnifiedManager.Cache do
  @moduledoc """
  Handles caching operations for the unified buffer manager.

  This module provides safe wrapper functions around the cache system,
  with proper error handling and fallback mechanisms.
  """

  @doc """
  Safely gets a value from the cache.
  """
  @spec get(String.t(), atom()) ::
          {:ok, any()} | {:error, :cache_miss | :cache_unavailable | any()}
  def get(key, namespace) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           case Raxol.Terminal.Cache.System.get(key, namespace: namespace) do
             {:ok, value} -> {:ok, value}
             {:error, :not_found} -> {:error, :cache_miss}
             {:error, reason} -> {:error, reason}
           end
         end) do
      {:ok, result} -> result
      {:error, _} -> {:error, :cache_unavailable}
    end
  end

  @doc """
  Safely puts a value into the cache.
  """
  @spec put(String.t(), any(), atom()) :: {:ok, any()} | {:error, any()}
  def put(key, value, namespace) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           case Raxol.Terminal.Cache.System.put(key, value,
                  namespace: namespace
                ) do
             :ok -> {:ok, value}
             {:error, reason} -> {:error, reason}
           end
         end) do
      {:ok, result} -> result
      {:error, _} -> {:error, :cache_unavailable}
    end
  end

  @doc """
  Safely clears the cache for a namespace.
  """
  @spec clear(atom()) :: :ok | {:error, any()}
  def clear(namespace) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           case Raxol.Terminal.Cache.System.clear(namespace: namespace) do
             :ok -> :ok
             {:error, reason} -> {:error, reason}
           end
         end) do
      {:ok, result} -> result
      {:error, _} -> {:error, :cache_unavailable}
    end
  end

  @doc """
  Safely invalidates a cache key.
  """
  @spec invalidate(String.t(), atom()) :: :ok | {:error, any()}
  def invalidate(key, namespace) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           case Raxol.Terminal.Cache.System.invalidate(key,
                  namespace: namespace
                ) do
             :ok -> :ok
             {:error, reason} -> {:error, reason}
           end
         end) do
      {:ok, result} -> result
      {:error, _} -> {:error, :cache_unavailable}
    end
  end

  @doc """
  Invalidates all cells in a region.
  """
  @spec invalidate_region(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          atom()
        ) :: :ok
  def invalidate_region(x, y, width, height, namespace) do
    _ = for cell_x <- x..(x + width - 1), cell_y <- y..(y + height - 1) do
      cache_key = "cell_#{cell_x}_#{cell_y}"
      _ = invalidate(cache_key, namespace)
    end

    :ok
  end
end

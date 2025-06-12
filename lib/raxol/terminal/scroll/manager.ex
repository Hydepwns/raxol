defmodule Raxol.Terminal.Scroll.Manager do
  @moduledoc """
  Manages terminal scrolling operations with advanced features.

  Features:
  - Predictive scrolling for smooth performance
  - Scroll caching for efficient memory usage
  - Scroll optimization for better performance
  - Scroll synchronization across splits
  """

  alias Raxol.Terminal.Scroll.Predictor
  alias Raxol.Terminal.Scroll.Optimizer
  alias Raxol.Terminal.Scroll.Sync
  alias Raxol.Terminal.Cache.System

  @type t :: %__MODULE__{
    predictor: Predictor.t(),
    optimizer: Optimizer.t(),
    sync: Sync.t(),
    metrics: %{
      scrolls: non_neg_integer(),
      predictions: non_neg_integer(),
      cache_hits: non_neg_integer(),
      cache_misses: non_neg_integer(),
      optimizations: non_neg_integer()
    }
  }

  defstruct [
    :predictor,
    :optimizer,
    :sync,
    :metrics
  ]

  @doc """
  Creates a new scroll manager.

  ## Options
    * `:prediction_enabled` - Whether to enable predictive scrolling (default: true)
    * `:optimization_enabled` - Whether to enable scroll optimization (default: true)
    * `:sync_enabled` - Whether to enable scroll synchronization (default: true)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    prediction_enabled = Keyword.get(opts, :prediction_enabled, true)
    optimization_enabled = Keyword.get(opts, :optimization_enabled, true)
    sync_enabled = Keyword.get(opts, :sync_enabled, true)

    %__MODULE__{
      predictor: if(prediction_enabled, do: Predictor.new(), else: nil),
      optimizer: if(optimization_enabled, do: Optimizer.new(), else: nil),
      sync: if(sync_enabled, do: Sync.new(), else: nil),
      metrics: %{
        scrolls: 0,
        predictions: 0,
        cache_hits: 0,
        cache_misses: 0,
        optimizations: 0
      }
    }
  end

  @doc """
  Scrolls the terminal content.

  ## Parameters
    * `manager` - The scroll manager
    * `direction` - Scroll direction (:up or :down)
    * `lines` - Number of lines to scroll
    * `opts` - Scroll options
      * `:predict` - Whether to use prediction (default: true)
      * `:optimize` - Whether to optimize the scroll (default: true)
      * `:sync` - Whether to sync across splits (default: true)
  """
  @spec scroll(t(), :up | :down, non_neg_integer(), keyword()) :: {:ok, t()} | {:error, term()}
  def scroll(manager, direction, lines, opts \\ []) do
    predict = Keyword.get(opts, :predict, true)
    optimize = Keyword.get(opts, :optimize, true)
    sync = Keyword.get(opts, :sync, true)

    # Try to get from cache first
    cache_key = {direction, lines}
    case System.get(cache_key, namespace: :scroll) do
      {:ok, cached_result} ->
        manager = update_metrics(manager, :cache_hit)
        {:ok, cached_result}

      {:error, _} ->
        with {:ok, predictor} <- maybe_predict(manager.predictor, direction, lines, predict),
             {:ok, optimizer} <- maybe_optimize(manager.optimizer, direction, lines, optimize),
             {:ok, sync} <- maybe_sync(manager.sync, direction, lines, sync) do
          manager = %{manager |
            predictor: predictor,
            optimizer: optimizer,
            sync: sync,
            metrics: update_metrics(manager.metrics, :scrolls)
          }

          # Cache the result
          System.put(cache_key, manager, namespace: :scroll)
          manager = update_metrics(manager, :cache_miss)
          {:ok, manager}
        end
    end
  end

  @doc """
  Gets the scroll history.

  ## Parameters
    * `manager` - The scroll manager
    * `opts` - History options
      * `:limit` - Maximum number of entries to return (default: all)
  """
  @spec get_history(t(), keyword()) :: [map()]
  def get_history(manager, opts \\ []) do
    limit = Keyword.get(opts, :limit)
    case System.get(:history, namespace: :scroll) do
      {:ok, history} ->
        if limit, do: Enum.take(history, limit), else: history
      {:error, _} -> []
    end
  end

  @doc """
  Gets the current scroll metrics.
  """
  @spec get_metrics(t()) :: map()
  def get_metrics(manager) do
    manager.metrics
  end

  @doc """
  Optimizes the scroll manager based on current metrics.
  """
  @spec optimize(t()) :: t()
  def optimize(manager) do
    # Clear old cache entries if cache is too large
    case System.stats(namespace: :scroll) do
      {:ok, stats} ->
        if stats.size > stats.max_size * 0.8 do
          System.clear(namespace: :scroll)
        end
      _ -> :ok
    end

    # Adjust prediction window based on prediction accuracy
    new_window = if manager.metrics.predictions > 100 do
      max(5, min(20, manager.prediction_window))
    else
      manager.prediction_window
    end

    %{manager | prediction_window: new_window}
  end

  # Private helper functions

  defp maybe_predict(predictor, direction, lines, true) when not is_nil(predictor) do
    {:ok, Predictor.predict(predictor, direction, lines)}
  end
  defp maybe_predict(predictor, _direction, _lines, _predict), do: {:ok, predictor}

  defp maybe_optimize(optimizer, direction, lines, true) when not is_nil(optimizer) do
    {:ok, Optimizer.optimize(optimizer, direction, lines)}
  end
  defp maybe_optimize(optimizer, _direction, _lines, _optimize), do: {:ok, optimizer}

  defp maybe_sync(sync, direction, lines, true) when not is_nil(sync) do
    {:ok, Sync.sync(sync, direction, lines)}
  end
  defp maybe_sync(sync, _direction, _lines, _sync), do: {:ok, sync}

  defp update_metrics(manager, :cache_hit) do
    update_in(manager.metrics.cache_hits, &(&1 + 1))
  end

  defp update_metrics(manager, :cache_miss) do
    update_in(manager.metrics.cache_misses, &(&1 + 1))
  end

  defp update_metrics(manager, :prediction) do
    update_in(manager.metrics.predictions, &(&1 + 1))
  end

  defp update_metrics(manager, :scroll_op) do
    update_in(manager.metrics.scroll_ops, &(&1 + 1))
  end
end

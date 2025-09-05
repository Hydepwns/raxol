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
      predictor: create_predictor(prediction_enabled),
      optimizer: create_optimizer(optimization_enabled),
      sync: create_sync(sync_enabled),
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
  @spec scroll(t(), :up | :down, non_neg_integer(), keyword()) ::
          {:ok, t()} | {:error, term()}
  def scroll(manager, direction, amount, opts \\ []) do
    case get_cached_scroll(manager, direction, amount) do
      {:hit, cached_result} ->
        _manager = update_metrics(manager, :cache_hit)
        cached_result

      {:miss, _} ->
        _manager = update_metrics(manager, :cache_miss)
        perform_scroll(manager, direction, amount, opts)
    end
  end

  @doc """
  Gets the scroll history.

  ## Parameters
    * `manager` - The scroll manager
    * `opts` - History options
      * `:limit` - Maximum number of entries to return (default: all)
      * `:direction` - Filter by direction (:up or :down)
  """
  @spec get_history(t(), keyword()) :: {:ok, [map()], t()}
  def get_history(manager, opts \\ []) do
    limit = Keyword.get(opts, :limit)
    direction = Keyword.get(opts, :direction)

    case Raxol.Terminal.Cache.System.get(:history, namespace: :scroll) do
      {:ok, history} ->
        result =
          history
          |> filter_by_direction(direction)
          |> limit_results(limit)

        {:ok, result, manager}

      {:error, _} ->
        {:ok, [], manager}
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
    case Raxol.Terminal.Cache.System.stats(namespace: :scroll) do
      {:ok, stats} ->
        handle_cache_stats(stats)

      _ ->
        :ok
    end

    manager
  end

  defp get_cached_scroll(_manager, direction, amount) do
    cache_key = {direction, amount}

    case Raxol.Terminal.Cache.System.get(cache_key, namespace: :scroll) do
      {:ok, result} -> {:hit, result}
      {:error, _} -> {:miss, nil}
    end
  end

  defp perform_scroll(manager, direction, amount, opts) do
    predict = Keyword.get(opts, :predict, true)
    optimize = Keyword.get(opts, :optimize, true)
    sync = Keyword.get(opts, :sync, true)

    manager = update_metrics(manager, :scroll)

    manager = apply_prediction(manager, predict, direction, amount)

    manager = apply_optimization(manager, optimize, direction, amount)

    manager = apply_sync(manager, sync, direction, amount)

    scroll_entry = %{
      direction: direction,
      amount: amount,
      timestamp: System.monotonic_time(),
      options: opts
    }

    case Raxol.Terminal.Cache.System.get(:history, namespace: :scroll) do
      {:ok, history} ->
        updated_history = [scroll_entry | history]

        Raxol.Terminal.Cache.System.put(:history, updated_history,
          namespace: :scroll
        )

      {:error, _} ->
        Raxol.Terminal.Cache.System.put(:history, [scroll_entry],
          namespace: :scroll
        )
    end

    {:ok, manager}
  end

  defp update_metrics(manager, :cache_hit) do
    %{
      manager
      | metrics: %{manager.metrics | cache_hits: manager.metrics.cache_hits + 1}
    }
  end

  defp update_metrics(manager, :cache_miss) do
    %{
      manager
      | metrics: %{
          manager.metrics
          | cache_misses: manager.metrics.cache_misses + 1
        }
    }
  end

  defp update_metrics(manager, :scroll) do
    %{
      manager
      | metrics: %{manager.metrics | scrolls: manager.metrics.scrolls + 1}
    }
  end

  defp update_metrics(manager, :prediction) do
    %{
      manager
      | metrics: %{
          manager.metrics
          | predictions: manager.metrics.predictions + 1
        }
    }
  end

  defp update_metrics(manager, :optimization) do
    %{
      manager
      | metrics: %{
          manager.metrics
          | optimizations: manager.metrics.optimizations + 1
        }
    }
  end

  defp filter_by_direction(history, nil), do: history

  defp filter_by_direction(history, direction) do
    Enum.filter(history, fn entry -> entry.direction == direction end)
  end

  defp limit_results(history, nil), do: history
  defp limit_results(history, limit), do: Enum.take(history, limit)

  @doc """
  Clears the scroll history.
  """
  @spec clear_history(t()) :: {:ok, t()}
  def clear_history(manager) do
    case Raxol.Terminal.Cache.System.clear(namespace: :scroll) do
      :ok -> {:ok, manager}
      {:error, _} -> {:ok, manager}
    end
  end

  defp create_predictor(true), do: Predictor.new()
  defp create_predictor(false), do: nil

  defp create_optimizer(true), do: Optimizer.new()
  defp create_optimizer(false), do: nil

  defp create_sync(true), do: Sync.new()
  defp create_sync(false), do: nil

  defp apply_prediction(manager, predict, direction, amount) do
    case {predict, manager.predictor} do
      {true, predictor} when not is_nil(predictor) ->
        %{
          manager
          | predictor: Predictor.predict(predictor, direction, amount)
        }
        |> update_metrics(:prediction)
      _ ->
        manager
    end
  end

  defp apply_optimization(manager, optimize, direction, amount) do
    case {optimize, manager.optimizer} do
      {true, optimizer} when not is_nil(optimizer) ->
        %{
          manager
          | optimizer: Optimizer.optimize(optimizer, direction, amount)
        }
        |> update_metrics(:optimization)
      _ ->
        manager
    end
  end

  defp apply_sync(manager, sync, direction, amount) do
    case {sync, manager.sync} do
      {true, sync_module} when not is_nil(sync_module) ->
        %{manager | sync: Sync.sync(sync_module, direction, amount)}
      _ ->
        manager
    end
  end

  defp handle_cache_stats(stats) do
    case stats.size > stats.max_size * 0.8 do
      true -> Raxol.Terminal.Cache.System.clear(namespace: :scroll)
      false -> :ok
    end
  end
end

defmodule Raxol.Terminal.Clipboard.Manager do
  @moduledoc """
  Manages clipboard operations for the terminal emulator.

  Features:
  - Clipboard operations (copy, paste, cut)
  - Clipboard history with configurable size
  - Clipboard synchronization across splits
  - Clipboard customization (formats, filters)
  """

  alias Raxol.Terminal.Clipboard.{History, Sync, Format}

  @type t :: %__MODULE__{
    history: History.t(),
    sync: Sync.t(),
    formats: [Format.t()],
    filters: [Format.t()],
    metrics: %{
      operations: non_neg_integer(),
      syncs: non_neg_integer(),
      cache_hits: non_neg_integer(),
      cache_misses: non_neg_integer()
    }
  }

  defstruct [
    :history,
    :sync,
    :formats,
    :filters,
    :metrics
  ]

  @doc """
  Creates a new clipboard manager.

  ## Options
    * `:history_size` - Maximum number of items to keep in history (default: 100)
    * `:formats` - List of supported clipboard formats (default: [:text, :html])
    * `:filters` - List of format filters to apply (default: [])
    * `:sync_enabled` - Whether to enable clipboard synchronization (default: true)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    history_size = Keyword.get(opts, :history_size, 100)
    formats = Keyword.get(opts, :formats, [:text, :html])
    filters = Keyword.get(opts, :filters, [])
    sync_enabled = Keyword.get(opts, :sync_enabled, true)

    %__MODULE__{
      history: History.new(history_size),
      sync: if(sync_enabled, do: Sync.new(), else: nil),
      formats: formats,
      filters: filters,
      metrics: %{
        operations: 0,
        syncs: 0,
        cache_hits: 0,
        cache_misses: 0
      }
    }
  end

  @doc """
  Copies content to the clipboard.

  ## Parameters
    * `manager` - The clipboard manager
    * `content` - The content to copy
    * `opts` - Copy options
      * `:format` - Content format (default: :text)
      * `:sync` - Whether to sync across splits (default: true)
  """
  @spec copy(t(), String.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def copy(manager, content, opts \\ []) do
    format = Keyword.get(opts, :format, :text)
    sync = Keyword.get(opts, :sync, true)

    with :ok <- validate_format(manager, format),
         :ok <- apply_filters(manager, content, format),
         {:ok, history} <- History.add(manager.history, content, format),
         {:ok, sync} <- maybe_sync(manager.sync, content, format, sync) do
      manager = %{manager |
        history: history,
        sync: sync,
        metrics: update_metrics(manager.metrics, :operations)
      }
      {:ok, manager}
    end
  end

  @doc """
  Pastes content from the clipboard.

  ## Parameters
    * `manager` - The clipboard manager
    * `opts` - Paste options
      * `:format` - Preferred content format (default: :text)
      * `:index` - History index to paste from (default: 0, most recent)
  """
  @spec paste(t(), keyword()) :: {:ok, String.t(), t()} | {:error, term()}
  def paste(manager, opts \\ []) do
    format = Keyword.get(opts, :format, :text)
    index = Keyword.get(opts, :index, 0)

    with :ok <- validate_format(manager, format),
         {:ok, content} <- History.get(manager.history, index, format) do
      manager = %{manager |
        metrics: update_metrics(manager.metrics, :operations)
      }
      {:ok, content, manager}
    end
  end

  @doc """
  Cuts content to the clipboard (copy + clear).

  ## Parameters
    * `manager` - The clipboard manager
    * `content` - The content to cut
    * `opts` - Cut options (same as copy options)
  """
  @spec cut(t(), String.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def cut(manager, content, opts \\ []) do
    with {:ok, manager} <- copy(manager, content, opts) do
      {:ok, manager}
    end
  end

  @doc """
  Gets the clipboard history.

  ## Parameters
    * `manager` - The clipboard manager
    * `opts` - History options
      * `:format` - Filter by format (default: all formats)
      * `:limit` - Maximum number of items to return (default: all)
  """
  @spec get_history(t(), keyword()) :: {:ok, [{String.t(), atom()}], t()}
  def get_history(manager, opts \\ []) do
    format = Keyword.get(opts, :format)
    limit = Keyword.get(opts, :limit)

    {:ok, history, manager} = History.get_all(manager.history, format, limit)
    {:ok, history, manager}
  end

  @doc """
  Clears the clipboard history.

  ## Parameters
    * `manager` - The clipboard manager
  """
  @spec clear_history(t()) :: {:ok, t()}
  def clear_history(manager) do
    {:ok, history} = History.clear(manager.history)
    {:ok, %{manager | history: history}}
  end

  @doc """
  Gets the current metrics.

  ## Parameters
    * `manager` - The clipboard manager
  """
  @spec get_metrics(t()) :: map()
  def get_metrics(manager) do
    manager.metrics
  end

  # Private functions

  defp validate_format(manager, format) do
    if format in manager.formats do
      :ok
    else
      {:error, :unsupported_format}
    end
  end

  defp apply_filters(manager, content, format) do
    Enum.reduce_while(manager.filters, {:ok, content}, fn filter, {:ok, content} ->
      case Format.apply_filter(filter, content, format) do
        {:ok, filtered} -> {:cont, {:ok, filtered}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp maybe_sync(nil, _content, _format, _sync), do: {:ok, nil}
  defp maybe_sync(sync, content, format, false), do: {:ok, sync}
  defp maybe_sync(sync, content, format, true) do
    case Sync.broadcast(sync, content, format) do
      {:ok, sync} -> {:ok, sync}
      {:error, reason} -> {:error, reason}
    end
  end

  defp update_metrics(metrics, :operations) do
    Map.update!(metrics, :operations, &(&1 + 1))
  end
end

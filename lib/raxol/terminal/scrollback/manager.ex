defmodule Raxol.Terminal.Scrollback.Manager do
  @moduledoc """
  Manages terminal scrollback buffer operations.
  """

  defstruct [
    :buffer,
    :limit,
    :metrics
  ]

  @type t :: %__MODULE__{
    buffer: list(String.t()),
    limit: integer(),
    metrics: map()
  }

  @doc """
  Creates a new scrollback manager with default settings.
  """
  def new(opts \\ []) do
    %__MODULE__{
      buffer: [],
      limit: Keyword.get(opts, :limit, 1000),
      metrics: %{
        lines_added: 0,
        lines_removed: 0,
        buffer_size: 0
      }
    }
  end

  @doc """
  Gets the scrollback buffer.
  """
  def get_scrollback_buffer(%__MODULE__{} = manager) do
    manager.buffer
  end

  @doc """
  Adds a line to the scrollback buffer.
  """
  def add_to_scrollback(%__MODULE__{} = manager, line) do
    buffer = [line | manager.buffer]
    buffer = if length(buffer) > manager.limit do
      Enum.take(buffer, manager.limit)
    else
      buffer
    end
    metrics = update_metrics(manager.metrics, :lines_added)
    %{manager | buffer: buffer, metrics: metrics}
  end

  @doc """
  Clears the scrollback buffer.
  """
  def clear_scrollback(%__MODULE__{} = manager) do
    metrics = update_metrics(manager.metrics, :lines_removed, length(manager.buffer))
    %{manager | buffer: [], metrics: metrics}
  end

  @doc """
  Gets the scrollback limit.
  """
  def get_scrollback_limit(%__MODULE__{} = manager) do
    manager.limit
  end

  @doc """
  Sets the scrollback limit.
  """
  def set_scrollback_limit(%__MODULE__{} = manager, limit) when is_integer(limit) and limit > 0 do
    buffer = if length(manager.buffer) > limit do
      Enum.take(manager.buffer, limit)
    else
      manager.buffer
    end
    %{manager | limit: limit, buffer: buffer}
  end

  @doc """
  Gets a range of lines from the scrollback buffer.
  """
  def get_scrollback_range(%__MODULE__{} = manager, start, count) when is_integer(start) and is_integer(count) do
    case Enum.slice(manager.buffer, start, count) do
      [] -> {:error, :invalid_range}
      lines -> {:ok, lines}
    end
  end

  @doc """
  Gets the current size of the scrollback buffer.
  """
  def get_scrollback_size(%__MODULE__{} = manager) do
    length(manager.buffer)
  end

  @doc """
  Checks if the scrollback buffer is empty.
  """
  def scrollback_empty?(%__MODULE__{} = manager) do
    Enum.empty?(manager.buffer)
  end

  @doc """
  Gets the current metrics.
  """
  def get_metrics(%__MODULE__{} = manager) do
    manager.metrics
  end

  # Private Functions

  defp update_metrics(metrics, :lines_added) do
    Map.update!(metrics, :lines_added, &(&1 + 1))
    |> Map.update!(:buffer_size, &(&1 + 1))
  end

  defp update_metrics(metrics, :lines_removed, count) do
    Map.update!(metrics, :lines_removed, &(&1 + count))
    |> Map.update!(:buffer_size, &(&1 - count))
  end
end

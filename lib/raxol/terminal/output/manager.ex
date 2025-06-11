defmodule Raxol.Terminal.Output.Manager do
  @moduledoc """
  Manages terminal output operations with advanced features:
  - Output buffering with batch processing
  - Output optimization for performance
  - Output formatting with style support
  - Output customization and filtering
  """

  alias Raxol.Terminal.{Buffer, ScreenBuffer}

  @type style :: %{
    foreground: String.t() | nil,
    background: String.t() | nil,
    bold: boolean(),
    italic: boolean(),
    underline: boolean()
  }

  @type output_event :: %{
    content: String.t(),
    style: style(),
    timestamp: integer(),
    priority: integer()
  }

  @type t :: %__MODULE__{
    buffer: Buffer.t(),
    format_rules: [function()],
    style_map: %{String.t() => style()},
    batch_size: integer(),
    metrics: %{
      processed_events: integer(),
      batch_count: integer(),
      format_applications: integer(),
      style_applications: integer()
    }
  }

  defstruct [
    :buffer,
    :format_rules,
    :style_map,
    :batch_size,
    :metrics
  ]

  @doc """
  Creates a new output manager with the given options.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      buffer: Buffer.new(Keyword.get(opts, :buffer_size, 1024)),
      format_rules: [
        &format_ansi/1,
        &format_unicode/1,
        &format_control/1
      ],
      style_map: %{
        "default" => %{
          foreground: nil,
          background: nil,
          bold: false,
          italic: false,
          underline: false
        }
      },
      batch_size: Keyword.get(opts, :batch_size, 100),
      metrics: %{
        processed_events: 0,
        batch_count: 0,
        format_applications: 0,
        style_applications: 0
      }
    }
  end

  @doc """
  Processes an output event with formatting and styling.
  """
  @spec process_output(t(), output_event()) :: {:ok, t()} | {:error, term()}
  def process_output(manager, event) do
    with :ok <- validate_event(event),
         formatted_event <- apply_formatting(manager, event),
         styled_event <- apply_style(manager, formatted_event),
         {:ok, new_buffer} <- Buffer.add(manager.buffer, styled_event) do
      updated_manager = %{manager |
        buffer: new_buffer,
        metrics: update_metrics(manager.metrics, :processed_events)
      }
      {:ok, updated_manager}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Processes a batch of output events for better performance.
  """
  @spec process_batch(t(), [output_event()]) :: {:ok, t()} | {:error, term()}
  def process_batch(manager, events) when length(events) <= manager.batch_size do
    Enum.reduce_while(events, {:ok, manager}, fn event, {:ok, acc_manager} ->
      case process_output(acc_manager, event) do
        {:ok, new_manager} -> {:cont, {:ok, new_manager}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, updated_manager} ->
        updated_manager = %{updated_manager |
          metrics: update_metrics(updated_manager.metrics, :batch_count)
        }
        {:ok, updated_manager}
      error -> error
    end
  end

  @doc """
  Adds a custom style definition.
  """
  @spec add_style(t(), String.t(), style()) :: t()
  def add_style(manager, name, style) do
    %{manager |
      style_map: Map.put(manager.style_map, name, style),
      metrics: update_metrics(manager.metrics, :style_applications)
    }
  end

  @doc """
  Adds a custom formatting rule.
  """
  @spec add_format_rule(t(), function()) :: t()
  def add_format_rule(manager, rule) when is_function(rule, 1) do
    %{manager |
      format_rules: [rule | manager.format_rules],
      metrics: update_metrics(manager.metrics, :format_applications)
    }
  end

  @doc """
  Gets the current output metrics.
  """
  @spec get_metrics(t()) :: map()
  def get_metrics(manager) do
    manager.metrics
  end

  @doc """
  Flushes the output buffer.
  """
  @spec flush_buffer(t()) :: t()
  def flush_buffer(manager) do
    %{manager | buffer: Buffer.new(manager.buffer.max_size)}
  end

  # Private helper functions

  defp validate_event(%{content: content, style: style, timestamp: ts, priority: priority})
       when is_binary(content) and is_map(style) and is_integer(ts) and is_integer(priority) do
    :ok
  end
  defp validate_event(_), do: {:error, :invalid_event}

  defp apply_formatting(manager, event) do
    Enum.reduce(manager.format_rules, event, fn rule, acc ->
      %{acc | content: rule.(acc.content)}
    end)
  end

  defp apply_style(manager, event) do
    style = Map.get(manager.style_map, event.style, manager.style_map["default"])
    %{event | style: style}
  end

  defp format_ansi(content) do
    # Convert ANSI escape sequences to internal format
    content
  end

  defp format_unicode(content) do
    # Handle Unicode characters and normalization
    content
  end

  defp format_control(content) do
    # Handle control characters
    content
  end

  defp update_metrics(metrics, :processed_events) do
    update_in(metrics.processed_events, &(&1 + 1))
  end
  defp update_metrics(metrics, :batch_count) do
    update_in(metrics.batch_count, &(&1 + 1))
  end
  defp update_metrics(metrics, :format_applications) do
    update_in(metrics.format_applications, &(&1 + 1))
  end
  defp update_metrics(metrics, :style_applications) do
    update_in(metrics.style_applications, &(&1 + 1))
  end
end

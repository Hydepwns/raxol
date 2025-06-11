defmodule Raxol.Terminal.Input.Manager do
  @moduledoc """
  Manages terminal input operations with advanced features:
  - Advanced key handling with modifier support
  - Input validation and sanitization
  - Input buffering with timeout handling
  - Input customization and mapping
  """

  alias Raxol.Terminal.Input.{Buffer, Processor}

  @type key_modifier :: :shift | :ctrl | :alt | :meta
  @type key_event :: %{
    key: String.t(),
    modifiers: [key_modifier()],
    timestamp: integer()
  }

  @type t :: %__MODULE__{
    buffer: Buffer.t(),
    processor: Processor.t(),
    key_mappings: %{String.t() => String.t()},
    validation_rules: [function()],
    metrics: %{
      processed_events: integer(),
      validation_failures: integer(),
      buffer_overflows: integer(),
      custom_mappings: integer()
    }
  }

  defstruct [
    :buffer,
    :processor,
    :key_mappings,
    :validation_rules,
    :metrics
  ]

  @doc """
  Creates a new input manager with the given options.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      buffer: Buffer.new(Keyword.get(opts, :buffer_size, 1024)),
      processor: Processor.new(),
      key_mappings: %{},
      validation_rules: [
        &validate_key/1,
        &validate_modifiers/1,
        &validate_timestamp/1
      ],
      metrics: %{
        processed_events: 0,
        validation_failures: 0,
        buffer_overflows: 0,
        custom_mappings: 0
      }
    }
  end

  @doc """
  Processes a key event with validation and mapping.
  """
  @spec process_key_event(t(), key_event()) :: {:ok, t()} | {:error, term()}
  def process_key_event(manager, event) do
    with :ok <- validate_event(manager, event),
         mapped_event <- apply_key_mapping(manager, event),
         {:ok, new_buffer} <- Buffer.add(manager.buffer, mapped_event) do
      updated_manager = %{manager |
        buffer: new_buffer,
        metrics: update_metrics(manager.metrics, :processed_events)
      }
      {:ok, updated_manager}
    else
      {:error, :validation} ->
        updated_manager = %{manager |
          metrics: update_metrics(manager.metrics, :validation_failures)
        }
        {:error, :validation_failed}
      {:error, :buffer_overflow} ->
        updated_manager = %{manager |
          metrics: update_metrics(manager.metrics, :buffer_overflows)
        }
        {:error, :buffer_overflow}
    end
  end

  @doc """
  Adds a custom key mapping.
  """
  @spec add_key_mapping(t(), String.t(), String.t()) :: t()
  def add_key_mapping(manager, from_key, to_key) do
    new_mappings = Map.put(manager.key_mappings, from_key, to_key)
    %{manager |
      key_mappings: new_mappings,
      metrics: update_metrics(manager.metrics, :custom_mappings)
    }
  end

  @doc """
  Adds a custom validation rule.
  """
  @spec add_validation_rule(t(), function()) :: t()
  def add_validation_rule(manager, rule) when is_function(rule, 1) do
    %{manager |
      validation_rules: [rule | manager.validation_rules]
    }
  end

  @doc """
  Gets the current input metrics.
  """
  @spec get_metrics(t()) :: map()
  def get_metrics(manager) do
    manager.metrics
  end

  @doc """
  Flushes the input buffer.
  """
  @spec flush_buffer(t()) :: t()
  def flush_buffer(manager) do
    %{manager | buffer: Buffer.new(manager.buffer.max_size)}
  end

  # Private helper functions

  defp validate_event(manager, event) do
    Enum.reduce_while(manager.validation_rules, :ok, fn rule, :ok ->
      case rule.(event) do
        :ok -> {:cont, :ok}
        :error -> {:halt, {:error, :validation}}
      end
    end)
  end

  defp validate_key(%{key: key}) when is_binary(key) and byte_size(key) > 0, do: :ok
  defp validate_key(_), do: :error

  defp validate_modifiers(%{modifiers: modifiers}) when is_list(modifiers) do
    if Enum.all?(modifiers, &valid_modifier?/1), do: :ok, else: :error
  end
  defp validate_modifiers(_), do: :error

  defp validate_timestamp(%{timestamp: ts}) when is_integer(ts) and ts > 0, do: :ok
  defp validate_timestamp(_), do: :error

  defp valid_modifier?(mod) when mod in [:shift, :ctrl, :alt, :meta], do: true
  defp valid_modifier?(_), do: false

  defp apply_key_mapping(manager, event) do
    case Map.get(manager.key_mappings, event.key) do
      nil -> event
      mapped_key -> %{event | key: mapped_key}
    end
  end

  defp update_metrics(metrics, :processed_events) do
    update_in(metrics.processed_events, &(&1 + 1))
  end
  defp update_metrics(metrics, :validation_failures) do
    update_in(metrics.validation_failures, &(&1 + 1))
  end
  defp update_metrics(metrics, :buffer_overflows) do
    update_in(metrics.buffer_overflows, &(&1 + 1))
  end
  defp update_metrics(metrics, :custom_mappings) do
    update_in(metrics.custom_mappings, &(&1 + 1))
  end
end

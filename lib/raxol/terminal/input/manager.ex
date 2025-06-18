defmodule Raxol.Terminal.Input.Manager do
  @moduledoc """
  Manages terminal input operations with advanced features:
  - Advanced key handling with modifier support
  - Input validation and sanitization
  - Input buffering with timeout handling
  - Input customization and mapping
  """

  alias Raxol.Terminal.{
    Input.Buffer,
    Input.Processor
  }

  @type key_modifier :: :shift | :ctrl | :alt | :meta
  @type key_event :: %{
          key: String.t(),
          modifiers: [key_modifier()],
          timestamp: integer()
        }

  @type t :: %__MODULE__{
          buffer: Buffer.t(),
          processor: Processor.t(),
          metrics: %{
            processed_events: integer(),
            validation_failures: integer(),
            buffer_overflows: integer()
          }
        }

  defstruct [
    :buffer,
    :processor,
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
      metrics: %{
        processed_events: 0,
        validation_failures: 0,
        buffer_overflows: 0
      }
    }
  end

  @doc """
  Processes a key event with validation and mapping.
  """
  @spec process_key_event(t(), key_event()) :: {:ok, t()} | {:error, term()}
  def process_key_event(manager, event) do
    with {:ok, mapped_event} <- Processor.map_event(event),
         {:ok, new_buffer} <- Buffer.add(manager.buffer, mapped_event) do
      _updated_manager = %{manager | buffer: new_buffer}
      {:ok, new_buffer}
    end
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
end

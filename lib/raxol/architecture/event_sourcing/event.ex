defmodule Raxol.Architecture.EventSourcing.Event do
  @moduledoc """
  Event structure for event sourcing implementation in Raxol.

  Events represent facts about what has happened in the system.
  They are immutable and form the single source of truth for all state changes.

  ## Event Design Principles

  1. **Past Tense**: Events represent things that have already happened
  2. **Immutable**: Once created, events cannot be changed
  3. **Rich Information**: Events should contain all relevant data
  4. **Causality**: Events should track what caused them
  5. **Versioned**: Events should support schema evolution

  ## Usage

      defmodule TerminalCreatedEvent do
        use Raxol.Architecture.EventSourcing.Event
        
        defstruct [
          :terminal_id,
          :user_id,
          :width,
          :height,
          :created_at,
          :metadata
        ]
        
        @type t :: %__MODULE__{
          terminal_id: String.t(),
          user_id: String.t(),
          width: pos_integer(),
          height: pos_integer(),
          created_at: integer(),
          metadata: map()
        }
      end
  """

  # @derive Jason.Encoder
  defstruct [
    :id,
    :stream_name,
    :event_type,
    :data,
    :metadata,
    :position,
    :created_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          stream_name: String.t(),
          event_type: module(),
          data: struct(),
          metadata: map(),
          position: non_neg_integer(),
          created_at: integer()
        }

  @type event_data :: struct()
  @type event_metadata :: %{
          correlation_id: String.t() | nil,
          causation_id: String.t() | nil,
          user_id: String.t() | nil,
          timestamp: integer(),
          version: non_neg_integer()
        }

  defmacro __using__(_opts) do
    quote do
      @derive Jason.Encoder

      @doc """
      Creates a new event with metadata.
      """
      def new(attrs) do
        # Add common event metadata if not provided
        attrs_with_defaults =
          attrs
          |> Map.put_new(:created_at, System.system_time(:millisecond))
          |> Map.put_new(:metadata, build_event_metadata(attrs))

        # Create the struct with the provided attributes
        struct(__MODULE__, attrs_with_defaults)
      end

      @doc """
      Gets the event type name.
      """
      def event_type do
        __MODULE__
        |> Module.split()
        |> List.last()
        |> String.replace("Event", "")
      end

      @doc """
      Validates the event data.
      """
      def validate(event) do
        # Default validation - can be overridden
        {:ok, event}
      end

      defoverridable validate: 1

      defp build_event_metadata(attrs) do
        %{
          correlation_id: Map.get(attrs, :correlation_id),
          causation_id: Map.get(attrs, :causation_id),
          user_id: Map.get(attrs, :user_id),
          source: Map.get(attrs, :source, "system"),
          version: Map.get(attrs, :version, 1)
        }
      end
    end
  end

  @doc """
  Creates an event envelope with all required metadata.
  """
  def create_envelope(event_data, stream_name, opts \\ []) do
    %__MODULE__{
      id: generate_event_id(),
      stream_name: stream_name,
      event_type: event_data.__struct__,
      data: event_data,
      metadata: build_metadata(opts),
      position: Keyword.get(opts, :position, 0),
      created_at: System.system_time(:millisecond)
    }
  end

  @doc """
  Extracts the event data from an envelope.
  """
  def extract_data(%__MODULE__{data: data}), do: data

  @doc """
  Gets the event type from an envelope or event data.
  """
  def get_event_type(%__MODULE__{event_type: type}), do: type
  def get_event_type(%{__struct__: type}), do: type

  @doc """
  Checks if an event is of a specific type.
  """
  def is_event_type?(%__MODULE__{event_type: type}, expected_type),
    do: type == expected_type

  def is_event_type?(%{__struct__: type}, expected_type),
    do: type == expected_type

  @doc """
  Serializes an event to JSON.
  """
  def to_json(%__MODULE__{} = event) do
    Jason.encode(event)
  end

  @doc """
  Deserializes an event from JSON.
  """
  def from_json(json) when is_binary(json) do
    case Jason.decode(json, keys: :atoms) do
      {:ok, data} -> from_map(data)
      error -> error
    end
  end

  @doc """
  Creates an event from a map.
  """
  def from_map(map) when is_map(map) do
    event = struct(__MODULE__, map)

    # Deserialize the event data if needed
    event_data =
      case map.data do
        %{__struct__: _} = data ->
          data

        data_map when is_map(data_map) ->
          struct(event.event_type, data_map)

        _ ->
          map.data
      end

    %{event | data: event_data}
  end

  @doc """
  Converts an event to a map for storage.
  """
  def to_map(%__MODULE__{} = event) do
    %{
      id: event.id,
      stream_name: event.stream_name,
      event_type: Module.split(event.event_type) |> Enum.join("."),
      data: Map.from_struct(event.data),
      metadata: event.metadata,
      position: event.position,
      created_at: event.created_at
    }
  end

  @doc """
  Validates event envelope structure.
  """
  def validate_envelope(%__MODULE__{} = event) do
    required_fields = [
      :id,
      :stream_name,
      :event_type,
      :data,
      :position,
      :created_at
    ]

    missing_fields =
      Enum.filter(required_fields, fn field ->
        Map.get(event, field) == nil
      end)

    case Enum.empty?(missing_fields) do
      true ->
        {:ok, event}

      false ->
        {:error, {:missing_fields, missing_fields}}
    end
  end

  @doc """
  Creates event correlation chain.
  """
  def correlate_events(parent_event, child_event) do
    correlation_id =
      case get_correlation_id(parent_event) do
        nil -> parent_event.id
        existing_id -> existing_id
      end

    causation_id = parent_event.id

    %{
      child_event
      | metadata:
          Map.merge(child_event.metadata, %{
            correlation_id: correlation_id,
            causation_id: causation_id
          })
    }
  end

  @doc """
  Gets the correlation ID from an event.
  """
  def get_correlation_id(%__MODULE__{metadata: metadata}) do
    Map.get(metadata, :correlation_id)
  end

  @doc """
  Gets the causation ID from an event.
  """
  def get_causation_id(%__MODULE__{metadata: metadata}) do
    Map.get(metadata, :causation_id)
  end

  @doc """
  Checks if events are correlated.
  """
  def correlated?(%__MODULE__{} = event1, %__MODULE__{} = event2) do
    corr1 = get_correlation_id(event1)
    corr2 = get_correlation_id(event2)

    corr1 != nil and corr2 != nil and corr1 == corr2
  end

  @doc """
  Gets all events in a correlation chain.
  """
  def get_correlation_chain(events, correlation_id) do
    Enum.filter(events, fn event ->
      get_correlation_id(event) == correlation_id
    end)
    |> Enum.sort_by(& &1.position)
  end

  @doc """
  Creates an event migration for schema evolution.
  """
  def migrate_event(%__MODULE__{} = event, migration_fn)
      when is_function(migration_fn, 1) do
    case migration_fn.(event.data) do
      {:ok, migrated_data} ->
        {:ok, %{event | data: migrated_data}}

      {:error, reason} ->
        {:error, {:migration_failed, reason}}
    end
  end

  ## Private Helper Functions

  defp generate_event_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  defp build_metadata(opts) do
    %{
      correlation_id: Keyword.get(opts, :correlation_id),
      causation_id: Keyword.get(opts, :causation_id),
      user_id: Keyword.get(opts, :user_id),
      timestamp: System.system_time(:millisecond),
      version: Keyword.get(opts, :version, 1),
      source: Keyword.get(opts, :source, "system"),
      trace_id: Keyword.get(opts, :trace_id),
      span_id: Keyword.get(opts, :span_id)
    }
  end
end

defmodule Raxol.Architecture.EventSourcing.EventStream do
  @moduledoc """
  Represents a stream of events for a specific aggregate.
  """

  # @derive Jason.Encoder
  defstruct [
    :name,
    :version,
    :last_position,
    :created_at,
    :last_event_at,
    :metadata
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          version: non_neg_integer(),
          last_position: non_neg_integer(),
          created_at: integer(),
          last_event_at: integer() | nil,
          metadata: map()
        }
end

defmodule Raxol.Architecture.EventSourcing.Snapshot do
  @moduledoc """
  Represents a snapshot of aggregate state at a specific version.
  """

  # @derive Jason.Encoder
  defstruct [
    :stream_name,
    :version,
    :data,
    :created_at,
    :metadata
  ]

  @type t :: %__MODULE__{
          stream_name: String.t(),
          version: non_neg_integer(),
          data: term(),
          created_at: integer(),
          metadata: map()
        }
end

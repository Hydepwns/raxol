defmodule Raxol.Agent.Protocol do
  @moduledoc """
  Message format for agent-to-agent and pilot-to-agent communication.

  All cockpit messages use a typed struct with correlation tracking.
  Messages route through `Events.Dispatcher` with topic `:agent_messages`.
  """

  @type message_type ::
          :directive
          | :observation
          | :query
          | :response
          | :takeover
          | :release
          | :status_update
          | :alert

  @type t :: %__MODULE__{
          from: atom(),
          to: atom() | :broadcast,
          type: message_type(),
          payload: term(),
          timestamp: DateTime.t(),
          correlation_id: binary()
        }

  @correlation_id_bytes 8

  @valid_types ~w(directive observation query response takeover release status_update alert)
  @valid_type_atoms Map.new(@valid_types, fn t -> {t, String.to_existing_atom(t)} end)

  @enforce_keys [:from, :to, :type, :payload]
  defstruct [:from, :to, :type, :payload, :timestamp, :correlation_id]

  @doc """
  Creates a new protocol message with auto-generated timestamp and correlation id.
  """
  @spec new(atom(), atom() | :broadcast, message_type(), term()) :: t()
  def new(from, to, type, payload) do
    %__MODULE__{
      from: from,
      to: to,
      type: type,
      payload: payload,
      timestamp: DateTime.utc_now(),
      correlation_id: generate_correlation_id()
    }
  end

  @doc """
  Creates a reply to an existing message, preserving the correlation id.
  """
  @spec reply(t(), atom(), message_type(), term()) :: t()
  def reply(%__MODULE__{} = original, from, type, payload) do
    %__MODULE__{
      from: from,
      to: original.from,
      type: type,
      payload: payload,
      timestamp: DateTime.utc_now(),
      correlation_id: original.correlation_id
    }
  end

  @doc """
  Encodes a message to a JSON-compatible map.
  """
  @spec encode(t()) :: map()
  def encode(%__MODULE__{} = msg) do
    %{
      "from" => to_string(msg.from),
      "to" => to_string(msg.to),
      "type" => to_string(msg.type),
      "payload" => msg.payload,
      "timestamp" => DateTime.to_iso8601(msg.timestamp),
      "correlation_id" => msg.correlation_id
    }
  end

  @doc """
  Decodes a map into a protocol message.
  """
  @spec decode(map()) :: {:ok, t()} | {:error, term()}
  def decode(%{"from" => from, "to" => to, "type" => type} = map)
      when is_binary(from) and is_binary(to) and is_binary(type) do
    with {:ok, type_atom} <- decode_type(type) do
      {:ok,
       %__MODULE__{
         from: safe_agent_atom(from),
         to: decode_to(to),
         type: type_atom,
         payload: Map.get(map, "payload"),
         timestamp: decode_timestamp(Map.get(map, "timestamp")),
         correlation_id: Map.get(map, "correlation_id")
       }}
    end
  end

  def decode(_), do: {:error, :invalid_format}

  defp decode_type(type) do
    case Map.fetch(@valid_type_atoms, type) do
      {:ok, atom} -> {:ok, atom}
      :error -> {:error, {:invalid_type, type}}
    end
  end

  defp decode_to("broadcast"), do: :broadcast
  defp decode_to(to), do: safe_agent_atom(to)

  # Convert agent name to atom only if it already exists in the atom table.
  # Falls back to keeping the string -- callers that need atoms for Registry
  # lookups should pre-register expected agent names.
  defp safe_agent_atom(name) do
    String.to_existing_atom(name)
  rescue
    ArgumentError -> name
  end

  defp decode_timestamp(nil), do: DateTime.utc_now()

  defp decode_timestamp(iso) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _} -> dt
      _ -> DateTime.utc_now()
    end
  end

  defp generate_correlation_id do
    @correlation_id_bytes
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end
end

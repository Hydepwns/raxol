defmodule Raxol.Agent.McpClient.Message do
  @moduledoc """
  JSON-RPC 2.0 message encoding/decoding for the Model Context Protocol.
  """

  @jsonrpc_version "2.0"

  @type request :: %{
          jsonrpc: String.t(),
          id: pos_integer(),
          method: String.t(),
          params: map()
        }

  @type notification :: %{
          jsonrpc: String.t(),
          method: String.t(),
          params: map()
        }

  @type response :: %{
          jsonrpc: String.t(),
          id: pos_integer(),
          result: term()
        }

  @type error_response :: %{
          jsonrpc: String.t(),
          id: pos_integer(),
          error: %{code: integer(), message: String.t(), data: term()}
        }

  @doc "Build a JSON-RPC request."
  @spec request(pos_integer(), String.t(), map()) :: request()
  def request(id, method, params \\ %{}) do
    %{jsonrpc: @jsonrpc_version, id: id, method: method, params: params}
  end

  @doc "Build a JSON-RPC notification (no id, no response expected)."
  @spec notification(String.t(), map()) :: notification()
  def notification(method, params \\ %{}) do
    %{jsonrpc: @jsonrpc_version, method: method, params: params}
  end

  @doc "Encode a message to a JSON string with newline delimiter."
  @spec encode(map()) :: {:ok, iodata()} | {:error, term()}
  def encode(message) do
    case Jason.encode(message) do
      {:ok, json} -> {:ok, [json, "\n"]}
      error -> error
    end
  end

  @doc "Decode a JSON string into a message map with atom keys for known fields."
  @spec decode(String.t()) :: {:ok, map()} | {:error, term()}
  def decode(json) do
    case Jason.decode(json) do
      {:ok, decoded} -> {:ok, normalize(decoded)}
      error -> error
    end
  end

  @doc "Check if a decoded message is a response (has id + result or error)."
  @spec response?(map()) :: boolean()
  def response?(%{id: _id, result: _}), do: true
  def response?(%{id: _id, error: _}), do: true
  def response?(_), do: false

  @doc "Check if a decoded message is an error response."
  @spec error?(map()) :: boolean()
  def error?(%{error: _}), do: true
  def error?(_), do: false

  @doc "Check if a decoded message is a notification (no id)."
  @spec notification?(map()) :: boolean()
  def notification?(%{method: _} = msg), do: not Map.has_key?(msg, :id)
  def notification?(_), do: false

  defp normalize(decoded) do
    decoded
    |> normalize_key("jsonrpc", :jsonrpc)
    |> normalize_key("id", :id)
    |> normalize_key("method", :method)
    |> normalize_key("params", :params)
    |> normalize_key("result", :result)
    |> normalize_key("error", :error)
  end

  defp normalize_key(map, string_key, atom_key) do
    case Map.pop(map, string_key) do
      {nil, map} -> map
      {value, map} -> Map.put(map, atom_key, value)
    end
  end
end

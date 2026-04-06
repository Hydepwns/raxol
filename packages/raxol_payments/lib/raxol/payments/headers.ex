defmodule Raxol.Payments.Headers do
  @moduledoc """
  Shared HTTP header utilities for payment protocol implementations.
  """

  @type headers :: [{String.t(), String.t()}]

  @doc """
  Flatten Req-style headers (map of lists) to a flat list of tuples.
  """
  @spec flatten(map() | headers()) :: headers()
  def flatten(headers) when is_map(headers) do
    Enum.flat_map(headers, fn
      {key, values} when is_list(values) ->
        Enum.map(values, fn v -> {key, v} end)

      {key, value} ->
        [{key, value}]
    end)
  end

  def flatten(headers) when is_list(headers), do: headers

  @doc """
  Find a header value by name (case-insensitive).
  """
  @spec find(headers(), String.t()) :: String.t() | nil
  def find(headers, name) do
    downcased = String.downcase(name)

    Enum.find_value(headers, fn
      {k, v} when is_binary(k) and is_binary(v) ->
        if String.downcase(k) == downcased, do: v

      _ ->
        nil
    end)
  end

  @doc """
  Find a header value by name, returning error if missing.
  """
  @spec require(headers(), String.t()) ::
          {:ok, String.t()} | {:error, {:missing_header, String.t()}}
  def require(headers, name) do
    case find(headers, name) do
      nil -> {:error, {:missing_header, name}}
      value -> {:ok, value}
    end
  end
end

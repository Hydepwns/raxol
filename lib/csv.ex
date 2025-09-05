defmodule CSV do
  @moduledoc """
  Simple CSV encoding functionality.
  This is a minimal implementation for basic CSV export needs.
  """

  @doc """
  Encodes a list of rows into CSV format.
  Each row should be a list of values.
  """
  def encode(rows) do
    Enum.map(rows, &encode_row/1)
  end

  defp encode_row(row) do
    row
    |> Enum.map_join(",", &escape_field/1)
    |> Kernel.<>("\n")
  end

  defp escape_field(value) when is_nil(value), do: ""

  defp escape_field(value) when is_binary(value) do
    case String.contains?(value, [",", "\"", "\n", "\r"]) do
      true ->
        escaped = String.replace(value, "\"", "\"\"")
        "\"#{escaped}\""
      false ->
        value
    end
  end

  defp escape_field(value), do: to_string(value)
end

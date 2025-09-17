defmodule Raxol.Utils.MemoryFormatter do
  @moduledoc """
  Utility functions for formatting memory values.
  """

  @doc """
  Format memory value in bytes to human-readable format.

  ## Examples

      iex> Raxol.Utils.MemoryFormatter.format_memory(1024)
      "1.00 KB"

      iex> Raxol.Utils.MemoryFormatter.format_memory(1048576)
      "1.00 MB"

      iex> Raxol.Utils.MemoryFormatter.format_memory(1073741824)
      "1.00 GB"
  """
  @spec format_memory(number()) :: String.t()
  def format_memory(bytes) when is_number(bytes) do
    cond do
      bytes >= 1_073_741_824 ->
        "#{Float.round(bytes / 1_073_741_824, 2)} GB"

      bytes >= 1_048_576 ->
        "#{Float.round(bytes / 1_048_576, 2)} MB"

      bytes >= 1024 ->
        "#{Float.round(bytes / 1024, 2)} KB"

      true ->
        "#{bytes} B"
    end
  end

  def format_memory(_), do: "0 B"

  @doc """
  Format memory difference with sign.

  ## Examples

      iex> Raxol.Utils.MemoryFormatter.format_memory_diff(1024)
      "+1.00 KB"

      iex> Raxol.Utils.MemoryFormatter.format_memory_diff(-1024)
      "-1.00 KB"
  """
  @spec format_memory_diff(number()) :: String.t()
  def format_memory_diff(bytes) when is_number(bytes) and bytes >= 0 do
    "+" <> format_memory(bytes)
  end

  def format_memory_diff(bytes) when is_number(bytes) and bytes < 0 do
    format_memory(abs(bytes))
    |> String.replace_prefix("", "-")
  end

  def format_memory_diff(_), do: "+0 B"
end

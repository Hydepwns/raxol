defmodule Raxol.Utils.Format do
  @moduledoc """
  Shared formatting utilities for human-readable output.
  """

  @doc """
  Formats a byte count as a human-readable string using SI units (1000-based).

  ## Examples

      iex> Raxol.Utils.Format.format_bytes(1_500_000)
      "1.5 MB"

      iex> Raxol.Utils.Format.format_bytes(512)
      "512 B"
  """
  @spec format_bytes(number()) :: String.t()
  def format_bytes(bytes) when is_number(bytes) and bytes >= 1_000_000_000 do
    "#{Float.round(bytes / 1_000_000_000, 2)} GB"
  end

  def format_bytes(bytes) when is_number(bytes) and bytes >= 1_000_000 do
    "#{Float.round(bytes / 1_000_000, 2)} MB"
  end

  def format_bytes(bytes) when is_number(bytes) and bytes >= 1_000 do
    "#{Float.round(bytes / 1_000, 2)} KB"
  end

  def format_bytes(bytes) when is_number(bytes), do: "#{bytes} B"
  def format_bytes(_), do: "N/A"

  @doc """
  Formats a byte count using binary units (1024-based, IEC).

  ## Examples

      iex> Raxol.Utils.Format.format_bytes_iec(1_048_576)
      "1.0 MB"

      iex> Raxol.Utils.Format.format_bytes_iec(512)
      "512 B"
  """
  @spec format_bytes_iec(number()) :: String.t()
  def format_bytes_iec(bytes)
      when is_number(bytes) and bytes >= 1_073_741_824 do
    "#{Float.round(bytes / 1_073_741_824, 2)} GB"
  end

  def format_bytes_iec(bytes) when is_number(bytes) and bytes >= 1_048_576 do
    "#{Float.round(bytes / 1_048_576, 2)} MB"
  end

  def format_bytes_iec(bytes) when is_number(bytes) and bytes >= 1024 do
    "#{Float.round(bytes / 1024, 2)} KB"
  end

  def format_bytes_iec(bytes) when is_number(bytes), do: "#{bytes} B"
  def format_bytes_iec(_), do: "N/A"
end

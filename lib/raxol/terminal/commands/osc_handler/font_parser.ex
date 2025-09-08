defmodule Raxol.Terminal.Commands.OSCHandler.FontParser do
  @moduledoc """
  Handles parsing of font-related OSC commands.

  This module is used to parse font-related OSC commands into a tuple of {family, size, style}.

  ## Supported Commands

  - OSC 50: Set/Query font
  - OSC 51: Set/Query font size
  """
  @spec parse(String.t()) ::
          {:query, nil}
          | {:set, String.t(), pos_integer() | nil, String.t() | nil}
          | {:error, term()}
  def parse(data) do
    case String.split(data, ";") do
      ["?"] -> {:query, nil}
      parts -> parse_font_parts(parts)
    end
  end

  defp parse_font_parts([family]) do
    {:set, family, nil, nil}
  end

  defp parse_font_parts([family, size_str]) do
    case parse_font_size(size_str) do
      {:ok, size} -> {:set, family, size, nil}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_font_parts([family, size_str, style]) do
    case parse_font_size(size_str) do
      {:ok, size} -> {:set, family, size, style}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_font_parts(_) do
    {:error, :invalid_format}
  end

  defp parse_font_size(size_str) do
    case Integer.parse(size_str) do
      {size, ""} when size > 0 -> {:ok, size}
      _ -> {:error, :invalid_size}
    end
  end
end

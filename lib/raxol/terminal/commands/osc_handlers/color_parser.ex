defmodule Raxol.Terminal.Commands.OSCHandlers.ColorParser do
  @moduledoc """
  Handles parsing of color specifications in various formats.
  """

  import Raxol.Guards

  @doc """
  Parses a color specification string into an RGB tuple.
  """
  @spec parse(String.t()) :: {:ok, {0..255, 0..255, 0..255}} | {:error, term()}
  def parse(spec) do
    cond do
      String.starts_with?(spec, "rgb:") -> parse_rgb_hex(spec)
      String.starts_with?(spec, "#") -> parse_hex_color(spec)
      String.starts_with?(spec, "rgb(") -> parse_rgb_decimal(spec)
      true -> {:error, :unsupported_format}
    end
  end

  @doc """
  Parses an RGB hex color specification.
  """
  def parse_rgb_hex("rgb:" <> rest) do
    case String.split(rest, "/") do
      [r, g, b] ->
        with {:ok, r_val} <- parse_hex_component(r),
             {:ok, g_val} <- parse_hex_component(g),
             {:ok, b_val} <- parse_hex_component(b) do
          {:ok, {r_val, g_val, b_val}}
        else
          _ -> {:error, :invalid_hex_component}
        end

      _ ->
        {:error, :invalid_format}
    end
  end

  defp parse_hex_color("#" <> hex) do
    case String.length(hex) do
      3 -> parse_short_hex(hex)
      6 -> parse_long_hex(hex)
      _ -> {:error, :invalid_hex_length}
    end
  end

  defp parse_short_hex(hex) do
    with [r, g, b] <- String.graphemes(hex),
         {:ok, r_val} <- parse_hex_component(r),
         {:ok, g_val} <- parse_hex_component(g),
         {:ok, b_val} <- parse_hex_component(b) do
      {:ok, {r_val, g_val, b_val}}
    else
      _ -> {:error, :invalid_hex_component}
    end
  end

  defp parse_long_hex(hex) do
    with [r, g, b] <- String.split(hex, "", parts: 3),
         {:ok, r_val} <- parse_hex_component(r),
         {:ok, g_val} <- parse_hex_component(g),
         {:ok, b_val} <- parse_hex_component(b) do
      {:ok, {r_val, g_val, b_val}}
    else
      _ -> {:error, :invalid_hex_component}
    end
  end

  defp parse_rgb_decimal("rgb(" <> rest) do
    with trimmed <- String.trim_trailing(rest, ")"),
         true <- binary?(trimmed),
         [r, g, b] <- String.split(trimmed, ","),
         {:ok, r_val} <- parse_decimal_component(r),
         {:ok, g_val} <- parse_decimal_component(g),
         {:ok, b_val} <- parse_decimal_component(b) do
      {:ok, {r_val, g_val, b_val}}
    else
      _ -> {:error, :invalid_format}
    end
  end

  defp parse_decimal_component(str) do
    with {val, ""} <- Integer.parse(String.trim(str)),
         true <- val >= 0 and val <= 255 do
      {:ok, val}
    else
      _ -> {:error, :invalid_decimal_component}
    end
  end

  defp parse_hex_component(hex_str) do
    len = byte_size(hex_str)

    if len >= 1 and len <= 4 do
      case Integer.parse(hex_str, 16) do
        {val, ""} -> {:ok, scale_hex_value(val, len)}
        _ -> :error
      end
    else
      :error
    end
  end

  defp scale_hex_value(val, len) do
    scaled =
      case len do
        1 -> round(val * 255 / 15)
        2 -> val
        3 -> round(val * 255 / 4095)
        4 -> round(val * 255 / 65_535)
      end

    max(0, min(255, scaled))
  end
end

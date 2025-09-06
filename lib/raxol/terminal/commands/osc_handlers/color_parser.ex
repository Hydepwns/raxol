defmodule Raxol.Terminal.Commands.OSCHandlers.ColorParser do
  @moduledoc """
  Handles parsing of color specifications in various formats.
  """

  @doc """
  Parses a color specification string into an RGB tuple.
  """
  @spec parse(String.t()) :: {:ok, {0..255, 0..255, 0..255}} | {:error, term()}
  def parse(spec) do
    parsers = [
      {"rgb:", &parse_rgb_hex/1},
      {"#", &parse_hex_color/1},
      {"rgb(", &parse_rgb_decimal/1}
    ]

    Enum.find_value(parsers, {:error, :unsupported_format}, fn {prefix, parser} ->
      case String.starts_with?(spec, prefix) do
        true -> parser.(spec)
        false -> nil
      end
    end)
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
         true <- is_binary(trimmed),
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

    case len >= 1 and len <= 4 do
      true ->
        case Integer.parse(hex_str, 16) do
          {val, ""} -> {:ok, scale_hex_value(val, len)}
          _ -> :error
        end
      false ->
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

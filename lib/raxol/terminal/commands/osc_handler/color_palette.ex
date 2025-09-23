defmodule Raxol.Terminal.Commands.OSCHandler.ColorPalette do
  @moduledoc """
  Handles OSC 4 (Color Palette Set/Query) commands.

  This handler manages the terminal's color palette, allowing dynamic
  modification of colors during runtime.

  ## Color Formats Supported

  - rgb:RRRR/GGGG/BBBB (hex, 1-4 digits per component)
  - #RRGGBB (hex, 2 digits per component)
  - #RGB (hex, 1 digit per component)
  - rgb(r,g,b) (decimal, 0-255)
  - rgb(r%,g%,b%) (percentage, 0-100%)
  """

  alias Raxol.Terminal.Emulator
  require Raxol.Core.Runtime.Log

  @spec handle_4(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, term(), Emulator.t()}

  def handle_4(emulator, data) do
    case parse_command(data) do
      {:set, index, spec} ->
        handle_color_set(emulator, index, spec)

      {:query, index} ->
        handle_color_query(emulator, index)

      {:error, reason} ->
        Raxol.Core.Runtime.Log.warning(
          "Invalid OSC 4 command: #{inspect(data)}"
        )

        {:error, reason, emulator}
    end
  end

  defp parse_command(data) do
    case String.split(data, ";", parts: 2) do
      [index_str, spec] -> parse_index_and_spec(index_str, spec)
      _ -> {:error, :invalid_format}
    end
  end

  defp parse_index_and_spec(index_str, spec) do
    case Integer.parse(index_str) do
      {index, ""} when index >= 0 and index <= 255 ->
        case spec do
          "?" -> {:query, index}
          _ -> {:set, index, spec}
        end

      _ ->
        {:error, {:invalid_index, index_str}}
    end
  end

  defp parse_color_spec(spec) do
    color_parsers = [
      {&String.starts_with?(&1, "rgb:"), &parse_rgb_hex/1},
      {&String.starts_with?(&1, "#"), &parse_hex_color/1},
      {&String.starts_with?(&1, "rgb("), &parse_rgb_decimal/1}
    ]

    Enum.find_value(color_parsers, {:error, :unsupported_format}, fn {check,
                                                                      parser} ->
      case check.(spec) do
        true -> parser.(spec)
        false -> nil
      end
    end)
  end

  defp parse_rgb_hex(spec) do
    # Delegate to the dedicated color parser
    Raxol.Terminal.Commands.OSCHandler.ColorParser.parse_rgb_hex(spec)
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
    case String.trim_trailing(rest, ")") do
      rest when is_binary(rest) -> parse_rgb_components(rest)
    end
  end

  defp parse_rgb_components(rest) do
    case String.split(rest, ",") do
      [r, g, b] -> validate_rgb_values(r, g, b)
      _ -> {:error, :invalid_format}
    end
  end

  defp validate_rgb_values(r, g, b) do
    with {:ok, r_val} <- parse_and_validate_component(r),
         {:ok, g_val} <- parse_and_validate_component(g),
         {:ok, b_val} <- parse_and_validate_component(b) do
      {:ok, {r_val, g_val, b_val}}
    else
      _ -> {:error, :invalid_decimal_component}
    end
  end

  defp parse_and_validate_component(str) do
    case Integer.parse(String.trim(str)) do
      {val, ""} when val >= 0 and val <= 255 -> {:ok, val}
      _ -> {:error, :invalid_component}
    end
  end

  defp parse_hex_component(hex_str) do
    len = byte_size(hex_str)

    case len < 1 or len > 4 do
      true ->
        :error

      false ->
        parse_hex_value(hex_str, len)
    end
  end

  defp parse_hex_value(hex_str, len) do
    case Integer.parse(hex_str, 16) do
      {val, ""} ->
        scaled_val = scale_hex_value(val, len)
        {:ok, max(0, min(255, scaled_val))}

      _ ->
        :error
    end
  end

  defp scale_hex_value(val, len) do
    case len do
      1 -> round(val * 255 / 15)
      2 -> val
      3 -> round(val * 255 / 4095)
      4 -> round(val * 255 / 65_535)
    end
  end

  defp get_palette_color(palette, index) do
    case Map.get(palette, index) do
      nil -> {:error, :not_found}
      color -> {:ok, color}
    end
  end

  defp format_color_response(index, {r, g, b}) do
    "4;#{index};rgb:#{:io_lib.format("~2.16.0B", [r])}/#{:io_lib.format("~2.16.0B", [g])}/#{:io_lib.format("~2.16.0B", [b])}"
  end

  defp handle_color_set(emulator, index, spec) do
    case parse_color_spec(spec) do
      {:ok, color} ->
        new_palette = Map.put(emulator.colors.palette, index, color)
        new_colors = %{emulator.colors | palette: new_palette}
        {:ok, %{emulator | colors: new_colors}}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.warning(
          "Invalid color specification: #{inspect(spec)}"
        )

        {:error, {:invalid_color, reason}, emulator}
    end
  end

  defp handle_color_query(emulator, index) do
    case get_palette_color(emulator.colors.palette, index) do
      {:ok, color} ->
        response = format_color_response(index, color)
        {:ok, %{emulator | output_buffer: response}}

      {:error, _} ->
        Raxol.Core.Runtime.Log.warning("Invalid color index: #{inspect(index)}")

        {:error, {:invalid_index, index}, emulator}
    end
  end
end

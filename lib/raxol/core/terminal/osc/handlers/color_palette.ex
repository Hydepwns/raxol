defmodule Raxol.Core.Terminal.OSC.Handlers.ColorPalette do
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

  @doc """
  Handles OSC 4 commands for color palette management.

  ## Commands

  - `4;c;spec` - Set color c to spec
  - `4;c;?` - Query color c

  Where:
  - c is the color index (0-255)
  - spec is the color specification
  """
  def handle("4;" <> rest, state) do
    case parse_command(rest) do
      {:set, index, spec} -> handle_set(index, spec, state)
      {:query, index} -> handle_query(index, state)
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_set(index, spec, state) do
    case parse_color_spec(spec) do
      {:ok, color} ->
        new_palette = Map.put(state.palette, index, color)
        {:ok, %{state | palette: new_palette}}

      {:error, reason} ->
        {:error, {:invalid_color, reason}}
    end
  end

  defp handle_query(index, state) do
    case get_palette_color(state.palette, index) do
      {:ok, color} -> {:ok, state, format_color_response(index, color)}
      {:error, _} -> {:error, {:invalid_index, index}}
    end
  end

  # Private Helpers

  defp parse_command(rest) do
    with [index_str, spec] <- String.split(rest, ";", parts: 2),
         {index, ""} <- Integer.parse(index_str),
         true <- index >= 0 and index <= 255 do
      if spec == "?", do: {:query, index}, else: {:set, index, spec}
    else
      _ -> {:error, :invalid_format}
    end
  end

  defp parse_color_spec(spec) do
    cond do
      parse_rgb_colon(spec) != :no_match -> parse_rgb_colon(spec)
      parse_hex6(spec) != :no_match -> parse_hex6(spec)
      parse_hex3(spec) != :no_match -> parse_hex3(spec)
      parse_rgb_decimal(spec) != :no_match -> parse_rgb_decimal(spec)
      parse_rgb_percent(spec) != :no_match -> parse_rgb_percent(spec)
      true -> {:error, "unsupported color format"}
    end
  end

  defp parse_and_validate_rgb({r, g, b}) do
    with {:ok, r} <- parse_component(r),
         {:ok, g} <- parse_component(g),
         {:ok, b} <- parse_component(b) do
      {:ok, {r, g, b}}
    else
      _ -> :no_match
    end
  end

  defp parse_rgb_colon(spec) do
    if String.starts_with?(spec, "rgb:") do
      case String.split(String.trim_leading(spec, "rgb:"), "/", parts: 3) do
        [r_hex, g_hex, b_hex] ->
          parse_and_validate_rgb({r_hex, g_hex, b_hex})

        _ ->
          :no_match
      end
    else
      :no_match
    end
  end

  defp parse_hex6(spec) do
    if String.starts_with?(spec, "#") and byte_size(spec) == 7 do
      r_hex = String.slice(spec, 1..2)
      g_hex = String.slice(spec, 3..4)
      b_hex = String.slice(spec, 5..6)

      parse_and_validate_rgb({r_hex, g_hex, b_hex})
    else
      :no_match
    end
  end

  defp parse_hex3(spec) do
    if String.starts_with?(spec, "#") and byte_size(spec) == 4 do
      r1 = String.slice(spec, 1..1)
      g1 = String.slice(spec, 2..2)
      b1 = String.slice(spec, 3..3)

      parse_and_validate_rgb({r1 <> r1, g1 <> g1, b1 <> b1})
    else
      :no_match
    end
  end

  defp parse_rgb_decimal(spec) do
    if String.match?(spec, ~r/^rgb\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*\)$/) do
      case Regex.run(~r/rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)/, spec,
             capture: :all_but_first
           ) do
        [r_str, g_str, b_str] ->
          parse_and_validate_rgb({r_str, g_str, b_str})

        _ ->
          :no_match
      end
    else
      :no_match
    end
  end

  defp parse_rgb_percent(spec) do
    if String.match?(spec, ~r/^rgb\(\s*\d+%\s*,\s*\d+%\s*,\s*\d+%\s*\)$/) do
      case Regex.run(~r/rgb\(\s*(\d+)%\s*,\s*(\d+)%\s*,\s*(\d+)%\s*\)/, spec,
             capture: :all_but_first
           ) do
        [r_str, g_str, b_str] ->
          parse_and_validate_rgb({r_str, g_str, b_str})

        _ ->
          :no_match
      end
    else
      :no_match
    end
  end

  # Parses hex color component (1-4 digits), scales to 0-255 appropriately
  defp parse_component(hex_str) do
    len = byte_size(hex_str)
    if len < 1 or len > 4, do: :error

    case Integer.parse(hex_str, 16) do
      {val, ""} ->
        scaled_val =
          case len do
            1 -> round(val * 255 / 15)
            2 -> val
            3 -> round(val * 255 / 4095)
            4 -> round(val * 255 / 65_535)
          end

        {:ok, max(0, min(255, scaled_val))}

      _ ->
        :error
    end
  end

  defp format_color_response(index, {r, g, b}) do
    # Format: OSC 4;index;rgb:r/g/b
    # Scale up to 16-bit range (0-65535)
    r_scaled =
      Integer.to_string(div(r * 65_535, 255), 16) |> String.pad_leading(4, "0")

    g_scaled =
      Integer.to_string(div(g * 65_535, 255), 16) |> String.pad_leading(4, "0")

    b_scaled =
      Integer.to_string(div(b * 65_535, 255), 16) |> String.pad_leading(4, "0")

    "4;#{index};rgb:#{r_scaled}/#{g_scaled}/#{b_scaled}"
  end

  # Helper for safe palette access
  defp get_palette_color(palette, index)
       when is_integer(index) and index >= 0 and index <= 255 do
    case Map.get(palette, index) do
      nil -> {:error, :invalid_color_index}
      color -> {:ok, color}
    end
  end

  defp get_palette_color(_palette, _index), do: {:error, :invalid_color_index}
end

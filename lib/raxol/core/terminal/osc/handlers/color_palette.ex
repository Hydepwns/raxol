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

  alias Raxol.Core.Terminal.Color
  alias Raxol.Core.Terminal.State
  require Raxol.Core.Runtime.Log

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
      {:set, index, spec} ->
        case parse_color_spec(spec) do
          {:ok, color} ->
            new_palette = Map.put(state.palette, index, color)
            new_state = %{state | palette: new_palette}
            {:ok, new_state}

          {:error, reason} ->
            {:error, {:invalid_color, reason}}
        end

      {:query, index} ->
        case get_palette_color(state.palette, index) do
          {:ok, color} ->
            response = format_color_response(index, color)
            {:ok, state, response}
          {:error, _} ->
            {:error, {:invalid_index, index}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private Helpers

  defp parse_command(rest) do
    case String.split(rest, ";", parts: 2) do
      [index_str, spec] ->
        case Integer.parse(index_str) do
          {index, ""} when index >= 0 and index <= 255 ->
            if spec == "?" do
              {:query, index}
            else
              {:set, index, spec}
            end

          _ ->
            {:error, {:invalid_index, index_str}}
        end

      _ ->
        {:error, :invalid_format}
    end
  end

  defp parse_color_spec(spec) do
    cond do
      # rgb:RR/GG/BB (hex, 1-4 digits per component)
      String.starts_with?(spec, "rgb:") ->
        case String.split(String.trim_leading(spec, "rgb:"), "/", parts: 3) do
          [r_hex, g_hex, b_hex] ->
            with {:ok, r} <- parse_hex_component(r_hex),
                 {:ok, g} <- parse_hex_component(g_hex),
                 {:ok, b} <- parse_hex_component(b_hex) do
              {:ok, {r, g, b}}
            else
              _ -> {:error, "invalid rgb: component(s)"}
            end

          _ ->
            {:error, "invalid rgb: format"}
        end

      # #RRGGBB (hex, 2 digits)
      String.starts_with?(spec, "#") and byte_size(spec) == 7 ->
        r_hex = String.slice(spec, 1..2)
        g_hex = String.slice(spec, 3..4)
        b_hex = String.slice(spec, 5..6)

        with {r, ""} <- Integer.parse(r_hex, 16),
             {g, ""} <- Integer.parse(g_hex, 16),
             {b, ""} <- Integer.parse(b_hex, 16) do
          {:ok, {r, g, b}}
        else
          _ -> {:error, "invalid #RRGGBB hex value(s)"}
        end

      # #RGB (hex, 1 digit - scale R*17, G*17, B*17)
      String.starts_with?(spec, "#") and byte_size(spec) == 4 ->
        r1 = String.slice(spec, 1..1)
        g1 = String.slice(spec, 2..2)
        b1 = String.slice(spec, 3..3)

        with {r, ""} <- Integer.parse(r1 <> r1, 16),
             {g, ""} <- Integer.parse(g1 <> g1, 16),
             {b, ""} <- Integer.parse(b1 <> b1, 16) do
          {:ok, {r, g, b}}
        else
          _ -> {:error, "invalid #RGB hex value(s)"}
        end

      # rgb(r,g,b) (decimal, 0-255)
      String.match?(spec, ~r/^rgb\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*\)$/) ->
        case Regex.run(~r/rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)/, spec,
               capture: :all_but_first
             ) do
          [r_str, g_str, b_str] ->
            with {r, ""} <- Integer.parse(r_str),
                 {g, ""} <- Integer.parse(g_str),
                 {b, ""} <- Integer.parse(b_str),
                 true <- r >= 0 and r <= 255,
                 true <- g >= 0 and g <= 255,
                 true <- b >= 0 and b <= 255 do
              {:ok, {r, g, b}}
            else
              _ -> {:error, "rgb() values must be between 0 and 255"}
            end

          _ ->
            {:error, "invalid rgb() format"}
        end

      # rgb(r%,g%,b%) (percentage, 0-100%)
      String.match?(spec, ~r/^rgb\(\s*\d+%\s*,\s*\d+%\s*,\s*\d+%\s*\)$/) ->
        case Regex.run(~r/rgb\(\s*(\d+)%\s*,\s*(\d+)%\s*,\s*(\d+)%\s*\)/, spec,
               capture: :all_but_first
             ) do
          [r_str, g_str, b_str] ->
            with {r_pct, ""} <- Integer.parse(r_str),
                 {g_pct, ""} <- Integer.parse(g_str),
                 {b_pct, ""} <- Integer.parse(b_str),
                 true <- r_pct >= 0 and r_pct <= 100,
                 true <- g_pct >= 0 and g_pct <= 100,
                 true <- b_pct >= 0 and b_pct <= 100 do
              r = round(r_pct * 255 / 100)
              g = round(g_pct * 255 / 100)
              b = round(b_pct * 255 / 100)
              {:ok, {r, g, b}}
            else
              _ -> {:error, "rgb() percentage values must be between 0 and 100"}
            end

          _ ->
            {:error, "invalid rgb() percentage format"}
        end

      true ->
        {:error, "unsupported color format"}
    end
  end

  # Parses hex color component (1-4 digits), scales to 0-255 appropriately
  defp parse_hex_component(hex_str) do
    len = byte_size(hex_str)

    if len >= 1 and len <= 4 do
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
    else
      :error
    end
  end

  defp format_color_response(index, {r, g, b}) do
    # Format: OSC 4;index;rgb:r/g/b
    # Scale up to 16-bit range (0-65535)
    r_scaled = Integer.to_string(div(r * 65_535, 255), 16) |> String.pad_leading(4, "0")
    g_scaled = Integer.to_string(div(g * 65_535, 255), 16) |> String.pad_leading(4, "0")
    b_scaled = Integer.to_string(div(b * 65_535, 255), 16) |> String.pad_leading(4, "0")
    "4;#{index};rgb:#{r_scaled}/#{g_scaled}/#{b_scaled}"
  end

  # Helper for safe palette access
  defp get_palette_color(palette, index) when is_integer(index) and index >= 0 and index <= 255 do
    case Map.get(palette, index) do
      nil -> {:error, :invalid_color_index}
      color -> {:ok, color}
    end
  end
  defp get_palette_color(_palette, _index), do: {:error, :invalid_color_index}
end

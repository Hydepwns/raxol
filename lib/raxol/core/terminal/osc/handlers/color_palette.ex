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

  @spec handle_set(non_neg_integer(), any(), map()) ::
          {:ok, any()} | {:error, any()}
  defp handle_set(index, spec, state) do
    case parse_color_spec(spec) do
      {:ok, color} ->
        new_palette = Map.put(state.palette, index, color)
        {:ok, %{state | palette: new_palette}}

      {:error, reason} ->
        {:error, {:invalid_color, reason}}
    end
  end

  @spec handle_query(non_neg_integer(), map()) ::
          {:ok, any(), any()} | {:error, any()}
  defp handle_query(index, state) do
    case get_palette_color(state.palette, index) do
      {:ok, color} -> {:ok, state, format_color_response(index, color)}
      {:error, _} -> {:error, {:invalid_index, index}}
    end
  end

  # Private Helpers

  @spec parse_command(String.t()) ::
          {:query, non_neg_integer()}
          | {:set, non_neg_integer(), String.t()}
          | {:error, :invalid_format | {:invalid_index, String.t()}}
  defp parse_command(rest) do
    case String.split(rest, ";", parts: 2) do
      [index_str, spec] ->
        case Integer.parse(index_str) do
          {index, ""} when index >= 0 and index <= 255 ->
            is_query = spec == "?"
            parse_command_type(is_query, index, spec)

          {_index, ""} ->
            {:error, {:invalid_index, index_str}}

          _ ->
            {:error, :invalid_format}
        end

      _ ->
        {:error, :invalid_format}
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

  @spec parse_and_validate_rgb({binary(), binary(), binary()}) ::
          {:ok, {integer(), integer(), integer()}} | :no_match
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
    starts_with_rgb = String.starts_with?(spec, "rgb:")
    parse_rgb_colon_by_prefix(starts_with_rgb, spec)
  end

  defp parse_hex6(spec) do
    is_hex6_format = String.starts_with?(spec, "#") and byte_size(spec) == 7
    parse_hex6_by_format(is_hex6_format, spec)
  end

  defp parse_hex3(spec) do
    is_hex3_format = String.starts_with?(spec, "#") and byte_size(spec) == 4
    parse_hex3_by_format(is_hex3_format, spec)
  end

  defp parse_rgb_decimal(spec) do
    matches_decimal_format =
      String.match?(spec, ~r/^rgb\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*\)$/)

    parse_rgb_decimal_by_format(matches_decimal_format, spec)
  end

  defp parse_rgb_percent(spec) do
    matches_percent_format =
      String.match?(spec, ~r/^rgb\(\s*\d+%\s*,\s*\d+%\s*,\s*\d+%\s*\)$/)

    parse_rgb_percent_by_format(matches_percent_format, spec)
  end

  @spec parse_and_validate_decimal({binary(), binary(), binary()}) ::
          {:ok, {integer(), integer(), integer()}} | :no_match
  defp parse_and_validate_decimal({r_str, g_str, b_str}) do
    with {:ok, r} <- parse_decimal_component(r_str),
         {:ok, g} <- parse_decimal_component(g_str),
         {:ok, b} <- parse_decimal_component(b_str) do
      {:ok, {r, g, b}}
    else
      _ -> :no_match
    end
  end

  @spec parse_and_validate_percent({binary(), binary(), binary()}) ::
          {:ok, {integer(), integer(), integer()}} | :no_match
  defp parse_and_validate_percent({r_str, g_str, b_str}) do
    with {:ok, r} <- parse_percent_component(r_str),
         {:ok, g} <- parse_percent_component(g_str),
         {:ok, b} <- parse_percent_component(b_str) do
      {:ok, {r, g, b}}
    else
      _ -> :no_match
    end
  end

  # Parses decimal color component (0-255)
  defp parse_decimal_component(decimal_str) do
    case Integer.parse(decimal_str) do
      {val, ""} when val >= 0 and val <= 255 -> {:ok, val}
      _ -> :error
    end
  end

  # Parses percentage color component (0-100%) and converts to 0-255
  defp parse_percent_component(percent_str) do
    case Integer.parse(percent_str) do
      {val, ""} when val >= 0 and val <= 100 ->
        {:ok, round(val * 255 / 100)}

      _ ->
        :error
    end
  end

  # Parses hex color component (1-4 digits), scales to 0-255 appropriately
  defp parse_component(hex_str) do
    len = byte_size(hex_str)
    valid_length = len >= 1 and len <= 4
    parse_component_by_length_validity(valid_length, hex_str, len)
  end

  @spec parse_component_by_length_validity(String.t(), String.t(), String.t()) ::
          {:ok, any()} | {:error, any()}
  defp parse_component_by_length_validity(false, _hex_str, _len), do: :error

  @spec parse_component_by_length_validity(String.t(), String.t(), String.t()) ::
          {:ok, any()} | {:error, any()}
  defp parse_component_by_length_validity(true, hex_str, len) do
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

  ## Helper Functions for Pattern Matching

  @spec parse_command_type(boolean(), non_neg_integer(), String.t()) ::
          {:query, non_neg_integer()} | {:set, non_neg_integer(), String.t()}
  defp parse_command_type(true, index, _spec), do: {:query, index}
  defp parse_command_type(false, index, spec), do: {:set, index, spec}

  @spec parse_rgb_colon_by_prefix(String.t(), String.t()) ::
          {:ok, any()} | {:error, any()}
  defp parse_rgb_colon_by_prefix(true, spec) do
    case String.split(String.trim_leading(spec, "rgb:"), "/", parts: 3) do
      [r_hex, g_hex, b_hex] ->
        parse_and_validate_rgb({r_hex, g_hex, b_hex})

      _ ->
        :no_match
    end
  end

  @spec parse_rgb_colon_by_prefix(String.t(), String.t()) ::
          {:ok, any()} | {:error, any()}
  defp parse_rgb_colon_by_prefix(false, _spec), do: :no_match

  @spec parse_hex6_by_format(String.t(), String.t()) ::
          {:ok, any()} | {:error, any()}
  defp parse_hex6_by_format(true, spec) do
    r_hex = String.slice(spec, 1..2)
    g_hex = String.slice(spec, 3..4)
    b_hex = String.slice(spec, 5..6)

    parse_and_validate_rgb({r_hex, g_hex, b_hex})
  end

  @spec parse_hex6_by_format(String.t(), String.t()) ::
          {:ok, any()} | {:error, any()}
  defp parse_hex6_by_format(false, _spec), do: :no_match

  @spec parse_hex3_by_format(String.t(), String.t()) ::
          {:ok, any()} | {:error, any()}
  defp parse_hex3_by_format(true, spec) do
    r1 = String.slice(spec, 1..1)
    g1 = String.slice(spec, 2..2)
    b1 = String.slice(spec, 3..3)

    parse_and_validate_rgb({r1 <> r1, g1 <> g1, b1 <> b1})
  end

  @spec parse_hex3_by_format(String.t(), String.t()) ::
          {:ok, any()} | {:error, any()}
  defp parse_hex3_by_format(false, _spec), do: :no_match

  @spec parse_rgb_decimal_by_format(String.t(), String.t()) ::
          {:ok, any()} | {:error, any()}
  defp parse_rgb_decimal_by_format(true, spec) do
    case Regex.run(~r/rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)/, spec,
           capture: :all_but_first
         ) do
      [r_str, g_str, b_str] ->
        parse_and_validate_decimal({r_str, g_str, b_str})

      _ ->
        :no_match
    end
  end

  @spec parse_rgb_decimal_by_format(String.t(), String.t()) ::
          {:ok, any()} | {:error, any()}
  defp parse_rgb_decimal_by_format(false, _spec), do: :no_match

  @spec parse_rgb_percent_by_format(String.t(), String.t()) ::
          {:ok, any()} | {:error, any()}
  defp parse_rgb_percent_by_format(true, spec) do
    case Regex.run(~r/rgb\(\s*(\d+)%\s*,\s*(\d+)%\s*,\s*(\d+)%\s*\)/, spec,
           capture: :all_but_first
         ) do
      [r_str, g_str, b_str] ->
        parse_and_validate_percent({r_str, g_str, b_str})

      _ ->
        :no_match
    end
  end

  @spec parse_rgb_percent_by_format(String.t(), String.t()) ::
          {:ok, any()} | {:error, any()}
  defp parse_rgb_percent_by_format(false, _spec), do: :no_match
end

defmodule Raxol.Terminal.ANSI.SixelRenderer do
  @moduledoc """
  Handles rendering Sixel graphics data from a pixel buffer.
  """

  require Raxol.Core.Runtime.Log
  import Bitwise

  # For sixel_state type
  alias Raxol.Terminal.ANSI.SixelGraphics

  @doc """
  Renders the image stored in the pixel_buffer as a Sixel data stream.
  """
  @spec render_image(SixelGraphics.sixel_state()) ::
          {:ok, binary()} | {:error, atom()}
  def render_image(state) do
    %{pixel_buffer: pixel_buffer, palette: palette, attributes: attrs} = state

    if map_size(pixel_buffer) == 0 do
      # No image data to render
      {:ok, ""}
    else
      # 1. Determine image dimensions and collect used colors
      {max_x, max_y, used_colors} =
        Enum.reduce(pixel_buffer, {0, 0, MapSet.new()}, fn {{x, y}, color_index},
                                                           {acc_max_x,
                                                            acc_max_y,
                                                            acc_colors} ->
          {max(x, acc_max_x), max(y, acc_max_y),
           MapSet.put(acc_colors, color_index)}
        end)

      # Image dimensions in pixels (0-indexed, so add 1)
      width = max_x + 1
      height = max_y + 1

      # 2. Start Sixel stream with raster attributes
      # Pan;Pad;Ph;Pv - Aspect ratio numerator/denominator, Width, Height
      # Sixel default aspect is typically 1:1 or 2:1, need to check spec. Using 1:1 for now.
      # Use provided attributes if they exist, otherwise use calculated dimensions.
      pan = Map.get(attrs, :aspect_num, 1)
      pad = Map.get(attrs, :aspect_den, 1)
      ph = Map.get(attrs, :width) || width
      pv = Map.get(attrs, :height) || height

      # Initial DCS sequence with raster attributes
      dcs_start =
        <<"\eP", Integer.to_string(pan)::binary, ";",
          Integer.to_string(pad)::binary, ";", Integer.to_string(ph)::binary,
          ";", Integer.to_string(pv)::binary, "q">>

      # 3. Define colors used in the image
      color_definitions =
        used_colors
        |> MapSet.to_list()
        |> Enum.map(fn color_index ->
          case get_palette_color(palette, color_index) do
            {:ok, {r, g, b}} ->
              # Convert RGB 0-255 to Sixel 0-100 scale
              sixel_r = round(r * 100 / 255)
              sixel_g = round(g * 100 / 255)
              sixel_b = round(b * 100 / 255)

              <<"#", Integer.to_string(color_index)::binary, ";2;",
                Integer.to_string(sixel_r)::binary, ";",
                Integer.to_string(sixel_g)::binary, ";",
                Integer.to_string(sixel_b)::binary>>

            {:error, _} ->
              Raxol.Core.Runtime.Log.warning_with_context("Sixel Render: Color index #{color_index} not found in palette.", %{})
              ""
          end
        end)
        # Concatenate all color definition strings
        |> Enum.join()

      # 4. Generate Sixel pixel data (column by column is often simpler for Sixel)
      # This part is complex: Group pixels into 6-high bands, generate characters.
      # Placeholder for now.
      sixel_pixel_data =
        generate_pixel_data(pixel_buffer, width, height, used_colors)

      # 5. End Sixel stream
      dcs_end = "\e\\"

      {:ok,
       IO.iodata_to_binary([
         dcs_start,
         color_definitions,
         sixel_pixel_data,
         dcs_end
       ])}
    end
  end

  # Helper function to generate the core Sixel pixel data string
  # Implements Run-Length Encoding (RLE) for optimization.
  defp generate_pixel_data(pixel_buffer, width, height, _used_colors) do
    # Assume SixelPalette.rgb_to_color_index/2 exists and returns index or nil
    # Need to pass the palette state from the parsing stage!
    # Placeholder: Assume `_palette` variable is available
    _palette = %{}

    # Sixel data is built column by column, band by band (6 rows high).
    sixel_bands =
      for band_y <- 0..(height - 1)//6 do
        # Process one 6-row high horizontal band across the image width
        current_band_height = min(6, height - band_y * 6)

        # Accumulator for the RLE logic: {band_commands, last_color, last_char, repeat_count}
        initial_acc = {[], nil, nil, 0}

        # Iterate through columns, applying RLE
        # Capture the full final accumulator
        {final_band_commands, _final_last_color, final_last_char,
         final_repeat_count} =
          for x <- 0..(width - 1), reduce: initial_acc do
            {acc_commands, last_color, last_char, repeat_count} ->
              # Collect pixels for the current column slice (x, band_y*6) to (x, band_y*6 + 5)
              column_pixels_by_color =
                (band_y * 6)..(band_y * 6 + current_band_height - 1)
                |> Enum.reduce(%{}, fn y, acc ->
                  case Map.get(pixel_buffer, {x, y}) do
                    # Ignore empty pixels
                    nil ->
                      acc

                    color_index ->
                      Map.update(acc, color_index, [{y, 1}], fn existing ->
                        [{y, 1} | existing]
                      end)
                  end
                end)
                |> Map.new(fn {color_index, y_coords} ->
                  # Calculate the sixel bitmask for this color in this column slice
                  bitmask =
                    Enum.reduce(y_coords, 0, fn {y, _}, mask_acc ->
                      row_in_band = rem(y, 6)
                      # Bit positions: 0 (top) to 5 (bottom)
                      mask_acc ||| Bitwise.bsl(1, row_in_band)
                    end)

                  {color_index, bitmask}
                end)

              # -- RLE Logic Start --
              # For simplicity in this RLE implementation, we only encode runs
              # where a *single* color+bitmask pair repeats across columns.
              # Handling RLE for multi-color columns is significantly more complex.

              # Initialize vars outside the if with defaults
              current_color = 0
              current_char = <<>>

              is_simple_column = map_size(column_pixels_by_color) == 1

              if is_simple_column do
                [{c, b}] = Map.to_list(column_pixels_by_color)
                # Prefix internal assignment only
                _current_color = c
                # Prefix internal assignment only
                _current_char = <<b + 63>>
              end

              # Check if the current simple column matches the previous one
              if is_simple_column and current_color == last_color and
                   current_char == last_char do
                # Continue the run
                {acc_commands, last_color, last_char, repeat_count + 1}
              else
                # Run ended (or never started, or complex column encountered)
                # Output the previous run if it existed
                output_commands =
                  case repeat_count do
                    # No previous run
                    0 ->
                      []

                    # Output single char
                    1 ->
                      [last_char]

                    # Output RLE
                    count ->
                      [<<"!", Integer.to_string(count)::binary>>, last_char]
                  end

                # Prepare commands for the current column (if any)
                current_column_commands =
                  column_pixels_by_color
                  |> Enum.flat_map(fn {color_index, bitmask} ->
                    sixel_char = <<bitmask + 63>>
                    # Select color, then emit character
                    [
                      <<"#", Integer.to_string(color_index)::binary>>,
                      sixel_char
                    ]
                  end)

                # Add carriage return if multiple colors were drawn
                current_column_commands =
                  if map_size(column_pixels_by_color) > 1 do
                    current_column_commands ++ ["-"]
                  else
                    current_column_commands
                  end

                # Determine color selection command and next RLE state
                {color_selection_cmd_for_new_run, new_last_color, new_last_char,
                 new_repeat_count} =
                  if is_simple_column do
                    # Prepare the command to select the new color
                    safe_color_index = current_color || 0
                    cmd = [<<"#", Integer.to_string(safe_color_index)::binary>>]
                    # Start new run of 1
                    {cmd, current_color, current_char, 1}
                  else
                    # Reset RLE state, no selection command needed now
                    {[], nil, nil, 0}
                  end

                # Combine output commands
                combined_output =
                  if new_repeat_count == 1 do
                    # Started a new run, prepend color selection command
                    output_commands ++
                      color_selection_cmd_for_new_run ++ current_column_commands
                  else
                    # Did not start a new run (complex column or end of data)
                    output_commands ++ current_column_commands
                  end

                {acc_commands ++ combined_output, new_last_color, new_last_char,
                 new_repeat_count}
              end
          end

        # end reduce loop (columns)

        # After the loop, output any remaining run using values from the final accumulator
        final_output_commands =
          case {final_last_char, final_repeat_count} do
            # No run pending
            {nil, _} -> []
            # Output single char
            {char, 1} -> [char]
            # Output RLE
            {char, count} -> [<<"!", Integer.to_string(count)::binary>>, char]
          end

        # Add line feed ('$') to move to next band
        [IO.iodata_to_binary(final_band_commands ++ final_output_commands), "$"]
      end

    # end sixel_bands loop

    # Remove trailing '$' from the last band
    final_data =
      case List.last(sixel_bands) do
        # Replace last element
        [data, "$"] -> List.replace_at(sixel_bands, -1, [data])
        # Should not happen if height > 0
        _ -> sixel_bands
      end

    IO.iodata_to_binary(List.flatten(final_data))
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

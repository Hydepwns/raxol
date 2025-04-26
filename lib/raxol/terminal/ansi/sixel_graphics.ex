defmodule Raxol.Terminal.ANSI.SixelGraphics do
  @moduledoc """
  Handles Sixel graphics for the terminal emulator.
  Supports:
  - Sixel color palette management
  - Sixel image rendering
  - Sixel image scaling
  - Sixel image positioning
  - Sixel image attributes
  """

  require Logger

  alias Raxol.Terminal.ANSI.SequenceParser
  alias Raxol.Terminal.ANSI.SixelPatternMap
  alias Raxol.Terminal.ANSI.SixelPalette

  @type sixel_state :: %{
          palette: map(),          # Current color palette {index => {r,g,b}}
          current_color: integer(), # Currently selected color index
          position: {integer(), integer()}, # Top-left corner for rendering (obsolete?)
          attributes: map(),      # Raster attributes from last " command
          # image_data: binary()    # Obsolete: Replaced by pixel_buffer
          pixel_buffer: map()      # Resulting image data %{ {x, y} => color_index }
        }

  # Represents the state during the parsing of a Sixel stream
  defmodule ParserState do
    @type t :: %__MODULE__{
            x: integer(),             # Current horizontal pixel position
            y: integer(),             # Current vertical pixel position (top of sixel band)
            color_index: integer(),   # Currently selected color index
            repeat_count: integer(),  # Repeat count from '!' command
            palette: map(),           # Current color palette (can be modified by '#')
            raster_attrs: map(),      # Raster attributes from '"' command
            pixel_buffer: map(),      # Accumulator for pixel data %{ {x, y} => color_index }
            max_x: integer(),         # Tracks max width encountered
            max_y: integer()          # Tracks max height encountered
          }

    defstruct [
      :x,
      :y,
      :color_index,
      :repeat_count,
      :palette,
      :raster_attrs,
      :pixel_buffer,
      :max_x,
      :max_y
    ]
  end

  @type sixel_attribute ::
          :normal | :double_width | :double_height | :double_size

  @doc """
  Creates a new Sixel state with default values.
  """
  @spec new() :: %{
          palette: map(),
          current_color: 0,
          position: {0, 0},
          attributes: %{width: :normal, height: :normal, size: :normal},
          pixel_buffer: %{}
        }
  def new do
    %{
      palette: SixelPalette.initialize_palette(),
      current_color: 0,
      position: {0, 0},
      attributes: %{
        width: :normal,
        height: :normal,
        size: :normal
      },
      pixel_buffer: %{}
    }
  end

  @doc """
  Processes a Sixel sequence (DCS P...q DATA ST) and returns the updated state.

  The pixel data is stored in `state.pixel_buffer`.
  """
  @spec process_sequence(sixel_state(), binary()) :: {sixel_state(), :ok | {:error, term()}}
  def process_sequence(state, <<"\eP", rest::binary>>) do
    # Find the end of the sequence (ST)
    case :binary.match(rest, "\e\\") do
      {st_pos, _st_len} ->
        dcs_content = :binary.part(rest, 0, st_pos)
        # Find the start of the data (after 'q')
        case :binary.match(dcs_content, "q") do
          {q_pos, _q_len} ->
            param_str = :binary.part(dcs_content, 0, q_pos)
            sixel_data = :binary.part(dcs_content, q_pos + 1, byte_size(dcs_content) - q_pos - 1)

            # TODO: Parse initial DCS parameters (P1;P2;P3) from param_str
            _initial_params = parse_dcs_params(param_str)

            # Initialize parser state
            initial_parser_state = %ParserState{
              x: 0,
              y: 0,
              color_index: 0,
              repeat_count: 1,
              palette: state.palette,
              raster_attrs: %{ # Default raster attributes
                aspect_num: 1,
                aspect_den: 1,
                width: nil,
                height: nil
              },
              pixel_buffer: %{},
              max_x: 0,
              max_y: 0
            }

            # Parse the actual data
            case parse_sixel_data(sixel_data, initial_parser_state) do
              {:ok, final_parser_state} ->
                # Update the main state with results from the parser
                updated_state = %{
                  state
                  | palette: final_parser_state.palette, # Palette might have changed
                    attributes: final_parser_state.raster_attrs, # Store final raster attributes
                    pixel_buffer: final_parser_state.pixel_buffer
                    # current_color: final_parser_state.color_index # Maybe store last color?
                }
                {updated_state, :ok}

              {:error, reason} ->
                Logger.error("Sixel data parsing failed: #{inspect(reason)}")
                {state, {:error, reason}} # Return original state on error
            end

          :nomatch ->
            Logger.error("Invalid Sixel DCS: missing 'q'")
            {state, {:error, :missing_q}}
        end

      :nomatch ->
        Logger.error("Invalid Sixel DCS: missing ST '\e\\'")
        {state, {:error, :missing_st}}
    end
  end

  # Handle non-DCS sequences (maybe log warning or ignore)
  def process_sequence(state, other_sequence) do
     Logger.warning("Received non-Sixel sequence in SixelGraphics: #{inspect(other_sequence)}")
     {state, {:error, :invalid_sequence}}
  end

  # --- Parsing Logic ---

  # Placeholder for DCS parameter parsing
  defp parse_dcs_params(_param_str), do: %{}

  @doc false
  # Main recursive Sixel data parser
  defp parse_sixel_data(<<>>, parser_state) do
    # End of stream
    {:ok, parser_state}
  end

  # Raster Attributes
  defp parse_sixel_data(<<?", rest::binary>>, parser_state) do
    # Parse " Pan;Pad;Ph;Pv
    case SequenceParser.consume_integer_params(rest) do
      {[pan, pad, ph, pv], remaining_data, _count} ->
        Logger.debug(
          "Sixel Parser: Found Raster Attributes. Pan=#{pan}, Pad=#{pad}, Ph=#{ph}, Pv=#{pv}"
        )

        new_attrs = %{
          aspect_num: pan || 1,
          aspect_den: pad || 1,
          width: ph,
          height: pv
        }

        parse_sixel_data(remaining_data, %{parser_state | raster_attrs: new_attrs})

      {_params, _remaining_data, 0} ->
        # No params provided, treat as default (or keep existing? Check spec - keeping existing for now)
        Logger.debug("Sixel Parser: Found Raster Attributes with no parameters.")
        parse_sixel_data(rest, parser_state) # Effectively skips just the '"'

      {:error, reason} ->
        Logger.warning("Sixel Parser: Error parsing Raster Attributes: #{inspect(reason)}. Skipping.")
        # Decide how to handle error - skip the likely malformed params?
        # For now, just skip the '"' and continue
        parse_sixel_data(rest, parser_state)
    end
  end

  # Color Definition
  defp parse_sixel_data(<<?#, rest::binary>>, parser_state) do
    # Parse # Pc;Pa;Px;Py;Pz
    case SequenceParser.consume_integer_params(rest) do
      {[pc | color_params], remaining_data, _count} ->
        if pc >= 0 and pc <= SixelPalette.max_colors() do
          color_space = List.first(color_params) || 1 # Default to HLS
          color_values = List.drop(color_params, 1)

          px = Enum.at(color_values, 0) || 0
          py = Enum.at(color_values, 1) || 0
          pz = Enum.at(color_values, 2) || 0

          case convert_color(color_space, px, py, pz) do
            {:ok, {r, g, b}} ->
              Logger.debug(
                "Sixel Parser: Defining Color ##{pc}. Space=#{color_space}, Vals=#{px};#{py};#{pz} -> RGB(#{r},#{g},#{b})"
              )
              new_palette = Map.put(parser_state.palette, pc, {r, g, b})
              parse_sixel_data(remaining_data, %{
                parser_state
                | palette: new_palette,
                  color_index: pc # Select the newly defined color
              })

            {:error, reason} ->
              Logger.warning(
                "Sixel Parser: Invalid color definition ##{pc}: #{inspect(reason)}. Skipping."
              )
              parse_sixel_data(remaining_data, parser_state) # Skip invalid definition
          end
        else
          Logger.warning("Sixel Parser: Invalid color index ##{pc}. Skipping.")
          parse_sixel_data(remaining_data, parser_state)
        end

      {_params, _remaining_data, 0} ->
        # No params means select color 0
        Logger.debug("Sixel Parser: Found Color Definition with no parameters (Selecting color 0).")
        parse_sixel_data(rest, %{parser_state | color_index: 0}) # Skip only '#'

      {:error, reason} ->
        Logger.warning("Sixel Parser: Error parsing Color Definition: #{inspect(reason)}. Skipping.")
        parse_sixel_data(rest, parser_state)
    end
  end

  # Repeat Command
  defp parse_sixel_data(<<?!, rest::binary>>, parser_state) do
    # Parse ! Pn <char>
    case SequenceParser.consume_integer_params(rest) do
      {[pn], remaining_data, _count} when pn > 0 ->
        Logger.debug("Sixel Parser: Found Repeat Command !#{pn}")
        # We only set the repeat count here.
        # The *next* character processed will use this count.
        parse_sixel_data(remaining_data, %{parser_state | repeat_count: pn})

      {_params, remaining_data, 0} ->
        # '!' without params is invalid according to some sources, but could mean repeat=1?
        # Treat as no-op for now, just consume '!'.
        Logger.debug("Sixel Parser: Found Repeat Command without parameters (Skipping).")
        parse_sixel_data(rest, parser_state) # Skip just '!'

      {_, remaining_data, _} -> # Includes pn <= 0 or multiple params
        Logger.warning("Sixel Parser: Invalid repeat count found. Skipping repeat command.")
        parse_sixel_data(remaining_data, parser_state)

      {:error, reason} ->
        Logger.warning("Sixel Parser: Error parsing Repeat Command: #{inspect(reason)}. Skipping.")
        parse_sixel_data(rest, parser_state) # Skip just '!'
    end
  end

  # Carriage Return
  defp parse_sixel_data(<<?$, rest::binary>>, parser_state) do
    Logger.debug("Sixel Parser: Found CR ($)")
    parse_sixel_data(rest, %{parser_state | x: 0})
  end

  # Newline
  defp parse_sixel_data(<<?-, rest::binary>>, parser_state) do
    Logger.debug("Sixel Parser: Found NL (-)")
    new_y = parser_state.y + 6
    parse_sixel_data(rest, %{parser_state | x: 0, y: new_y, max_y: max(parser_state.max_y, new_y + 5)})
  end

  # Data Character
  defp parse_sixel_data(<<char_code, rest::binary>>, parser_state) when char_code >= ?\? and char_code <= ?~ do
    pattern_int = SixelPatternMap.get_pattern(char_code)
    pixels = SixelPatternMap.pattern_to_pixels(pattern_int)
    repeat = parser_state.repeat_count
    start_x = parser_state.x
    y = parser_state.y
    color = parser_state.color_index

    # Optimize pixel buffer update using batching
    new_pixels_batch =
      for i <- 0..(repeat - 1), reduce: %{} do
        acc ->
          current_x = start_x + i
          Enum.reduce(0..5, acc, fn bit_index, inner_acc ->
            if Enum.at(pixels, bit_index) == 1 do
              Map.put(inner_acc, {current_x, y + bit_index}, color)
            else
              inner_acc
            end
          end)
      end

    new_buffer = Map.merge(parser_state.pixel_buffer, new_pixels_batch)

    new_x = start_x + repeat
    updated_state = %{
      parser_state |
      x: new_x,
      repeat_count: 1, # Reset repeat count after use
      pixel_buffer: new_buffer,
      max_x: max(parser_state.max_x, new_x - 1), # Track max column used
      max_y: max(parser_state.max_y, y + 5)      # Track max row used
    }
    parse_sixel_data(rest, updated_state)
  end

  # Unknown/Invalid Character
  defp parse_sixel_data(<<byte, rest::binary>>, parser_state) do
    Logger.warning("Sixel Parser: Skipping invalid byte #{byte}")
    parse_sixel_data(rest, parser_state)
  end

  # --- Color Conversion Helpers ---

  defp convert_color(color_space, px, py, pz) do
    # Clamp values to 0-100 range
    px = max(0, min(100, px))
    py = max(0, min(100, py))
    pz = max(0, min(100, pz))

    case color_space do
      1 -> # HLS (Hue: 0-360 -> Px*3.6, Lightness: 0-100 -> Py, Saturation: 0-100 -> Pz)
        h = px * 3.6
        l = py / 100.0
        s = pz / 100.0
        hls_to_rgb(h, l, s)
      2 -> # RGB (R: 0-100 -> Px, G: 0-100 -> Py, B: 0-100 -> Pz)
        r = round(px * 2.55)
        g = round(py * 2.55)
        b = round(pz * 2.55)
        {:ok, {r, g, b}}
      _ ->
        {:error, :unknown_color_space}
    end
  end

  # Simplified HLS to RGB conversion (based on standard formulas)
  # Input: H (0-360), L (0-1), S (0-1)
  # Output: {:ok, {R, G, B}} (0-255)
  defp hls_to_rgb(h, l, s) do
    if s == 0 do
      # Achromatic
      val = round(l * 255)
      {:ok, {val, val, val}}
    else
      c = (1 - abs(2 * l - 1)) * s
      h_prime = h / 60.0
      x = c * (1 - abs(rem(h_prime, 2) - 1))

      {r1, g1, b1} =
        cond do
          h_prime < 1 -> {c, x, 0}
          h_prime < 2 -> {x, c, 0}
          h_prime < 3 -> {0, c, x}
          h_prime < 4 -> {0, x, c}
          h_prime < 5 -> {x, 0, c}
          true -> {c, 0, x}
        end

      m = l - c / 2

      r = round((r1 + m) * 255)
      g = round((g1 + m) * 255)
      b = round((b1 + m) * 255)
      {:ok, {r, g, b}}
    end
  end

  # --- Rendering Logic ---

  @doc """
  Renders the image stored in the pixel_buffer as a Sixel data stream.
  """
  @spec render_image(sixel_state()) :: {:ok, binary()} | {:error, atom()}
  def render_image(state) do
    %{pixel_buffer: pixel_buffer, palette: palette, attributes: attrs} = state

    if map_size(pixel_buffer) == 0 do
      {:ok, ""} # No image data to render
    else
      # 1. Determine image dimensions and collect used colors
      {max_x, max_y, used_colors} =
        Enum.reduce(pixel_buffer, {0, 0, MapSet.new()}, fn {{x, y}, color_index},
                                                          {acc_max_x, acc_max_y, acc_colors} ->
          {max(x, acc_max_x),
           max(y, acc_max_y),
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
      dcs_start = <<"\eP", Integer.to_string(pan)::binary, ";",
                    Integer.to_string(pad)::binary, ";",
                    Integer.to_string(ph)::binary, ";",
                    Integer.to_string(pv)::binary, "q">>

      # 3. Define colors used in the image
      color_definitions =
        used_colors
        |> MapSet.to_list()
        |> Enum.map(fn color_index ->
          case Map.get(palette, color_index) do
            {r, g, b} ->
              # Convert RGB 0-255 to Sixel 0-100 scale
              sixel_r = round(r * 100 / 255)
              sixel_g = round(g * 100 / 255)
              sixel_b = round(b * 100 / 255)

              <<"#", Integer.to_string(color_index)::binary, ";2;",
                Integer.to_string(sixel_r)::binary, ";",
                Integer.to_string(sixel_g)::binary, ";",
                Integer.to_string(sixel_b)::binary>>

            nil ->
              # Color not found in palette, skip definition (or use default?)
              Logger.warning("Sixel Render: Color index #{color_index} not found in palette.")
              ""
          end
        end)
        |> Enum.join() # Concatenate all color definition strings

      # 4. Generate Sixel pixel data (column by column is often simpler for Sixel)
      # This part is complex: Group pixels into 6-high bands, generate characters.
      # Placeholder for now.
      sixel_pixel_data = generate_pixel_data(pixel_buffer, width, height, used_colors)

      # 5. End Sixel stream
      dcs_end = "\e\\"

      {:ok, IO.iodata_to_binary([dcs_start, color_definitions, sixel_pixel_data, dcs_end])}
    end
  end

  # Helper function to generate the core Sixel pixel data string
  # Implements Run-Length Encoding (RLE) for optimization.
  defp generate_pixel_data(pixel_buffer, width, height, _used_colors) do
    # Sixel data is built column by column, band by band (6 rows high).
    sixel_bands = for band_y <- 0..(height - 1) // 6 do
      # Process one 6-row high horizontal band across the image width
      current_band_height = min(6, height - band_y * 6)

      # Accumulator for the RLE logic: {band_commands, last_color, last_char, repeat_count}
      initial_acc = {[], nil, nil, 0}

      # Iterate through columns, applying RLE
      {final_band_commands, _, _, _} =
        for x <- 0..(width - 1), reduce: initial_acc do
        {acc_commands, last_color, last_char, repeat_count} ->
          # Collect pixels for the current column slice (x, band_y*6) to (x, band_y*6 + 5)
          # Group them by color index
          column_pixels_by_color =
            (band_y * 6)..(band_y * 6 + current_band_height - 1)
            |> Enum.reduce(%{}, fn y, acc ->
              case Map.get(pixel_buffer, {x, y}) do
                nil -> acc # Ignore empty pixels
                color_index -> Map.update(acc, color_index, [{y, 1}], fn existing -> [{y, 1} | existing] end)
              end
            end)
            |> Map.new(fn {color_index, y_coords} ->
                 # Calculate the sixel bitmask for this color in this column slice
                 bitmask = Enum.reduce(y_coords, 0, fn {y, _}, mask_acc ->
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

          current_color = nil
          current_char = nil
          is_simple_column = map_size(column_pixels_by_color) == 1

          if is_simple_column do
             [{c, b}] = Map.to_list(column_pixels_by_color)
             current_color = c
             current_char = <<(b + 63)>>
          end

          # Check if the current simple column matches the previous one
          if is_simple_column and current_color == last_color and current_char == last_char do
             # Continue the run
            {acc_commands, last_color, last_char, repeat_count + 1}
          else
            # Run ended (or never started, or complex column encountered)
            # Output the previous run if it existed
            output_commands =
              case repeat_count do
                0 -> [] # No previous run
                1 -> [last_char] # Output single char
                count -> [<<"!", Integer.to_string(count)::binary>>, last_char] # Output RLE
              end

            # Prepare commands for the current column (if any)
            current_column_commands =
              column_pixels_by_color
              |> Enum.flat_map(fn {color_index, bitmask} ->
                   sixel_char = <<(bitmask + 63)>>
                   # Select color, then emit character
                   [<<"#", Integer.to_string(color_index)::binary>>, sixel_char]
                 end)

            # Add carriage return if multiple colors were drawn
            current_column_commands =
              if map_size(column_pixels_by_color) > 1 do
                 current_column_commands ++ ["-"]
              else
                 current_column_commands
              end

            # Start a new run if it's a simple column, otherwise reset RLE state
            {new_last_color, new_last_char, new_repeat_count} =
              if is_simple_column do
                 # Select the new color before starting the run
                 color_selection_cmd = [<<"#", Integer.to_string(current_color)::binary>>]
                 {current_color, current_char, 1} # Start new run of 1
              else
                 {nil, nil, 0} # Reset RLE state
              end

            # Combine output commands
            # If starting a new run, prepend the color selection
            combined_output =
              if new_repeat_count == 1 do
                output_commands ++ color_selection_cmd ++ current_column_commands
              else
                output_commands ++ current_column_commands
              end

            {acc_commands ++ combined_output, new_last_color, new_last_char, new_repeat_count}
          end
        # -- RLE Logic End --
      end # end reduce loop (columns)

      # After the loop, output any remaining run
      final_output_commands =
        case {last_char, repeat_count} do
          {nil, _} -> [] # No run pending
          {char, 1} -> [char] # Output single char
          {char, count} -> [<<"!", Integer.to_string(count)::binary>>, char] # Output RLE
        end

      # Add line feed ('$') to move to next band
      [IO.iodata_to_binary(final_band_commands ++ final_output_commands), "$"]

    end # end sixel_bands loop

    # Remove trailing '$' from the last band
    final_data =
      case List.last(sixel_bands) do
        [data, "$"] -> List.replace_at(sixel_bands, -1, [data]) # Replace last element
        _ -> sixel_bands # Should not happen if height > 0
      end

    IO.iodata_to_binary(List.flatten(final_data))

  end

  # Obsolete - kept for reference if needed, but pixel_buffer is source now
  # def calculate_dimensions(image_data, attributes) do ... end
  # def render_sixel_data(image_data, position, attributes) do ... end
end

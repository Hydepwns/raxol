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
  # Import Bitwise for operators
  import Bitwise

  alias Raxol.Terminal.ANSI.SixelPatternMap
  alias Raxol.Terminal.ANSI.SixelPalette

  @type sixel_state :: %{
          # Current color palette {index => {r,g,b}}
          palette: map(),
          # Currently selected color index
          current_color: integer(),
          # Top-left corner for rendering (obsolete?)
          position: {integer(), integer()},
          # Raster attributes from last " command
          attributes: map(),
          # image_data: binary()    # Obsolete: Replaced by pixel_buffer
          # Resulting image data %{ {x, y} => color_index }
          pixel_buffer: map()
        }

  # Represents the state during the parsing of a Sixel stream
  defmodule ParserState do
    @type t :: %__MODULE__{
            # Current horizontal pixel position
            x: integer(),
            # Current vertical pixel position (top of sixel band)
            y: integer(),
            # Currently selected color index
            color_index: integer(),
            # Repeat count from '!' command
            repeat_count: integer(),
            # Current color palette (can be modified by '#')
            palette: map(),
            # Raster attributes from '"' command
            raster_attrs: map(),
            # Accumulator for pixel data %{ {x, y} => color_index }
            pixel_buffer: map(),
            # Tracks max width encountered
            max_x: integer(),
            # Tracks max height encountered
            max_y: integer()
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
  @spec process_sequence(sixel_state(), binary()) ::
          {sixel_state(), :ok | {:error, term()}}
  # Use explicit ASCII values for ESC P (27, 80)
  def process_sequence(state, <<27, 80, rest::binary>>) do
    # Find the end of the sequence (ST = ESC \ = 27, 92)
    case :binary.match(rest, <<27, 92>>) do
      {st_pos, _st_len} ->
        content_before_st = :binary.part(rest, 0, st_pos)

        # Logger.debug("process_sequence: Found ST at #{st_pos}, content_before_st: #{inspect(content_before_st)}")

        # Attempt to parse initial DCS parameters first (optional)
        # We assume parameters end before the 'q'
        case consume_integer_params(content_before_st) do
          {:ok, initial_params, after_params} ->
            # Logger.debug("process_sequence: Parsed initial params: #{inspect(initial_params)}, after_params: #{inspect(after_params)}")
            # Now look for 'q' in the part *after* the parameters
            case :binary.match(after_params, "q") do
              # 'q' must be immediately after params (or at start if no params)
              {q_pos, _q_len} when q_pos == 0 ->
                sixel_data =
                  :binary.part(
                    after_params,
                    q_pos + 1,
                    byte_size(after_params) - q_pos - 1
                  )

                # Logger.debug("process_sequence: Found q after params, sixel_data: #{inspect(sixel_data)}")

                # TODO: Use initial_params if needed (e.g., P1=pixel aspect ratio, P2=background color mode)
                # Updated placeholder call
                _initial_params_map = parse_dcs_params_list(initial_params)

                # Initialize parser state
                initial_parser_state = %ParserState{
                  x: 0,
                  y: 0,
                  color_index: 0,
                  repeat_count: 1,
                  palette: state.palette,
                  # Default raster attributes
                  raster_attrs: %{
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
                parse_result =
                  parse_sixel_data(sixel_data, initial_parser_state)

                # Logger.debug("process_sequence: parse_sixel_data result: #{inspect(parse_result)}")

                case parse_result do
                  {:ok, final_parser_state} ->
                    # Update the main state with results from the parser
                    updated_state = %{
                      state
                      | # Palette might have changed
                        palette: final_parser_state.palette,
                        # Store final raster attributes
                        attributes: final_parser_state.raster_attrs,
                        pixel_buffer: final_parser_state.pixel_buffer,
                        position: {final_parser_state.x, final_parser_state.y},
                        current_color: final_parser_state.color_index
                    }

                    # Logger.debug("process_sequence: Returning OK, final state: #{inspect(updated_state)}")
                    {updated_state, :ok}

                  {:error, reason} ->
                    # Logger.error("Sixel data parsing failed: #{inspect(reason)}")
                    # Logger.debug("process_sequence: Returning ERROR from parse_sixel_data: #{inspect(reason)}")
                    # Return original state on error
                    {state, {:error, reason}}
                end

              # 'q' not found immediately after params, or other content present
              _ ->
                # Logger.error("Invalid Sixel DCS: missing 'q' immediately after parameters or invalid content before 'q'. Found: #{inspect(after_params)}")
                # Logger.debug("process_sequence: Returning ERROR :missing_or_misplaced_q")
                {state, {:error, :missing_or_misplaced_q}}
            end

          # Error parsing initial parameters
          {:error, reason, _} ->
            # Logger.error("Invalid Sixel DCS: error parsing initial parameters: #{inspect(reason)}")
            # Logger.debug("process_sequence: Returning ERROR :invalid_initial_params")
            {state, {:error, :invalid_initial_params}}
        end

      :nomatch ->
        # Logger.error("Invalid Sixel DCS: missing ST '\\e\\'")
        # Logger.debug("process_sequence: Returning ERROR :missing_st")
        {state, {:error, :missing_st}}
    end
  end

  # Handle non-DCS sequences (restore this clause)
  def process_sequence(state, other_sequence) do
    Logger.warning(
      "Received non-Sixel sequence in SixelGraphics: #{inspect(other_sequence)}"
    )

    {state, {:error, :invalid_sequence}}
  end

  # --- Parsing Logic ---

  # Helper to parse integer parameters like Pn1;Pn2;... from the start of a binary
  # Returns {:ok, [param1, param2, ...], rest_of_binary} or {:error, reason, original_binary}
  def consume_integer_params(input_binary) do
    # Regex to find leading digits, optionally separated by semicolons
    # It captures the entire param section and the rest
    case Regex.run(~r/^([0-9;]*)(.*)/s, input_binary) do
      # Case 1: Params found (e.g., "1;2;3...")
      [_full_match, param_section, rest_of_binary] when param_section != "" ->
        try do
          params =
            param_section
            # Keep empty strings like in "1;;3"
            |> String.split(";", trim: false)
            |> Enum.map(fn
              # Default empty param to 0 (common Sixel behavior)
              "" -> 0
              str -> String.to_integer(str)
            end)

          {:ok, params, rest_of_binary}
        rescue
          # Catch errors during String.to_integer
          e in ArgumentError ->
            {:error, {"Invalid integer parameter in '#{param_section}'", e},
             input_binary}
        end

      # Case 2: No numeric/semicolon characters at the start (param_section is "")
      # e.g., input starts with '#', '$', '-', '?', etc.
      [_full_match, "", rest_of_binary] ->
        # No parameters found before the non-parameter character
        # Return empty list and the rest of the binary
        {:ok, [], rest_of_binary}

      # Case 3: Regex doesn't match at all (should not happen with `.*`, but good practice)
      nil ->
        # Treat as no parameters found
        {:ok, [], input_binary}
    end
  end

  # Placeholder for DCS parameter parsing
  defp parse_dcs_params(_param_str), do: %{}

  # Placeholder for parsing the list of initial integer parameters
  defp parse_dcs_params_list(params_list) when is_list(params_list) do
    # Example: P1=pixel aspect ratio, P2=background color mode, P3=horizontal grid size
    %{
      p1: Enum.at(params_list, 0),
      p2: Enum.at(params_list, 1),
      p3: Enum.at(params_list, 2)
    }
  end

  @doc false
  # Main recursive Sixel data parser
  defp parse_sixel_data(data, state) when is_binary(data) do
    # Handle end-of-stream, space, or other characters
    case data do
      # End of stream
      <<>> ->
        {:ok, state}

      # Ignore space
      <<" ", rest::binary>> ->
        parse_sixel_data(rest, state)

      # Process other characters (commands or data)
      _ ->
        # Parse " Pan;Pad;Ph;Pv (moved the original case content here)
        # Inner case to handle actual commands/data
        case data do
          <<"\"", rest::binary>> ->
            # Use local helper
            case consume_integer_params(rest) do
              {:ok, [pan, pad, ph, pv], remaining_data} ->
                Logger.debug(
                  "Sixel Parser: Found Raster Attributes. Pan=#{pan}, Pad=#{pad}, Ph=#{ph}, Pv=#{pv}"
                )

                new_attrs = %{
                  aspect_num: pan || 1,
                  aspect_den: pad || 1,
                  width: ph,
                  height: pv
                }

                parse_sixel_data(remaining_data, %{
                  state
                  | raster_attrs: new_attrs
                })

              # Handle case where params might be fewer than 4 - use Enum.at or defaults
              {:ok, params, remaining_data} ->
                Logger.debug(
                  "Sixel Parser: Found Raster Attributes with params: #{inspect(params)}"
                )

                pan = Enum.at(params, 0)
                pad = Enum.at(params, 1)
                ph = Enum.at(params, 2)
                pv = Enum.at(params, 3)

                new_attrs = %{
                  aspect_num: pan || 1,
                  aspect_den: pad || 1,
                  # ph/pv can be nil if not provided
                  width: ph,
                  height: pv
                }

                parse_sixel_data(remaining_data, %{
                  state
                  | raster_attrs: new_attrs
                })

              {:error, reason, _original_binary} ->
                Logger.warning(
                  "Sixel Parser: Error parsing Raster Attributes: #{inspect(reason)}. Skipping."
                )

                # Decide how to handle error - skip the likely malformed params?
                # For now, just skip the '"' and continue
                parse_sixel_data(rest, state)
            end

          # Parse # Pc;Pa;Px;Py;Pz
          <<"#", rest::binary>> ->
            Logger.debug(
              "Sixel Parser: Matched '#' command. Rest: #{inspect(rest)}"
            )

            # Use local helper
            case consume_integer_params(rest) do
              {:ok, [pc | color_params], remaining_data} ->
                Logger.debug(
                  "Sixel Parser: Parsed color definition params: pc=#{pc}, color_params=#{inspect(color_params)}, remaining=#{inspect(remaining_data)}"
                )

                if pc >= 0 and pc <= SixelPalette.max_colors() do
                  # Default to HLS if Pa missing
                  color_space = Enum.at(color_params, 0) || 1
                  px = Enum.at(color_params, 1) || 0
                  py = Enum.at(color_params, 2) || 0
                  # Use Enum.at for safety
                  pz = Enum.at(color_params, 3) || 0

                  case convert_color(color_space, px, py, pz) do
                    {:ok, {r, g, b}} ->
                      Logger.debug(
                        "Sixel Parser: Defining Color ##{pc}. Space=#{color_space}, Vals=#{px};#{py};#{pz} -> RGB(#{r},#{g},#{b})"
                      )

                      new_palette = Map.put(state.palette, pc, {r, g, b})

                      Logger.debug(
                        "Sixel Parser: Setting color_index to #{pc} before recursive call."
                      )

                      parse_sixel_data(remaining_data, %{
                        state
                        | palette: new_palette,
                          # Select the newly defined color
                          color_index: pc
                      })

                    {:error, reason} ->
                      Logger.warning(
                        "Sixel Parser: Invalid color definition ##{pc}: #{inspect(reason)}. Skipping."
                      )

                      # Skip invalid definition
                      parse_sixel_data(remaining_data, state)
                  end
                else
                  Logger.warning(
                    "Sixel Parser: Invalid color index ##{pc}. Skipping."
                  )

                  parse_sixel_data(remaining_data, state)
                end

              # Handle case where only Pc is provided (or empty params)
              {:ok, params, remaining_data} ->
                Logger.debug(
                  "Sixel Parser: Parsed color selection params: params=#{inspect(params)}, remaining=#{inspect(remaining_data)}"
                )

                case params do
                  # Only Pc provided
                  [pc] ->
                    if pc >= 0 and pc <= SixelPalette.max_colors() do
                      Logger.debug("Sixel Parser: Selecting Color ##{pc}")

                      Logger.debug(
                        "Sixel Parser: Setting color_index to #{pc} before recursive call."
                      )

                      parse_sixel_data(remaining_data, %{
                        state
                        | color_index: pc
                      })
                    else
                      Logger.warning(
                        "Sixel Parser: Invalid color index ##{pc} for selection. Skipping."
                      )

                      parse_sixel_data(remaining_data, state)
                    end

                  # No params means select color 0
                  [] ->
                    Logger.debug(
                      "Sixel Parser: Found Color Definition with no parameters (Selecting color 0)."
                    )

                    Logger.debug(
                      "Sixel Parser: Setting color_index to 0 before recursive call."
                    )

                    parse_sixel_data(remaining_data, %{state | color_index: 0})

                  # Unexpected number of params
                  _ ->
                    Logger.warning(
                      "Sixel Parser: Unexpected params for Color Definition: #{inspect(params)}. Skipping."
                    )

                    parse_sixel_data(remaining_data, state)
                end

              {:error, reason, _original_binary} ->
                Logger.warning(
                  "Sixel Parser: Error parsing Color Definition: #{inspect(reason)}. Skipping."
                )

                parse_sixel_data(rest, state)
            end

          # Parse ! Pn <char>
          <<"!", rest::binary>> ->
            # Use local helper
            case consume_integer_params(rest) do
              {:ok, [pn], remaining_data} when pn > 0 ->
                Logger.debug("Sixel Parser: Found Repeat Command !#{pn}")
                # We only set the repeat count here.
                # The *next* character processed will use this count.
                parse_sixel_data(remaining_data, %{state | repeat_count: pn})

              # Includes pn <= 0, Renamed _pn to pn
              {:ok, [pn], remaining_data} ->
                Logger.warning(
                  "Sixel Parser: Invalid repeat count found (!#{pn}). Skipping repeat command."
                )

                parse_sixel_data(remaining_data, state)

              # No params
              {:ok, [], remaining_data} ->
                Logger.debug(
                  "Sixel Parser: Found Repeat Command without parameters (Skipping)."
                )

                parse_sixel_data(remaining_data, state)

              {:error, reason, _original_binary} ->
                Logger.warning(
                  "Sixel Parser: Error parsing Repeat Command: #{inspect(reason)}. Skipping."
                )

                # Skip just '!'
                parse_sixel_data(rest, state)
            end

          # Parse CR ($)
          <<"$", rest::binary>> ->
            # Fix: Process the character data *before* moving cursor
            char_byte = ?$
            pattern_int = SixelPatternMap.get_pattern(char_byte)

            if pattern_int != nil do
              # Simplified pixel generation for just this char (no repeat)
              y = state.y
              color = state.color_index
              x = state.x

              new_pixels =
                Enum.reduce(0..5, %{}, fn bit_index, acc ->
                  is_set =
                    Bitwise.band(pattern_int, Bitwise.bsl(1, bit_index)) != 0

                  if is_set,
                    do: Map.put(acc, {x, y + bit_index}, color),
                    else: acc
                end)

              # Update buffer and max dimensions
              updated_buffer = Map.merge(state.pixel_buffer, new_pixels)
              new_max_x = max(state.max_x, x)
              new_max_y = max(state.max_y, y + 5)

              # Reset x to 0, keep y the same, continue parsing
              parse_sixel_data(rest, %{
                state
                | x: 0,
                  pixel_buffer: updated_buffer,
                  max_x: new_max_x,
                  max_y: new_max_y
              })
            else
              # Should not happen for '$', but handle defensively
              parse_sixel_data(rest, %{state | x: 0})
            end

          # Parse NL (-), move to next line
          <<"-", rest::binary>> ->
            Logger.debug("Sixel Parser: Found NL (-)")
            new_y = state.y + 6

            parse_sixel_data(rest, %{
              state
              | x: 0,
                y: new_y,
                max_y: max(state.max_y, new_y + 5)
            })

          # Parse data character
          <<char_byte, remaining_data::binary>> ->
            # Validate it's within the valid range
            if char_byte >= ?\? and char_byte <= ?\~ do
              # --- Restored Pixel Generation Logic ---
              pattern_int = SixelPatternMap.get_pattern(char_byte)
              pixels = SixelPatternMap.pattern_to_pixels(pattern_int)
              repeat = state.repeat_count
              start_x = state.x
              y = state.y
              color = state.color_index

              new_pixels_batch =
                for i <- 0..(repeat - 1), reduce: %{} do
                  acc ->
                    current_x = start_x + i

                    Enum.reduce(0..5, acc, fn bit_index, inner_acc ->
                      # Check if the bit_index'th bit of pattern_int is set
                      # Compatible equivalent
                      is_set =
                        Bitwise.band(pattern_int, Bitwise.bsl(1, bit_index)) !=
                          0

                      Logger.debug(
                        "  pattern=#{pattern_int}, bit_index=#{bit_index}, is_set=#{is_set}"
                      )

                      if is_set do
                        coord = {current_x, y + bit_index}
                        Map.put(inner_acc, coord, color)
                      else
                        inner_acc
                      end
                    end)
                end

              new_buffer = Map.merge(state.pixel_buffer, new_pixels_batch)

              new_x = start_x + repeat

              updated_state = %{
                state
                | x: new_x,
                  # Reset repeat count after use
                  repeat_count: 1,
                  pixel_buffer: new_buffer,
                  max_x: max(state.max_x, new_x - 1),
                  max_y: max(state.max_y, y + 5),
                  color_index: state.color_index
              }

              parse_sixel_data(remaining_data, updated_state)
              # --- End Restored Logic ---
            else
              # Unknown/Invalid Character
              Logger.warning(
                "Sixel Parser: Invalid sixel character byte #{char_byte}. Stopping parsing."
              )

              {:error, :invalid_sixel_char}
            end
        end
    end
  end

  # --- Color Conversion Helpers ---

  defp convert_color(color_space, px, py, pz) do
    # Clamp values to 0-100 range
    px = max(0, min(100, px))
    py = max(0, min(100, py))
    pz = max(0, min(100, pz))

    case color_space do
      # HLS (Hue: Px=H/3.6 (0-100), Lightness: Py (0-100), Saturation: Pz (0-100))
      1 ->
        # H is 0-360
        h = px * 3.6
        # L is 0-1
        l = py / 100.0
        # S is 0-1
        s = pz / 100.0
        # Clamp h to 0-360 range using fmod for floats
        h = :math.fmod(h, 360.0)
        h = if h < 0.0, do: h + 360.0, else: h
        hls_to_rgb(h, l, s)

      # RGB (R: Px, G: Py, B: Pz - all 0-100)
      2 ->
        # Scale 0-100 to 0-255
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
  def hls_to_rgb(h, l, s) do
    # Clamp inputs
    h = max(0.0, min(360.0, h))
    l = max(0.0, min(1.0, l))
    s = max(0.0, min(1.0, s))

    if s == 0 do
      # Achromatic
      grey = round(l * 255)
      {:ok, {grey, grey, grey}}
    else
      c = (1.0 - abs(2.0 * l - 1.0)) * s
      h_prime = h / 60.0
      x = c * (1.0 - abs(:math.fmod(h_prime, 2.0) - 1.0))
      m = l - c / 2.0

      {r1, g1, b1} =
        cond do
          h_prime >= 0 and h_prime < 1 -> {c, x, 0.0}
          h_prime >= 1 and h_prime < 2 -> {x, c, 0.0}
          h_prime >= 2 and h_prime < 3 -> {0.0, c, x}
          h_prime >= 3 and h_prime < 4 -> {0.0, x, c}
          h_prime >= 4 and h_prime < 5 -> {x, 0.0, c}
          # Fix: Allow h_prime == 6 (Hue 360)
          h_prime >= 5 and h_prime <= 6 -> {c, 0.0, x}
          # Should not happen with clamping
          true -> {0.0, 0.0, 0.0}
        end

      r = round((r1 + m) * 255)
      g = round((g1 + m) * 255)
      b = round((b1 + m) * 255)
      # Ensure values are within 0-255 after rounding
      r = max(0, min(255, r))
      g = max(0, min(255, g))
      b = max(0, min(255, b))
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
              Logger.warning(
                "Sixel Render: Color index #{color_index} not found in palette."
              )

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
    # Placeholder: Assume `palette` variable is available
    # Added placeholder palette, prefixed unused
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

  # Obsolete - kept for reference if needed, but pixel_buffer is source now
  # def calculate_dimensions(image_data, attributes) do ... end
  # def render_sixel_data(image_data, position, attributes) do ... end
end

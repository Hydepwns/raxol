defmodule Raxol.Terminal.ANSI.SixelParser do
  @moduledoc """
  Handles the parsing logic for Sixel graphics data streams within a DCS sequence.
  """

  require Logger

  alias Raxol.Terminal.ANSI.SixelPatternMap
  # Needed for color definitions/selection
  alias Raxol.Terminal.ANSI.SixelPalette

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

  # Placeholder for the main parsing function to be moved here
  @spec parse(binary(), ParserState.t()) ::
          {:ok, ParserState.t()} | {:error, atom()}
  # Main recursive Sixel data parser
  def parse(data, state) when is_binary(data) do
    # Handle end-of-stream, space, or other characters
    case data do
      # End of stream
      <<>> ->
        {:ok, state}

      # Ignore space
      <<" ", rest::binary>> ->
        parse(rest, state)

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

                parse(remaining_data, %{
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

                parse(remaining_data, %{
                  state
                  | raster_attrs: new_attrs
                })

              {:error, reason, _original_binary} ->
                Logger.warning(
                  "Sixel Parser: Error parsing Raster Attributes: #{inspect(reason)}. Skipping."
                )

                # Decide how to handle error - skip the likely malformed params?
                # For now, just skip the '"' and continue
                parse(rest, state)
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

                  # *** This calls convert_color which needs to be moved/aliased ***
                  case SixelPalette.convert_color(color_space, px, py, pz) do
                    {:ok, {r, g, b}} ->
                      Logger.debug(
                        "Sixel Parser: Defining Color ##{pc}. Space=#{color_space}, Vals=#{px};#{py};#{pz} -> RGB(#{r},#{g},#{b})"
                      )

                      new_palette = Map.put(state.palette, pc, {r, g, b})

                      Logger.debug(
                        "Sixel Parser: Setting color_index to #{pc} before recursive call."
                      )

                      parse(remaining_data, %{
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
                      parse(remaining_data, state)
                  end
                else
                  Logger.warning(
                    "Sixel Parser: Invalid color index ##{pc}. Skipping."
                  )

                  parse(remaining_data, state)
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

                      parse(remaining_data, %{
                        state
                        | color_index: pc
                      })
                    else
                      Logger.warning(
                        "Sixel Parser: Invalid color index ##{pc} for selection. Skipping."
                      )

                      parse(remaining_data, state)
                    end

                  # No params means select color 0
                  [] ->
                    Logger.debug(
                      "Sixel Parser: Found Color Definition with no parameters (Selecting color 0)."
                    )

                    Logger.debug(
                      "Sixel Parser: Setting color_index to 0 before recursive call."
                    )

                    parse(remaining_data, %{state | color_index: 0})

                  # Unexpected number of params
                  _ ->
                    Logger.warning(
                      "Sixel Parser: Unexpected params for Color Definition: #{inspect(params)}. Skipping."
                    )

                    parse(remaining_data, state)
                end

              {:error, reason, _original_binary} ->
                Logger.warning(
                  "Sixel Parser: Error parsing Color Definition: #{inspect(reason)}. Skipping."
                )

                parse(rest, state)
            end

          # Parse ! Pn <char>
          <<"!", rest::binary>> ->
            # Use local helper
            case consume_integer_params(rest) do
              {:ok, [pn], remaining_data} when pn > 0 ->
                Logger.debug("Sixel Parser: Found Repeat Command !#{pn}")
                # We only set the repeat count here.
                # The *next* character processed will use this count.
                parse(remaining_data, %{state | repeat_count: pn})

              # Includes pn <= 0, Renamed _pn to pn
              {:ok, [pn], remaining_data} ->
                Logger.warning(
                  "Sixel Parser: Invalid repeat count found (!#{pn}). Skipping repeat command."
                )

                parse(remaining_data, state)

              # No params
              {:ok, [], remaining_data} ->
                Logger.debug(
                  "Sixel Parser: Found Repeat Command without parameters (Skipping)."
                )

                parse(remaining_data, state)

              {:error, reason, _original_binary} ->
                Logger.warning(
                  "Sixel Parser: Error parsing Repeat Command: #{inspect(reason)}. Skipping."
                )

                # Skip just '!'
                parse(rest, state)
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
              parse(rest, %{
                state
                | x: 0,
                  pixel_buffer: updated_buffer,
                  max_x: new_max_x,
                  max_y: new_max_y,
                  color_index: state.color_index
              })
            else
              # Should not happen for '$', but handle defensively
              parse(rest, %{state | x: 0, color_index: state.color_index})
            end

          # Parse NL (-), move to next line
          <<"-", rest::binary>> ->
            Logger.debug("Sixel Parser: Found NL (-)")
            new_y = state.y + 6

            parse(rest, %{
              state
              | x: 0,
                y: new_y,
                max_y: max(state.max_y, new_y + 5)
            })

          # Parse data character
          <<char_byte, remaining_data::binary>> ->
            # Validate it's within the valid range and get pattern
            case SixelPatternMap.get_pattern(char_byte) do
              # Valid Sixel character
              pattern_int when is_integer(pattern_int) ->
                start_x = state.x
                y = state.y
                color = state.color_index
                # Capture repeat count before loop
                repeat = state.repeat_count

                # Loop 'repeat' times to generate pixels for repeated character
                {final_buffer, final_x, final_max_x} =
                  Enum.reduce(
                    0..(repeat - 1),
                    {state.pixel_buffer, start_x, state.max_x},
                    fn _i, {current_buffer, current_x, current_max_x} ->
                      # Generate pixels for the pattern at the current column (current_x)
                      pixels_for_this_column =
                        Enum.reduce(0..5, %{}, fn bit_index, acc ->
                          is_set =
                            Bitwise.band(pattern_int, Bitwise.bsl(1, bit_index)) !=
                              0

                          if is_set do
                            Map.put(acc, {current_x, y + bit_index}, color)
                          else
                            acc
                          end
                        end)

                      # Merge into buffer and update max_x
                      merged_buffer =
                        Map.merge(current_buffer, pixels_for_this_column)

                      new_max_x = max(current_max_x, current_x)

                      # Return updated buffer, next x, and max_x for next iteration
                      {merged_buffer, current_x + 1, new_max_x}
                    end
                  )

                # Update state after the loop
                updated_state = %{
                  state
                  | # Final x position after repeats
                    x: final_x,
                    # Reset repeat count after use
                    repeat_count: 1,
                    # Use buffer accumulated in the loop
                    pixel_buffer: final_buffer,
                    # Use max_x calculated in the loop
                    max_x: final_max_x,
                    max_y: max(state.max_y, y + 5),
                    color_index: state.color_index
                }

                parse(remaining_data, updated_state)

              # Character is not a valid Sixel data char (e.g., outside ?-~ or a command char handled elsewhere)
              nil ->
                # Unknown/Invalid Character
                Logger.warning(
                  "Sixel Parser: Invalid sixel character byte #{char_byte}. Stopping parsing."
                )

                {:error, :invalid_sixel_char}
            end
        end
    end
  end

  # Placeholder for helper functions to be moved here

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

  # Placeholder for parsing the list of initial integer parameters
  def parse_dcs_params_list(params_list) when is_list(params_list) do
    # Example: P1=pixel aspect ratio, P2=background color mode, P3=horizontal grid size
    %{
      p1: Enum.at(params_list, 0),
      p2: Enum.at(params_list, 1),
      p3: Enum.at(params_list, 2)
    }
  end
end

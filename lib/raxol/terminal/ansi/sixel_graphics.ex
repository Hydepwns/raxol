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

  require Raxol.Core.Runtime.Log
  # Import Bitwise for operators
  import Bitwise

  alias Raxol.Terminal.ANSI.SixelPatternMap
  alias Raxol.Terminal.ANSI.SixelPalette
  alias Raxol.Terminal.ANSI.SixelParser
  alias Raxol.Terminal.ANSI.SixelRenderer

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
          pixel_buffer: map(),
          sixel_cursor_pos: {integer(), integer()} | nil
        }

  @type sixel_attribute ::
          :normal | :double_width | :double_height | :double_size

  defstruct palette: %{},
            current_color: 0,
            position: {0, 0},
            attributes: %{width: :normal, height: :normal, size: :normal},
            pixel_buffer: %{},
            sixel_cursor_pos: nil

  @doc """
  Creates a new Sixel state with default values.
  """
  @spec new() :: %__MODULE__{}
  def new do
    %__MODULE__{
      palette: SixelPalette.initialize_palette(),
      current_color: 0,
      position: {0, 0},
      attributes: %{
        width: :normal,
        height: :normal,
        size: :normal
      },
      pixel_buffer: %{},
      sixel_cursor_pos: nil
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
    # Find the end of the sequence (ST = ESC \\ = 27, 92)
    case :binary.match(rest, <<27, 92>>) do
      {st_pos, _st_len} ->
        content_before_st = :binary.part(rest, 0, st_pos)

        # Raxol.Core.Runtime.

        # Attempt to parse initial DCS parameters first (optional)
        # We assume parameters end before the main Sixel data
        case SixelParser.consume_integer_params(content_before_st) do
          {:ok, initial_params, sixel_data} ->
            # Raxol.Core.Runtime.Log.debug("process_sequence: Parsed initial params: #{inspect(initial_params)}, sixel_data: #{inspect(sixel_data)}")

            # TODO: Use initial_params if needed (e.g., P1=pixel aspect ratio, P2=background color mode)
            _initial_params_map =
              SixelParser.parse_dcs_params_list(initial_params)

            # Initialize parser state using the new module
            initial_parser_state = %SixelParser.ParserState{
              x: 0,
              y: 0,
              color_index: state.current_color,
              repeat_count: 1,
              palette: state.palette,
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

            # Check for 'q' introducer REQUIRED after initial parameters
            case sixel_data do
              <<"q", rest_after_q::binary>> ->
                # Delegate parsing to the new module
                parse_result =
                  SixelParser.parse(rest_after_q, initial_parser_state)

                # Raxol.Core.Runtime.Log.debug("process_sequence: parse_sixel_data result: #{inspect(parse_result)}")

                case parse_result do
                  {:ok, final_parser_state} ->
                    # Update the main state with results from the parser
                    updated_state = %__MODULE__{
                      state
                      | # Palette might have changed
                        palette: final_parser_state.palette,
                        # Store final raster attributes
                        attributes: final_parser_state.raster_attrs,
                        pixel_buffer: final_parser_state.pixel_buffer,
                        position: {final_parser_state.x, final_parser_state.y},
                        current_color: final_parser_state.color_index,
                        sixel_cursor_pos:
                          {final_parser_state.x, final_parser_state.y}
                    }

                    # Raxol.Core.Runtime.Log.debug("process_sequence: Returning OK, final state: #{inspect(updated_state)}")
                    {updated_state, :ok}

                  {:error, reason} ->
                    # Raxol.Core.Runtime.Log.error("Sixel data parsing failed: #{inspect(reason)}")
                    # Raxol.Core.Runtime.Log.debug("process_sequence: Returning ERROR from parse_sixel_data: #{inspect(reason)}")
                    # Return original state on error
                    {state, {:error, reason}}
                end

              # If 'q' is missing after parameters
              _ ->
                # Raxol.Core.Runtime.Log.error("Invalid Sixel DCS: missing 'q' after parameters")
                # Raxol.Core.Runtime.Log.debug("process_sequence: Returning ERROR :missing_or_misplaced_q")
                {state, {:error, :missing_or_misplaced_q}}
            end

          # Error parsing initial parameters (rare, as consume_integer_params defaults to empty list)
          {:error, reason, _} ->
            # Raxol.Core.Runtime.Log.error("Invalid Sixel DCS: error parsing initial parameters: #{inspect(reason)}")
            # Raxol.Core.Runtime.Log.debug("process_sequence: Returning ERROR :invalid_initial_params")
            {state, {:error, :invalid_initial_params}}
        end

      :nomatch ->
        # Raxol.Core.Runtime.Log.error("Invalid Sixel DCS: missing ST '\e'")
        # Raxol.Core.Runtime.Log.debug("process_sequence: Returning ERROR :missing_st")
        {state, {:error, :missing_st}}
    end
  end

  # Handle non-DCS sequences (restore this clause)
  def process_sequence(state, other_sequence) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Received non-Sixel sequence in SixelGraphics: #{inspect(other_sequence)}",
      %{}
    )

    {state, {:error, :invalid_sequence}}
  end
end

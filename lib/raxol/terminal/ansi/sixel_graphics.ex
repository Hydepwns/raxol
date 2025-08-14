defmodule Raxol.Terminal.ANSI.SixelGraphics do
    require Logger

  @moduledoc """
  Sixel graphics support for terminal rendering.

  This module handles:
  * Sixel image encoding and decoding
  * Color palette management
  * Image scaling and positioning
  * Terminal compatibility checks
  """

  @behaviour Raxol.Terminal.ANSI.SixelGraphics.Behaviour

  @type sixel_state :: %{
          width: non_neg_integer(),
          height: non_neg_integer(),
          data: binary(),
          palette: map(),
          current_color: non_neg_integer(),
          pixel_buffer: map()
        }

  @type t :: %__MODULE__{
          width: non_neg_integer(),
          height: non_neg_integer(),
          data: binary(),
          palette: map(),
          scale: {non_neg_integer(), non_neg_integer()},
          position: {non_neg_integer(), non_neg_integer()},
          current_color: non_neg_integer(),
          attributes: map(),
          pixel_buffer: map(),
          sixel_cursor_pos: {non_neg_integer(), non_neg_integer()}
        }

  defstruct width: 0,
            height: 0,
            data: "",
            palette: %{},
            scale: {1, 1},
            position: {0, 0},
            current_color: 0,
            attributes: %{
              width: :normal,
              height: :normal,
              size: :normal
            },
            pixel_buffer: %{},
            sixel_cursor_pos: {0, 0}

  @doc """
  Creates a new Sixel image with default values.

  ## Returns

  A new `t:Raxol.Terminal.ANSI.SixelGraphics.t/0` struct with default values.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      palette: Raxol.Terminal.ANSI.SixelPalette.initialize_palette()
    }
  end

  @doc """
  Creates a new Sixel image with specified dimensions.

  ## Parameters

  * `width` - The image width in pixels
  * `height` - The image height in pixels

  ## Returns

  A new `t:Raxol.Terminal.ANSI.SixelGraphics.t/0` struct with the specified dimensions.
  """
  @spec new(non_neg_integer(), non_neg_integer()) :: t()
  def new(width, height)
      when is_integer(width) and is_integer(height) and width > 0 and height > 0 do
    %__MODULE__{width: width, height: height}
  end

  @doc """
  Sets the image data for a Sixel image.

  ## Parameters

  * `image` - The current image
  * `data` - The binary image data

  ## Returns

  The updated image with new data.
  """
  @spec set_data(t(), binary()) :: t()
  def set_data(image, data) when is_binary(data) do
    %{image | data: data}
  end

  @doc """
  Gets the current image data.

  ## Parameters

  * `image` - The current image

  ## Returns

  The binary image data.
  """
  @spec get_data(t()) :: binary()
  def get_data(image) do
    image.data
  end

  @doc """
  Sets the color palette for a Sixel image.

  ## Parameters

  * `image` - The current image
  * `palette` - A map of color indices to RGB values

  ## Returns

  The updated image with new palette.
  """
  @spec set_palette(t(), map()) :: t()
  def set_palette(image, palette) when is_map(palette) do
    %{image | palette: palette}
  end

  @doc """
  Gets the current color palette.

  ## Parameters

  * `image` - The current image

  ## Returns

  A map containing the current color palette.
  """
  @spec get_palette(t()) :: map()
  def get_palette(image) do
    image.palette
  end

  @doc """
  Sets the scale factor for a Sixel image.

  ## Parameters

  * `image` - The current image
  * `x_scale` - The horizontal scale factor
  * `y_scale` - The vertical scale factor

  ## Returns

  The updated image with new scale factors.
  """
  @spec set_scale(t(), non_neg_integer(), non_neg_integer()) :: t()
  def set_scale(image, x_scale, y_scale)
      when is_integer(x_scale) and is_integer(y_scale) and x_scale > 0 and
             y_scale > 0 do
    %{image | scale: {x_scale, y_scale}}
  end

  @doc """
  Gets the current scale factors.

  ## Parameters

  * `image` - The current image

  ## Returns

  A tuple `{x_scale, y_scale}` with the current scale factors.
  """
  @spec get_scale(t()) :: {non_neg_integer(), non_neg_integer()}
  def get_scale(image) do
    image.scale
  end

  @doc """
  Sets the position for a Sixel image.

  ## Parameters

  * `image` - The current image
  * `x` - The horizontal position
  * `y` - The vertical position

  ## Returns

  The updated image with new position.
  """
  @spec set_position(t(), non_neg_integer(), non_neg_integer()) :: t()
  def set_position(image, x, y)
      when is_integer(x) and is_integer(y) and x >= 0 and y >= 0 do
    %{image | position: {x, y}}
  end

  @doc """
  Gets the current position.

  ## Parameters

  * `image` - The current image

  ## Returns

  A tuple `{x, y}` with the current position.
  """
  @spec get_position(t()) :: {non_neg_integer(), non_neg_integer()}
  def get_position(image) do
    image.position
  end

  @doc """
  Encodes a Sixel image to ANSI escape sequence.

  ## Parameters

  * `image` - The image to encode

  ## Returns

  A binary containing the ANSI escape sequence for the Sixel image.
  """
  @spec encode(t()) :: binary()
  def encode(_image) do
    ""
  end

  @doc """
  Decodes an ANSI escape sequence into a Sixel image.

  ## Parameters

  * `data` - The ANSI escape sequence to decode

  ## Returns

  A new `t:Raxol.Terminal.ANSI.SixelGraphics.t/0` struct with the decoded image data.
  """
  @spec decode(binary()) :: t()
  def decode(data) when is_binary(data) do
    %__MODULE__{}
  end

  @doc """
  Checks if the terminal supports Sixel graphics.

  ## Returns

  `true` if Sixel graphics are supported, `false` otherwise.
  """
  @spec supported?() :: boolean()
  def supported? do
    false
  end

  @doc """
  Processes a sequence of Sixel data.

  ## Parameters

  * `state` - The current Sixel state
  * `data` - The Sixel data to process

  ## Returns

  A tuple containing the updated state and a response.
  """
  @spec process_sequence(t(), binary()) :: {t(), :ok | {:error, atom()}}
  def process_sequence(state, data) when is_binary(data) do
    Logger.debug(
      "SixelGraphics: process_sequence called with data: #{inspect(data)}"
    )

    # Ensure palette is initialized
    state_with_palette =
      if map_size(state.palette) == 0 do
        %{
          state
          | palette: Raxol.Terminal.ANSI.SixelPalette.initialize_palette()
        }
      else
        state
      end

    Logger.debug(
      "SixelGraphics: Initial palette has #{map_size(state_with_palette.palette)} colors"
    )

    Logger.debug(
      "SixelGraphics: Color index 1 is #{inspect(Map.get(state_with_palette.palette, 1, :not_found))}"
    )

    Logger.debug(
      "SixelGraphics: Calling SixelParser.parse with data: #{inspect(data)}"
    )

    case Raxol.Terminal.ANSI.SixelParser.parse(
           data,
           %Raxol.Terminal.ANSI.SixelParser.ParserState{
             x: 0,
             y: 0,
             color_index: state_with_palette.current_color,
             repeat_count: 1,
             palette: state_with_palette.palette,
             raster_attrs: state_with_palette.attributes,
             pixel_buffer: state_with_palette.pixel_buffer,
             max_x: 0,
             max_y: 0
           }
         ) do
      {:ok, parser_state} ->
        Logger.debug(
          "SixelGraphics: Parser returned palette with #{map_size(parser_state.palette)} colors"
        )

        Logger.debug(
          "SixelGraphics: Parser color index 1 is #{inspect(Map.get(parser_state.palette, 1, :not_found))}"
        )

        # Preserve the original palette if the parser didn't modify it
        final_palette =
          if map_size(parser_state.palette) == 0 do
            state_with_palette.palette
          else
            parser_state.palette
          end

        Logger.debug(
          "SixelGraphics: Final palette has #{map_size(final_palette)} colors"
        )

        Logger.debug(
          "SixelGraphics: Final color index 1 is #{inspect(Map.get(final_palette, 1, :not_found))}"
        )

        updated_state = %{
          state_with_palette
          | palette: final_palette,
            pixel_buffer: parser_state.pixel_buffer,
            position: {parser_state.x, parser_state.y},
            current_color: parser_state.color_index,
            attributes: parser_state.raster_attrs
        }

        {updated_state, :ok}

      {:error, reason} ->
        Logger.debug("SixelGraphics: Parser returned error: #{inspect(reason)}")
        {state_with_palette, {:error, reason}}
    end
  end
end

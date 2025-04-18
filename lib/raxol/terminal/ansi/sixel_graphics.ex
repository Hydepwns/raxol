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

  alias Raxol.Terminal.ANSI.SequenceParser

  @type sixel_state :: %{
          palette: map(),
          current_color: integer(),
          repeat_count: integer(),
          position: {integer(), integer()},
          attributes: map(),
          image_data: binary()
        }

  @type sixel_attribute ::
          :normal | :double_width | :double_height | :double_size

  @doc """
  Creates a new Sixel state with default values.
  """
  @spec new() :: %{
          palette: map(),
          current_color: 0,
          repeat_count: 1,
          position: {0, 0},
          attributes: %{width: :normal, height: :normal, size: :normal},
          image_data: <<>>
        }
  def new do
    %{
      palette: initialize_palette(),
      current_color: 0,
      repeat_count: 1,
      position: {0, 0},
      attributes: %{
        width: :normal,
        height: :normal,
        size: :normal
      },
      image_data: ""
    }
  end

  @doc """
  Initializes the default Sixel color palette.
  """
  @spec initialize_palette() :: map()
  def initialize_palette do
    # Standard 16 colors
    base_palette = %{
      # Black
      0 => {0, 0, 0},
      # Red
      1 => {205, 0, 0},
      # Green
      2 => {0, 205, 0},
      # Yellow
      3 => {205, 205, 0},
      # Blue
      4 => {0, 0, 238},
      # Magenta
      5 => {205, 0, 205},
      # Cyan
      6 => {0, 205, 205},
      # White
      7 => {229, 229, 229},
      # Bright Black
      8 => {127, 127, 127},
      # Bright Red
      9 => {255, 0, 0},
      # Bright Green
      10 => {0, 255, 0},
      # Bright Yellow
      11 => {255, 255, 0},
      # Bright Blue
      12 => {92, 92, 255},
      # Bright Magenta
      13 => {255, 0, 255},
      # Bright Cyan
      14 => {0, 255, 255},
      # Bright White
      15 => {255, 255, 255}
    }

    # Add 240 additional colors (16-255)
    Enum.reduce(16..255, base_palette, fn i, acc ->
      case i do
        # RGB cube (16-231)
        n when n <= 231 ->
          code = n - 16
          r = div(code, 36) * 51
          g = rem(div(code, 6), 6) * 51
          b = rem(code, 6) * 51
          Map.put(acc, i, {r, g, b})

        # Grayscale (232-255)
        n ->
          value = (n - 232) * 10 + 8
          Map.put(acc, i, {value, value, value})
      end
    end)
  end

  @doc """
  Processes a Sixel sequence and returns the updated state and rendered image.
  """
  @spec process_sequence(sixel_state(), binary()) :: {sixel_state(), binary()}
  def process_sequence(state, <<"\e[", _rest::binary>>) do
    # Sixel parsing is currently incomplete and returns :error.
    # Simply return the state until parsing is fixed.
    # case parse_sequence(rest) do
    #   {:ok, operation, params} ->
    #     handle_operation(state, operation, params)
    #   :error ->
    #     {state, ""}
    # end
    # Return empty binary as no image is rendered
    {state, ""}
  end

  @doc """
  Parses a Sixel graphics sequence.
  """
  @spec parse_sequence(binary()) :: {:ok, atom(), list(integer())} | :error
  def parse_sequence(sequence) do
    SequenceParser.parse_sequence(sequence, &decode_operation/1)
  end

  @doc """
  Decodes a Sixel graphics operation from its character code.
  """
  @spec decode_operation(integer()) :: atom()
  def decode_operation(?P), do: :set_color
  def decode_operation(?Q), do: :set_position
  def decode_operation(?R), do: :set_repeat
  def decode_operation(?S), do: :set_attribute
  def decode_operation(?T), do: :set_background
  def decode_operation(?V), do: :set_foreground
  def decode_operation(?X), do: :set_dimension
  def decode_operation(?Y), do: :set_scale
  def decode_operation(?Z), do: :set_transparency
  def decode_operation(_), do: :unknown

  @doc """
  Handles a Sixel operation and returns the updated state and rendered image.
  """
  @spec handle_operation(sixel_state(), atom(), list(integer())) ::
          {sixel_state(), binary()}
  def handle_operation(state, :set_color, [color]) do
    {%{state | current_color: color}, ""}
  end

  def handle_operation(state, :set_position, [x, y]) do
    {%{state | position: {x, y}}, ""}
  end

  def handle_operation(state, :set_repeat, [count]) do
    {%{state | repeat_count: count}, ""}
  end

  def handle_operation(state, :set_attribute, [attr]) do
    attributes = update_attributes(state.attributes, attr)
    {%{state | attributes: attributes}, ""}
  end

  def handle_operation(state, :set_background, [_color]) do
    # Implementation
    {state, ""}
  end

  def handle_operation(state, :set_foreground, [color]) do
    {%{state | current_color: color}, ""}
  end

  def handle_operation(state, :set_dimension, [_width, _height]) do
    # Implementation
    {state, ""}
  end

  def handle_operation(state, :set_scale, [_scale]) do
    # Implementation
    {state, ""}
  end

  def handle_operation(state, :set_transparency, [_alpha]) do
    # Implementation
    {state, ""}
  end

  def handle_operation(state, :unknown, _) do
    {state, ""}
  end

  @doc """
  Updates Sixel attributes based on the attribute code.
  """
  @spec update_attributes(map(), integer()) :: map()
  def update_attributes(attrs, code) do
    case code do
      1 ->
        %{attrs | width: :double_width}

      2 ->
        %{attrs | height: :double_height}

      3 ->
        %{
          attrs
          | width: :double_width,
            height: :double_height,
            size: :double_size
        }

      _ ->
        attrs
    end
  end

  @doc """
  Renders a Sixel image from the current state.
  Converts the Sixel data into a bitmap format suitable for display.
  """
  @spec render_image(sixel_state()) :: binary()
  def render_image(state) do
    _repeat_count = state.repeat_count
    # Extract the image data and current color
    image_data = state.image_data
    current_color = state.current_color
    position = state.position
    attributes = state.attributes

    # Get the color from the palette
    {r, g, b} = Map.get(state.palette, current_color, {0, 0, 0})

    # Create a bitmap representation
    # For now, we'll return a simple SVG representation
    # In a real implementation, this would be converted to a bitmap format
    # suitable for the terminal display

    # Calculate dimensions based on attributes
    {width, height} = calculate_dimensions(image_data, attributes)

    # Create SVG representation
    svg = """
    <svg width="#{width}" height="#{height}" xmlns="http://www.w3.org/2000/svg">
      <rect x="#{elem(position, 0)}" y="#{elem(position, 1)}" width="#{width}" height="#{height}"
            fill="rgb(#{r}, #{g}, #{b})" />
      #{render_sixel_data(image_data, position, attributes)}
    </svg>
    """

    # In a real implementation, this would be converted to a bitmap
    # For now, we'll return the SVG as a string
    svg
  end

  @doc """
  Calculates the dimensions of the Sixel image based on the data and attributes.
  """
  @spec calculate_dimensions(binary(), map()) :: {integer(), integer()}
  def calculate_dimensions(image_data, attributes) do
    # Count the number of lines in the image data
    lines = String.split(image_data, "\n", trim: true)
    # Each Sixel is 6 pixels high
    height = length(lines) * 6

    # Count the maximum number of characters in a line
    max_width =
      Enum.reduce(lines, 0, fn line, acc ->
        max(acc, String.length(line))
      end)

    # Apply attribute scaling
    {width, height} =
      case attributes do
        %{width: :double_width, height: :double_height} ->
          {max_width * 2, height * 2}

        %{width: :double_width} ->
          {max_width * 2, height}

        %{height: :double_height} ->
          {max_width, height * 2}

        _ ->
          {max_width, height}
      end

    {width, height}
  end

  @doc """
  Renders the Sixel data as SVG elements.
  """
  @spec render_sixel_data(binary(), {integer(), integer()}, map()) :: String.t()
  def render_sixel_data(image_data, position, attributes) do
    # Split the image data into lines
    lines = String.split(image_data, "\n", trim: true)

    # Process each line
    Enum.with_index(lines)
    |> Enum.map(fn {line, y_index} ->
      # Process each character in the line
      String.graphemes(line)
      |> Enum.with_index()
      |> Enum.map(fn {char, x_index} ->
        # Convert the character to a Sixel pattern
        pattern = char_to_sixel_pattern(char)

        # Calculate the position of this Sixel
        x = elem(position, 0) + x_index
        y = elem(position, 1) + y_index * 6

        # Apply attribute scaling
        {x, y, scale_x, scale_y} =
          case attributes do
            %{width: :double_width, height: :double_height} ->
              {x * 2, y * 2, 2, 2}

            %{width: :double_width} ->
              {x * 2, y, 2, 1}

            %{height: :double_height} ->
              {x, y * 2, 1, 2}

            _ ->
              {x, y, 1, 1}
          end

        # Create SVG elements for each pixel in the Sixel pattern
        Enum.with_index(pattern)
        |> Enum.map_join("", fn {pixel, pixel_y} ->
          Enum.with_index(pixel)
          |> Enum.map_join("", fn {pixel_value, pixel_x} ->
            if pixel_value == 1 do
              """
              <rect x="#{x + pixel_x * scale_x}" y="#{y + pixel_y * scale_y}"
                    width="#{scale_x}" height="#{scale_y}" fill="currentColor" />
              """
            else
              ""
            end
          end)
        end)
      end)
      |> Enum.map_join("")
    end)
    |> Enum.map_join("")
  end

  @doc """
  Converts a character to a Sixel pattern.
  Each Sixel is represented as a 6x1 grid of pixels.
  """
  @spec char_to_sixel_pattern(char()) :: list(list(integer()))
  def char_to_sixel_pattern(char) do
    # Map characters to Sixel patterns
    # Each pattern is a list of 6 lists, each containing 1 or 0
    # 1 represents a filled pixel, 0 represents an empty pixel
    case char do
      "?" ->
        [
          [0, 1, 1, 1, 1, 0],
          [1, 0, 0, 0, 0, 1],
          [0, 0, 0, 0, 0, 1],
          [0, 0, 0, 1, 1, 0],
          [0, 0, 0, 0, 0, 0],
          [0, 0, 0, 1, 0, 0]
        ]

      "!" ->
        [
          [0, 0, 1, 0, 0, 0],
          [0, 0, 1, 0, 0, 0],
          [0, 0, 1, 0, 0, 0],
          [0, 0, 1, 0, 0, 0],
          [0, 0, 0, 0, 0, 0],
          [0, 0, 1, 0, 0, 0]
        ]

      "@" ->
        [
          [0, 1, 1, 1, 1, 0],
          [1, 0, 0, 0, 0, 1],
          [1, 0, 1, 1, 0, 1],
          [1, 0, 1, 1, 0, 1],
          [1, 0, 0, 0, 0, 1],
          [0, 1, 1, 1, 1, 0]
        ]

      "#" ->
        [
          [0, 1, 0, 1, 0, 0],
          [0, 1, 0, 1, 0, 0],
          [1, 1, 1, 1, 1, 1],
          [0, 1, 0, 1, 0, 0],
          [1, 1, 1, 1, 1, 1],
          [0, 1, 0, 1, 0, 0]
        ]

      "$" ->
        [
          [0, 0, 1, 0, 0, 0],
          [0, 1, 1, 1, 1, 0],
          [1, 0, 1, 0, 0, 0],
          [0, 1, 1, 1, 1, 0],
          [0, 0, 1, 0, 1, 0],
          [1, 1, 1, 1, 1, 0]
        ]

      "%" ->
        [
          [1, 1, 0, 0, 0, 1],
          [1, 1, 0, 0, 1, 0],
          [0, 0, 0, 1, 0, 0],
          [0, 0, 1, 0, 0, 0],
          [0, 1, 0, 0, 1, 1],
          [1, 0, 0, 0, 1, 1]
        ]

      "&" ->
        [
          [0, 1, 1, 0, 0, 0],
          [1, 0, 0, 1, 0, 0],
          [0, 1, 1, 0, 0, 0],
          [1, 0, 0, 1, 0, 0],
          [1, 0, 0, 1, 0, 0],
          [0, 1, 1, 0, 1, 1]
        ]

      "'" ->
        [
          [0, 0, 1, 0, 0, 0],
          [0, 0, 1, 0, 0, 0],
          [0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0]
        ]

      "(" ->
        [
          [0, 0, 0, 1, 0, 0],
          [0, 0, 1, 0, 0, 0],
          [0, 1, 0, 0, 0, 0],
          [0, 1, 0, 0, 0, 0],
          [0, 0, 1, 0, 0, 0],
          [0, 0, 0, 1, 0, 0]
        ]

      ")" ->
        [
          [0, 0, 1, 0, 0, 0],
          [0, 0, 0, 1, 0, 0],
          [0, 0, 0, 0, 1, 0],
          [0, 0, 0, 0, 1, 0],
          [0, 0, 0, 1, 0, 0],
          [0, 0, 1, 0, 0, 0]
        ]

      "*" ->
        [
          [0, 0, 0, 0, 0, 0],
          [0, 0, 1, 0, 0, 0],
          [1, 1, 1, 1, 1, 0],
          [0, 0, 1, 0, 0, 0],
          [0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0]
        ]

      "+" ->
        [
          [0, 0, 0, 0, 0, 0],
          [0, 0, 1, 0, 0, 0],
          [0, 0, 1, 0, 0, 0],
          [1, 1, 1, 1, 1, 0],
          [0, 0, 1, 0, 0, 0],
          [0, 0, 1, 0, 0, 0]
        ]

      "," ->
        [
          [0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0],
          [0, 0, 1, 0, 0, 0],
          [0, 0, 1, 0, 0, 0]
        ]

      "-" ->
        [
          [0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0],
          [1, 1, 1, 1, 1, 0],
          [0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0]
        ]

      "." ->
        [
          [0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0],
          [0, 0, 1, 0, 0, 0],
          [0, 0, 0, 0, 0, 0]
        ]

      "/" ->
        [
          [0, 0, 0, 0, 1, 0],
          [0, 0, 0, 1, 0, 0],
          [0, 0, 1, 0, 0, 0],
          [0, 1, 0, 0, 0, 0],
          [1, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0]
        ]

      "0" ->
        [
          [0, 1, 1, 1, 1, 0],
          [1, 0, 0, 0, 0, 1],
          [1, 0, 0, 0, 0, 1],
          [1, 0, 0, 0, 0, 1],
          [1, 0, 0, 0, 0, 1],
          [0, 1, 1, 1, 1, 0]
        ]

      "1" ->
        [
          [0, 0, 0, 1, 0, 0],
          [0, 0, 1, 1, 0, 0],
          [0, 0, 0, 1, 0, 0],
          [0, 0, 0, 1, 0, 0],
          [0, 0, 0, 1, 0, 0],
          [0, 0, 1, 1, 1, 0]
        ]

      "2" ->
        [
          [0, 1, 1, 1, 1, 0],
          [1, 0, 0, 0, 0, 1],
          [0, 0, 0, 0, 0, 1],
          [0, 0, 0, 1, 1, 0],
          [0, 1, 1, 0, 0, 0],
          [1, 1, 1, 1, 1, 1]
        ]

      "3" ->
        [
          [0, 1, 1, 1, 1, 0],
          [1, 0, 0, 0, 0, 1],
          [0, 0, 0, 1, 1, 0],
          [0, 0, 0, 0, 0, 1],
          [1, 0, 0, 0, 0, 1],
          [0, 1, 1, 1, 1, 0]
        ]

      "4" ->
        [
          [0, 0, 0, 1, 1, 0],
          [0, 0, 1, 0, 1, 0],
          [0, 1, 0, 0, 1, 0],
          [1, 1, 1, 1, 1, 1],
          [0, 0, 0, 0, 1, 0],
          [0, 0, 0, 0, 1, 0]
        ]

      "5" ->
        [
          [1, 1, 1, 1, 1, 1],
          [1, 0, 0, 0, 0, 0],
          [1, 1, 1, 1, 1, 0],
          [0, 0, 0, 0, 0, 1],
          [1, 0, 0, 0, 0, 1],
          [0, 1, 1, 1, 1, 0]
        ]

      "6" ->
        [
          [0, 1, 1, 1, 1, 0],
          [1, 0, 0, 0, 0, 0],
          [1, 1, 1, 1, 1, 0],
          [1, 0, 0, 0, 0, 1],
          [1, 0, 0, 0, 0, 1],
          [0, 1, 1, 1, 1, 0]
        ]

      "7" ->
        [
          [1, 1, 1, 1, 1, 1],
          [0, 0, 0, 0, 0, 1],
          [0, 0, 0, 0, 1, 0],
          [0, 0, 0, 1, 0, 0],
          [0, 0, 1, 0, 0, 0],
          [0, 1, 0, 0, 0, 0]
        ]

      "8" ->
        [
          [0, 1, 1, 1, 1, 0],
          [1, 0, 0, 0, 0, 1],
          [0, 1, 1, 1, 1, 0],
          [1, 0, 0, 0, 0, 1],
          [1, 0, 0, 0, 0, 1],
          [0, 1, 1, 1, 1, 0]
        ]

      "9" ->
        [
          [0, 1, 1, 1, 1, 0],
          [1, 0, 0, 0, 0, 1],
          [1, 0, 0, 0, 0, 1],
          [0, 1, 1, 1, 1, 1],
          [0, 0, 0, 0, 0, 1],
          [0, 1, 1, 1, 1, 0]
        ]

      ":" ->
        [
          [0, 0, 0, 0, 0, 0],
          [0, 0, 1, 0, 0, 0],
          [0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0],
          [0, 0, 1, 0, 0, 0],
          [0, 0, 0, 0, 0, 0]
        ]

      ";" ->
        [
          [0, 0, 0, 0, 0, 0],
          [0, 0, 1, 0, 0, 0],
          [0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0],
          [0, 0, 1, 0, 0, 0],
          [0, 0, 1, 0, 0, 0]
        ]

      "<" ->
        [
          [0, 0, 0, 1, 0, 0],
          [0, 0, 1, 0, 0, 0],
          [0, 1, 0, 0, 0, 0],
          [0, 0, 1, 0, 0, 0],
          [0, 0, 0, 1, 0, 0],
          [0, 0, 0, 0, 0, 0]
        ]

      "=" ->
        [
          [0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0],
          [1, 1, 1, 1, 1, 0],
          [0, 0, 0, 0, 0, 0],
          [1, 1, 1, 1, 1, 0],
          [0, 0, 0, 0, 0, 0]
        ]

      ">" ->
        [
          [0, 1, 0, 0, 0, 0],
          [0, 0, 1, 0, 0, 0],
          [0, 0, 0, 1, 0, 0],
          [0, 0, 1, 0, 0, 0],
          [0, 1, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0]
        ]

      _ ->
        [
          [0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0]
        ]
    end
  end
end

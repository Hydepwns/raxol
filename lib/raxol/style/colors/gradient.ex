alias Raxol.Style.Colors.Color

defmodule Raxol.Style.Colors.Gradient do
  @moduledoc """
  Creates and manages color gradients for terminal applications.

  This module provides functionality for creating gradients between colors and
  applying them to text, creating visually striking terminal effects.

  ## Examples

  ```elixir
  # Create a simple linear gradient between red and blue
  alias Raxol.Style.Colors.{Color, Gradient}

  red = Color.from_hex("#FF0000")
  blue = Color.from_hex("#0000FF")
  gradient = Gradient.linear(red, blue, 10)

  # Apply the gradient to text
  colored_text = Gradient.apply_to_text(gradient, "Hello, World!")

  # Create a rainbow gradient
  rainbow = Gradient.rainbow(20)
  rainbow_text = Gradient.apply_to_text(rainbow, "Rainbow Text")

  # Create a multi-stop gradient
  colors = [
    Color.from_hex("#FF0000"),  # Red
    Color.from_hex("#FFFF00"),  # Yellow
    Color.from_hex("#00FF00")   # Green
  ]
  multi = Gradient.multi_stop(colors, 15)
  ```
  """

  
  defstruct [
    # List of color stops
    :colors,
    # Number of discrete steps
    :steps,
    # Linear, radial, etc.
    :type
  ]

  @type gradient_type :: :linear | :rainbow | :heat_map | :multi_stop

  @type t :: %__MODULE__{
          colors: [Color.t()],
          steps: non_neg_integer(),
          type: gradient_type()
        }

  @doc """
  Creates a linear gradient between two colors.

  ## Parameters

  - `start_color` - The starting color
  - `end_color` - The ending color
  - `steps` - The number of color steps in the gradient (including start and end)

  ## Examples

      iex> red = Raxol.Style.Colors.Color.from_hex("#FF0000")
      iex> blue = Raxol.Style.Colors.Color.from_hex("#0000FF")
      iex> gradient = Raxol.Style.Colors.Gradient.linear(red, blue, 5)
      iex> length(gradient.colors)
      5
  """
  def linear(%Color{} = start_color, %Color{} = end_color, steps)
      when is_integer(steps) and steps >= 2 do
    colors = generate_gradient_colors(start_color, end_color, steps)

    %__MODULE__{
      colors: colors,
      steps: steps,
      type: :linear
    }
  end

  @doc """
  Creates a multi-stop gradient with multiple color stops.

  ## Parameters

  - `color_stops` - A list of colors to transition between
  - `steps` - The total number of color steps in the gradient

  ## Examples

      iex> colors = [
      ...>   Raxol.Style.Colors.Color.from_hex("#FF0000"),
      ...>   Raxol.Style.Colors.Color.from_hex("#00FF00"),
      ...>   Raxol.Style.Colors.Color.from_hex("#0000FF")
      ...> ]
      iex> gradient = Raxol.Style.Colors.Gradient.multi_stop(colors, 10)
      iex> length(gradient.colors)
      10
  """
  def multi_stop(color_stops, steps)
      when is_list(color_stops) and length(color_stops) >= 2 and
             is_integer(steps) and steps >= 2 do
    # Calculate how many steps to allocate for each segment
    segment_count = length(color_stops) - 1

    # For even distribution, we need to calculate how many steps per segment
    # We add segment_count - 1 to account for the shared points between segments
    segments_steps = distribute_steps(steps, segment_count)

    # Generate the colors for each segment
    colors =
      color_stops
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.zip(segments_steps)
      |> Enum.flat_map(fn {[start_color, end_color], segment_steps} ->
        # Generate colors for this segment, excluding the last one (except for the final segment)
        segment_colors =
          generate_gradient_colors(start_color, end_color, segment_steps)

        if end_color == List.last(color_stops),
          do: segment_colors,
          else: Enum.drop(segment_colors, -1)
      end)

    %__MODULE__{
      colors: colors,
      steps: steps,
      type: :multi_stop
    }
  end

  @doc """
  Creates a rainbow gradient with the given number of steps.

  ## Parameters

  - `steps` - The number of color steps in the rainbow

  ## Examples

      iex> gradient = Raxol.Style.Colors.Gradient.rainbow(6)
      iex> length(gradient.colors)
      6
  """
  def rainbow(steps) when is_integer(steps) and steps >= 2 do
    # Create a list of rainbow colors
    rainbow_colors = [
      # Red
      Color.from_hex("#FF0000"),
      # Orange
      Color.from_hex("#FF7F00"),
      # Yellow
      Color.from_hex("#FFFF00"),
      # Green
      Color.from_hex("#00FF00"),
      # Blue
      Color.from_hex("#0000FF"),
      # Indigo
      Color.from_hex("#4B0082"),
      # Violet
      Color.from_hex("#9400D3")
    ]

    # Create a multi-stop gradient with these colors
    multi_stop(rainbow_colors, steps)
    |> Map.put(:type, :rainbow)
  end

  @doc """
  Creates a heat map gradient from cool to hot colors.

  ## Parameters

  - `steps` - The number of color steps in the heat map

  ## Examples

      iex> gradient = Raxol.Style.Colors.Gradient.heat_map(5)
      iex> length(gradient.colors)
      5
  """
  def heat_map(steps) when is_integer(steps) and steps >= 2 do
    # Create a list of heat map colors from cool to hot
    heat_colors = [
      # Blue (coldest)
      Color.from_hex("#0000FF"),
      # Cyan
      Color.from_hex("#00FFFF"),
      # Green
      Color.from_hex("#00FF00"),
      # Yellow
      Color.from_hex("#FFFF00"),
      # Red (hottest)
      Color.from_hex("#FF0000")
    ]

    # Create a multi-stop gradient with these colors
    multi_stop(heat_colors, steps)
    |> Map.put(:type, :heat_map)
  end

  @doc """
  Gets the color at a specific position in the gradient.

  ## Parameters

  - `gradient` - The gradient to sample from
  - `position` - A value between 0.0 and 1.0 representing the position in the gradient

  ## Examples

      iex> red = Raxol.Style.Colors.Color.from_hex("#FF0000")
      iex> blue = Raxol.Style.Colors.Color.from_hex("#0000FF")
      iex> gradient = Raxol.Style.Colors.Gradient.linear(red, blue, 5)
      iex> color = Raxol.Style.Colors.Gradient.at_position(gradient, 0.5)
      iex> color.hex
      "#800080"  # Purple (mix of red and blue)
  """
  def at_position(%__MODULE__{colors: colors}, position)
      when is_float(position) and position >= 0.0 and position <= 1.0 do
    # Determine the index based on position
    index =
      if position == 1.0 do
        length(colors) - 1
      else
        trunc(position * length(colors))
      end

    Enum.at(colors, index)
  end

  @doc """
  Reverses the direction of a gradient.

  ## Parameters

  - `gradient` - The gradient to reverse

  ## Examples

      iex> red = Raxol.Style.Colors.Color.from_hex("#FF0000")
      iex> blue = Raxol.Style.Colors.Color.from_hex("#0000FF")
      iex> gradient = Raxol.Style.Colors.Gradient.linear(red, blue, 3)
      iex> reversed = Raxol.Style.Colors.Gradient.reverse(gradient)
      iex> hd(reversed.colors).hex
      "#0000FF"
  """
  def reverse(%__MODULE__{colors: colors} = gradient) do
    %{gradient | colors: Enum.reverse(colors)}
  end

  @doc """
  Applies a gradient to text, returning an ANSI-formatted string.

  ## Parameters

  - `gradient` - The gradient to apply
  - `text` - The text to colorize

  ## Examples

      iex> red = Raxol.Style.Colors.Color.from_hex("#FF0000")
      iex> blue = Raxol.Style.Colors.Color.from_hex("#0000FF")
      iex> gradient = Raxol.Style.Colors.Gradient.linear(red, blue, 5)
      iex> Raxol.Style.Colors.Gradient.apply_to_text(gradient, "Hello")
      "\e[38;2;255;0;0mH\e[0m\e[38;2;191;0;64me\e[0m\e[38;2;128;0;128ml\e[0m\e[38;2;64;0;191ml\e[0m\e[38;2;0;0;255mo\e[0m"
  """
  def apply_to_text(%__MODULE__{colors: colors}, text) when is_binary(text) do
    # Split the text into graphemes
    graphemes = String.graphemes(text)

    # Calculate how to distribute colors across characters
    {chars_per_color, remainder} = distribute_colors(colors, graphemes)

    # Combine colors with text
    colored_chars =
      combine_colors_with_text(colors, graphemes, chars_per_color, remainder)

    # Join the colored characters
    Enum.join(colored_chars)
  end

  # Also provide to_ansi_sequence as an alias for apply_to_text for API compatibility
  @doc """
  Alias for apply_to_text/2.
  """
  def to_ansi_sequence(gradient, text), do: apply_to_text(gradient, text)

  # Private functions

  # Generate interpolated colors between start and end
  defp generate_gradient_colors(start_color, _end_color, 1), do: [start_color]

  defp generate_gradient_colors(start_color, end_color, steps) do
    0..(steps - 1)
    |> Enum.map(fn step ->
      # Calculate the interpolation factor
      factor = step / (steps - 1)
      # Interpolate between start and end colors
      interpolate_color(start_color, end_color, factor)
    end)
  end

  # Interpolate between two colors
  defp interpolate_color(
         %Color{r: r1, g: g1, b: b1},
         %Color{r: r2, g: g2, b: b2},
         factor
       ) do
    r = round(r1 + (r2 - r1) * factor)
    g = round(g1 + (g2 - g1) * factor)
    b = round(b1 + (b2 - b1) * factor)

    Color.from_rgb(r, g, b)
  end

  # Distribute steps across segments
  defp distribute_steps(total_steps, segment_count) do
    # Calculate the number of intervals to distribute
    total_intervals = max(0, total_steps - 1)

    # Calculate base intervals per segment
    base_intervals = div(total_intervals, segment_count)
    # Calculate remaining intervals
    remainder_intervals = rem(total_intervals, segment_count)

    # Distribute intervals, giving one extra to segments until remainder is used
    # Then add 1 to get the number of *colors* needed for each segment's generation
    Enum.map(1..segment_count, fn segment_index ->
      intervals_for_segment =
        if segment_index <= remainder_intervals,
          do: base_intervals + 1,
          else: base_intervals

      # Need intervals + 1 colors to cover the intervals
      intervals_for_segment + 1
    end)
  end

  # Distribute colors across text
  defp distribute_colors(colors, graphemes) do
    color_count = length(colors)
    char_count = length(graphemes)

    if color_count >= char_count do
      # If we have more or equal colors than characters, we can assign one color per character
      {1, 0}
    else
      # Otherwise, calculate how many characters per color
      chars_per_color = div(char_count, color_count)
      remainder = rem(char_count, color_count)
      {chars_per_color, remainder}
    end
  end

  # Combine colors with text characters
  defp combine_colors_with_text(colors, graphemes, chars_per_color, remainder) do
    # If we have more colors than characters, just use the first n colors
    if chars_per_color == 1 and remainder == 0 do
      Enum.zip(graphemes, colors)
      |> Enum.map(fn {char, color} -> colorize_text(char, color) end)
    else
      # Distribute colors across characters
      colors
      |> Enum.with_index()
      |> Enum.flat_map(fn {color, index} ->
        # Calculate how many characters for this color
        extra = if index < remainder, do: 1, else: 0
        count = chars_per_color + extra

        # Calculate the starting position in the graphemes list
        start_pos = index * chars_per_color + min(index, remainder)

        # Extract the characters for this color
        chars = Enum.slice(graphemes, start_pos, count)

        # Apply color to each character
        Enum.map(chars, fn char -> colorize_text(char, color) end)
      end)
    end
  end

  # Apply a color to a text string
  defp colorize_text(text, %Color{r: r, g: g, b: b}) do
    # Format as true-color ANSI escape sequence
    "\e[38;2;#{r};#{g};#{b}m#{text}\e[0m"
  end
end

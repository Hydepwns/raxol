defmodule Raxol.Components.Terminal.ANSI do
  @moduledoc """
  Handles ANSI escape code processing for the terminal component.
  
  This module provides:
  - ANSI escape code parsing
  - Terminal state updates based on escape codes
  - Cursor movement and styling
  - Screen clearing and manipulation
  """

  @type ansi_state :: %{
    cursor: {integer(), integer()},
    style: map(),
    screen: map(),
    buffer: [String.t()]
  }

  @doc """
  Processes ANSI escape codes in the input string and updates the terminal state.
  
  ## Examples
  
      iex> ANSI.process("\\e[31mHello\\e[0m", %{cursor: {0, 0}, style: %{}, screen: %{}, buffer: []})
      %{
        cursor: {5, 0},
        style: %{color: :red},
        screen: %{},
        buffer: ["Hello"]
      }
  """
  def process(input, state) do
    input
    |> String.split(~r/(\e\[[0-9;]*[a-zA-Z])/)
    |> Enum.reduce(state, &process_segment/2)
  end

  @doc """
  Processes a single segment of input (either text or escape code).
  """
  def process_segment(segment, state) do
    cond do
      String.starts_with?(segment, "\e[") ->
        process_escape_code(segment, state)
      true ->
        process_text(segment, state)
    end
  end

  @doc """
  Processes ANSI escape codes.
  
  Supported codes:
  - Cursor movement: [A, B, C, D, H, f
  - Erase: [J, K
  - Colors: [30-37, 40-47, 90-97, 100-107
  - Styles: [0, 1, 4, 7
  """
  def process_escape_code(<<?\e, ?[, rest::binary>>, state) do
    case extract_escape_sequence(rest) do
      {sequence, rest} ->
        # Process the sequence and continue
        new_state = case sequence do
          # Cursor movement (A=65, B=66, C=67, D=68)
          n when n in [65, 66, 67, 68] -> move_cursor(state, sequence)
          # Screen clearing (J=74, K=75)
          n when n in [74, 75] -> clear_screen(state, sequence)
          # Style changes
          n when n in 0..7 -> set_style(state, [sequence])
          n when n in 30..37 -> set_style(state, [sequence])
          n when n in 40..47 -> set_style(state, [sequence])
          n when n in 90..97 -> set_style(state, [sequence])
          n when n in 100..107 -> set_style(state, [sequence])
          _ -> state
        end
        process_escape_code(rest, new_state)
      :error ->
        # Invalid escape sequence, treat as literal
        process_escape_code(rest, [?\e, ?[ | state])
    end
  end

  @doc """
  Processes regular text input.
  """
  def process_text(text, state) do
    # Update cursor position based on text length
    {x, y} = state.cursor
    new_x = x + String.length(text)
    
    # Handle line wrapping
    {cols, _} = state.dimensions
    if new_x >= cols do
      %{state | 
        cursor: {new_x - cols, y + 1},
        buffer: [text | state.buffer]
      }
    else
      %{state | 
        cursor: {new_x, y},
        buffer: [text | state.buffer]
      }
    end
  end

  # Private functions for handling specific escape codes

  defp move_cursor(state, sequence) do
    case sequence do
      65 -> move_cursor_up(state, [1])      # Up
      66 -> move_cursor_down(state, [1])    # Down
      67 -> move_cursor_forward(state, [1]) # Right
      68 -> move_cursor_backward(state, [1])# Left
      _ -> state
    end
  end

  defp clear_screen(state, sequence) do
    case sequence do
      74 -> erase_display(state, [0])  # Clear from cursor to end
      75 -> erase_line(state, [0])     # Clear from cursor to end of line
      _ -> state
    end
  end

  defp move_cursor_up(state, [n]) do
    {x, y} = state.cursor
    %{state | cursor: {x, max(0, y - n)}}
  end

  defp move_cursor_down(state, [n]) do
    {x, y} = state.cursor
    {_, rows} = state.dimensions
    %{state | cursor: {x, min(rows - 1, y + n)}}
  end

  defp move_cursor_forward(state, [n]) do
    {x, y} = state.cursor
    {cols, _} = state.dimensions
    %{state | cursor: {min(cols - 1, x + n), y}}
  end

  defp move_cursor_backward(state, [n]) do
    {x, y} = state.cursor
    %{state | cursor: {max(0, x - n), y}}
  end

  defp erase_display(state, [n]) do
    case n do
      0 -> %{state | buffer: []}  # Clear from cursor to end
      1 -> %{state | buffer: []}  # Clear from beginning to cursor
      2 -> %{state | buffer: []}  # Clear entire screen
      _ -> state
    end
  end

  defp erase_line(state, [n]) do
    case n do
      0 -> %{state | buffer: []}  # Clear from cursor to end of line
      1 -> %{state | buffer: []}  # Clear from beginning of line to cursor
      2 -> %{state | buffer: []}  # Clear entire line
      _ -> state
    end
  end

  defp set_style(state, params) do
    style = Enum.reduce(params, state.style, &apply_style_param/2)
    %{state | style: style}
  end

  defp apply_style_param(param, style) do
    case param do
      # Reset
      0 -> %{}
      
      # Text styles
      1 -> Map.put(style, :bold, true)
      4 -> Map.put(style, :underline, true)
      7 -> Map.put(style, :inverse, true)
      
      # Foreground colors
      n when n in 30..37 -> Map.put(style, :color, color_for_code(n - 30))
      n when n in 90..97 -> Map.put(style, :color, color_for_code(n - 90))
      
      # Background colors
      n when n in 40..47 -> Map.put(style, :background, color_for_code(n - 40))
      n when n in 100..107 -> Map.put(style, :background, color_for_code(n - 100))
      
      _ -> style
    end
  end

  defp color_for_code(code) do
    case code do
      0 -> :black
      1 -> :red
      2 -> :green
      3 -> :yellow
      4 -> :blue
      5 -> :magenta
      6 -> :cyan
      7 -> :white
    end
  end

  defp extract_escape_sequence(binary) do
    case binary do
      <<digit, rest::binary>> when digit in ?0..?9 ->
        extract_digits(rest, [digit])
      _ ->
        :error
    end
  end

  defp extract_digits(<<digit, rest::binary>>, acc) when digit in ?0..?9 do
    extract_digits(rest, [digit | acc])
  end

  defp extract_digits(rest, acc) do
    sequence = acc |> Enum.reverse() |> List.to_integer()
    {sequence, rest}
  end

  def rgb_to_ansi256({r, g, b}) do
    # Convert RGB values to 0-5 range for ANSI 256 color cube
    r_index = trunc(r / 255.0 * 5)
    g_index = trunc(g / 255.0 * 5)
    b_index = trunc(b / 255.0 * 5)

    # Calculate color cube index (16..231)
    cube_index = 16 + (36 * r_index) + (6 * g_index) + b_index

    # Handle grayscale colors (232..255)
    gray_value = (r + g + b) / 3
    gray_index = trunc(gray_value / 255.0 * 23) + 232

    # Find closest color between color cube and grayscale
    cube_color = {
      r_index * 51,
      g_index * 51,
      b_index * 51
    }
    gray_rgb = {gray_value, gray_value, gray_value}

    cube_distance = color_distance({r, g, b}, cube_color)
    gray_distance = color_distance({r, g, b}, gray_rgb)

    if cube_distance <= gray_distance do
      cube_index
    else
      gray_index
    end
  end

  defp color_distance({r1, g1, b1}, {r2, g2, b2}) do
    dr = r1 - r2
    dg = g1 - g2
    db = b1 - b2
    :math.sqrt(dr * dr + dg * dg + db * db)
  end

  def ansi256_to_rgb(code) when code in 16..231 do
    code = code - 16
    r = div(code, 36) * 51
    g = div(rem(code, 36), 6) * 51
    b = rem(code, 6) * 51
    {r, g, b}
  end

  def ansi256_to_rgb(code) when code in 232..255 do
    gray = (code - 232) * 10 + 8
    {gray, gray, gray}
  end
end 
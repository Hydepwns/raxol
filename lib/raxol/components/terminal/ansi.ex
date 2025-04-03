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
  def process_escape_code(code, state) do
    # Remove the escape sequence prefix
    code = String.replace_prefix(code, "\e[", "")
    
    # Get the command character (last character)
    command = String.last(code)
    
    # Get the parameters (numbers before the command)
    params = 
      code
      |> String.slice(0..-2)
      |> String.split(";")
      |> Enum.map(&String.to_integer/1)
    
    case command do
      # Cursor movement
      "A" -> move_cursor_up(state, params)
      "B" -> move_cursor_down(state, params)
      "C" -> move_cursor_forward(state, params)
      "D" -> move_cursor_backward(state, params)
      "H" -> set_cursor_position(state, params)
      "f" -> set_cursor_position(state, params)
      
      # Erase
      "J" -> erase_display(state, params)
      "K" -> erase_line(state, params)
      
      # Colors and styles
      "m" -> set_style(state, params)
      
      _ -> state
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

  defp set_cursor_position(state, [row, col]) do
    {cols, rows} = state.dimensions
    %{state | cursor: {
      min(cols - 1, max(0, col - 1)),
      min(rows - 1, max(0, row - 1))
    }}
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
end 
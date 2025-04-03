defmodule Raxol.Terminal.ANSI do
  @moduledoc """
  ANSI escape code processing module.
  
  This module handles the parsing and processing of ANSI escape codes,
  including:
  - Cursor movement
  - Color and style attributes
  - Screen clearing
  - Terminal mode switching
  """

  @colors %{
    0 => :black,
    1 => :red,
    2 => :green,
    3 => :yellow,
    4 => :blue,
    5 => :magenta,
    6 => :cyan,
    7 => :white,
    8 => :bright_black,
    9 => :bright_red,
    10 => :bright_green,
    11 => :bright_yellow,
    12 => :bright_blue,
    13 => :bright_magenta,
    14 => :bright_cyan,
    15 => :bright_white
  }

  @doc """
  Processes an ANSI escape sequence and returns the updated terminal state.
  """
  def process_escape(emulator, sequence) do
    case parse_sequence(sequence) do
      {:cursor_move, x, y} ->
        Raxol.Terminal.Emulator.move_cursor(emulator, x, y)
      
      {:set_foreground, color} ->
        set_attribute(emulator, :foreground, color)
      
      {:set_background, color} ->
        set_attribute(emulator, :background, color)
      
      {:set_attribute, attr} ->
        set_attribute(emulator, attr, true)
      
      {:reset_attribute, attr} ->
        set_attribute(emulator, attr, false)
      
      {:clear_screen, mode} ->
        clear_screen(emulator, mode)
      
      _ ->
        emulator
    end
  end

  @doc """
  Generates an ANSI escape sequence for the given command and parameters.
  """
  def generate_sequence(command, params \\ []) do
    case command do
      :cursor_move ->
        [x, y] = params
        "\e[#{y};#{x}H"
      
      :set_foreground ->
        [color] = params
        "\e[#{color_code(color, :foreground)}m"
      
      :set_background ->
        [color] = params
        "\e[#{color_code(color, :background)}m"
      
      :set_attribute ->
        [attr] = params
        "\e[#{attribute_code(attr)}m"
      
      :reset_attribute ->
        [attr] = params
        "\e[#{reset_attribute_code(attr)}m"
      
      :clear_screen ->
        [mode] = params
        "\e[#{clear_screen_code(mode)}J"
    end
  end

  # Private functions

  defp parse_sequence(sequence) do
    case sequence do
      <<"\e[", rest::binary>> ->
        parse_parameters(rest)
      
      _ ->
        :unknown
    end
  end

  defp parse_parameters(sequence) do
    case String.split(sequence, ";") do
      [params, "H"] ->
        [x, y] = String.split(params) |> Enum.map(&String.to_integer/1)
        {:cursor_move, x, y}
      
      [params, "m"] ->
        parse_attributes(String.split(params))
      
      [params, "J"] ->
        {:clear_screen, String.to_integer(params)}
      
      _ ->
        :unknown
    end
  end

  defp parse_attributes([code | rest]) do
    case code do
      "30" -> {:set_foreground, :black}
      "31" -> {:set_foreground, :red}
      "32" -> {:set_foreground, :green}
      "33" -> {:set_foreground, :yellow}
      "34" -> {:set_foreground, :blue}
      "35" -> {:set_foreground, :magenta}
      "36" -> {:set_foreground, :cyan}
      "37" -> {:set_foreground, :white}
      "40" -> {:set_background, :black}
      "41" -> {:set_background, :red}
      "42" -> {:set_background, :green}
      "43" -> {:set_background, :yellow}
      "44" -> {:set_background, :blue}
      "45" -> {:set_background, :magenta}
      "46" -> {:set_background, :cyan}
      "47" -> {:set_background, :white}
      "1" -> {:set_attribute, :bold}
      "4" -> {:set_attribute, :underline}
      "5" -> {:set_attribute, :blink}
      "7" -> {:set_attribute, :reverse}
      "0" -> {:reset_all}
      _ -> parse_attributes(rest)
    end
  end

  defp set_attribute(emulator, attr, value) do
    new_attributes = Map.put(emulator.attributes, attr, value)
    %{emulator | attributes: new_attributes}
  end

  defp color_code(color, type) do
    base = if type == :foreground, do: 30, else: 40
    base + Map.get(@colors, color, 0)
  end

  defp attribute_code(:bold), do: 1
  defp attribute_code(:underline), do: 4
  defp attribute_code(:blink), do: 5
  defp attribute_code(:reverse), do: 7

  defp reset_attribute_code(:bold), do: 22
  defp reset_attribute_code(:underline), do: 24
  defp reset_attribute_code(:blink), do: 25
  defp reset_attribute_code(:reverse), do: 27

  defp clear_screen_code(0), do: 0  # Clear from cursor to end
  defp clear_screen_code(1), do: 1  # Clear from beginning to cursor
  defp clear_screen_code(2), do: 2  # Clear entire screen
  defp clear_screen_code(3), do: 3  # Clear scrollback buffer
end 
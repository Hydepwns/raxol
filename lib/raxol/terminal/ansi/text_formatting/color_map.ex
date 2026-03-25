defmodule Raxol.Terminal.ANSI.TextFormatting.ColorMap do
  @moduledoc false

  @ansi_code_to_name %{
    30 => :black,
    31 => :red,
    32 => :green,
    33 => :yellow,
    34 => :blue,
    35 => :magenta,
    36 => :cyan,
    37 => :white,
    40 => :black,
    41 => :red,
    42 => :green,
    43 => :yellow,
    44 => :blue,
    45 => :magenta,
    46 => :cyan,
    47 => :white,
    90 => :bright_black,
    91 => :bright_red,
    92 => :bright_green,
    93 => :bright_yellow,
    94 => :bright_blue,
    95 => :bright_magenta,
    96 => :bright_cyan,
    97 => :bright_white,
    100 => :bright_black,
    101 => :bright_red,
    102 => :bright_green,
    103 => :bright_yellow,
    104 => :bright_blue,
    105 => :bright_magenta,
    106 => :bright_cyan,
    107 => :bright_white
  }

  @name_to_fg_code %{
    "black" => 30,
    "red" => 31,
    "green" => 32,
    "yellow" => 33,
    "blue" => 34,
    "magenta" => 35,
    "cyan" => 36,
    "white" => 37,
    "bright_black" => 90,
    "bright_red" => 91,
    "bright_green" => 92,
    "bright_yellow" => 93,
    "bright_blue" => 94,
    "bright_magenta" => 95,
    "bright_cyan" => 96,
    "bright_white" => 97
  }

  @name_to_bg_code %{
    "black" => 40,
    "red" => 41,
    "green" => 42,
    "yellow" => 43,
    "blue" => 44,
    "magenta" => 45,
    "cyan" => 46,
    "white" => 47,
    "bright_black" => 100,
    "bright_red" => 101,
    "bright_green" => 102,
    "bright_yellow" => 103,
    "bright_blue" => 104,
    "bright_magenta" => 105,
    "bright_cyan" => 106,
    "bright_white" => 107
  }

  @sgr_fg_colors %{
    30 => :black,
    31 => :red,
    32 => :green,
    33 => :yellow,
    34 => :blue,
    35 => :magenta,
    36 => :cyan,
    37 => :white
  }

  @sgr_bg_colors %{
    40 => :black,
    41 => :red,
    42 => :green,
    43 => :yellow,
    44 => :blue,
    45 => :magenta,
    46 => :cyan,
    47 => :white
  }

  @sgr_bright_fg %{
    90 => :black,
    91 => :red,
    92 => :green,
    93 => :yellow,
    94 => :blue,
    95 => :magenta,
    96 => :cyan,
    97 => :white
  }

  @sgr_bright_bg %{
    100 => :black,
    101 => :red,
    102 => :green,
    103 => :yellow,
    104 => :blue,
    105 => :magenta,
    106 => :cyan,
    107 => :white
  }

  def ansi_code_to_name(code), do: @ansi_code_to_name[code]
  def name_to_fg_code(name), do: @name_to_fg_code[name]
  def name_to_bg_code(name), do: @name_to_bg_code[name]
  def sgr_fg_color(code), do: @sgr_fg_colors[code]
  def sgr_bg_color(code), do: @sgr_bg_colors[code]
  def sgr_bright_fg(code), do: @sgr_bright_fg[code]
  def sgr_bright_bg(code), do: @sgr_bright_bg[code]
end

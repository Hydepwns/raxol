defmodule Raxol.Terminal.ANSI.TextFormatting.Colors do
  @moduledoc """
  Color handling utilities for ANSI text formatting.
  """

  @doc """
  Converts ANSI color codes to color names.
  """
  @spec ansi_code_to_color_name(non_neg_integer()) :: atom() | nil
  def ansi_code_to_color_name(code) do
    case code do
      30 -> :black
      31 -> :red
      32 -> :green
      33 -> :yellow
      34 -> :blue
      35 -> :magenta
      36 -> :cyan
      37 -> :white
      # background colors
      40 -> :black
      41 -> :red
      42 -> :green
      43 -> :yellow
      44 -> :blue
      45 -> :magenta
      46 -> :cyan
      47 -> :white
      90 -> :bright_black
      91 -> :bright_red
      92 -> :bright_green
      93 -> :bright_yellow
      94 -> :bright_blue
      95 -> :bright_magenta
      96 -> :bright_cyan
      97 -> :bright_white
      # bright background colors
      100 -> :bright_black
      101 -> :bright_red
      102 -> :bright_green
      103 -> :bright_yellow
      104 -> :bright_blue
      105 -> :bright_magenta
      106 -> :bright_cyan
      107 -> :bright_white
      _ -> nil
    end
  end

  @doc """
  Builds foreground color codes.
  """
  @spec build_foreground_codes(term()) :: [String.t()]
  def build_foreground_codes(nil), do: []

  def build_foreground_codes(color) when is_binary(color) do
    case color_name_to_code(color) do
      nil -> []
      code -> [to_string(code)]
    end
  end

  def build_foreground_codes(color) when is_atom(color) do
    case color_name_to_code(to_string(color)) do
      nil -> []
      code -> [to_string(code)]
    end
  end

  def build_foreground_codes(color) when is_integer(color),
    do: [to_string(color)]

  def build_foreground_codes(_), do: []

  @doc """
  Builds background color codes.
  """
  @spec build_background_codes(term()) :: [String.t()]
  def build_background_codes(nil), do: []

  def build_background_codes(color) when is_binary(color) do
    case color_name_to_bg_code(color) do
      nil -> []
      code -> [to_string(code)]
    end
  end

  def build_background_codes(color) when is_atom(color) do
    case color_name_to_bg_code(to_string(color)) do
      nil -> []
      code -> [to_string(code)]
    end
  end

  def build_background_codes(color) when is_integer(color),
    do: [to_string(color + 10)]

  def build_background_codes(_), do: []

  defp color_name_to_code(name) do
    case name do
      "black" -> 30
      "red" -> 31
      "green" -> 32
      "yellow" -> 33
      "blue" -> 34
      "magenta" -> 35
      "cyan" -> 36
      "white" -> 37
      "bright_black" -> 90
      "bright_red" -> 91
      "bright_green" -> 92
      "bright_yellow" -> 93
      "bright_blue" -> 94
      "bright_magenta" -> 95
      "bright_cyan" -> 96
      "bright_white" -> 97
      _ -> nil
    end
  end

  defp color_name_to_bg_code(name) do
    case name do
      "black" -> 40
      "red" -> 41
      "green" -> 42
      "yellow" -> 43
      "blue" -> 44
      "magenta" -> 45
      "cyan" -> 46
      "white" -> 47
      "bright_black" -> 100
      "bright_red" -> 101
      "bright_green" -> 102
      "bright_yellow" -> 103
      "bright_blue" -> 104
      "bright_magenta" -> 105
      "bright_cyan" -> 106
      "bright_white" -> 107
      _ -> nil
    end
  end

  @doc """
  Handles integer color parameters for SGR sequences.
  """
  @spec handle_integer_color_param(integer(), map()) :: map()
  def handle_integer_color_param(code, style) do
    cond do
      code >= 30 and code <= 37 ->
        # Standard foreground colors
        %{style | foreground: ansi_code_to_color_name(code)}

      code >= 40 and code <= 47 ->
        # Standard background colors
        %{style | background: ansi_code_to_color_name(code - 10)}

      code >= 90 and code <= 97 ->
        # Bright foreground colors
        %{style | foreground: ansi_code_to_color_name(code)}

      code >= 100 and code <= 107 ->
        # Bright background colors  
        %{style | background: ansi_code_to_color_name(code - 10)}

      true ->
        style
    end
  end

  @doc """
  Handles tuple color parameters for SGR sequences (e.g., RGB colors).
  """
  @spec handle_tuple_color_param(tuple(), map()) :: map()
  def handle_tuple_color_param(tuple, style) do
    case tuple do
      {38, 5, n} when n >= 0 and n <= 255 ->
        # 256 color foreground
        %{style | foreground: {:indexed, n}}

      {48, 5, n} when n >= 0 and n <= 255 ->
        # 256 color background
        %{style | background: {:indexed, n}}

      {38, 2, r, g, b}
      when r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255 ->
        # RGB foreground
        %{style | foreground: {:rgb, r, g, b}}

      {48, 2, r, g, b}
      when r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255 ->
        # RGB background
        %{style | background: {:rgb, r, g, b}}

      _ ->
        style
    end
  end
end

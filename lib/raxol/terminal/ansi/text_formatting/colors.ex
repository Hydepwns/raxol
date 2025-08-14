defmodule Raxol.Terminal.ANSI.TextFormatting.Colors do
  @moduledoc """
  Color handling for the Raxol Terminal ANSI TextFormatting module.
  Handles color operations, ANSI code conversion, and color mapping.
  """

  alias Raxol.Terminal.ANSI.TextFormatting.Core

  @ansi_color_map %{
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
    # Bright colors (90-97 for foreground, 100-107 for background)
    0 => :black,
    1 => :red,
    2 => :green,
    3 => :yellow,
    4 => :blue,
    5 => :magenta,
    6 => :cyan,
    7 => :white
  }

  @doc """
  Converts an ANSI code to a color name.
  """
  @spec ansi_code_to_color_name(integer()) :: atom()
  def ansi_code_to_color_name(code) do
    Map.get(@ansi_color_map, code)
  end

  @doc """
  Converts a color name to its ANSI code.
  """
  @spec color_to_code(atom()) :: integer()
  def color_to_code(:black), do: 0
  def color_to_code(:red), do: 1
  def color_to_code(:green), do: 2
  def color_to_code(:yellow), do: 3
  def color_to_code(:blue), do: 4
  def color_to_code(:magenta), do: 5
  def color_to_code(:cyan), do: 6
  def color_to_code(:white), do: 7
  def color_to_code(_), do: 0

  @doc """
  Builds foreground color codes for SGR formatting.
  """
  @spec build_foreground_codes(Core.color()) :: [integer()]
  def build_foreground_codes(nil), do: []

  def build_foreground_codes(color) when is_atom(color),
    do: [30 + color_to_code(color)]

  def build_foreground_codes(_), do: []

  @doc """
  Builds background color codes for SGR formatting.
  """
  @spec build_background_codes(Core.color()) :: [integer()]
  def build_background_codes(nil), do: []

  def build_background_codes(color) when is_atom(color),
    do: [40 + color_to_code(color)]

  def build_background_codes(_), do: []

  @doc """
  Handles tuple color parameters for RGB and indexed colors.
  """
  @spec handle_tuple_color_param(tuple(), Core.text_style()) ::
          Core.text_style()
  def handle_tuple_color_param({:fg_8bit, color_code}, style)
      when is_integer(color_code) do
    %{style | foreground: {:index, color_code}}
  end

  def handle_tuple_color_param({:bg_8bit, color_code}, style) do
    %{style | background: {:index, color_code}}
  end

  def handle_tuple_color_param({:fg_rgb, r, g, b}, style) do
    %{style | foreground: {:rgb, r, g, b}}
  end

  def handle_tuple_color_param({:bg_rgb, r, g, b}, style) do
    %{style | background: {:rgb, r, g, b}}
  end

  def handle_tuple_color_param(_, style) do
    style
  end

  @doc """
  Handles integer color parameters for basic ANSI colors.
  """
  @spec handle_integer_color_param(integer(), Core.text_style()) ::
          Core.text_style()
  def handle_integer_color_param(code, style)
      when code in [30, 31, 32, 33, 34, 35, 36, 37] do
    %{style | foreground: ansi_code_to_color_name(code - 30)}
  end

  def handle_integer_color_param(code, style)
      when code in [90, 91, 92, 93, 94, 95, 96, 97] do
    %{style | foreground: ansi_code_to_color_name(code - 90)}
  end

  def handle_integer_color_param(code, style)
      when code in [40, 41, 42, 43, 44, 45, 46, 47] do
    %{style | background: ansi_code_to_color_name(code - 40)}
  end

  def handle_integer_color_param(code, style)
      when code in [100, 101, 102, 103, 104, 105, 106, 107] do
    %{style | background: ansi_code_to_color_name(code - 100)}
  end

  def handle_integer_color_param(_code, style) do
    style
  end
end

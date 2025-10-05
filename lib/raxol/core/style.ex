defmodule Raxol.Core.Style do
  @moduledoc """
  Style management and ANSI escape code generation.

  This module provides utilities for creating, merging, and converting
  terminal styles to ANSI escape codes.

  ## Color Support

  - RGB colors (24-bit true color)
  - 256-color palette
  - Named colors (16 basic ANSI colors)

  ## Style Attributes

  - Foreground and background colors
  - Bold, italic, underline
  - Reverse video
  - Strikethrough

  ## Examples

      # Create a style
      style = Raxol.Core.Style.new(
        fg_color: Raxol.Core.Style.rgb(255, 0, 0),
        bold: true
      )

      # Use named colors
      style = Raxol.Core.Style.new(
        fg_color: Raxol.Core.Style.named_color(:red),
        bg_color: Raxol.Core.Style.named_color(:black)
      )

      # Merge styles
      base_style = Raxol.Core.Style.new(bold: true)
      colored_style = Raxol.Core.Style.new(fg_color: :red)
      merged = Raxol.Core.Style.merge(base_style, colored_style)

      # Generate ANSI codes
      ansi = Raxol.Core.Style.to_ansi(style)

  """

  @type color ::
          nil
          | {non_neg_integer(), non_neg_integer(), non_neg_integer()}
          | non_neg_integer()
          | atom()

  @type t :: %__MODULE__{
          fg_color: color(),
          bg_color: color(),
          bold: boolean(),
          italic: boolean(),
          underline: boolean(),
          reverse: boolean(),
          strikethrough: boolean()
        }

  defstruct fg_color: nil,
            bg_color: nil,
            bold: false,
            italic: false,
            underline: false,
            reverse: false,
            strikethrough: false

  @doc """
  Creates a new style with the given attributes.

  ## Parameters

    - `opts` - Keyword list of style attributes

  ## Examples

      iex> style = Raxol.Core.Style.new(bold: true, fg_color: :red)
      %Raxol.Core.Style{bold: true, fg_color: :red}

  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end

  @doc """
  Merges two styles, with the second style taking precedence.

  ## Parameters

    - `style1` - Base style
    - `style2` - Style to merge on top

  """
  @spec merge(t(), t()) :: t()
  def merge(style1, style2) do
    %__MODULE__{
      fg_color: style2.fg_color || style1.fg_color,
      bg_color: style2.bg_color || style1.bg_color,
      bold: style2.bold || style1.bold,
      italic: style2.italic || style1.italic,
      underline: style2.underline || style1.underline,
      reverse: style2.reverse || style1.reverse,
      strikethrough: style2.strikethrough || style1.strikethrough
    }
  end

  @doc """
  Creates an RGB color value.

  ## Parameters

    - `r` - Red component (0-255)
    - `g` - Green component (0-255)
    - `b` - Blue component (0-255)

  """
  @spec rgb(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: color()
  def rgb(r, g, b)
      when r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255 do
    {r, g, b}
  end

  @doc """
  Returns a color from the 256-color palette.

  ## Parameters

    - `code` - Color code (0-255)

  """
  @spec color_256(non_neg_integer()) :: color()
  def color_256(code) when code >= 0 and code <= 255 do
    code
  end

  @doc """
  Returns a named color.

  Supported colors: `:black`, `:red`, `:green`, `:yellow`, `:blue`,
  `:magenta`, `:cyan`, `:white`, `:bright_black`, `:bright_red`,
  `:bright_green`, `:bright_yellow`, `:bright_blue`, `:bright_magenta`,
  `:bright_cyan`, `:bright_white`

  """
  @spec named_color(atom()) :: color()
  def named_color(name) when is_atom(name) do
    name
  end

  @doc """
  Converts a style to ANSI escape codes.

  ## Parameters

    - `style` - The style to convert

  ## Returns

  A string containing the ANSI escape codes for the style.

  """
  @spec to_ansi(t()) :: String.t()
  def to_ansi(style) do
    codes = []

    # Text attributes
    codes = if style.bold, do: codes ++ [1], else: codes
    codes = if style.italic, do: codes ++ [3], else: codes
    codes = if style.underline, do: codes ++ [4], else: codes
    codes = if style.reverse, do: codes ++ [7], else: codes
    codes = if style.strikethrough, do: codes ++ [9], else: codes

    # Foreground color
    codes =
      case style.fg_color do
        nil -> codes
        {r, g, b} -> codes ++ [38, 2, r, g, b]
        code when is_integer(code) -> codes ++ [38, 5, code]
        :black -> codes ++ [30]
        :red -> codes ++ [31]
        :green -> codes ++ [32]
        :yellow -> codes ++ [33]
        :blue -> codes ++ [34]
        :magenta -> codes ++ [35]
        :cyan -> codes ++ [36]
        :white -> codes ++ [37]
        :bright_black -> codes ++ [90]
        :bright_red -> codes ++ [91]
        :bright_green -> codes ++ [92]
        :bright_yellow -> codes ++ [93]
        :bright_blue -> codes ++ [94]
        :bright_magenta -> codes ++ [95]
        :bright_cyan -> codes ++ [96]
        :bright_white -> codes ++ [97]
        _ -> codes
      end

    # Background color
    codes =
      case style.bg_color do
        nil -> codes
        {r, g, b} -> codes ++ [48, 2, r, g, b]
        code when is_integer(code) -> codes ++ [48, 5, code]
        :black -> codes ++ [40]
        :red -> codes ++ [41]
        :green -> codes ++ [42]
        :yellow -> codes ++ [43]
        :blue -> codes ++ [44]
        :magenta -> codes ++ [45]
        :cyan -> codes ++ [46]
        :white -> codes ++ [47]
        :bright_black -> codes ++ [100]
        :bright_red -> codes ++ [101]
        :bright_green -> codes ++ [102]
        :bright_yellow -> codes ++ [103]
        :bright_blue -> codes ++ [104]
        :bright_magenta -> codes ++ [105]
        :bright_cyan -> codes ++ [106]
        :bright_white -> codes ++ [107]
        _ -> codes
      end

    case codes do
      [] -> ""
      codes -> "\e[#{Enum.join(codes, ";")}m"
    end
  end
end

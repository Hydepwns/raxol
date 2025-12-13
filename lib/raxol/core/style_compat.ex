defmodule Raxol.Core.Style do
  @moduledoc """
  Style utilities for Raxol.Core.Buffer.

  Provides functions to create, merge, and convert styles for terminal rendering.
  Supports named colors, RGB colors, and 256-color palette.

  ## Example

      style = Raxol.Core.Style.new(bold: true, fg_color: :blue)
      ansi = Raxol.Core.Style.to_ansi(style)
      # => "\e[1;34m"
  """

  @type color ::
          atom()
          | non_neg_integer()
          | {non_neg_integer(), non_neg_integer(), non_neg_integer()}

  @type t :: %{
          bold: boolean(),
          italic: boolean(),
          underline: boolean(),
          fg_color: color() | nil,
          bg_color: color() | nil
        }

  @valid_colors [:black, :red, :green, :yellow, :blue, :magenta, :cyan, :white]

  @color_codes %{
    black: 0,
    red: 1,
    green: 2,
    yellow: 3,
    blue: 4,
    magenta: 5,
    cyan: 6,
    white: 7
  }

  @doc """
  Create a new style map with the given options.

  ## Options

    - `:bold` - Boolean, enables bold text
    - `:italic` - Boolean, enables italic text
    - `:underline` - Boolean, enables underlined text
    - `:fg_color` - Foreground color (atom, integer 0-255, or RGB tuple)
    - `:bg_color` - Background color (atom, integer 0-255, or RGB tuple)

  ## Example

      Raxol.Core.Style.new(bold: true, fg_color: :blue)
      # => %{bold: true, italic: false, underline: false, fg_color: :blue, bg_color: nil}
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %{
      bold: Keyword.get(opts, :bold, false),
      italic: Keyword.get(opts, :italic, false),
      underline: Keyword.get(opts, :underline, false),
      fg_color: Keyword.get(opts, :fg_color),
      bg_color: Keyword.get(opts, :bg_color)
    }
  end

  @doc """
  Merge two style maps, with override values taking precedence.

  ## Example

      base = Raxol.Core.Style.new(bold: true, fg_color: :red)
      override = Raxol.Core.Style.new(fg_color: :blue)
      Raxol.Core.Style.merge(base, override)
      # => %{bold: true, ..., fg_color: :blue, ...}
  """
  @spec merge(t(), t()) :: t()
  def merge(base, override) when is_map(base) and is_map(override) do
    Map.merge(base, override, fn _key, _base_val, override_val ->
      override_val
    end)
  end

  @doc """
  Create an RGB color tuple.

  ## Example

      Raxol.Core.Style.rgb(255, 100, 50)
      # => {255, 100, 50}
  """
  @spec rgb(0..255, 0..255, 0..255) :: {0..255, 0..255, 0..255}
  def rgb(r, g, b) when r in 0..255 and g in 0..255 and b in 0..255 do
    {r, g, b}
  end

  @doc """
  Create a 256-color palette index.

  ## Example

      Raxol.Core.Style.color_256(196)
      # => 196
  """
  @spec color_256(0..255) :: 0..255
  def color_256(index) when index in 0..255 do
    index
  end

  @doc """
  Validate and return a named color atom.

  Valid colors: :black, :red, :green, :yellow, :blue, :magenta, :cyan, :white

  ## Example

      Raxol.Core.Style.named_color(:blue)
      # => :blue
  """
  @spec named_color(
          :black
          | :red
          | :green
          | :yellow
          | :blue
          | :magenta
          | :cyan
          | :white
        ) ::
          :black | :red | :green | :yellow | :blue | :magenta | :cyan | :white
  def named_color(color) when color in @valid_colors do
    color
  end

  @doc """
  Convert a style map to ANSI escape codes.

  ## Example

      style = Raxol.Core.Style.new(bold: true, fg_color: :blue)
      Raxol.Core.Style.to_ansi(style)
      # => "\e[1;34m"
  """
  @spec to_ansi(map()) :: String.t()
  def to_ansi(style) when is_map(style) do
    codes =
      []
      |> maybe_add_code(style[:bold], "1")
      |> maybe_add_code(style[:italic], "3")
      |> maybe_add_code(style[:underline], "4")
      |> add_fg_color(style[:fg_color])
      |> add_bg_color(style[:bg_color])

    case codes do
      [] -> ""
      _ -> "\e[#{Enum.join(codes, ";")}m"
    end
  end

  @doc """
  Reset ANSI sequence to clear all styling.

  ## Example

      Raxol.Core.Style.reset()
      # => "\e[0m"
  """
  @spec reset() :: String.t()
  def reset, do: "\e[0m"

  # Private helpers

  defp maybe_add_code(codes, true, code), do: codes ++ [code]
  defp maybe_add_code(codes, _, _code), do: codes

  defp add_fg_color(codes, nil), do: codes

  defp add_fg_color(codes, color) when is_atom(color) do
    case Map.get(@color_codes, color) do
      nil -> codes
      code -> codes ++ [Integer.to_string(30 + code)]
    end
  end

  defp add_fg_color(codes, index) when is_integer(index) and index in 0..255 do
    codes ++ ["38", "5", Integer.to_string(index)]
  end

  defp add_fg_color(codes, {r, g, b})
       when r in 0..255 and g in 0..255 and b in 0..255 do
    codes ++
      [
        "38",
        "2",
        Integer.to_string(r),
        Integer.to_string(g),
        Integer.to_string(b)
      ]
  end

  defp add_fg_color(codes, _), do: codes

  defp add_bg_color(codes, nil), do: codes

  defp add_bg_color(codes, color) when is_atom(color) do
    case Map.get(@color_codes, color) do
      nil -> codes
      code -> codes ++ [Integer.to_string(40 + code)]
    end
  end

  defp add_bg_color(codes, index) when is_integer(index) and index in 0..255 do
    codes ++ ["48", "5", Integer.to_string(index)]
  end

  defp add_bg_color(codes, {r, g, b})
       when r in 0..255 and g in 0..255 and b in 0..255 do
    codes ++
      [
        "48",
        "2",
        Integer.to_string(r),
        Integer.to_string(g),
        Integer.to_string(b)
      ]
  end

  defp add_bg_color(codes, _), do: codes
end

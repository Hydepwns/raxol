defmodule Raxol.Terminal.Color.TrueColor.Palette do
  @moduledoc """
  Named color constants and lookup for TrueColor.
  """

  @colors %{
    black: {0, 0, 0},
    white: {255, 255, 255},
    red: {255, 0, 0},
    green: {0, 255, 0},
    blue: {0, 0, 255},
    yellow: {255, 255, 0},
    magenta: {255, 0, 255},
    cyan: {0, 255, 255},
    orange: {255, 165, 0},
    purple: {128, 0, 128},
    pink: {255, 192, 203},
    brown: {165, 42, 42},
    gray: {128, 128, 128},
    lime: {0, 255, 0},
    navy: {0, 0, 128},
    olive: {128, 128, 0},
    silver: {192, 192, 192},
    teal: {0, 128, 128}
  }

  @doc """
  Looks up a named color and returns `{:ok, {r, g, b}}` or `{:error, :unknown_color_name}`.
  """
  @spec lookup(atom() | binary()) ::
          {:ok, {0..255, 0..255, 0..255}} | {:error, :unknown_color_name}
  def lookup(name) when is_binary(name), do: lookup(String.to_atom(name))

  def lookup(name) when is_atom(name) do
    case Map.get(@colors, name) do
      nil -> {:error, :unknown_color_name}
      rgb -> {:ok, rgb}
    end
  end

  @doc """
  Returns the full map of named colors.
  """
  @spec all() :: %{atom() => {0..255, 0..255, 0..255}}
  def all, do: @colors
end

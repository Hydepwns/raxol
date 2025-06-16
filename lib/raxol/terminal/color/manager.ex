defmodule Raxol.Terminal.Color.Manager do
  @moduledoc """
  Manages terminal colors and color operations.
  """

  defstruct [
    colors: %{
      foreground: :default,
      background: :default,
      palette: %{}
    },
    default_palette: %{
      black: {0, 0, 0},
      red: {205, 0, 0},
      green: {0, 205, 0},
      yellow: {205, 205, 0},
      blue: {0, 0, 238},
      magenta: {205, 0, 205},
      cyan: {0, 205, 205},
      white: {229, 229, 229},
      bright_black: {127, 127, 127},
      bright_red: {255, 0, 0},
      bright_green: {0, 255, 0},
      bright_yellow: {255, 255, 0},
      bright_blue: {92, 92, 255},
      bright_magenta: {255, 0, 255},
      bright_cyan: {0, 255, 255},
      bright_white: {255, 255, 255}
    }
  ]

  @type color :: :default | {0..255, 0..255, 0..255} | atom()
  @type color_map :: %{atom() => color()}

  @type t :: %__MODULE__{
    colors: %{
      foreground: color(),
      background: color(),
      palette: color_map()
    },
    default_palette: color_map()
  }

  @doc """
  Creates a new color manager instance.
  """
  def new(opts \\ []) do
    %__MODULE__{
      colors: %{
        foreground: Keyword.get(opts, :foreground, :default),
        background: Keyword.get(opts, :background, :default),
        palette: Keyword.get(opts, :palette, %{})
      }
    }
  end

  @doc """
  Sets multiple colors at once.
  """
  def set_colors(%__MODULE__{} = state, colors) when is_map(colors) do
    new_colors = Map.merge(state.colors, colors)
    %{state | colors: new_colors}
  end

  @doc """
  Gets all current colors.
  """
  def get_colors(%__MODULE__{} = state) do
    state.colors
  end

  @doc """
  Gets a specific color by name.
  """
  def get_color(%__MODULE__{} = state, name) when is_atom(name) do
    case name do
      :foreground -> state.colors.foreground
      :background -> state.colors.background
      _ -> Map.get(state.colors.palette, name)
    end
  end

  @doc """
  Sets a specific color by name.
  """
  def set_color(%__MODULE__{} = state, name, value) when is_atom(name) do
    case name do
      :foreground ->
        %{state | colors: %{state.colors | foreground: value}}
      :background ->
        %{state | colors: %{state.colors | background: value}}
      _ ->
        new_palette = Map.put(state.colors.palette, name, value)
        %{state | colors: %{state.colors | palette: new_palette}}
    end
  end

  @doc """
  Resets all colors to their default values.
  """
  def reset_colors(%__MODULE__{} = state) do
    %{state |
      colors: %{
        foreground: :default,
        background: :default,
        palette: %{}
      }
    }
  end

  @doc """
  Converts a color to RGB format.
  """
  def color_to_rgb(%__MODULE__{} = state, color) do
    case color do
      :default -> :default
      {r, g, b} when is_integer(r) and is_integer(g) and is_integer(b) -> {r, g, b}
      name when is_atom(name) ->
        Map.get(state.colors.palette, name) || Map.get(state.default_palette, name)
      _ -> :default
    end
  end

  @doc """
  Gets the default color palette.
  """
  def get_default_palette(%__MODULE__{} = state) do
    state.default_palette
  end

  @doc """
  Sets a custom color palette.
  """
  def set_palette(%__MODULE__{} = state, palette) when is_map(palette) do
    %{state | colors: %{state.colors | palette: palette}}
  end

  @doc """
  Merges a new palette with the existing one.
  """
  def merge_palette(%__MODULE__{} = state, palette) when is_map(palette) do
    new_palette = Map.merge(state.colors.palette, palette)
    %{state | colors: %{state.colors | palette: new_palette}}
  end
end

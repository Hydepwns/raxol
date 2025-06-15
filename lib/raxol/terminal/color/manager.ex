defmodule Raxol.Terminal.Color.Manager do
  @moduledoc """
  Manages terminal colors and color-related operations.
  """

  defstruct [
    :colors,
    :default_colors,
    :color_mode
  ]

  @type color :: {integer(), integer(), integer()}
  @type color_mode :: :rgb | :indexed
  @type color_map :: %{integer() => color()}

  @type t :: %__MODULE__{
          colors: color_map(),
          default_colors: color_map(),
          color_mode: color_mode()
        }

  @doc """
  Creates a new color manager with default settings.
  """
  def new(opts \\ []) do
    %__MODULE__{
      colors: Keyword.get(opts, :colors, default_colors()),
      default_colors: default_colors(),
      color_mode: Keyword.get(opts, :color_mode, :rgb)
    }
  end

  @doc """
  Sets multiple colors at once.
  """
  def set_colors(%__MODULE__{} = manager, colors) when is_map(colors) do
    %{manager | colors: Map.merge(manager.colors, colors)}
  end

  @doc """
  Gets all current colors.
  """
  def get_colors(%__MODULE__{} = manager) do
    manager.colors
  end

  @doc """
  Gets a specific color by index.
  """
  def get_color(%__MODULE__{} = manager, index) do
    Map.get(manager.colors, index)
  end

  @doc """
  Sets a specific color by index.
  """
  def set_color(%__MODULE__{} = manager, index, color)
      when is_tuple(color) and tuple_size(color) == 3 do
    %{manager | colors: Map.put(manager.colors, index, color)}
  end

  @doc """
  Resets all colors to their default values.
  """
  def reset_colors(%__MODULE__{} = manager) do
    %{manager | colors: manager.default_colors}
  end

  @doc """
  Converts a color to RGB format.
  """
  def color_to_rgb(%__MODULE__{} = manager, color) do
    case manager.color_mode do
      :rgb -> color
      :indexed -> Map.get(manager.colors, color, {0, 0, 0})
    end
  end

  @doc """
  Sets the color mode.
  """
  def set_color_mode(%__MODULE__{} = manager, mode)
      when mode in [:rgb, :indexed] do
    %{manager | color_mode: mode}
  end

  @doc """
  Gets the current color mode.
  """
  def get_color_mode(%__MODULE__{} = manager) do
    manager.color_mode
  end

  # Private Functions

  defp default_colors do
    %{
      # Black
      0 => {0, 0, 0},
      # Red
      1 => {170, 0, 0},
      # Green
      2 => {0, 170, 0},
      # Yellow
      3 => {170, 85, 0},
      # Blue
      4 => {0, 0, 170},
      # Magenta
      5 => {170, 0, 170},
      # Cyan
      6 => {0, 170, 170},
      # White
      7 => {170, 170, 170},
      # Bright Black
      8 => {85, 85, 85},
      # Bright Red
      9 => {255, 85, 85},
      # Bright Green
      10 => {85, 255, 85},
      # Bright Yellow
      11 => {255, 255, 85},
      # Bright Blue
      12 => {85, 85, 255},
      # Bright Magenta
      13 => {255, 85, 255},
      # Bright Cyan
      14 => {85, 255, 255},
      # Bright White
      15 => {255, 255, 255}
    }
  end
end

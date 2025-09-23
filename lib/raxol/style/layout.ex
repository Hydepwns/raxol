defmodule Raxol.Style.Layout do
  @moduledoc """
  Handles layout styling for Raxol components.
  """

  @type t :: %__MODULE__{
          margin:
            {non_neg_integer(), non_neg_integer(), non_neg_integer(),
             non_neg_integer()},
          padding:
            {non_neg_integer(), non_neg_integer(), non_neg_integer(),
             non_neg_integer()},
          border: {atom(), atom(), atom(), atom()},
          alignment: :start | :center | :end | :space_between | :space_around,
          overflow: :visible | :hidden | :scroll | :auto,
          position: :static | :relative | :absolute | :fixed,
          z_index: integer(),
          display: :block | :inline | :flex | :grid | :none,
          flex: map(),
          grid: map()
        }

  defstruct margin: {0, 0, 0, 0},
            padding: {0, 0, 0, 0},
            border: {:none, :none, :none, :none},
            alignment: :start,
            overflow: :visible,
            position: :static,
            z_index: 0,
            display: :block,
            flex: %{},
            grid: %{}

  @doc """
  Creates a new layout style with default values.
  """
  def new do
    %__MODULE__{}
  end

  @doc """
  Creates a new layout style with the specified margin.
  """
  def new(margin) do
    %__MODULE__{margin: margin}
  end

  @doc """
  Sets the margin for a layout style.
  """
  def set_margin(style, margin) do
    %{style | margin: margin}
  end

  @doc """
  Gets the margin from a layout style.
  """
  def get_margin(style) do
    style.margin
  end

  @doc """
  Sets the padding for a layout style.
  """
  def set_padding(style, padding) do
    %{style | padding: padding}
  end

  @doc """
  Gets the padding from a layout style.
  """
  def get_padding(style) do
    style.padding
  end

  @doc """
  Sets the border for a layout style.
  """
  def set_border(style, border, _border_style \\ nil) do
    %{style | border: border}
  end

  @doc """
  Gets the border from a layout style.
  """
  def get_border(style) do
    style.border
  end

  @doc """
  Sets the alignment for a layout style.
  """
  def set_alignment(style, alignment)
      when alignment in [:start, :center, :end, :space_between, :space_around] do
    %{style | alignment: alignment}
  end

  @doc """
  Gets the alignment from a layout style.
  """
  def get_alignment(style) do
    style.alignment
  end

  @doc """
  Sets the overflow behavior for a layout style.
  """
  def set_overflow(style, overflow)
      when overflow in [:visible, :hidden, :scroll, :auto] do
    %{style | overflow: overflow}
  end

  @doc """
  Gets the overflow behavior from a layout style.
  """
  def get_overflow(style) do
    style.overflow
  end

  @doc """
  Sets the position for a layout style.
  """
  def set_position(style, position)
      when position in [:static, :relative, :absolute, :fixed] do
    %{style | position: position}
  end

  @doc """
  Gets the position from a layout style.
  """
  def get_position(style) do
    style.position
  end

  @doc """
  Sets the z-index for a layout style.
  """
  def set_z_index(style, z_index) do
    %{style | z_index: z_index}
  end

  @doc """
  Gets the z-index from a layout style.
  """
  def get_z_index(style) do
    style.z_index
  end

  @doc """
  Sets the display property for a layout style.
  """
  def set_display(style, display)
      when display in [:block, :inline, :flex, :grid, :none] do
    %{style | display: display}
  end

  @doc """
  Gets the display property from a layout style.
  """
  def get_display(style) do
    style.display
  end

  @doc """
  Sets the flex properties for a layout style.
  """
  def set_flex(style, flex) when is_map(flex) do
    %{style | flex: flex}
  end

  @doc """
  Gets the flex properties from a layout style.
  """
  def get_flex(style) do
    style.flex
  end

  @doc """
  Sets the grid properties for a layout style.
  """
  def set_grid(style, grid) when is_map(grid) do
    %{style | grid: grid}
  end

  @doc """
  Gets the grid properties from a layout style.
  """
  def get_grid(style) do
    style.grid
  end
end

defmodule Raxol.UI.RendererTestHelper do
  @moduledoc """
  Test helper functions for UI rendering tests.
  Provides utilities to create test elements and verify rendering results.
  """

  @doc """
  Creates a test text element.

  ## Parameters
    * `x` - X position
    * `y` - Y position  
    * `text` - Text content

  ## Returns
    * Element map for rendering
  """
  def create_test_text(x, y, text) do
    %{
      type: :text,
      x: x,
      y: y,
      text: text,
      width: String.length(text),
      height: 1,
      style: %{
        fg: :default,
        bg: :default
      }
    }
  end

  @doc """
  Creates a test panel element.

  ## Parameters
    * `x` - X position
    * `y` - Y position
    * `width` - Panel width
    * `height` - Panel height
    * `children` - List of child elements (optional)

  ## Returns
    * Element map for rendering
  """
  def create_test_panel(x, y, width, height, children \\ []) do
    %{
      type: :panel,
      x: x,
      y: y,
      width: width,
      height: height,
      children: children,
      style: %{
        fg: :default,
        bg: :default,
        border: :single
      }
    }
  end

  @doc """
  Creates a test element of the specified type.

  ## Parameters
    * `type` - Element type (atom)
    * `x` - X position
    * `y` - Y position
    * `attrs` - Additional attributes map

  ## Returns
    * Element map for rendering
  """
  def create_test_element(type, x, y, attrs \\ %{}) do
    base = %{
      type: type,
      x: x,
      y: y,
      style: %{
        fg: :default,
        bg: :default
      }
    }

    Map.merge(base, attrs)
  end

  @doc """
  Gets cells from a cell list that contain the specified character.

  ## Parameters
    * `cells` - List of cells in format {x, y, char, fg, bg, attrs}
    * `char` - Character to search for

  ## Returns
    * List of matching cells
  """
  def get_cells_with_char(cells, char) do
    Enum.filter(cells, fn
      {_x, _y, ^char, _fg, _bg, _attrs} -> true
      _ -> false
    end)
  end

  @doc """
  Gets cells from a cell list that are at the specified position.

  ## Parameters
    * `cells` - List of cells in format {x, y, char, fg, bg, attrs}
    * `x` - X position
    * `y` - Y position

  ## Returns
    * List of matching cells
  """
  def get_cells_at_position(cells, x, y) do
    Enum.filter(cells, fn
      {^x, ^y, _char, _fg, _bg, _attrs} -> true
      _ -> false
    end)
  end

  @doc """
  Gets the first cell at the specified position.

  ## Parameters
    * `cells` - List of cells in format {x, y, char, fg, bg, attrs}
    * `x` - X position
    * `y` - Y position

  ## Returns
    * Cell tuple or nil if not found
  """
  def get_cell_at_position(cells, x, y) do
    Enum.find(cells, fn
      {^x, ^y, _char, _fg, _bg, _attrs} -> true
      _ -> false
    end)
  end

  @doc """
  Creates a test box element with padding.

  ## Parameters
    * `x` - X position
    * `y` - Y position
    * `width` - Box width
    * `height` - Box height
    * `padding` - Padding amount

  ## Returns
    * Element map for rendering
  """
  def create_test_box_with_padding(x, y, width, height, padding) do
    %{
      type: :box,
      x: x,
      y: y,
      width: width,
      height: height,
      style: %{
        fg: :default,
        bg: :default,
        border: :single,
        padding: padding
      }
    }
  end

  @doc """
  Creates a test element with visibility settings.

  ## Parameters
    * `x` - X position
    * `y` - Y position
    * `visible` - Boolean visibility

  ## Returns
    * Element map for rendering
  """
  def create_test_element_with_visibility(x, y, visible) do
    %{
      type: :text,
      x: x,
      y: y,
      text: "Test",
      width: 4,
      height: 1,
      visible: visible,
      style: %{
        fg: :default,
        bg: :default
      }
    }
  end
end

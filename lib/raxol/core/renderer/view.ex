defmodule Raxol.Core.Renderer.View do
  @moduledoc """
  Main facade module for the Raxol view system.
  Provides a unified interface for creating and managing views.
  """

  alias Raxol.Core.Renderer.View.Types
  alias Raxol.Core.Renderer.View.Layout.{Flex, Grid}
  alias Raxol.Core.Renderer.View.Style.Border
  alias Raxol.Core.Renderer.View.Components.{Text, Box, Scroll}
  alias Raxol.Core.Renderer.View.Utils.ViewUtils
  alias Raxol.Renderer.Layout, as: LayoutEngine

  @typedoc """
  Style options for a view. Typically a list of atoms, e.g., [:bold, :underline].
  See `Raxol.Core.Renderer.View.Types.style/0` for details.
  """
  @type style :: Types.style()

  @doc """
  Creates a new view with the specified type and options.

  ## Options
    * `:type` - The type of view to create
    * `:position` - Position of the view {x, y}
    * `:z_index` - Z-index for layering
    * `:size` - Size of the view {width, height}
    * `:style` - Style options for the view
    * `:fg` - Foreground color
    * `:bg` - Background color
    * `:border` - Border style
    * `:padding` - Padding around the view
    * `:margin` - Margin around the view
    * `:children` - Child views
    * `:content` - Content for the view

  ## Examples

      View.new(:box, size: {80, 24})
      View.new(:text, content: "Hello", fg: :red)
  """
  def new(type, opts \\ []) do
    defaults = %{
      type: type,
      position: {0, 0},
      z_index: 0,
      size: {0, 0},
      style: %{},
      fg: nil,
      bg: nil,
      border: nil,
      padding: {0, 0, 0, 0},
      margin: {0, 0, 0, 0},
      children: [],
      content: nil
    }

    view = Map.merge(defaults, Map.new(opts))
    normalize_spacing(view)
  end

  @doc """
  Creates a new text view.

  ## Options
    * `:content` - The text content
    * `:fg` - Foreground color
    * `:bg` - Background color
    * `:style` - Text style options
    * `:align` - Text alignment
    * `:wrap` - Text wrapping mode

  ## Examples

      View.text("Hello", fg: :red)
      View.text("World", style: [bold: true, underline: true])
  """
  def text(content, opts \\ []) do
    Text.new(content, opts)
  end

  @doc """
  Creates a new box view with padding and optional border.

  ## Parameters
    * `opts` - Options for the box
      * `:padding` - Padding around the content (default: 0)
      * `:border` - Border style (`:none`, `:single`, `:double`, `:rounded`, `:bold`, `:block`, `:simple`)

  ## Examples

      View.box(padding: 2)
      View.box(padding: 2, border: :single)
  """
  def box(opts \\ []) do
    Box.new(opts)
  end

  @doc """
  Creates a new row layout.

  ## Options
    * `:children` - Child views
    * `:align` - Alignment of children
    * `:justify` - Justification of children
    * `:gap` - Gap between children

  ## Examples

      View.row do
        [text("Hello"), text("World")]
      end
      View.row align: :center, gap: 2 do
        [text("A"), text("B")]
      end
  """
  def row(opts \\ []) do
    Flex.row(opts)
  end

  @doc """
  Creates a new flex container.

  ## Options
    * `:direction` - Flex direction (:row or :column)
    * `:children` - Child views
    * `:align` - Alignment of children
    * `:justify` - Justification of children
    * `:gap` - Gap between children
    * `:wrap` - Whether to wrap children

  ## Examples

      View.flex(direction: :column, children: [text("Hello"), text("World")])
      View.flex(align: :center, gap: 2, wrap: true)
  """

  # def flex(opts, children) do
  #   Flex.container(Keyword.merge(opts, children: children))
  # end

  @doc """
  Creates a new grid layout.

  ## Options
    * `:columns` - Number of columns or list of column sizes
    * `:rows` - Number of rows or list of row sizes
    * `:gap` - Gap between grid items
    * `:align` - Alignment of items within cells
    * `:justify` - Justification of items within cells
    * `:children` - Child views

  ## Examples

      View.grid(columns: 3, rows: 2)
      View.grid(columns: [1, 2, 1], rows: ["auto", "1fr"])
  """
  def grid(opts \\ []) do
    Grid.new(opts)
  end

  @doc """
  Creates a new border around a view.

  ## Options
    * `:style` - Border style
    * `:title` - Title for the border
    * `:fg` - Foreground color
    * `:bg` - Background color

  ## Examples

      View.border(view, style: :single)
      View.border(view, title: "Title", style: :double)
  """
  def border(view, opts \\ []) do
    Border.wrap(view, opts)
  end

  @doc """
  Creates a new scrollable view.

  ## Options
    * `:viewport` - Viewport size {width, height}
    * `:offset` - Initial scroll offset {x, y}
    * `:scrollbars` - Whether to show scrollbars
    * `:fg` - Foreground color
    * `:bg` - Background color

  ## Examples

      View.scroll(view, viewport: {80, 24})
      View.scroll(view, offset: {0, 10}, scrollbars: true)
  """
  def scroll(view, opts \\ []) do
    Scroll.new(view, opts)
  end

  @doc """
  Applies layout to a view, calculating absolute positions for all elements.
  Delegates to Raxol.Renderer.Layout.apply_layout/2.
  """
  def layout(view, dimensions) do
    LayoutEngine.apply_layout(view, dimensions)
  end

  @doc """
  Macro for creating a row layout with a do-block for children.

  ## Examples

      View.row style: [:bold] do
        [View.text("A"), View.text("B")]
      end
  """
  defmacro row(opts, do: block) do
    quote do
      Raxol.Core.Renderer.View.Layout.Flex.row(
        Keyword.merge(unquote(opts), children: unquote(block))
      )
    end
  end

  @doc """
  Macro for creating a grid layout with a do-block for children.

  ## Examples

      View.grid columns: 3 do
        [View.text("A"), View.text("B"), View.text("C")]
      end
  """
  defmacro grid(opts, do: block) do
    quote do
      Raxol.Core.Renderer.View.Layout.Grid.new(
        Keyword.merge(unquote(opts), children: unquote(block))
      )
    end
  end

  @doc """
  Macro for creating a border around a view with a do-block for children.

  ## Examples

      View.border_wrap style: [:bold] do
        [View.text("A"), View.text("B")]
      end

      View.border_wrap :single, style: [:bold] do
        [View.text("A"), View.text("B")]
      end
  """
  defmacro border_wrap(style, do: block) do
    quote do
      Raxol.Core.Renderer.View.Style.Border.wrap(unquote(block),
        style: unquote(style)
      )
    end
  end

  @doc """
  Macro for creating a border around a view with a do-block for children,
  allowing style and other options.

  ## Examples
      View.border :single, size: {5,5}, title: "Box" do
        View.text("Content")
      end
  """
  defmacro border(style, opts, do: block) do
    quote do
      all_opts = Keyword.merge(unquote(opts), style: unquote(style))
      Raxol.Core.Renderer.View.Style.Border.wrap(unquote(block), all_opts)
    end
  end

  @doc """
  Macro for creating a scrollable view with a do-block for children.

  ## Examples

      View.scroll_wrap viewport: {80, 24} do
        [View.text("A"), View.text("B")]
      end
  """
  defmacro scroll_wrap(opts, do: block) do
    quote do
      Raxol.Core.Renderer.View.Components.Scroll.new(
        unquote(block),
        unquote(opts)
      )
    end
  end

  @doc """
  Wraps a view with a border, optionally with a title and style.

  ## Parameters
    * `view` - The view to wrap with a border
    * `opts` - Options for the border
      * `:title` - Optional title to display in the border
      * `:style` - Border style (`:single`, `:double`, `:rounded`, `:bold`, `:block`, `:simple`)
      * `:align` - Title alignment (`:left`, `:center`, `:right`)

  ## Examples

      View.border_wrap(view, style: :single)
      View.border_wrap(view, title: "Title", style: :double)
  """
  def wrap_with_border(view, opts \\ []) do
    Border.wrap(view, opts)
  end

  @doc """
  Wraps a view with a border using a block style.

  ## Parameters
    * `view` - The view to wrap with a border
    * `opts` - Options for the border
      * `:title` - Optional title to display in the border
      * `:align` - Title alignment (`:left`, `:center`, `:right`)

  ## Examples

      View.block_border(view)
      View.block_border(view, title: "Title")
  """
  def block_border(view, opts \\ []) do
    wrap_with_border(view, Keyword.put(opts, :style, :block))
  end

  @doc """
  Wraps a view with a border using a double line style.

  ## Parameters
    * `view` - The view to wrap with a border
    * `opts` - Options for the border
      * `:title` - Optional title to display in the border
      * `:align` - Title alignment (`:left`, `:center`, `:right`)

  ## Examples

      View.double_border(view)
      View.double_border(view, title: "Title")
  """
  def double_border(view, opts \\ []) do
    wrap_with_border(view, Keyword.put(opts, :style, :double))
  end

  @doc """
  Wraps a view with a border using a rounded style.

  ## Parameters
    * `view` - The view to wrap with a border
    * `opts` - Options for the border
      * `:title` - Optional title to display in the border
      * `:align` - Title alignment (`:left`, `:center`, `:right`)

  ## Examples

      View.rounded_border(view)
      View.rounded_border(view, title: "Title")
  """
  def rounded_border(view, opts \\ []) do
    wrap_with_border(view, Keyword.put(opts, :style, :rounded))
  end

  @doc """
  Wraps a view with a border using a bold style.

  ## Parameters
    * `view` - The view to wrap with a border
    * `opts` - Options for the border
      * `:title` - Optional title to display in the border
      * `:align` - Title alignment (`:left`, `:center`, `:right`)

  ## Examples

      View.bold_border(view)
      View.bold_border(view, title: "Title")
  """
  def bold_border(view, opts \\ []) do
    wrap_with_border(view, Keyword.put(opts, :style, :bold))
  end

  @doc """
  Wraps a view with a border using a simple style.

  ## Parameters
    * `view` - The view to wrap with a border
    * `opts` - Options for the border
      * `:title` - Optional title to display in the border
      * `:align` - Title alignment (`:left`, `:center`, `:right`)

  ## Examples

      View.simple_border(view)
      View.simple_border(view, title: "Title")
  """
  def simple_border(view, opts \\ []) do
    wrap_with_border(view, Keyword.put(opts, :style, :simple))
  end

  @doc """
  Creates a new panel view (box with border and children).

  ## Options
    * `:children` - Child views
    * `:border` - Border style (default: :single)
    * `:padding` - Padding inside the panel (default: 1)
    * `:style` - Additional style options
    * `:title` - Optional title for the panel
    * `:fg` - Foreground color
    * `:bg` - Background color

  ## Examples
      View.panel(children: [View.text("Hello")])
      View.panel(border: :double, title: "Panel")

  NOTE: Only panel/1 (with a keyword list) is supported. Update any panel/2 usages to panel/1.
  """
  def panel(opts \\ []) do
    border = Keyword.get(opts, :border, :single)
    padding = Keyword.get(opts, :padding, 1)
    children = Keyword.get(opts, :children, [])
    style = Keyword.get(opts, :style, [])
    title = Keyword.get(opts, :title)
    fg = Keyword.get(opts, :fg)
    bg = Keyword.get(opts, :bg)

    box_opts =
      [
        border: border,
        padding: padding,
        children: children,
        fg: fg,
        bg: bg
      ]
      |> Keyword.merge(if(title, do: [title: title], else: []))
      |> Keyword.merge(if(style != [], do: [style: style], else: []))

    __MODULE__.box(box_opts)
  end

  @doc """
  Macro for creating a flex layout with a do-block for children.

  ## Examples

      View.flex direction: :row do
        [View.text("A"), View.text("B")]
      end
  """
  defmacro flex(opts, do: block) do
    quote do
      Raxol.Core.Renderer.View.Layout.Flex.container(
        Keyword.merge(unquote(opts), children: unquote(block))
      )
    end
  end

  def flex(opts) do
    Raxol.Core.Renderer.View.Layout.Flex.container(opts)
  end

  defmacro shadow(opts, do: block) do
    quote do
      # Placeholder: just returns children, actual shadow logic TBD
      # Needs to be a map representing a view element.
      %{
        # Placeholder type
        type: :shadow_wrapper,
        opts: unquote(opts),
        children: unquote(block)
      }
    end
  end

  defp normalize_spacing(view) do
    view
    |> Map.update!(:padding, &ViewUtils.normalize_spacing/1)
    |> Map.update!(:margin, &ViewUtils.normalize_spacing/1)
  end
end

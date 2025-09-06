defmodule Raxol.Core.Renderer.View do
  @moduledoc """
  Provides view-related functionality for rendering UI components.
  """

  alias Raxol.Core.Renderer.View.Types
  alias Raxol.Core.Renderer.View.Layout.Flex
  alias Raxol.Core.Renderer.View.Style.Border
  alias Raxol.Core.Renderer.View.Components.{Text, Box, Scroll}
  alias Raxol.Core.Renderer.View.Utils.ViewUtils
  alias Raxol.Core.Renderer.Layout, as: LayoutEngine

  alias Raxol.Core.Renderer.View.{
    Components,
    Borders,
    Validation,
    LayoutHelpers
  }

  @typedoc """
  Style options for a view. Typically a list of atoms, e.g., [:bold, :underline].
  See `Raxol.Core.Renderer.View.Types.style()` type for details.
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
    Validation.validate_view_type(type)
    Validation.validate_view_options(opts)

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
      * `:children` - Child views to place inside the box
      * `:size` - Size of the box {width, height}
      * `:style` - Style options for the box

  ## Examples

      View.box(padding: 2)
      View.box(padding: 2, border: :single)
      View.box(style: [border: :double, padding: 1], children: [text("Hello")])
  """
  def box(opts \\ []) do
    validate_keyword_opts(opts, "View.box")
    Box.new(opts)
  end

  defmacro box(opts, do: block) do
    quote do
      Raxol.Core.Renderer.View.validate_keyword_opts(
        unquote(opts),
        "View.box macro"
      )

      children = unquote(block)

      Raxol.Core.Renderer.View.Components.Box.new(
        Keyword.merge(unquote(opts), children: children)
      )
    end
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
    validate_keyword_opts(opts, "View.row")
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
  defmacro flex(opts, do: block) do
    quote do
      Raxol.Core.Renderer.View.validate_keyword_opts(
        unquote(opts),
        "View.flex macro"
      )

      children = unquote(block)

      Raxol.Core.Renderer.View.Layout.Flex.container(
        Keyword.merge(unquote(opts), children: children)
      )
    end
  end

  @doc """
  Creates a grid layout with the given options and block.

  ## Options
    * `:columns` - Number of columns in the grid
    * `:rows` - Number of rows in the grid
    * `:gap` - Gap between grid items
    * `:align` - Alignment of grid items
    * `:justify` - Justification of grid items

  ## Examples

      View.grid(columns: 2, gap: 2) do
        [text("A"), text("B"), text("C"), text("D")]
      end
  """
  defmacro grid(opts, do: block) do
    quote do
      Raxol.Core.Renderer.View.validate_keyword_opts(
        unquote(opts),
        "View.grid macro"
      )

      children = unquote(block)

      Raxol.Core.Renderer.View.Layout.Grid.new(
        Keyword.merge(
          Raxol.Core.Renderer.View.ensure_keyword(unquote(opts)),
          Raxol.Core.Renderer.View.ensure_keyword(children: children)
        )
      )
    end
  end

  defmacro grid(opts) do
    quote do
      Raxol.Core.Renderer.View.validate_keyword_opts(
        unquote(opts),
        "View.grid macro"
      )

      Raxol.Core.Renderer.View.Layout.Grid.new(unquote(opts))
    end
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
    validate_keyword_opts(opts, "View.border")
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
    validate_keyword_opts(opts, "View.scroll")
    Scroll.new(view, opts)
  end

  @doc """
  Applies layout to a view, calculating absolute positions for all elements.
  Delegates to Raxol.Renderer.Layout.apply_layout/2.
  """
  def layout(view, dimensions) do
    Validation.validate_layout_dimensions(dimensions)

    result = LayoutEngine.apply_layout(view, Map.new(dimensions))
    process_layout_result(result, view)
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
      Raxol.Core.Renderer.View.validate_keyword_opts(
        unquote(opts),
        "View.row macro"
      )

      Raxol.Core.Renderer.View.Layout.Flex.row(
        Keyword.merge(
          Raxol.Core.Renderer.View.ensure_keyword(unquote(opts)),
          Raxol.Core.Renderer.View.ensure_keyword(children: unquote(block))
        )
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
      opts = [style: unquote(style)]

      Raxol.Core.Renderer.View.validate_keyword_opts(
        opts,
        "View.border_wrap macro"
      )

      Raxol.Core.Renderer.View.Style.Border.wrap(unquote(block), opts)
    end
  end

  defmacro border(style, opts, do: block) do
    quote do
      all_opts =
        Keyword.merge(
          Raxol.Core.Renderer.View.ensure_keyword(unquote(opts)),
          Raxol.Core.Renderer.View.ensure_keyword(style: unquote(style))
        )

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
      Raxol.Core.Renderer.View.validate_keyword_opts(
        unquote(opts),
        "View.scroll_wrap macro"
      )

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
    Borders.wrap_with_border(view, opts)
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
    Borders.block_border(view, opts)
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
    Borders.double_border(view, opts)
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
    Borders.rounded_border(view, opts)
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
    Borders.bold_border(view, opts)
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
    Borders.simple_border(view, opts)
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
    LayoutHelpers.panel(opts)
  end

  @doc """
  Creates a new column layout.

  ## Options
    * `:children` - Child views
    * `:align` - Alignment of children
    * `:justify` - Justification of children
    * `:gap` - Gap between children

  ## Examples

      View.column do
        [text("Hello"), text("World")]
      end
      View.column align: :center, gap: 2 do
        [text("A"), text("B")]
      end
  """
  def column(opts) do
    Raxol.Core.Renderer.View.Layout.Flex.column(opts)
  end

  @doc """
  Creates a button element.

  ## Options
    * `:id` - Unique identifier for the button
    * `:on_click` - Event handler for click events
    * `:aria_label` - Accessibility label
    * `:aria_description` - Accessibility description
    * `:style` - Style options for the button

  ## Examples

      View.button("Click Me", on_click: {:button_clicked})
      View.button("Submit", id: "submit_btn", aria_label: "Submit form")
  """
  def button(text, opts \\ []) do
    Components.button(text, opts)
  end

  @doc """
  Creates a checkbox element.

  ## Options
    * `:checked` - Whether the checkbox is checked (default: false)
    * `:on_toggle` - Event handler for toggle events
    * `:aria_label` - Accessibility label
    * `:aria_description` - Accessibility description
    * `:style` - Style options for the checkbox

  ## Examples

      View.checkbox("Enable Feature", checked: true)
      View.checkbox("Accept Terms", on_toggle: {:terms_toggled})
  """
  def checkbox(label, opts \\ []) do
    Components.checkbox(label, opts)
  end

  @doc """
  Creates a text input element.

  ## Options
    * `:value` - Current value of the input (default: "")
    * `:placeholder` - Placeholder text
    * `:on_change` - Event handler for change events
    * `:aria_label` - Accessibility label
    * `:aria_description` - Accessibility description
    * `:style` - Style options for the input

  ## Examples

      View.text_input(placeholder: "Enter your name...")
      View.text_input(value: "John", on_change: {:name_changed})
  """
  def text_input(opts \\ []) do
    Components.text_input(opts)
  end

  @doc """
  Renders a view with the given options.

  ## Parameters
    - _options: A keyword list of rendering options
    - _block: A block containing the view content

  ## Returns
    - A rendered view
  """
  defmacro view(opts, do: block) do
    quote do
      rendered_view = unquote(block)

      rendered_view
      |> Map.merge(unquote(opts))
      |> normalize_spacing()
    end
  end

  defp normalize_spacing(view) do
    padding = Map.get(view, :padding, {0, 0, 0, 0})
    margin = Map.get(view, :margin, {0, 0, 0, 0})

    normalized_padding = ViewUtils.normalize_spacing(padding)
    normalized_margin = ViewUtils.normalize_margin(margin)

    view
    |> Map.put(:padding, normalized_padding)
    |> Map.put(:margin, normalized_margin)
  end

  # Helper function for ensuring keyword lists (public for macro usage)
  def ensure_keyword_list(opts) when is_list(opts), do: opts
  def ensure_keyword_list(opts) when is_map(opts), do: Map.to_list(opts)
  def ensure_keyword_list(_), do: []

  defmacro ensure_keyword(opts) do
    quote do
      case unquote(opts) do
        opts when is_list(opts) and length(opts) > 0 ->
          Raxol.Core.Renderer.View.ensure_keyword_list(opts)

        opts when is_map(opts) ->
          Map.to_list(opts)

        _opts ->
          []
      end
    end
  end

  @doc """
  Creates a simple box element with the given options.
  """
  def box_element(opts \\ []) do
    Components.box_element(opts)
  end

  @doc """
  Calculates flex layout dimensions based on the given constraints.
  Returns a map with calculated width and height.
  """
  @spec flex(map()) :: %{width: integer(), height: integer()}
  def flex(constraints) do
    LayoutHelpers.flex(constraints)
  end

  @doc """
  Creates a shadow effect for a view.

  ## Options
    * `:offset` - Shadow offset as a string or tuple {x, y}
    * `:blur` - Shadow blur radius
    * `:color` - Shadow color
    * `:opacity` - Shadow opacity (0.0 to 1.0)

  ## Examples

      View.shadow(offset: "2px 2px", blur: 4, color: :black)
      View.shadow(offset: {1, 1}, color: :gray, opacity: 0.5)
  """
  def shadow(opts \\ []) do
    Components.shadow(opts)
  end

  defp process_layout_result(result, _view), do: result

  # Helper functions for if statement elimination

  def validate_keyword_opts(opts, function_name) when is_list(opts) do
    require Keyword
    validate_keyword_list(opts, function_name)
  end

  def validate_keyword_opts(opts, function_name) do
    raise ArgumentError,
          "#{function_name} expects a keyword list as the first argument, got: #{inspect(opts)}"
  end

  defp validate_keyword_list(opts, _function_name) when is_list(opts) do
    case opts do
      [] -> :ok
      [tuple | _] when is_tuple(tuple) -> :ok
      _ -> raise ArgumentError, "Expected keyword list"
    end
  end
end

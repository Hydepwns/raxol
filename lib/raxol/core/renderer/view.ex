defmodule Raxol.Core.Renderer.View do
  import Raxol.Guards

  @moduledoc """
  Provides view-related functionality for rendering UI components.
  """

  alias Raxol.Core.Renderer.View.Types
  alias Raxol.Core.Renderer.View.Layout.Flex
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
    validate_view_type(type)
    validate_view_options(opts)

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
    require Keyword

    if !Keyword.keyword?(opts) do
      raise ArgumentError,
            "View.box macro expects a keyword list as the first argument, got: #{inspect(opts)}"
    end

    Box.new(opts)
  end

  defmacro box(opts, do: block) do
    quote do
      require Keyword

      if !Keyword.keyword?(unquote(opts)) do
        raise ArgumentError,
              "View.box macro expects a keyword list as the first argument, got: #{inspect(unquote(opts))}"
      end

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
    require Keyword

    if !Keyword.keyword?(opts) do
      raise ArgumentError,
            "View.row macro expects a keyword list as the first argument, got: #{inspect(opts)}"
    end

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
      require Keyword

      if !Keyword.keyword?(unquote(opts)) do
        raise ArgumentError,
              "View.flex macro expects a keyword list as the first argument, got: #{inspect(unquote(opts))}"
      end

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
      require Keyword

      if !Keyword.keyword?(unquote(opts)) do
        raise ArgumentError,
              "View.grid macro expects a keyword list as the first argument, got: #{inspect(unquote(opts))}"
      end

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
      require Keyword

      if !Keyword.keyword?(unquote(opts)) do
        raise ArgumentError,
              "View.grid macro expects a keyword list as the first argument, got: #{inspect(unquote(opts))}"
      end

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
    require Keyword

    if !Keyword.keyword?(opts) do
      raise ArgumentError,
            "View.border macro expects a keyword list as the first argument, got: #{inspect(opts)}"
    end

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
    require Keyword

    if !Keyword.keyword?(opts) do
      raise ArgumentError,
            "View.scroll macro expects a keyword list as the first argument, got: #{inspect(opts)}"
    end

    Scroll.new(view, opts)
  end

  @doc """
  Applies layout to a view, calculating absolute positions for all elements.
  Delegates to Raxol.Renderer.Layout.apply_layout/2.
  """
  def layout(view, dimensions) do
    validate_layout_dimensions(dimensions)

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
      require Keyword

      if !Keyword.keyword?(unquote(opts)) do
        raise ArgumentError,
              "View.row macro expects a keyword list as the first argument, got: #{inspect(unquote(opts))}"
      end

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
      require Keyword
      opts = [style: unquote(style)]

      if !Keyword.keyword?(opts) do
        raise ArgumentError,
              "View.border_wrap macro expects a keyword list as the first argument, got: #{inspect(opts)}"
      end

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
      require Keyword

      if !Keyword.keyword?(unquote(opts)) do
        raise ArgumentError,
              "View.scroll_wrap macro expects a keyword list as the first argument, got: #{inspect(unquote(opts))}"
      end

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
    require Keyword

    if !Keyword.keyword?(opts) do
      raise ArgumentError,
            "View.wrap_with_border macro expects a keyword list as the second argument, got: #{inspect(opts)}"
    end

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
    require Keyword

    if !Keyword.keyword?(opts) do
      raise ArgumentError,
            "View.block_border macro expects a keyword list as the second argument, got: #{inspect(opts)}"
    end

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
    require Keyword

    if !Keyword.keyword?(opts) do
      raise ArgumentError,
            "View.double_border macro expects a keyword list as the second argument, got: #{inspect(opts)}"
    end

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
    require Keyword

    if !Keyword.keyword?(opts) do
      raise ArgumentError,
            "View.rounded_border macro expects a keyword list as the second argument, got: #{inspect(opts)}"
    end

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
    require Keyword

    if !Keyword.keyword?(opts) do
      raise ArgumentError,
            "View.bold_border macro expects a keyword list as the second argument, got: #{inspect(opts)}"
    end

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
    require Keyword

    if !Keyword.keyword?(opts) do
      raise ArgumentError,
            "View.simple_border macro expects a keyword list as the second argument, got: #{inspect(opts)}"
    end

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
    require Keyword

    if !Keyword.keyword?(opts) do
      raise ArgumentError,
            "View.panel macro expects a keyword list as the first argument, got: #{inspect(opts)}"
    end

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
    * `:on_click` - Event handler for click events
    * `:aria_label` - Accessibility label
    * `:aria_description` - Accessibility description
    * `:style` - Style options for the button

  ## Examples

      View.button("Click Me", on_click: {:button_clicked})
      View.button("Submit", aria_label: "Submit form")
  """
  def button(text, opts \\ []) do
    %{
      type: :button,
      text: text,
      on_click: Keyword.get(opts, :on_click),
      aria_label: Keyword.get(opts, :aria_label),
      aria_description: Keyword.get(opts, :aria_description),
      style: Keyword.get(opts, :style, [])
    }
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
    %{
      type: :checkbox,
      label: label,
      checked: Keyword.get(opts, :checked, false),
      on_toggle: Keyword.get(opts, :on_toggle),
      aria_label: Keyword.get(opts, :aria_label),
      aria_description: Keyword.get(opts, :aria_description),
      style: Keyword.get(opts, :style, [])
    }
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
    %{
      type: :text_input,
      value: Keyword.get(opts, :value, ""),
      placeholder: Keyword.get(opts, :placeholder),
      on_change: Keyword.get(opts, :on_change),
      aria_label: Keyword.get(opts, :aria_label),
      aria_description: Keyword.get(opts, :aria_description),
      style: Keyword.get(opts, :style, [])
    }
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

  defmacro ensure_keyword(opts) do
    quote do
      cond do
        list?(unquote(opts)) and length(unquote(opts)) > 0 and
            tuple?(hd(unquote(opts))) ->
          unquote(opts)

        map?(unquote(opts)) ->
          Map.to_list(unquote(opts))

        true ->
          []
      end
    end
  end

  @doc """
  Creates a simple box element with the given options.
  """
  def box_element(opts \\ []) do
    %{
      type: :box,
      style: Keyword.get(opts, :style, %{}),
      children: Keyword.get(opts, :children, [])
    }
  end

  @doc """
  Calculates flex layout dimensions based on the given constraints.
  Returns a map with calculated width and height.
  """
  @spec flex(map()) :: %{width: integer(), height: integer()}
  def flex(constraints) do
    %{
      width: calculate_flex_width(constraints),
      height: calculate_flex_height(constraints)
    }
  end

  # Private helper functions

  defp calculate_flex_width(constraints) do
    case constraints do
      %{width: :auto, flex: flex} when flex > 0 ->
        # Calculate width based on flex grow
        trunc(constraints.available_width * (flex / constraints.total_flex))

      %{width: width} when integer?(width) ->
        # Fixed width
        width

      _ ->
        # Default to available width
        constraints.available_width
    end
  end

  defp calculate_flex_height(constraints) do
    case constraints do
      %{height: :auto, flex: flex} when flex > 0 ->
        # Calculate height based on flex grow
        trunc(constraints.available_height * (flex / constraints.total_flex))

      %{height: height} when integer?(height) ->
        # Fixed height
        height

      _ ->
        # Default to available height
        constraints.available_height
    end
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
    offset = parse_offset(Keyword.get(opts, :offset, {1, 1}))
    blur = Keyword.get(opts, :blur, 2)
    color = Keyword.get(opts, :color, :black)
    opacity = Keyword.get(opts, :opacity, 0.3)

    %{
      type: :shadow,
      offset: offset,
      blur: blur,
      color: color,
      opacity: opacity
    }
  end

  defp parse_offset(offset) do
    case offset do
      {x, y} when integer?(x) and integer?(y) -> {x, y}
      {x, y} when number?(x) and number?(y) -> {trunc(x), trunc(y)}
      str when binary?(str) -> parse_offset_string(str)
      _ -> {1, 1}
    end
  end

  defp parse_offset_string(str) do
    str
    |> String.split(~r/\s+/)
    |> parse_offset_parts()
  end

  defp parse_offset_parts([x_str, y_str]) do
    {parse_offset_value(x_str), parse_offset_value(y_str)}
  end

  defp parse_offset_parts(_), do: {1, 1}

  defp parse_offset_value(str) do
    str
    |> String.replace("px", "")
    |> String.trim()
    |> parse_integer_or_default()
  end

  defp parse_integer_or_default(""), do: 1

  defp parse_integer_or_default(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> 1
    end
  end

  # Private validation functions
  defp valid_size?({width, height}) when integer?(width) and integer?(height) do
    width > 0 and height > 0
  end

  defp valid_size?(_), do: false

  defp valid_position?({x, y}) when integer?(x) and integer?(y), do: true
  defp valid_position?(_), do: false

  defp validate_view_type(type) do
    valid_types = [
      :text,
      :box,
      :flex,
      :grid,
      :border,
      :scroll,
      :label,
      :button,
      :checkbox,
      :panel
    ]

    if type not in valid_types do
      raise ArgumentError, "Invalid view type: #{inspect(type)}"
    end
  end

  defp validate_view_options(opts) do
    validate_size_option(opts)
    validate_position_option(opts)
    validate_container_dimensions(opts)
  end

  defp validate_size_option(opts) do
    if Keyword.has_key?(opts, :size) do
      size = Keyword.get(opts, :size)

      if not valid_size?(size) do
        raise ArgumentError, "Size must be a tuple of two positive integers"
      end
    end
  end

  defp validate_position_option(opts) do
    if Keyword.has_key?(opts, :position) do
      position = Keyword.get(opts, :position)

      if not valid_position?(position) do
        raise ArgumentError, "Position must be a tuple of two integers"
      end
    end
  end

  defp validate_container_dimensions(opts) do
    if Keyword.has_key?(opts, :width) or Keyword.has_key?(opts, :height) do
      width = Keyword.get(opts, :width)
      height = Keyword.get(opts, :height)

      if (is_integer(width) and width <= 0) or
           (is_integer(height) and height <= 0) do
        raise ArgumentError, "Container dimensions must be positive integers"
      end
    end
  end

  defp validate_layout_dimensions(dimensions) do
    require Keyword

    if !Keyword.keyword?(dimensions) do
      raise ArgumentError,
            "View.layout macro expects a keyword list as the second argument, got: #{inspect(dimensions)}"
    end

    width = Keyword.get(dimensions, :width)
    height = Keyword.get(dimensions, :height)

    if is_integer(width) and width <= 0 do
      raise ArgumentError, "Container width must be a positive integer"
    end

    if is_integer(height) and height <= 0 do
      raise ArgumentError, "Container height must be a positive integer"
    end
  end

  defp process_layout_result(result, _view), do: result
end

defmodule Raxol.Core.Renderer.View.LayoutHelpers do
  @moduledoc """
  Layout helper functions for the View module.
  Extracted from the main View module to improve maintainability.
  """

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
      LayoutHelpers.panel(children: [View.text("Hello")])
      LayoutHelpers.panel(border: :double, title: "Panel")

  NOTE: Only panel/1 (with a keyword list) is supported. Update any panel/2 usages to panel/1.
  """
  def panel(opts \\ []) do
    require Keyword

    if !Keyword.keyword?(opts) do
      raise ArgumentError,
            "LayoutHelpers.panel macro expects a keyword list as the first argument, got: #{inspect(opts)}"
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

    # Note: This will need to be updated to use the new Box module
    # For now, we'll delegate to the main View module
    Raxol.Core.Renderer.View.box(box_opts)
  end

  # Private helper functions

  defp calculate_flex_width(constraints) do
    case constraints do
      %{width: :auto, flex: flex} when flex > 0 ->
        # Calculate width based on flex grow
        trunc(constraints.available_width * (flex / constraints.total_flex))

      %{width: width} when is_integer(width) ->
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

      %{height: height} when is_integer(height) ->
        # Fixed height
        height

      _ ->
        # Default to available height
        constraints.available_height
    end
  end
end

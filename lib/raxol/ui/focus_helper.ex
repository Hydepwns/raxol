defmodule Raxol.UI.FocusHelper do
  @moduledoc """
  Helpers for widgets to determine focus state from the render context.

  The render context includes `focused_element` (the ID of the currently
  focused widget). Widgets call `focused?/2` during render to check if
  they should display focus indicators.

  ## Usage in a widget's render/2

      def render(state, context) do
        am_focused = FocusHelper.focused?(state.id, context)
        style = if am_focused, do: FocusHelper.focus_style(state.style), else: state.style
        # ... render with style
      end
  """

  @doc """
  Returns true if the widget with the given ID is the currently focused element.
  """
  @spec focused?(any(), map()) :: boolean()
  def focused?(nil, _context), do: false

  def focused?(widget_id, context) when is_map(context) do
    context[:focused_element] == widget_id
  end

  def focused?(_widget_id, _context), do: false

  @doc """
  Merges focus indicator styles into the given base style.
  Adds a visible border/highlight for focused widgets.
  """
  @spec focus_style(map()) :: map()
  def focus_style(style) when is_map(style) do
    Map.merge(style, %{border: :single, border_fg: :cyan})
  end

  def focus_style(style), do: style

  @doc """
  Returns the base style with focus styles merged in only if focused.
  Convenience for the common pattern in render/2.
  """
  @spec maybe_focus_style(any(), map(), map()) :: map()
  def maybe_focus_style(widget_id, context, base_style) do
    if focused?(widget_id, context) do
      focus_style(base_style)
    else
      base_style
    end
  end
end

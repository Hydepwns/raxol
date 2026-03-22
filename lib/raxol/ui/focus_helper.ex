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

  @default_focus_style %{border: :single, border_fg: :cyan}
  @default_pseudo_styles %{
    disabled: %{fg: :gray},
    active: %{border: :double, border_fg: :white},
    focused: @default_focus_style
  }

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
  Uses hardcoded defaults. Prefer `focus_style/2` for theme-aware styling.
  """
  @spec focus_style(map()) :: map()
  def focus_style(style) when is_map(style) do
    Map.merge(style, @default_focus_style)
  end

  def focus_style(style), do: style

  @doc """
  Merges focus indicator styles from the theme into the given base style.
  Falls back to hardcoded defaults when no theme focus config is present.
  """
  @spec focus_style(map(), map()) :: map()
  def focus_style(style, context) when is_map(style) and is_map(context) do
    focus_cfg = get_focus_theme(context)
    Map.merge(style, focus_cfg)
  end

  def focus_style(style, _context), do: focus_style(style)

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

  @doc """
  Theme-aware variant of maybe_focus_style. Reads focus config from theme.
  """
  @spec maybe_focus_style(any(), map(), map(), map()) :: map()
  def maybe_focus_style(widget_id, context, base_style, _theme_context)
      when is_map(context) do
    if focused?(widget_id, context) do
      focus_style(base_style, context)
    else
      base_style
    end
  end

  @doc """
  Determines the visual pseudo-state for a widget.

  Priority: `:disabled` > `:active` > `:focused` > `:default`

  `widget_attrs` should contain `:disabled` and/or `:active` boolean keys.
  """
  @spec widget_state(map(), map()) :: :disabled | :active | :focused | :default
  def widget_state(widget_attrs, context) when is_map(widget_attrs) do
    cond do
      widget_attrs[:disabled] -> :disabled
      widget_attrs[:active] -> :active
      focused?(widget_attrs[:id], context) -> :focused
      true -> :default
    end
  end

  def widget_state(_widget_attrs, _context), do: :default

  @doc """
  Looks up the style for a given pseudo-state from the theme.
  Falls back to built-in defaults when no theme config exists.
  """
  @spec state_style(atom(), map(), map()) :: map()
  def state_style(:default, _context, base_style), do: base_style

  def state_style(pseudo_state, context, base_style)
      when pseudo_state in [:disabled, :active, :focused] do
    theme_pseudo =
      get_in_safe(context, [:theme, :component_styles, pseudo_state]) ||
        @default_pseudo_styles[pseudo_state] ||
        %{}

    Map.merge(base_style, theme_pseudo)
  end

  def state_style(_pseudo_state, _context, base_style), do: base_style

  # -- Private --

  defp get_focus_theme(context) do
    raw =
      get_in_safe(context, [:theme, :component_styles, :focus]) ||
        @default_focus_style

    adapt_style_colors(raw)
  end

  defp adapt_style_colors(style) when is_map(style) do
    color_keys = [:fg, :bg, :border_fg, :border_bg]

    Enum.reduce(color_keys, style, fn key, acc ->
      case Map.get(acc, key) do
        nil -> acc
        val -> Map.put(acc, key, Raxol.Style.Colors.Adaptive.adapt_color_safe(val))
      end
    end)
  end

  defp adapt_style_colors(style), do: style

  defp get_in_safe(nil, _path), do: nil
  defp get_in_safe(_data, []), do: nil

  defp get_in_safe(data, [key | rest]) when is_map(data) do
    case Map.get(data, key) do
      nil -> nil
      value when rest == [] -> value
      value -> get_in_safe(value, rest)
    end
  end

  defp get_in_safe(_data, _path), do: nil
end

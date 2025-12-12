defmodule Raxol.AccessibilityCase do
  @moduledoc """
  Test case helper for accessibility testing.

  Provides helper functions for testing WCAG compliance, screen reader
  compatibility, and keyboard accessibility.

  ## Example

      defmodule A11yTest do
        use Raxol.AccessibilityCase

        test "meets WCAG standards" do
          component = render_component(MyForm)

          assert all_inputs_labeled?(component)
          assert proper_heading_order?(component)
          assert meets_wcag_aa?(component)
          assert fully_keyboard_accessible?(component)
        end
      end
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Raxol.AccessibilityCase
    end
  end

  setup _tags do
    {:ok, %{}}
  end

  @doc """
  Check if all form inputs have associated labels.
  """
  def all_inputs_labeled?(component) do
    inputs = find_elements(component, :input)
    labels = find_elements(component, :label)

    input_ids = Enum.map(inputs, &get_attr(&1, :id)) |> Enum.filter(& &1)
    label_fors = Enum.map(labels, &get_attr(&1, :for)) |> Enum.filter(& &1)

    Enum.all?(input_ids, &(&1 in label_fors))
  end

  @doc """
  Check if headings are in proper hierarchical order (h1 -> h2 -> h3, etc.).
  """
  def proper_heading_order?(component) do
    headings = find_headings(component)
    levels = Enum.map(headings, &heading_level/1)

    check_heading_order(levels, 0)
  end

  @doc """
  Check if the component meets WCAG 2.1 AA contrast requirements.

  Minimum contrast ratios:
  - Normal text: 4.5:1
  - Large text: 3:1
  """
  def meets_wcag_aa?(component) do
    elements = find_text_elements(component)

    Enum.all?(elements, fn elem ->
      fg = get_color(elem, :foreground)
      bg = get_color(elem, :background)
      ratio = contrast_ratio(fg, bg)

      if large_text?(elem) do
        ratio >= 3.0
      else
        ratio >= 4.5
      end
    end)
  end

  @doc """
  Check if the component is fully navigable via keyboard.
  """
  def fully_keyboard_accessible?(component) do
    interactive = find_interactive_elements(component)

    Enum.all?(interactive, fn elem ->
      focusable?(elem) and has_focus_indicator?(elem)
    end)
  end

  @doc """
  Execute a block with simulated screen reader context.
  """
  defmacro with_screen_reader(do: block) do
    quote do
      Process.put(:screen_reader_mode, true)
      Process.put(:screen_reader_announcements, [])

      try do
        unquote(block)
      after
        Process.delete(:screen_reader_mode)
        Process.delete(:screen_reader_announcements)
      end
    end
  end

  @doc """
  Check if the screen reader would announce the given text.
  """
  def announces?(text) do
    announcements = Process.get(:screen_reader_announcements, [])
    text in announcements
  end

  @doc """
  Record a screen reader announcement.
  """
  def announce(text) do
    current = Process.get(:screen_reader_announcements, [])
    Process.put(:screen_reader_announcements, current ++ [text])
  end

  # Private helpers

  defp find_elements(component, type) do
    do_find_elements(component, type, [])
  end

  defp do_find_elements(nil, _type, acc), do: acc

  defp do_find_elements(%{type: type} = elem, type, acc) do
    [elem | acc]
  end

  defp do_find_elements(%{children: children}, type, acc)
       when is_list(children) do
    Enum.reduce(children, acc, fn child, a ->
      do_find_elements(child, type, a)
    end)
  end

  defp do_find_elements(_, _type, acc), do: acc

  defp find_headings(component) do
    [:h1, :h2, :h3, :h4, :h5, :h6]
    |> Enum.flat_map(&find_elements(component, &1))
  end

  defp find_text_elements(component) do
    find_elements(component, :text) ++ find_elements(component, :span)
  end

  defp find_interactive_elements(component) do
    [:button, :input, :select, :link, :a]
    |> Enum.flat_map(&find_elements(component, &1))
  end

  defp get_attr(elem, attr) do
    get_in(elem, [:attrs, attr])
  end

  defp heading_level(%{type: :h1}), do: 1
  defp heading_level(%{type: :h2}), do: 2
  defp heading_level(%{type: :h3}), do: 3
  defp heading_level(%{type: :h4}), do: 4
  defp heading_level(%{type: :h5}), do: 5
  defp heading_level(%{type: :h6}), do: 6
  defp heading_level(_), do: 0

  defp check_heading_order([], _prev), do: true

  defp check_heading_order([level | rest], prev) do
    # Each heading can only increase by 1 level at most
    if level <= prev + 1 do
      check_heading_order(rest, level)
    else
      false
    end
  end

  defp get_color(elem, type) do
    style = Map.get(elem, :style, %{})

    case type do
      :foreground -> Map.get(style, :fg_color, {255, 255, 255})
      :background -> Map.get(style, :bg_color, {0, 0, 0})
    end
  end

  defp large_text?(elem) do
    font_size = get_in(elem, [:style, :font_size]) || 16
    bold = get_in(elem, [:style, :bold]) || false

    font_size >= 18 or (font_size >= 14 and bold)
  end

  defp focusable?(elem) do
    tabindex = get_attr(elem, :tabindex)
    tabindex != "-1" and tabindex != -1
  end

  defp has_focus_indicator?(elem) do
    focus_style = get_in(elem, [:style, :focus])
    focus_style != nil or get_in(elem, [:style, :outline]) != nil
  end

  defp contrast_ratio({r1, g1, b1}, {r2, g2, b2}) do
    l1 = relative_luminance(r1, g1, b1)
    l2 = relative_luminance(r2, g2, b2)

    {lighter, darker} = if l1 > l2, do: {l1, l2}, else: {l2, l1}
    (lighter + 0.05) / (darker + 0.05)
  end

  defp contrast_ratio(_, _), do: 21.0

  defp relative_luminance(r, g, b) do
    [r, g, b]
    |> Enum.map(fn c ->
      c = c / 255

      if c <= 0.03928 do
        c / 12.92
      else
        :math.pow((c + 0.055) / 1.055, 2.4)
      end
    end)
    |> then(fn [r, g, b] -> 0.2126 * r + 0.7152 * g + 0.0722 * b end)
  end
end

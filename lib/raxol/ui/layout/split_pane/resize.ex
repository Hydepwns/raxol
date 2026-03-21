defmodule Raxol.UI.Layout.SplitPane.Resize do
  @moduledoc """
  Helpers for interactive split pane resize in TEA applications.

  Resize is handled at the app level via TEA update/2 -- the SplitPane element
  is stateless (takes ratio from app model). This module provides the math.
  """

  @default_step 0.05

  @doc """
  Checks if a mouse position hits a divider.

  Returns `{:hit, pane_index}` if the position is on a divider, or `:miss`.

  ## Parameters

    * `mouse_pos` - `{x, y}` mouse coordinates
    * `dividers` - List of divider rects from `divider_positions/3`
    * `direction` - `:horizontal` or `:vertical`
  """
  def check_divider_hit({mx, my}, dividers, direction) do
    Enum.find_value(dividers, :miss, fn {x, y, w, h, index} ->
      hit =
        case direction do
          :horizontal -> mx >= x and mx < x + w and my >= y and my < y + h
          :vertical -> mx >= x and mx < x + w and my >= y and my < y + h
        end

      if hit, do: {:hit, index}, else: nil
    end)
  end

  @doc """
  Calculates a new ratio tuple from a drag position.

  ## Parameters

    * `drag_pos` - Current mouse `{x, y}` position
    * `direction` - `:horizontal` or `:vertical`
    * `origin` - `{x, y}` of the split pane's top-left corner
    * `total_size` - Total width (horizontal) or height (vertical)
    * `pane_count` - Number of panes
    * `min_size` - Minimum pane size in characters

  Returns a ratio tuple with integer parts proportional to the drag position.
  """
  def calculate_ratio(drag_pos, direction, origin, total_size, pane_count, min_size \\ 5) do
    divider_space = max(0, pane_count - 1)
    usable = max(1, total_size - divider_space)

    position =
      case direction do
        :horizontal -> elem(drag_pos, 0) - elem(origin, 0)
        :vertical -> elem(drag_pos, 1) - elem(origin, 1)
      end

    # Clamp position to valid range
    position = position |> max(min_size) |> min(usable - min_size)

    # For 2-pane splits, return proportional ratio
    if pane_count == 2 do
      left = max(1, position)
      right = max(1, usable - position)
      gcd = Integer.gcd(left, right)
      {div(left, gcd), div(right, gcd)}
    else
      # For N-pane, this handles the divider being dragged
      # Return equal ratio (caller should track which divider and adjust)
      List.to_tuple(List.duplicate(1, pane_count))
    end
  end

  @doc """
  Handles keyboard-based resize.

  Returns `{:ok, new_ratio}` if the key event triggers a resize, or `:ignore`.

  ## Parameters

    * `key_event` - A key event map with `:key`, `:char`, and `:ctrl` fields
    * `direction` - `:horizontal` or `:vertical`
    * `current_ratio` - Current ratio tuple
    * `step` - Adjustment step as float proportion (default 0.05)
  """
  def handle_keyboard_resize(key_event, direction, current_ratio, step \\ @default_step) do
    case classify_key(key_event, direction) do
      :grow_first -> {:ok, adjust_ratio(current_ratio, step)}
      :shrink_first -> {:ok, adjust_ratio(current_ratio, -step)}
      :ignore -> :ignore
    end
  end

  @doc """
  Computes divider positions for hit testing.

  Returns a list of `{x, y, width, height, pane_index}` tuples.

  ## Parameters

    * `direction` - `:horizontal` or `:vertical`
    * `ratio` - Ratio tuple
    * `space` - Available space map with `:x`, `:y`, `:width`, `:height`
  """
  def divider_positions(direction, ratio, space) do
    ratio_list = Tuple.to_list(ratio)
    count = length(ratio_list)

    if count <= 1 do
      []
    else
      sizes =
        Raxol.UI.Layout.SplitPane.distribute_space(
          direction,
          ratio_list,
          space,
          0
        )

      sizes
      |> Enum.take(count - 1)
      |> Enum.with_index()
      |> Enum.reduce({0, []}, fn {size, index}, {offset, positions} ->
        pos = offset + size

        rect =
          case direction do
            :horizontal ->
              {space.x + pos, space.y, 1, space.height, index}

            :vertical ->
              {space.x, space.y + pos, space.width, 1, index}
          end

        {pos + 1, [rect | positions]}
      end)
      |> elem(1)
      |> Enum.reverse()
    end
  end

  # -- Private --

  defp classify_key(%{ctrl: true, key: :arrow_right}, :horizontal), do: :grow_first
  defp classify_key(%{ctrl: true, key: :arrow_left}, :horizontal), do: :shrink_first
  defp classify_key(%{ctrl: true, key: :arrow_down}, :vertical), do: :grow_first
  defp classify_key(%{ctrl: true, key: :arrow_up}, :vertical), do: :shrink_first
  defp classify_key(_, _), do: :ignore

  defp adjust_ratio(ratio, delta) when tuple_size(ratio) == 2 do
    {a, b} = ratio
    total = a + b
    proportion = a / total + delta
    proportion = proportion |> max(0.1) |> min(0.9)

    # Convert back to integer ratio (scale to 100 for precision)
    new_a = round(proportion * 100)
    new_b = 100 - new_a
    gcd = Integer.gcd(new_a, new_b)
    {div(new_a, gcd), div(new_b, gcd)}
  end

  defp adjust_ratio(ratio, _delta), do: ratio
end

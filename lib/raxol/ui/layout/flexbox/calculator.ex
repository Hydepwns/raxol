defmodule Raxol.UI.Layout.Flexbox.Calculator do
  @moduledoc """
  Container sizing and the legacy calculate_layout/distribute_flex API.
  """

  @compile {:no_warn_undefined, Raxol.UI.Layout.Flexbox.Positioner}

  alias Raxol.UI.Layout.Flexbox.Positioner

  @doc "Calculate container size from measured child dimensions."
  def calculate_container_size([], _flex_props, _content_space) do
    %{width: 0, height: 0}
  end

  def calculate_container_size(
        child_dimensions,
        %{flex_wrap: :nowrap} = flex_props,
        _content_space
      ) do
    {main_axis, cross_axis} = get_axes(flex_props.flex_direction)

    main_size =
      Enum.reduce(child_dimensions, 0, fn dims, acc ->
        acc + Positioner.get_dimension(dims, main_axis)
      end)

    cross_size =
      Enum.reduce(child_dimensions, 0, fn dims, acc ->
        max(acc, Positioner.get_dimension(dims, cross_axis))
      end)

    case main_axis do
      :horizontal -> %{width: main_size, height: cross_size}
      :vertical -> %{width: cross_size, height: main_size}
    end
  end

  def calculate_container_size(child_dimensions, _flex_props, _content_space) do
    total_width =
      Enum.reduce(child_dimensions, 0, fn dims, acc -> max(acc, dims.width) end)

    total_height =
      Enum.reduce(child_dimensions, 0, fn dims, acc -> acc + dims.height end)

    %{width: total_width, height: total_height}
  end

  # ---------------------------------------------------------------------------
  # Legacy calculate_layout / distribute_flex API
  # ---------------------------------------------------------------------------

  @doc "Calculate content width for row-direction containers."
  def calculate_content_width(%{direction: :row, children: children, gap: gap}) do
    children
    |> Enum.map(fn child -> Map.get(child, :width, 0) end)
    |> Enum.sum()
    |> Kernel.+(gap * max(0, length(children) - 1))
  end

  def calculate_content_width(%{direction: :column, children: children}) do
    children
    |> Enum.map(fn child -> Map.get(child, :width, 0) end)
    |> Enum.max(fn -> 0 end)
  end

  @doc "Calculate content height for column-direction containers."
  def calculate_content_height(%{
        direction: :column,
        children: children,
        gap: gap
      }) do
    children
    |> Enum.map(fn child -> Map.get(child, :height, 0) end)
    |> Enum.sum()
    |> Kernel.+(gap * max(0, length(children) - 1))
  end

  def calculate_content_height(%{direction: :row, children: children}) do
    children
    |> Enum.map(fn child -> Map.get(child, :height, 0) end)
    |> Enum.max(fn -> 0 end)
  end

  @doc "Lay out children within the given total dimensions."
  def calculate_child_layouts(flexbox, total_width, total_height) do
    children = flexbox.children
    gap = flexbox.gap || 0
    gap_count = max(0, length(children) - 1)

    case flexbox.direction do
      :row ->
        total_gap = gap * gap_count
        available = max(0, total_width - total_gap)
        distribute_flex(children, available, gap, :width, :x)

      :column ->
        total_gap = gap * gap_count
        available = max(0, total_height - total_gap)
        distribute_flex(children, available, gap, :height, :y)
    end
  end

  @doc "Distribute flex children across available space."
  def distribute_flex(children, available_space, gap, size_key, pos_key) do
    raw_flex = Enum.map(children, fn child -> Map.get(child, :flex, 1) end)
    total_flex = Enum.sum(raw_flex)

    flex_values =
      if total_flex == 0 do
        Enum.map(raw_flex, fn _ -> 1 end)
      else
        raw_flex
      end

    total_flex = max(Enum.sum(flex_values), 1)

    base_sizes =
      Enum.map(flex_values, fn flex ->
        div(available_space * flex, total_flex)
      end)

    remainder = available_space - Enum.sum(base_sizes)

    fractional_parts =
      flex_values
      |> Enum.with_index()
      |> Enum.map(fn {flex, idx} ->
        exact = available_space * flex / total_flex
        {exact - Enum.at(base_sizes, idx), idx}
      end)
      |> Enum.sort_by(fn {frac, _} -> frac end, :desc)
      |> Enum.take(remainder)
      |> Enum.map(fn {_, idx} -> idx end)
      |> MapSet.new()

    sizes =
      base_sizes
      |> Enum.with_index()
      |> Enum.map(fn {size, idx} ->
        if MapSet.member?(fractional_parts, idx), do: size + 1, else: size
      end)

    {laid_out, _} =
      children
      |> Enum.zip(sizes)
      |> Enum.map_reduce(0, fn {child, size}, offset ->
        updated =
          child
          |> Map.put(size_key, size)
          |> Map.put(pos_key, offset)

        {updated, offset + size + gap}
      end)

    laid_out
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def get_axes(:row), do: {:horizontal, :vertical}
  def get_axes(:row_reverse), do: {:horizontal, :vertical}
  def get_axes(:column), do: {:vertical, :horizontal}
  def get_axes(:column_reverse), do: {:vertical, :horizontal}
end

defmodule Raxol.UI.Layout.Flexbox.Distributor do
  @moduledoc """
  Flex grow/shrink space distribution along the main axis.
  """

  @doc "Distribute extra or deficit space among flex children."
  def distribute_main_space(children_with_dims, available_main_space, main_axis)
      when available_main_space > 0 do
    distribute_extra_space(children_with_dims, available_main_space, main_axis)
  end

  def distribute_main_space(children_with_dims, available_main_space, main_axis) do
    shrink_items(children_with_dims, -available_main_space, main_axis)
  end

  # ---------------------------------------------------------------------------
  # Grow
  # ---------------------------------------------------------------------------

  def distribute_extra_space(children_with_dims, extra_space, main_axis) do
    total_grow =
      Enum.reduce(children_with_dims, 0, fn {_child, _dims, flex}, acc ->
        acc + flex.grow
      end)

    distribute_grow_space(
      children_with_dims,
      extra_space,
      total_grow,
      main_axis
    )
  end

  def distribute_grow_space(children_with_dims, _extra_space, 0, _main_axis) do
    children_with_dims
  end

  def distribute_grow_space(
        children_with_dims,
        extra_space,
        total_grow,
        main_axis
      ) do
    Enum.map(children_with_dims, fn {child, dims, flex} ->
      apply_flex_grow(child, dims, flex, extra_space, total_grow, main_axis)
    end)
  end

  def apply_flex_grow(
        child,
        dims,
        %{grow: 0} = flex,
        _extra_space,
        _total_grow,
        _main_axis
      ) do
    {child, dims, flex}
  end

  def apply_flex_grow(child, dims, flex, extra_space, total_grow, main_axis) do
    extra = div(extra_space * flex.grow, total_grow)

    new_dims =
      case main_axis do
        :horizontal -> %{dims | width: dims.width + extra}
        :vertical -> %{dims | height: dims.height + extra}
      end

    {child, new_dims, flex}
  end

  # ---------------------------------------------------------------------------
  # Shrink
  # ---------------------------------------------------------------------------

  def shrink_items(children_with_dims, shortage, main_axis) do
    total_shrink_weight =
      Enum.reduce(children_with_dims, 0, fn {_child, dims, flex}, acc ->
        acc + flex.shrink * get_dimension(dims, main_axis)
      end)

    distribute_shrink_space(
      children_with_dims,
      shortage,
      total_shrink_weight,
      main_axis
    )
  end

  def distribute_shrink_space(children_with_dims, _shortage, 0, _main_axis) do
    children_with_dims
  end

  def distribute_shrink_space(
        children_with_dims,
        shortage,
        total_shrink_weight,
        main_axis
      ) do
    Enum.map(children_with_dims, fn {child, dims, flex} ->
      apply_flex_shrink(
        child,
        dims,
        flex,
        shortage,
        total_shrink_weight,
        main_axis
      )
    end)
  end

  def apply_flex_shrink(
        child,
        dims,
        %{shrink: 0} = flex,
        _shortage,
        _total_weight,
        _axis
      ) do
    {child, dims, flex}
  end

  def apply_flex_shrink(
        child,
        dims,
        flex,
        shortage,
        total_shrink_weight,
        main_axis
      ) do
    size = get_dimension(dims, main_axis)
    shrink_weight = flex.shrink * size

    shrink_amount =
      min(size, div(shortage * shrink_weight, total_shrink_weight))

    new_dims =
      case main_axis do
        :horizontal -> %{dims | width: max(0, dims.width - shrink_amount)}
        :vertical -> %{dims | height: max(0, dims.height - shrink_amount)}
      end

    {child, new_dims, flex}
  end

  # ---------------------------------------------------------------------------
  # Shared helpers
  # ---------------------------------------------------------------------------

  def get_dimension(dims, :horizontal), do: dims.width
  def get_dimension(dims, :vertical), do: dims.height
end

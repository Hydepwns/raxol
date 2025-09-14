defmodule Raxol.UI.Rendering.DamageTracker do
  @moduledoc """
  Tracks damaged/dirty regions in the UI tree to optimize rendering.
  Only re-renders areas that have actually changed, reducing unnecessary work.

  ## Damage Types
  - `:content` - Text or visual content changed
  - `:layout` - Size or position changed
  - `:style` - Visual styling changed
  - `:structure` - Child nodes added/removed/reordered
  """

  @type damage_type :: :content | :layout | :style | :structure
  @type damage_region :: %{
          path: [integer()],
          type: damage_type(),
          bounds:
            %{x: integer(), y: integer(), width: integer(), height: integer()}
            | nil,
          priority: :low | :medium | :high
        }

  @type damage_map :: %{[integer()] => damage_region()}

  @doc """
  Computes damaged regions from a tree diff result.
  Returns a map of path -> damage_region for efficient lookups.
  """
  @spec compute_damage(
          diff_result ::
            :no_change | {:replace, any()} | {:update, [integer()], any()},
          tree :: map() | nil
        ) :: damage_map()
  def compute_damage(:no_change, _tree), do: %{}

  def compute_damage({:replace, new_tree}, _old_tree) do
    # Full replacement means everything is damaged
    %{
      [] => %{
        path: [],
        type: :structure,
        bounds: estimate_tree_bounds(new_tree),
        priority: :high
      }
    }
  end

  def compute_damage({:update, path, changes}, tree) do
    base_damage = %{
      path => %{
        path: path,
        type: classify_change_type(changes),
        bounds: estimate_node_bounds(get_node_at_path(tree, path)),
        priority: calculate_priority(changes)
      }
    }

    # Add child damage regions for complex changes
    child_damage = extract_child_damage(changes, path, tree)
    Map.merge(base_damage, child_damage)
  end

  @doc """
  Merges two damage maps, keeping higher priority damages.
  Used for accumulating damage across multiple updates.
  """
  @spec merge_damage(damage_map(), damage_map()) :: damage_map()
  def merge_damage(existing_damage, new_damage) do
    Map.merge(existing_damage, new_damage, fn _path, existing, new ->
      if priority_value(new.priority) > priority_value(existing.priority) do
        new
      else
        existing
      end
    end)
  end

  @doc """
  Filters damage regions to only those that intersect with the viewport.
  Optimizes rendering by skipping off-screen damage.
  """
  @spec filter_viewport_damage(damage_map(), %{
          x: integer(),
          y: integer(),
          width: integer(),
          height: integer()
        }) :: damage_map()
  def filter_viewport_damage(damage_map, viewport) do
    damage_map
    |> Enum.filter(fn {_path, region} ->
      region.bounds && regions_intersect?(region.bounds, viewport)
    end)
    |> Map.new()
  end

  @doc """
  Groups damage regions by priority for batch processing.
  High priority damages are processed first.
  """
  @spec group_by_priority(damage_map()) :: %{
          high: [damage_region()],
          medium: [damage_region()],
          low: [damage_region()]
        }
  def group_by_priority(damage_map) do
    damage_map
    |> Map.values()
    |> Enum.group_by(& &1.priority, & &1)
    |> Map.put_new(:high, [])
    |> Map.put_new(:medium, [])
    |> Map.put_new(:low, [])
  end

  @doc """
  Optimizes damage regions by combining adjacent/overlapping regions.
  Reduces the number of separate render operations needed.
  """
  @spec optimize_damage_regions(damage_map()) :: damage_map()
  def optimize_damage_regions(damage_map) when map_size(damage_map) <= 1,
    do: damage_map

  def optimize_damage_regions(damage_map) do
    regions = Map.values(damage_map)
    optimized = combine_adjacent_regions(regions)

    optimized
    |> Enum.map(fn region -> {region.path, region} end)
    |> Map.new()
  end

  # Private helper functions

  defp classify_change_type(%{type: :indexed_children}), do: :structure
  defp classify_change_type(%{type: :keyed_children}), do: :structure
  defp classify_change_type(_other), do: :content

  defp calculate_priority(%{type: :indexed_children, diffs: diffs}) do
    if length(diffs) > 10, do: :high, else: :medium
  end

  defp calculate_priority(%{type: :keyed_children, ops: ops}) do
    if length(ops) > 5, do: :high, else: :medium
  end

  defp calculate_priority(_other), do: :low

  defp extract_child_damage(
         %{type: :indexed_children, diffs: diffs},
         parent_path,
         tree
       ) do
    diffs
    |> Enum.map(fn {idx, diff} ->
      child_path = parent_path ++ [idx]
      child_node = get_node_at_path(tree, child_path)

      {child_path,
       %{
         path: child_path,
         type: classify_diff_type(diff),
         bounds: estimate_node_bounds(child_node),
         priority: :medium
       }}
    end)
    |> Map.new()
  end

  defp extract_child_damage(
         %{type: :keyed_children, ops: ops},
         parent_path,
         _tree
       ) do
    ops
    |> Enum.with_index()
    |> Enum.map(fn {_op, idx} ->
      child_path = parent_path ++ [idx]

      {child_path,
       %{
         path: child_path,
         type: :structure,
         # Keyed operations may not have predictable bounds
         bounds: nil,
         priority: :medium
       }}
    end)
    |> Map.new()
  end

  defp extract_child_damage(_other, _parent_path, _tree), do: %{}

  defp classify_diff_type({:replace, _}), do: :structure
  defp classify_diff_type({:update, _, _}), do: :content
  defp classify_diff_type(_), do: :content

  defp get_node_at_path(tree, []), do: tree

  defp get_node_at_path(%{children: children}, [idx | rest])
       when is_list(children) do
    child = Enum.at(children, idx)
    get_node_at_path(child, rest)
  end

  defp get_node_at_path(_tree, _path), do: nil

  defp estimate_tree_bounds(%{attrs: %{width: w, height: h}}),
    do: %{x: 0, y: 0, width: w, height: h}

  defp estimate_tree_bounds(%{children: children}) when is_list(children) do
    # Estimate based on children count - simple heuristic
    # Assume 20px per row
    height = length(children) * 20
    %{x: 0, y: 0, width: 800, height: height}
  end

  defp estimate_tree_bounds(_), do: %{x: 0, y: 0, width: 800, height: 24}

  defp estimate_node_bounds(%{type: :label, attrs: %{text: text}}) do
    # Estimate text dimensions - simple heuristic
    # Assume 8px per char
    width = String.length(text) * 8
    %{x: 0, y: 0, width: width, height: 16}
  end

  defp estimate_node_bounds(%{children: children}) when is_list(children) do
    height = length(children) * 16
    %{x: 0, y: 0, width: 400, height: height}
  end

  defp estimate_node_bounds(_), do: %{x: 0, y: 0, width: 100, height: 16}

  defp regions_intersect?(r1, r2) do
    not (r1.x + r1.width <= r2.x or r2.x + r2.width <= r1.x or
           r1.y + r1.height <= r2.y or r2.y + r2.height <= r1.y)
  end

  defp combine_adjacent_regions(regions) when length(regions) <= 1, do: regions

  defp combine_adjacent_regions(regions) do
    # Simple implementation - just return original for now
    # More sophisticated region combining would be implemented here
    regions
  end

  defp priority_value(:high), do: 3
  defp priority_value(:medium), do: 2
  defp priority_value(:low), do: 1
end

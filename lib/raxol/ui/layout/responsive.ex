defmodule Raxol.UI.Layout.Responsive do
  @moduledoc """
  Responsive layout system for Raxol UI components with breakpoint support.

  This module provides responsive design capabilities similar to CSS media queries
  and responsive frameworks like Bootstrap, Tailwind CSS, and Material-UI.

  ## Features

  - Breakpoint-based responsive design
  - Container queries (element-based breakpoints)
  - Responsive typography scaling
  - Adaptive spacing and sizing
  - Orientation-based layouts
  - Terminal size detection and adaptation

  ## Breakpoints

  Default breakpoints (based on terminal column widths):
  - `:xs` (extra-small): 0-39 columns
  - `:sm` (small): 40-79 columns  
  - `:md` (medium): 80-119 columns
  - `:lg` (large): 120-159 columns
  - `:xl` (extra-large): 160+ columns

  ## Example Usage

      # Responsive container
      %{
        type: :responsive,
        attrs: %{
          breakpoints: %{
            xs: %{flex_direction: :column, gap: 5},
            sm: %{flex_direction: :row, gap: 10},
            md: %{flex_direction: :row, gap: 15, padding: 20},
            lg: %{flex_direction: :row, gap: 20, padding: 30}
          },
          container_query: %{
            min_width: 100,
            styles: %{justify_content: :center}
          }
        },
        children: [
          %{
            type: :text,
            attrs: %{
              content: "Responsive Text",
              responsive: %{
                xs: %{font_size: :small},
                md: %{font_size: :medium},
                lg: %{font_size: :large}
              }
            }
          }
        ]
      }
      
      # Grid with responsive columns
      %{
        type: :responsive_grid,
        attrs: %{
          columns: %{
            xs: 1,
            sm: 2, 
            md: 3,
            lg: 4
          },
          gap: %{
            xs: 5,
            md: 10,
            lg: 15
          }
        },
        children: grid_items
      }
  """

  import Raxol.Guards
  alias Raxol.UI.Layout.{Engine, Flexbox, CSSGrid}

  # Default breakpoints (column-based for terminals)
  @default_breakpoints %{
    xs: %{min_width: 0, max_width: 39},
    sm: %{min_width: 40, max_width: 79},
    md: %{min_width: 80, max_width: 119},
    lg: %{min_width: 120, max_width: 159},
    xl: %{min_width: 160, max_width: :infinity}
  }

  @doc """
  Processes a responsive container, adapting layout based on available space.
  """
  def process_responsive(
        %{type: :responsive, children: children} = responsive,
        space,
        acc
      )
      when list?(children) do
    attrs = Map.get(responsive, :attrs, %{})

    # Determine current breakpoint
    current_breakpoint = get_current_breakpoint(space, attrs)

    # Get styles for current breakpoint
    responsive_styles = get_responsive_styles(attrs, current_breakpoint)

    # Apply container queries if specified
    final_styles = apply_container_queries(responsive_styles, attrs, space)

    # Create adapted container
    adapted_container = create_adapted_container(responsive, final_styles)

    # Process with appropriate layout engine
    case Map.get(final_styles, :layout_type, :flex) do
      :flex ->
        Flexbox.process_flex(adapted_container, space, acc)

      :css_grid ->
        CSSGrid.process_css_grid(adapted_container, space, acc)

      _ ->
        # Process children with responsive styles applied
        process_responsive_children(children, space, acc, current_breakpoint)
    end
  end

  def process_responsive(_, _space, acc), do: acc

  @doc """
  Processes a responsive grid with column breakpoints.
  """
  def process_responsive_grid(
        %{type: :responsive_grid, children: children} = grid,
        space,
        acc
      )
      when list?(children) do
    attrs = Map.get(grid, :attrs, %{})

    # Determine current breakpoint
    current_breakpoint = get_current_breakpoint(space, attrs)

    # Get responsive configuration
    columns =
      get_breakpoint_value(Map.get(attrs, :columns, 1), current_breakpoint)

    gap = get_breakpoint_value(Map.get(attrs, :gap, 10), current_breakpoint)

    # Create CSS Grid configuration
    grid_template_columns = create_grid_columns(columns)

    adapted_grid = %{
      type: :css_grid,
      attrs:
        Map.merge(attrs, %{
          grid_template_columns: grid_template_columns,
          gap: gap
        }),
      children: children
    }

    CSSGrid.process_css_grid(adapted_grid, space, acc)
  end

  def process_responsive_grid(_, _space, acc), do: acc

  @doc """
  Measures responsive containers.
  """
  def measure_responsive(%{type: :responsive} = responsive, available_space) do
    attrs = Map.get(responsive, :attrs, %{})
    current_breakpoint = get_current_breakpoint(available_space, attrs)
    responsive_styles = get_responsive_styles(attrs, current_breakpoint)

    final_styles =
      apply_container_queries(responsive_styles, attrs, available_space)

    adapted_container = create_adapted_container(responsive, final_styles)

    case Map.get(final_styles, :layout_type, :flex) do
      :flex ->
        Flexbox.measure_flex(adapted_container, available_space)

      :css_grid ->
        CSSGrid.measure_css_grid(adapted_container, available_space)

      _ ->
        measure_responsive_children(
          Map.get(responsive, :children, []),
          available_space,
          current_breakpoint
        )
    end
  end

  def measure_responsive(%{type: :responsive_grid} = grid, available_space) do
    attrs = Map.get(grid, :attrs, %{})
    current_breakpoint = get_current_breakpoint(available_space, attrs)

    columns =
      get_breakpoint_value(Map.get(attrs, :columns, 1), current_breakpoint)

    gap = get_breakpoint_value(Map.get(attrs, :gap, 10), current_breakpoint)

    grid_template_columns = create_grid_columns(columns)

    adapted_grid = %{
      type: :css_grid,
      attrs:
        Map.merge(attrs, %{
          grid_template_columns: grid_template_columns,
          gap: gap
        }),
      children: Map.get(grid, :children, [])
    }

    CSSGrid.measure_css_grid(adapted_grid, available_space)
  end

  def measure_responsive(_, _available_space), do: %{width: 0, height: 0}

  @doc """
  Gets the current breakpoint based on available space.
  """
  def get_current_breakpoint(space, attrs \\ %{}) do
    breakpoints = Map.get(attrs, :custom_breakpoints, @default_breakpoints)
    width = Map.get(space, :width, 0)

    # Find matching breakpoint
    Enum.find(breakpoints, fn {_name, config} ->
      min_width = Map.get(config, :min_width, 0)
      max_width = Map.get(config, :max_width, :infinity)

      width >= min_width and (max_width == :infinity or width <= max_width)
    end)
    |> case do
      {name, _config} -> name
      # Default fallback
      nil -> :md
    end
  end

  @doc """
  Applies responsive typography scaling.
  """
  def apply_responsive_typography(attrs, breakpoint) do
    base_font_size = Map.get(attrs, :font_size, :medium)
    responsive_font = Map.get(attrs, :responsive_font_size, %{})

    final_font_size =
      get_breakpoint_value(responsive_font, breakpoint, base_font_size)

    # Apply scaling factors based on breakpoint
    scale_factor =
      case breakpoint do
        :xs -> 0.8
        :sm -> 0.9
        :md -> 1.0
        :lg -> 1.1
        :xl -> 1.2
      end

    scaled_font_size = apply_font_scale(final_font_size, scale_factor)

    Map.put(attrs, :font_size, scaled_font_size)
  end

  @doc """
  Creates responsive spacing based on breakpoint.
  """
  def get_responsive_spacing(spacing_config, breakpoint) do
    base_spacing =
      case breakpoint do
        :xs -> 4
        :sm -> 8
        :md -> 12
        :lg -> 16
        :xl -> 20
      end

    case spacing_config do
      value when is_integer(value) ->
        value

      %{} = config ->
        get_breakpoint_value(config, breakpoint, base_spacing)

      _ ->
        base_spacing
    end
  end

  # Private helper functions

  defp get_responsive_styles(attrs, breakpoint) do
    breakpoint_styles = Map.get(attrs, :breakpoints, %{})

    base_styles =
      Map.drop(attrs, [:breakpoints, :container_query, :custom_breakpoints])

    # Get styles for current breakpoint
    current_styles = Map.get(breakpoint_styles, breakpoint, %{})

    # Merge base styles with breakpoint-specific styles
    Map.merge(base_styles, current_styles)
  end

  defp apply_container_queries(styles, attrs, space) do
    container_query = Map.get(attrs, :container_query, %{})

    if container_query != %{} do
      query_matches = evaluate_container_query(container_query, space)

      if query_matches do
        query_styles = Map.get(container_query, :styles, %{})
        Map.merge(styles, query_styles)
      else
        styles
      end
    else
      styles
    end
  end

  defp evaluate_container_query(query, space) do
    conditions = [
      evaluate_size_condition(
        :min_width,
        Map.get(query, :min_width),
        space.width
      ),
      evaluate_size_condition(
        :max_width,
        Map.get(query, :max_width),
        space.width
      ),
      evaluate_size_condition(
        :min_height,
        Map.get(query, :min_height),
        space.height
      ),
      evaluate_size_condition(
        :max_height,
        Map.get(query, :max_height),
        space.height
      )
    ]

    # All non-nil conditions must be true
    conditions
    |> Enum.filter(&(&1 != nil))
    |> Enum.all?(&(&1 == true))
  end

  defp evaluate_size_condition(_condition, nil, _value), do: nil

  defp evaluate_size_condition(:min_width, min_width, width),
    do: width >= min_width

  defp evaluate_size_condition(:max_width, max_width, width),
    do: width <= max_width

  defp evaluate_size_condition(:min_height, min_height, height),
    do: height >= min_height

  defp evaluate_size_condition(:max_height, max_height, height),
    do: height <= max_height

  defp create_adapted_container(original, styles) do
    layout_type = Map.get(styles, :layout_type, :flex)

    adapted_type =
      case layout_type do
        :flex -> :flex
        :css_grid -> :css_grid
        _ -> :flex
      end

    %{original | type: adapted_type, attrs: styles}
  end

  defp get_breakpoint_value(config, breakpoint, default \\ nil)

  defp get_breakpoint_value(value, _breakpoint, _default)
       when not is_map(value) do
    value
  end

  defp get_breakpoint_value(config, breakpoint, default) when is_map(config) do
    # Try current breakpoint first
    case Map.get(config, breakpoint) do
      nil ->
        # Fall back to smaller breakpoints
        fallback_value = find_fallback_breakpoint(config, breakpoint)
        fallback_value || default

      value ->
        value
    end
  end

  defp find_fallback_breakpoint(config, breakpoint) do
    # Define breakpoint hierarchy for fallback
    hierarchy = [:xs, :sm, :md, :lg, :xl]
    current_index = Enum.find_index(hierarchy, &(&1 == breakpoint)) || 2

    # Look for values in smaller breakpoints
    hierarchy
    |> Enum.take(current_index)
    |> Enum.reverse()
    |> Enum.find_value(fn bp ->
      Map.get(config, bp)
    end)
  end

  defp create_grid_columns(column_count) do
    List.duplicate("1fr", column_count)
    |> Enum.join(" ")
  end

  defp process_responsive_children(children, space, acc, current_breakpoint) do
    Enum.reduce(children, acc, fn child, child_acc ->
      # Apply responsive attributes to child
      responsive_child = apply_child_responsiveness(child, current_breakpoint)

      # Process with layout engine
      Engine.process_element(responsive_child, space, child_acc)
    end)
  end

  defp apply_child_responsiveness(child, breakpoint) do
    child_attrs = Map.get(child, :attrs, %{})
    responsive_attrs = Map.get(child_attrs, :responsive, %{})

    if responsive_attrs != %{} do
      # Get responsive styles for this breakpoint
      current_responsive_styles =
        get_breakpoint_value(responsive_attrs, breakpoint, %{})

      # Apply responsive typography if font-related properties exist
      final_attrs =
        if Map.has_key?(current_responsive_styles, :font_size) or
             Map.has_key?(child_attrs, :font_size) do
          apply_responsive_typography(
            Map.merge(child_attrs, current_responsive_styles),
            breakpoint
          )
        else
          Map.merge(child_attrs, current_responsive_styles)
        end

      %{child | attrs: final_attrs}
    else
      child
    end
  end

  defp measure_responsive_children(children, space, current_breakpoint) do
    if length(children) == 0 do
      %{width: 0, height: 0}
    else
      # Apply responsiveness to children and measure
      responsive_children =
        Enum.map(children, fn child ->
          apply_child_responsiveness(child, current_breakpoint)
        end)

      # Calculate total dimensions (simple column layout assumption)
      total_height =
        Enum.reduce(responsive_children, 0, fn child, acc ->
          dims = Engine.measure_element(child, space)
          acc + dims.height
        end)

      max_width =
        Enum.reduce(responsive_children, 0, fn child, acc ->
          dims = Engine.measure_element(child, space)
          max(acc, dims.width)
        end)

      %{width: max_width, height: total_height}
    end
  end

  defp apply_font_scale(:small, scale), do: scale_font_size(:small, scale)
  defp apply_font_scale(:medium, scale), do: scale_font_size(:medium, scale)
  defp apply_font_scale(:large, scale), do: scale_font_size(:large, scale)
  defp apply_font_scale(size, _scale) when is_integer(size), do: size
  defp apply_font_scale(other, _scale), do: other

  defp scale_font_size(:small, scale) when scale < 0.9, do: :small
  defp scale_font_size(:small, scale) when scale >= 1.1, do: :medium
  defp scale_font_size(:small, _scale), do: :small

  defp scale_font_size(:medium, scale) when scale < 0.9, do: :small
  defp scale_font_size(:medium, scale) when scale >= 1.1, do: :large
  defp scale_font_size(:medium, _scale), do: :medium

  defp scale_font_size(:large, scale) when scale < 0.9, do: :medium
  defp scale_font_size(:large, _scale), do: :large

  defp scale_font_size(other, _scale), do: other
end

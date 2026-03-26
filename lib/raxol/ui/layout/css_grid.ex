defmodule Raxol.UI.Layout.CSSGrid do
  @moduledoc """
  CSS Grid layout system for Raxol UI components.

  Provides CSS Grid-compatible layout with template rows/columns, grid areas,
  gaps, alignment properties, auto-placement, and grid line naming.

  ## Usage

      %{
        type: :css_grid,
        attrs: %{
          grid_template_columns: "1fr 200px 1fr",
          grid_template_rows: "auto 1fr auto",
          gap: 10
        },
        children: children
      }
  """

  alias Raxol.UI.Layout.Engine
  alias Raxol.UI.Layout.LayoutUtils

  @compile {:no_warn_undefined,
            [
              Raxol.UI.Layout.CSSGrid.TrackParser,
              Raxol.UI.Layout.CSSGrid.ItemPlacement,
              Raxol.UI.Layout.CSSGrid.Sizing,
              Raxol.UI.Layout.CSSGrid.Positioning
            ]}
  alias Raxol.UI.Layout.CSSGrid.{
    ItemPlacement,
    Positioning,
    Sizing,
    TrackParser
  }

  # Grid track definition
  defmodule Track do
    @moduledoc """
    Grid track (row or column) definition.

    Defines a track's type (fr, px, percent, minmax, auto), value, and optional name.
    """
    defstruct [:type, :value, :name]

    def new(type, value, name \\ nil) do
      %__MODULE__{type: type, value: value, name: name}
    end
  end

  # Grid cell definition
  defmodule Cell do
    @moduledoc """
    Grid cell definition specifying position and span.

    Defines a cell's row, column, row span, column span, and optional named area.
    """
    defstruct [:row, :column, :row_span, :column_span, :area]

    def new(row, column, row_span \\ 1, column_span \\ 1, area \\ nil) do
      %__MODULE__{
        row: row,
        column: column,
        row_span: row_span,
        column_span: column_span,
        area: area
      }
    end
  end

  # Grid item placement
  defmodule Item do
    @moduledoc """
    Grid item with placement information.

    Associates a child element with its cell position, dimensions, and
    auto-placement status.
    """
    defstruct [:child, :cell, :dimensions, :auto_placed]

    def new(child, cell, dimensions, auto_placed \\ false) do
      %__MODULE__{
        child: child,
        cell: cell,
        dimensions: dimensions,
        auto_placed: auto_placed
      }
    end
  end

  @doc """
  Processes a CSS Grid container, calculating layout for it and its children.
  """
  def process_css_grid(
        %{type: :css_grid, children: children} = grid,
        space,
        acc
      )
      when is_list(children) do
    attrs = Map.get(grid, :attrs, %{})
    grid_props = parse_grid_properties(attrs)
    content_space = apply_padding(space, grid_props.padding)
    areas = ItemPlacement.parse_grid_areas(grid_props.grid_template_areas)

    column_tracks =
      TrackParser.parse_grid_tracks(
        grid_props.grid_template_columns,
        content_space.width
      )

    row_tracks =
      TrackParser.parse_grid_tracks(
        grid_props.grid_template_rows,
        content_space.height
      )

    placed_items =
      ItemPlacement.place_grid_items(
        children,
        column_tracks,
        row_tracks,
        areas,
        content_space,
        grid_props
      )

    all_items =
      ItemPlacement.auto_place_items(
        placed_items,
        column_tracks,
        row_tracks,
        grid_props
      )

    {final_column_tracks, final_row_tracks} =
      Sizing.size_tracks(
        all_items,
        column_tracks,
        row_tracks,
        content_space,
        grid_props
      )

    positioned_items =
      Positioning.calculate_positions(
        all_items,
        final_column_tracks,
        final_row_tracks,
        content_space,
        grid_props
      )

    elements =
      Enum.flat_map(positioned_items, fn {child, child_space} ->
        Engine.process_element(child, child_space, [])
      end)

    elements ++ acc
  end

  def process_css_grid(_, _space, acc), do: acc

  @doc """
  Measures the space needed by a CSS Grid container.
  """
  def measure_css_grid(
        %{type: :css_grid, children: children} = grid,
        available_space
      )
      when is_list(children) do
    attrs = Map.get(grid, :attrs, %{})
    grid_props = parse_grid_properties(attrs)
    content_space = apply_padding(available_space, grid_props.padding)
    areas = ItemPlacement.parse_grid_areas(grid_props.grid_template_areas)

    column_tracks =
      TrackParser.parse_grid_tracks(
        grid_props.grid_template_columns,
        content_space.width
      )

    row_tracks =
      TrackParser.parse_grid_tracks(
        grid_props.grid_template_rows,
        content_space.height
      )

    placed_items =
      ItemPlacement.place_grid_items(
        children,
        column_tracks,
        row_tracks,
        areas,
        content_space,
        grid_props
      )

    all_items =
      ItemPlacement.auto_place_items(
        placed_items,
        column_tracks,
        row_tracks,
        grid_props
      )

    {final_column_tracks, final_row_tracks} =
      Sizing.size_tracks(
        all_items,
        column_tracks,
        row_tracks,
        content_space,
        grid_props
      )

    total_width =
      Enum.reduce(final_column_tracks, 0, fn track, acc -> acc + track.value end) +
        grid_props.gap.column * max(0, length(final_column_tracks) - 1)

    total_height =
      Enum.reduce(final_row_tracks, 0, fn track, acc -> acc + track.value end) +
        grid_props.gap.row * max(0, length(final_row_tracks) - 1)

    %{
      width: total_width + grid_props.padding.left + grid_props.padding.right,
      height: total_height + grid_props.padding.top + grid_props.padding.bottom
    }
  end

  def measure_css_grid(_, _available_space), do: %{width: 0, height: 0}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp parse_grid_properties(attrs) do
    %{
      grid_template_columns: Map.get(attrs, :grid_template_columns, "none"),
      grid_template_rows: Map.get(attrs, :grid_template_rows, "none"),
      grid_template_areas: Map.get(attrs, :grid_template_areas, "none"),
      grid_auto_columns: Map.get(attrs, :grid_auto_columns, "auto"),
      grid_auto_rows: Map.get(attrs, :grid_auto_rows, "auto"),
      grid_auto_flow: Map.get(attrs, :grid_auto_flow, :row),
      gap: parse_gap(Map.get(attrs, :gap, 0)),
      justify_items: Map.get(attrs, :justify_items, :stretch),
      align_items: Map.get(attrs, :align_items, :stretch),
      justify_content: Map.get(attrs, :justify_content, :start),
      align_content: Map.get(attrs, :align_content, :start),
      padding: parse_padding(Map.get(attrs, :padding, 0))
    }
  end

  defp parse_gap(gap) when is_integer(gap), do: %{row: gap, column: gap}
  defp parse_gap(%{row: row, column: column}), do: %{row: row, column: column}
  defp parse_gap(_), do: %{row: 0, column: 0}

  defp parse_padding(padding), do: LayoutUtils.parse_padding(padding)

  defp apply_padding(space, padding),
    do: LayoutUtils.apply_padding(space, padding)
end

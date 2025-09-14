import ExUnit.Assertions

defmodule Raxol.Test.RendererTestHelper do
  @moduledoc """
  Helper module for renderer tests providing common test utilities and fixtures.
  """

  alias Raxol.UI.Theming.Theme

  def create_test_theme(name, arg2, arg3, arg4) do
    {colors, styles, fonts, variants} = parse_theme_args(arg2, arg3, arg4)

    %Raxol.UI.Theming.Theme{
      id: :test_theme,
      name: name,
      colors: colors,
      component_styles: styles,
      styles: styles,
      fonts: fonts,
      variants: variants,
      metadata: %{},
      ui_mappings: %{}
    }
  end

  defp parse_theme_args(arg2, arg3, arg4) do
    cond do
      is_binary(arg2) and is_binary(arg3) and is_map(arg4) ->
        # Called as (name, desc, desc, colors_or_config)
        # Check if arg4 contains variants
        has_variants = Map.has_key?(arg4, :variants)
        handle_variants_parsing(has_variants, arg4)

      is_map(arg2) and is_map(arg3) and (is_map(arg4) or is_nil(arg4)) ->
        # Called as (name, colors, styles, fonts)
        # Don't merge defaults - let themes be partial for inheritance testing
        {arg2, arg3, arg4 || %{}, %{}}

      true ->
        # Fallback: treat arg2 as colors if it's a map
        arg2_is_map = is_map(arg2)
        arg3_is_map = is_map(arg3)
        arg4_is_map = is_map(arg4)

        {get_map_or_empty(arg2_is_map, arg2),
         get_map_or_empty(arg3_is_map, arg3),
         get_map_or_empty(arg4_is_map, arg4), %{}}
    end
  end

  def get_cell_at(cells, x, y) do
    Enum.find(cells, fn {cx, cy, _, _, _, _} -> cx == x && cy == y end)
  end

  def get_cells_with_char(cells, char) do
    Enum.filter(cells, fn {_, _, c, _, _, _} -> c == char end)
  end

  def assert_cell_style(
        cell,
        expected_fg,
        expected_bg,
        expected_style_attrs \\ []
      ) do
    assert cell != nil
    {_, _, _, fg, bg, style_attrs} = cell

    # Resolve symbolic colors to match renderer output
    resolved_expected_fg = resolve_color(expected_fg)
    resolved_expected_bg = resolve_color(expected_bg)

    assert fg == resolved_expected_fg
    assert bg == resolved_expected_bg

    Enum.each(expected_style_attrs, fn attr ->
      assert attr in style_attrs
    end)
  end

  # Helper to resolve symbolic color names to color structs
  defp resolve_color(color) when is_atom(color) do
    # For test purposes, map common color names to their expected values
    case color do
      # Keep as atom for test expectations
      :green ->
        :green

      :red ->
        :red

      :blue ->
        :blue

      :yellow ->
        :yellow

      :black ->
        :black

      :white ->
        :white

      _ ->
        # Return the atom as-is for test expectations
        color
    end
  end

  defp resolve_color(color), do: color

  defp ensure_id(%Theme{} = map), do: map

  defp ensure_id(map) do
    has_id = Map.has_key?(map, :id)
    ensure_id_by_presence(has_id, map)
  end

  defp ensure_style(map) do
    has_style = Map.has_key?(map, :style)
    ensure_style_by_presence(has_style, map)
  end

  defp ensure_position(map) do
    has_position = Map.has_key?(map, :position)
    ensure_position_by_presence(has_position, map)
  end

  defp ensure_disabled(map) do
    has_disabled = Map.has_key?(map, :disabled)
    ensure_disabled_by_presence(has_disabled, map)
  end

  defp ensure_focused(map) do
    has_focused = Map.has_key?(map, :focused)
    ensure_focused_by_presence(has_focused, map)
  end

  defp ensure_attrs(map) do
    has_attrs = Map.has_key?(map, :attrs)
    ensure_attrs_by_presence(has_attrs, map)
  end

  def create_test_element(type, x, y, opts \\ %{}) do
    base = %{
      type: type,
      x: x,
      y: y,
      position: {x, y}
    }

    Map.merge(base, opts)
    |> ensure_style()
    |> ensure_id()
    |> ensure_position()
    |> ensure_disabled()
    |> ensure_focused()
    |> ensure_attrs()
  end

  def create_test_box(x, y, width, height, opts \\ %{}) do
    create_test_element(
      :box,
      x,
      y,
      Map.merge(%{width: width, height: height}, opts)
    )
    |> ensure_style()
    |> ensure_id()
    |> ensure_position()
    |> ensure_disabled()
    |> ensure_focused()
    |> ensure_attrs()
  end

  def create_test_text(x, y, text, opts \\ %{}) do
    create_test_element(:text, x, y, Map.merge(%{text: text}, opts))
    |> ensure_style()
    |> ensure_id()
    |> ensure_position()
    |> ensure_disabled()
    |> ensure_focused()
    |> ensure_attrs()
  end

  def create_test_panel(x, y, width, height, children \\ [], opts \\ %{}) do
    create_test_element(
      :panel,
      x,
      y,
      Map.merge(%{width: width, height: height, children: children}, opts)
    )
    |> ensure_style()
    |> ensure_id()
    |> ensure_position()
    |> ensure_disabled()
    |> ensure_focused()
    |> ensure_attrs()
  end

  def create_test_table(x, y, headers, data, opts \\ %{}) do
    opts = Map.put_new(opts, :width, 10)
    opts = Map.put_new(opts, :height, 5)

    create_test_element(
      :table,
      x,
      y,
      Map.merge(%{headers: headers, data: data}, opts)
    )
    |> ensure_style()
    |> ensure_id()
    |> ensure_position()
    |> ensure_disabled()
    |> ensure_focused()
    |> ensure_attrs()
  end

  ## Helper Functions for Pattern Matching

  defp handle_variants_parsing(true, arg4) do
    variants = Map.get(arg4, :variants, %{})
    colors = Map.drop(arg4, [:variants])

    # Don't merge defaults - let themes be partial for inheritance testing
    {colors, %{}, %{}, variants}
  end

  defp handle_variants_parsing(false, arg4) do
    # Don't merge defaults - let themes be partial for inheritance testing
    {arg4, %{}, %{}, %{}}
  end

  defp get_map_or_empty(true, map), do: map
  defp get_map_or_empty(false, _), do: %{}

  defp ensure_id_by_presence(true, map), do: map
  defp ensure_id_by_presence(false, map), do: Map.put(map, :id, :test_id)

  defp ensure_style_by_presence(true, map), do: map
  defp ensure_style_by_presence(false, map), do: Map.put(map, :style, %{})

  defp ensure_position_by_presence(true, map), do: map

  defp ensure_position_by_presence(false, map),
    do: Map.put(map, :position, {0, 0})

  defp ensure_disabled_by_presence(true, map), do: map

  defp ensure_disabled_by_presence(false, map),
    do: Map.put(map, :disabled, false)

  defp ensure_focused_by_presence(true, map), do: map
  defp ensure_focused_by_presence(false, map), do: Map.put(map, :focused, false)

  defp ensure_attrs_by_presence(true, map), do: map
  defp ensure_attrs_by_presence(false, map), do: Map.put(map, :attrs, %{})
end

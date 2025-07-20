import ExUnit.Assertions

defmodule Raxol.UI.RendererTestHelper do
  @moduledoc """
  Helper module for renderer tests providing common test utilities and fixtures.
  """

  alias Raxol.UI.Theming.Theme

  def create_test_theme(name, arg2, arg3, arg4) do
    {colors, styles, fonts} =
      cond do
        is_binary(arg2) and is_binary(arg3) and is_map(arg4) ->
          # Called as (name, desc, desc, colors)
          {Map.merge(%{foreground: :white, background: :black}, arg4), %{}, %{}}
        is_map(arg2) and is_map(arg3) and (is_map(arg4) or is_nil(arg4)) ->
          # Called as (name, colors, styles, fonts)
          {Map.merge(%{foreground: :white, background: :black}, arg2), arg3, arg4 || %{}}
        true ->
          # Fallback: treat arg2 as colors if it's a map
          {Map.merge(%{foreground: :white, background: :black}, if(is_map(arg2), do: arg2, else: %{})),
           if(is_map(arg3), do: arg3, else: %{}),
           if(is_map(arg4), do: arg4, else: %{})}
      end

    %Raxol.UI.Theming.Theme{
      id: :test_theme,
      name: name,
      colors: colors,
      component_styles: styles,
      styles: styles,
      fonts: fonts,
      variants: %{},
      metadata: %{},
      ui_mappings: %{}
    }
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
    if Map.has_key?(map, :id), do: map, else: Map.put(map, :id, :test_id)
  end

  defp ensure_style(map) do
    if Map.has_key?(map, :style), do: map, else: Map.put(map, :style, %{})
  end

  defp ensure_position(map) do
    if Map.has_key?(map, :position),
      do: map,
      else: Map.put(map, :position, {0, 0})
  end

  defp ensure_disabled(map) do
    if Map.has_key?(map, :disabled),
      do: map,
      else: Map.put(map, :disabled, false)
  end

  defp ensure_focused(map) do
    if Map.has_key?(map, :focused), do: map, else: Map.put(map, :focused, false)
  end

  defp ensure_attrs(map) do
    if Map.has_key?(map, :attrs), do: map, else: Map.put(map, :attrs, %{})
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
end

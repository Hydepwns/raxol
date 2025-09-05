defmodule Raxol.Renderer.Layout.Scroll do
  @moduledoc """
  Handles scroll layout calculations for UI elements.

  This module provides scroll functionality including:
  - Scrollbar rendering
  - Viewport calculations
  - Content positioning
  - Scrollbar thumb positioning
  """

  @doc """
  Processes a scroll element and returns positioned children with scrollbars.

  ## Parameters

  * `scroll_map` - The scroll element configuration
  * `space` - Available space for layout
  * `acc` - Accumulator for processed elements

  ## Returns

  A list of positioned elements including scrollbars.
  """
  def process_scroll_element(%{children: children} = scroll_map, space, acc)
      when is_list(children) do
    scroll_config = extract_scroll_config(scroll_map, space)

    scrolled_children =
      process_scrolled_children(children, space, scroll_config)

    scrollbar_elements = create_scrollbar_elements(scroll_config)

    scrolled_children ++ scrollbar_elements ++ acc
  end

  @doc """
  Creates shadow elements for shadow wrapper components.

  ## Parameters

  * `space` - Available space for layout
  * `offset` - Shadow offset {x, y}

  ## Returns

  A list of shadow elements.
  """
  def create_shadow_elements(space, {offset_x, offset_y}) do
    shadow_color = :darkgray

    shadow_box = %{
      type: :box,
      position: {space.x + offset_x, space.y + offset_y},
      size: {space.width - offset_x, space.height - offset_y},
      style: %{bg: shadow_color, fg: shadow_color}
    }

    [shadow_box]
  end

  defp extract_scroll_config(scroll_map, space) do
    {ox, oy} = Map.get(scroll_map, :offset, {0, 0})
    scrollbar_thickness = Map.get(scroll_map, :scrollbar_thickness, 1)
    render_v_bar = Map.get(scroll_map, :vertical_scrollbar, true)
    render_h_bar = Map.get(scroll_map, :horizontal_scrollbar, true)

    default_sb_attrs = %{
      track_fg: :gray,
      track_bg: nil,
      thumb_fg: :white,
      thumb_bg: :darkgray,
      corner_fg: :gray,
      corner_bg: nil
    }

    scrollbar_attrs =
      Map.merge(
        default_sb_attrs,
        Map.get(scroll_map, :scrollbar_attrs, Map.get(scroll_map, :attrs, %{}))
      )

    %{
      space: space,
      ox: ox,
      oy: oy,
      scrollbar_thickness: scrollbar_thickness,
      render_v_bar: render_v_bar,
      render_h_bar: render_h_bar,
      scrollbar_attrs: scrollbar_attrs
    }
  end

  defp process_scrolled_children(children, space, scroll_config) do
    %{
      ox: ox,
      oy: oy,
      scrollbar_thickness: scrollbar_thickness,
      render_v_bar: render_v_bar,
      render_h_bar: render_h_bar
    } = scroll_config

    scrolled_children =
      Enum.flat_map(children, fn child ->
        Raxol.Renderer.Layout.process_element(
          child,
          %{space | x: space.x - ox, y: space.y - oy},
          []
        )
      end)

    {content_width, content_height} =
      calculate_content_dimensions(scrolled_children)

    v_bar_adjustment =
      case render_v_bar do
        true -> scrollbar_thickness
        false -> 0
      end

    h_bar_adjustment =
      case render_h_bar do
        true -> scrollbar_thickness
        false -> 0
      end

    viewport_width = max(0, space.width - v_bar_adjustment)
    viewport_height = max(0, space.height - h_bar_adjustment)

    scrollbar_elements =
      create_scrollbar_elements(%{
        space: space,
        viewport_width: viewport_width,
        viewport_height: viewport_height,
        content_width: content_width,
        content_height: content_height,
        ox: ox,
        oy: oy,
        scrollbar_thickness: scrollbar_thickness,
        render_v_bar: render_v_bar,
        render_h_bar: render_h_bar,
        scrollbar_attrs: scroll_config.scrollbar_attrs
      })

    scrolled_children ++ scrollbar_elements
  end

  # Helper function to calculate content dimensions
  defp calculate_content_dimensions(scrolled_children) do
    children_empty = Enum.empty?(scrolled_children)

    case children_empty do
      true ->
        {0, 0}

      false ->
        {min_x, min_y, max_x, max_y} = calculate_bounds(scrolled_children)
        {max(0, max_x - min_x), max(0, max_y - min_y)}
    end
  end

  defp calculate_bounds(scrolled_children) do
    positions = Enum.map(scrolled_children, &Map.get(&1, :position, {0, 0}))
    sizes = Enum.map(scrolled_children, &Map.get(&1, :size, {0, 0}))

    {min_x, min_y} = calculate_min_bounds(positions)
    {max_x, max_y} = calculate_max_bounds(positions, sizes)

    {min_x, min_y, max_x, max_y}
  end

  defp calculate_min_bounds(positions) do
    {
      Enum.map(positions, &elem(&1, 0)) |> Enum.min(),
      Enum.map(positions, &elem(&1, 1)) |> Enum.min()
    }
  end

  defp calculate_max_bounds(positions, sizes) do
    {
      Enum.zip_with(positions, sizes, fn {x, _}, {w, _} -> x + w end)
      |> Enum.max(),
      Enum.zip_with(positions, sizes, fn {_, y}, {_, h} -> y + h end)
      |> Enum.max()
    }
  end

  # Helper function to create scrollbar elements
  defp create_scrollbar_elements(%{
         space: space,
         viewport_width: viewport_width,
         viewport_height: viewport_height,
         content_width: content_width,
         content_height: content_height,
         ox: ox,
         oy: oy,
         scrollbar_thickness: scrollbar_thickness,
         render_v_bar: render_v_bar,
         render_h_bar: render_h_bar,
         scrollbar_attrs: scrollbar_attrs
       }) do
    elements = []

    elements =
      create_vertical_scrollbar(elements, %{
        space: space,
        viewport_width: viewport_width,
        viewport_height: viewport_height,
        content_height: content_height,
        oy: oy,
        scrollbar_thickness: scrollbar_thickness,
        render_v_bar: render_v_bar,
        scrollbar_attrs: scrollbar_attrs
      })

    elements =
      create_horizontal_scrollbar(elements, %{
        space: space,
        viewport_width: viewport_width,
        viewport_height: viewport_height,
        content_width: content_width,
        ox: ox,
        scrollbar_thickness: scrollbar_thickness,
        render_h_bar: render_h_bar,
        scrollbar_attrs: scrollbar_attrs
      })

    create_corner_element(elements, %{
      space: space,
      viewport_width: viewport_width,
      viewport_height: viewport_height,
      scrollbar_thickness: scrollbar_thickness,
      render_v_bar: render_v_bar,
      render_h_bar: render_h_bar,
      scrollbar_attrs: scrollbar_attrs
    })
  end

  defp create_scrollbar_elements(_), do: []

  defp create_vertical_scrollbar(elements, %{
         space: space,
         viewport_width: viewport_width,
         viewport_height: viewport_height,
         content_height: content_height,
         oy: oy,
         scrollbar_thickness: scrollbar_thickness,
         render_v_bar: render_v_bar,
         scrollbar_attrs: scrollbar_attrs
       }) do
    should_render_v_bar =
      render_v_bar and space.width >= scrollbar_thickness and
        viewport_height > 0

    case should_render_v_bar do
      true ->
        track =
          create_scrollbar_track(
            space.x + viewport_width,
            space.y,
            scrollbar_thickness,
            viewport_height,
            scrollbar_attrs
          )

        needs_thumb = content_height > viewport_height

        case needs_thumb do
          true ->
            thumb =
              create_vertical_thumb(
                space,
                viewport_width,
                viewport_height,
                content_height,
                oy,
                scrollbar_thickness,
                scrollbar_attrs
              )

            [thumb, track | elements]

          false ->
            [track | elements]
        end

      false ->
        elements
    end
  end

  defp create_horizontal_scrollbar(elements, %{
         space: space,
         viewport_width: viewport_width,
         viewport_height: viewport_height,
         content_width: content_width,
         ox: ox,
         scrollbar_thickness: scrollbar_thickness,
         render_h_bar: render_h_bar,
         scrollbar_attrs: scrollbar_attrs
       }) do
    should_render_h_bar =
      render_h_bar and space.height >= scrollbar_thickness and
        viewport_width > 0

    case should_render_h_bar do
      true ->
        track =
          create_scrollbar_track(
            space.x,
            space.y + viewport_height,
            viewport_width,
            scrollbar_thickness,
            scrollbar_attrs
          )

        needs_thumb = content_width > viewport_width

        case needs_thumb do
          true ->
            thumb =
              create_horizontal_thumb(
                space,
                viewport_width,
                viewport_height,
                content_width,
                ox,
                scrollbar_thickness,
                scrollbar_attrs
              )

            [thumb, track | elements]

          false ->
            [track | elements]
        end

      false ->
        elements
    end
  end

  defp create_corner_element(elements, %{
         space: space,
         viewport_width: viewport_width,
         viewport_height: viewport_height,
         scrollbar_thickness: scrollbar_thickness,
         render_v_bar: render_v_bar,
         render_h_bar: render_h_bar,
         scrollbar_attrs: scrollbar_attrs
       }) do
    should_render_corner =
      render_v_bar and render_h_bar and space.width >= scrollbar_thickness and
        space.height >= scrollbar_thickness

    case should_render_corner do
      true ->
        corner = %{
          type: :box,
          position: {space.x + viewport_width, space.y + viewport_height},
          size: {scrollbar_thickness, scrollbar_thickness},
          style: %{fg: scrollbar_attrs.corner_fg, bg: scrollbar_attrs.corner_bg}
        }

        [corner | elements]

      false ->
        elements
    end
  end

  defp create_scrollbar_track(x, y, width, height, scrollbar_attrs) do
    %{
      type: :box,
      position: {x, y},
      size: {width, height},
      style: %{fg: scrollbar_attrs.track_fg, bg: scrollbar_attrs.track_bg}
    }
  end

  defp create_vertical_thumb(
         space,
         viewport_width,
         viewport_height,
         content_height,
         oy,
         scrollbar_thickness,
         scrollbar_attrs
       ) do
    thumb_height =
      max(1, round(viewport_height * (viewport_height / content_height)))

    scroll_ratio = oy / (content_height - viewport_height)
    thumb_y = space.y + round(scroll_ratio * (viewport_height - thumb_height))

    %{
      type: :box,
      position: {space.x + viewport_width, thumb_y},
      size: {scrollbar_thickness, thumb_height},
      style: %{fg: scrollbar_attrs.thumb_fg, bg: scrollbar_attrs.thumb_bg}
    }
  end

  defp create_horizontal_thumb(
         space,
         viewport_width,
         viewport_height,
         content_width,
         ox,
         scrollbar_thickness,
         scrollbar_attrs
       ) do
    thumb_width =
      max(1, round(viewport_width * (viewport_width / content_width)))

    scroll_ratio = ox / (content_width - viewport_width)
    thumb_x = space.x + round(scroll_ratio * (viewport_width - thumb_width))

    %{
      type: :box,
      position: {thumb_x, space.y + viewport_height},
      size: {thumb_width, scrollbar_thickness},
      style: %{fg: scrollbar_attrs.thumb_fg, bg: scrollbar_attrs.thumb_bg}
    }
  end
end

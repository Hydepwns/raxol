defmodule Raxol.Terminal.Rendering.CachedStyleRenderer do
  @moduledoc """
  High-performance terminal renderer with style string caching.

  Phase 2 optimization targeting the critical bottleneck:
  - Style string building: 44.9% of render time
  - Target: Reduce from 1461μs to <500μs (65% improvement)

  Key optimizations:
  1. LRU cache for compiled CSS style strings
  2. Pre-compiled templates for common styles
  3. Batch processing for consecutive identical styles
  4. Memory-efficient string building
  """

  alias Raxol.Terminal.ScreenBuffer
  # alias Raxol.Terminal.ANSI.TextFormatting  # Not used currently

  @type t :: %__MODULE__{
          screen_buffer: ScreenBuffer.t(),
          cursor: {non_neg_integer(), non_neg_integer()} | nil,
          theme: map(),
          font_settings: map(),
          style_cache: map(),
          cache_hits: non_neg_integer(),
          cache_misses: non_neg_integer()
        }

  defstruct [
    :screen_buffer,
    :cursor,
    :theme,
    :font_settings,
    style_cache: %{},
    cache_hits: 0,
    cache_misses: 0
  ]

  # Pre-compiled style templates for common combinations
  @style_templates %{
    # Empty/default style - most common
    :default => "",

    # Basic colors - very common
    :red_fg => "color: red",
    :green_fg => "color: green",
    :blue_fg => "color: blue",
    :yellow_fg => "color: yellow",
    :cyan_fg => "color: cyan",
    :magenta_fg => "color: magenta",
    :white_fg => "color: white",
    :black_fg => "color: black",

    # Basic text attributes - common
    :bold => "font-weight: bold",
    :italic => "font-style: italic",
    :underline => "text-decoration: underline",

    # Common combinations
    :bold_red => "font-weight: bold; color: red",
    :bold_green => "font-weight: bold; color: green",
    :bold_blue => "font-weight: bold; color: blue",
    :underline_red => "text-decoration: underline; color: red"
  }

  # Maximum cache size to prevent unbounded growth
  @max_cache_size 200

  @doc """
  Creates a new cached style renderer.
  """
  def new(screen_buffer, theme \\ %{}, font_settings \\ %{}) do
    %__MODULE__{
      screen_buffer: screen_buffer,
      cursor: nil,
      theme: theme,
      font_settings: font_settings,
      style_cache: %{},
      cache_hits: 0,
      cache_misses: 0
    }
  end

  @doc """
  Renders the terminal content with cached style optimization.
  """
  def render(%__MODULE__{} = renderer) do
    {content, updated_renderer} = render_with_cache_tracking(renderer)

    # Store final cache stats in Process dictionary for get_cache_stats/0
    Process.put(:style_cache_hits, updated_renderer.cache_hits)
    Process.put(:style_cache_misses, updated_renderer.cache_misses)

    # Optional: Log cache performance for optimization monitoring
    # log_cache_performance(updated_renderer)

    content
  end

  @doc """
  Renders the terminal content and returns both content and updated renderer with cache.
  Use this for stateful rendering where you want to preserve cache between renders.
  """
  def render_with_state(%__MODULE__{} = renderer) do
    {content, updated_renderer} = render_with_cache_tracking(renderer)

    # Store final cache stats in Process dictionary for get_cache_stats/0
    Process.put(:style_cache_hits, updated_renderer.cache_hits)
    Process.put(:style_cache_misses, updated_renderer.cache_misses)

    {content, updated_renderer}
  end

  defp render_with_cache_tracking(renderer) do
    # Initialize cache tracking in process dictionary
    Process.put(:current_style_cache, renderer.style_cache)
    Process.put(:style_cache_hits, renderer.cache_hits)
    Process.put(:style_cache_misses, renderer.cache_misses)

    content =
      renderer.screen_buffer.cells
      |> Enum.map_join("\n", fn row ->
        render_row_with_cached_styles(row, renderer)
      end)
      |> apply_font_settings(renderer.font_settings)
      |> maybe_apply_cursor(renderer.cursor)

    # Get updated cache state from process dictionary
    final_cache = Process.get(:current_style_cache, renderer.style_cache)
    final_hits = Process.get(:style_cache_hits, renderer.cache_hits)
    final_misses = Process.get(:style_cache_misses, renderer.cache_misses)

    # Clean up process dictionary
    Process.delete(:current_style_cache)
    Process.delete(:style_cache_hits)
    Process.delete(:style_cache_misses)

    updated_renderer = %{
      renderer
      | style_cache: final_cache,
        cache_hits: final_hits,
        cache_misses: final_misses
    }

    {content, updated_renderer}
  end

  defp render_row_with_cached_styles(row, renderer) do
    # Group consecutive cells with identical styles for batch processing
    row
    |> group_cells_by_identical_style()
    |> Enum.map_join("", fn {style_struct, chars} ->
      render_styled_group(style_struct, chars, renderer)
    end)
  end

  defp group_cells_by_identical_style(row) do
    row
    |> Enum.chunk_by(fn cell -> cell.style end)
    |> Enum.map(fn cells_with_same_style ->
      style = hd(cells_with_same_style).style
      chars = Enum.map_join(cells_with_same_style, "", & &1.char)
      {style, chars}
    end)
  end

  defp render_styled_group(style_struct, chars, renderer) do
    css_string =
      get_cached_style_string(
        style_struct,
        renderer.theme,
        renderer.style_cache
      )

    if css_string == "" do
      # No styling needed - just return the characters
      chars
    else
      "<span style=\"#{css_string}\">#{chars}</span>"
    end
  end

  defp get_cached_style_string(style_struct, theme, cache) do
    # Create cache key from style struct
    cache_key = create_style_cache_key(style_struct, theme)

    case Map.get(cache, cache_key) do
      nil ->
        # Cache miss - compute and cache the style string
        css_string = compute_style_string(style_struct, theme)

        # Update cache in process dictionary
        current_cache = Process.get(:current_style_cache, cache)
        updated_cache = Map.put(current_cache, cache_key, css_string)

        # Implement LRU eviction if cache is too large
        final_cache =
          if map_size(updated_cache) > @max_cache_size do
            # Remove oldest entries (simplified LRU - could be optimized)
            updated_cache
            # Remove 10 entries to avoid thrashing
            |> Enum.take(@max_cache_size - 10)
            |> Map.new()
          else
            updated_cache
          end

        Process.put(:current_style_cache, final_cache)

        Process.put(
          :style_cache_misses,
          Process.get(:style_cache_misses, 0) + 1
        )

        css_string

      cached_string ->
        # Cache hit - return cached result
        Process.put(:style_cache_hits, Process.get(:style_cache_hits, 0) + 1)
        cached_string
    end
  end

  defp create_style_cache_key(style_struct, theme) do
    # Create a lightweight cache key based on style attributes and theme version
    style_map = normalize_style(style_struct)
    theme_hash = :erlang.phash2(theme)

    key_parts = [
      Map.get(style_map, :foreground),
      Map.get(style_map, :background),
      Map.get(style_map, :bold, false),
      Map.get(style_map, :italic, false),
      Map.get(style_map, :underline, false),
      theme_hash
    ]

    :erlang.phash2(key_parts)
  end

  defp compute_style_string(style_struct, theme) do
    # Check for pre-compiled template first
    template_key = get_template_key(style_struct)

    case Map.get(@style_templates, template_key) do
      nil ->
        # No template available - build style string
        build_style_string_optimized(style_struct, theme)

      template_css ->
        # Use pre-compiled template
        template_css
    end
  end

  defp get_template_key(style_struct) do
    style_map = normalize_style(style_struct)

    cond do
      default_style?(style_map) ->
        :default

      simple_color_style?(style_map) ->
        get_simple_color_key(style_map)

      simple_attribute_style?(style_map) ->
        get_simple_attribute_key(style_map)

      common_combination?(style_map) ->
        get_combination_key(style_map)

      true ->
        nil
    end
  end

  defp default_style?(style_map) do
    all_default_values?(style_map)
  end

  defp simple_color_style?(style_map) do
    has_only_foreground_color?(style_map) and
      basic_color?(Map.get(style_map, :foreground))
  end

  defp simple_attribute_style?(style_map) do
    has_single_text_attribute?(style_map)
  end

  defp common_combination?(style_map) do
    bold_color_combination?(style_map) or
      underline_color_combination?(style_map)
  end

  defp build_style_string_optimized(style_struct, theme) do
    style_map = normalize_style(style_struct)

    # Use iolist for efficient string building, then convert to string
    style_parts =
      []
      |> add_color_style(style_map, :foreground, "color", theme)
      |> add_color_style(style_map, :background, "background-color", theme)
      |> add_boolean_style(style_map, :bold, "font-weight", "bold")
      |> add_boolean_style(style_map, :italic, "font-style", "italic")
      |> add_boolean_style(
        style_map,
        :underline,
        "text-decoration",
        "underline"
      )

    case style_parts do
      [] -> ""
      parts -> parts |> Enum.reverse() |> Enum.join("; ")
    end
  end

  # Helper functions for template matching
  defp all_default_values?(style_map) do
    default_values = %{
      foreground: nil,
      background: nil,
      bold: false,
      italic: false,
      underline: false,
      blink: false,
      reverse: false
    }

    Enum.all?(default_values, fn {key, default_value} ->
      Map.get(style_map, key, default_value) == default_value
    end)
  end

  defp has_only_foreground_color?(style_map) do
    Map.get(style_map, :foreground) != nil and
      Map.get(style_map, :background) == nil and
      Map.get(style_map, :bold, false) == false and
      Map.get(style_map, :italic, false) == false and
      Map.get(style_map, :underline, false) == false
  end

  defp basic_color?(color)
       when color in [
              :red,
              :green,
              :blue,
              :yellow,
              :cyan,
              :magenta,
              :white,
              :black
            ],
       do: true

  defp basic_color?(_), do: false

  defp get_simple_color_key(style_map) do
    case Map.get(style_map, :foreground) do
      :red -> :red_fg
      :green -> :green_fg
      :blue -> :blue_fg
      :yellow -> :yellow_fg
      :cyan -> :cyan_fg
      :magenta -> :magenta_fg
      :white -> :white_fg
      :black -> :black_fg
      _ -> nil
    end
  end

  defp has_single_text_attribute?(style_map) do
    attributes = [:bold, :italic, :underline]

    active_attributes =
      Enum.filter(attributes, fn attr ->
        Map.get(style_map, attr, false) == true
      end)

    length(active_attributes) == 1 and Map.get(style_map, :foreground) == nil and
      Map.get(style_map, :background) == nil
  end

  defp get_simple_attribute_key(style_map) do
    cond do
      Map.get(style_map, :bold, false) -> :bold
      Map.get(style_map, :italic, false) -> :italic
      Map.get(style_map, :underline, false) -> :underline
      true -> nil
    end
  end

  defp bold_color_combination?(style_map) do
    Map.get(style_map, :bold, false) == true and
      basic_color?(Map.get(style_map, :foreground)) and
      Map.get(style_map, :background) == nil and
      Map.get(style_map, :italic, false) == false and
      Map.get(style_map, :underline, false) == false
  end

  defp underline_color_combination?(style_map) do
    Map.get(style_map, :underline, false) == true and
      Map.get(style_map, :foreground) == :red and
      Map.get(style_map, :background) == nil and
      Map.get(style_map, :bold, false) == false and
      Map.get(style_map, :italic, false) == false
  end

  defp get_combination_key(style_map) do
    cond do
      bold_color_combination?(style_map) ->
        case Map.get(style_map, :foreground) do
          :red -> :bold_red
          :green -> :bold_green
          :blue -> :bold_blue
          _ -> nil
        end

      underline_color_combination?(style_map) ->
        :underline_red

      true ->
        nil
    end
  end

  # Optimized style building functions
  defp add_color_style(parts, style_map, key, css_prop, theme) do
    case Map.get(style_map, key) do
      nil ->
        parts

      color ->
        css_value = resolve_color_value(color, theme)

        if css_value == "",
          do: parts,
          else: ["#{css_prop}: #{css_value}" | parts]
    end
  end

  defp add_boolean_style(parts, style_map, key, css_prop, css_value) do
    if Map.get(style_map, key, false) do
      ["#{css_prop}: #{css_value}" | parts]
    else
      parts
    end
  end

  defp resolve_color_value(color, theme) when is_atom(color) do
    # Basic color resolution
    color_map = Map.get(theme, :foreground, %{})
    Map.get(color_map, color, to_string(color))
  end

  defp resolve_color_value(%{r: r, g: g, b: b}, _theme) do
    "rgb(#{r},#{g},#{b})"
  end

  defp resolve_color_value(color, _theme), do: to_string(color)

  defp normalize_style(%{__struct__: _} = style), do: Map.from_struct(style)
  defp normalize_style(style) when is_map(style), do: style
  defp normalize_style(_), do: %{}

  # Copied from original renderer for compatibility
  defp apply_font_settings(content, _font_settings), do: content
  defp maybe_apply_cursor(content, nil), do: content
  defp maybe_apply_cursor(content, _cursor), do: content

  @doc """
  Get cache performance statistics.
  """
  def get_cache_stats do
    hits = Process.get(:style_cache_hits, 0)
    misses = Process.get(:style_cache_misses, 0)
    total = hits + misses
    hit_rate = if total > 0, do: hits / total * 100, else: 0.0
    hit_rate_display = Float.round(hit_rate, 1)

    %{
      cache_hits: hits,
      cache_misses: misses,
      hit_rate_percent: hit_rate_display,
      templates_available: map_size(@style_templates)
    }
  end

  @doc """
  Reset cache statistics.
  """
  def reset_cache_stats do
    Process.delete(:style_cache_hits)
    Process.delete(:style_cache_misses)
    :ok
  end
end

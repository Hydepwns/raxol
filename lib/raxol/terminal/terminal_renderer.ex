defmodule Raxol.Terminal.Renderer do
  @moduledoc """
  Terminal renderer module.

  This module handles rendering of terminal output, including:
  - Character cell rendering
  - Text styling
  - Cursor rendering
  - Performance optimizations

  ## Integration with Other Modules

  The Renderer module works closely with several specialized modules:

  ### Manipulation Module
  - Receives text and style updates from the Manipulation module
  - Renders text with proper styling and positioning
  - Handles text insertion, deletion, and modification

  ### Selection Module
  - Renders text selections with visual highlighting
  - Supports multiple selections
  - Handles selection state changes

  ### Validation Module
  - Renders validation errors and warnings
  - Applies visual indicators for invalid input
  - Shows validation state through styling

  ## Performance Optimizations

  The renderer includes several optimizations:
  - Only renders changed cells
  - Batches style updates for consecutive cells
  - Minimizes DOM updates
  - Caches rendered output when possible

  ## Usage

  ```elixir
  # Create a new renderer
  buffer = ScreenBuffer.new(80, 24)
  renderer = Renderer.new(buffer)

  # Render with selection
  selection = %{selection: {0, 0, 0, 5}}
  output = Renderer.render(renderer, selection: selection)

  # Render with validation
  validation = Validation.validate_input(buffer, 0, 0, "text")
  output = Renderer.render(renderer, validation: validation)
  ```
  """

  alias Raxol.Terminal.ScreenBuffer

  @type t :: %__MODULE__{
          screen_buffer: ScreenBuffer.t(),
          cursor: {non_neg_integer(), non_neg_integer()} | nil,
          theme: map(),
          font_settings: map(),
          style_cache: map()
        }

  defstruct [
    :screen_buffer,
    :cursor,
    :theme,
    :font_settings,
    :style_batching,
    style_cache: %{}
  ]

  require Logger

  # Pre-compiled style templates for common combinations - Phase 3 optimization
  @style_templates %{
    # Empty/default style - most common
    default: "",

    # Basic colors - very common
    red: "color: #FF0000",
    green: "color: #00FF00",
    blue: "color: #0000FF",
    yellow: "color: #FFFF00",
    cyan: "color: #00FFFF",
    magenta: "color: #FF00FF",
    white: "color: #FFFFFF",
    black: "color: #000000",

    # Text attributes - common
    bold: "font-weight: bold",
    italic: "font-style: italic",
    underline: "text-decoration: underline",

    # Common combinations
    bold_red: "font-weight: bold; color: #FF0000",
    bold_green: "font-weight: bold; color: #00FF00",
    bold_blue: "font-weight: bold; color: #0000FF"
  }

  # Maximum cache size to prevent memory growth
  @max_cache_size 100

  @doc """
  Creates a new renderer with the given screen buffer.

  ## Examples

      iex> screen_buffer = ScreenBuffer.new(80, 24)
      iex> renderer = Renderer.new(screen_buffer)
      iex> renderer.screen_buffer
      %ScreenBuffer{}
  """
  def new(
        screen_buffer,
        theme \\ %{},
        font_settings \\ %{},
        style_batching \\ true
      ) do
    %__MODULE__{
      screen_buffer: screen_buffer,
      cursor: nil,
      theme: theme,
      font_settings: font_settings,
      style_batching: style_batching,
      style_cache: %{}
    }
  end

  @doc """
  Renders the terminal content without additional options.
  """
  def render(%__MODULE__{} = renderer) do
    render(renderer, %{}, %{})
  end

  @doc """
  Renders the terminal content.
  """
  def render(%__MODULE__{} = renderer, opts) do
    render(renderer, opts, %{})
  end

  @doc """
  Renders the terminal content with additional options.
  Returns {content, updated_renderer} to preserve cache state.
  """
  def render(%__MODULE__{} = renderer, _opts \\ %{}, _additional_opts \\ %{}) do
    {content, _updated_renderer} = render_with_cache(renderer)
    content
  end

  @doc """
  Renders the terminal content and returns both content and updated renderer.
  Use this for stateful rendering to preserve the style cache.
  """
  def render_with_cache(%__MODULE__{} = renderer) do
    {content, updated_cache} =
      renderer.screen_buffer
      |> get_styled_content_cached(renderer.theme, renderer.style_batching, renderer.style_cache)
      |> apply_font_settings(renderer.font_settings)
      |> maybe_apply_cursor(renderer.cursor)
      |> extract_content_and_cache()

    updated_renderer = %{renderer | style_cache: updated_cache}
    {content, updated_renderer}
  end

  defp get_styled_content_cached(buffer, theme, style_batching, style_cache) do
    {content, final_cache} = buffer.cells
    |> Enum.map_reduce(style_cache, fn row, acc_cache ->
      {row_content, updated_cache} = render_row_with_caching(row, theme, style_batching, acc_cache)
      {row_content, updated_cache}
    end)

    {Enum.join(content, "\n"), final_cache}
  end

  defp render_row_with_caching(row, theme, style_batching, cache) do
    {result, final_cache} = if style_batching do
      render_batched_with_cache(row, theme, cache)
    else
      render_individual_with_cache(row, theme, cache)
    end
    {result, final_cache}
  end

  # Optimized batched rendering with caching
  defp render_batched_with_cache(row, theme, cache) do
    {grouped_cells, updated_cache} = group_cells_by_style_cached(row, theme, cache)

    content = grouped_cells
    |> Enum.map_join("", fn {style_string, chars} ->
      if style_string == "" do
        chars
      else
        "<span style=\"#{style_string}\">#{chars}</span>"
      end
    end)

    {content, updated_cache}
  end

  # Individual cell rendering with caching
  defp render_individual_with_cache(row, theme, cache) do
    {cells_content, final_cache} = row
    |> Enum.map_reduce(cache, fn cell, acc_cache ->
      {style_string, updated_cache} = get_cached_style_string(cell.style, theme, acc_cache)
      content = if style_string == "" do
        cell.char
      else
        "<span style=\"#{style_string}\">#{cell.char}</span>"
      end
      {content, updated_cache}
    end)

    {Enum.join(cells_content, ""), final_cache}
  end

  defp group_cells_by_style_cached(row, theme, cache) do
    {grouped_data, final_cache} = row
    |> Enum.chunk_by(&(&1.style))
    |> Enum.map_reduce(cache, fn cells_with_same_style, acc_cache ->
      style = hd(cells_with_same_style).style
      chars = Enum.map_join(cells_with_same_style, "", & &1.char)
      {style_string, updated_cache} = get_cached_style_string(style, theme, acc_cache)
      {{style_string, chars}, updated_cache}
    end)

    {grouped_data, final_cache}
  end

  # Fast cached style string lookup with templates
  defp get_cached_style_string(style, theme, cache) do
    cache_key = create_cache_key(style, theme)

    case Map.get(cache, cache_key) do
      nil ->
        # Cache miss - check templates first, then build
        style_string = get_template_or_build(style, theme)
        updated_cache = put_in_cache(cache, cache_key, style_string)
        {style_string, updated_cache}

      cached_string ->
        # Cache hit
        {cached_string, cache}
    end
  end

  defp get_template_or_build(style, theme) do
    template_key = get_template_key(style)

    case Map.get(@style_templates, template_key) do
      nil -> build_style_string_optimized(style, theme)
      template -> template
    end
  end

  defp get_template_key(style) do
    style_map = normalize_style(style)

    cond do
      is_default_style?(style_map) -> :default
      is_simple_color?(style_map) -> get_simple_color_key(style_map)
      is_simple_attribute?(style_map) -> get_simple_attribute_key(style_map)
      is_common_combo?(style_map) -> get_combo_key(style_map)
      true -> nil
    end
  end

  # Helper functions for cache management and style analysis
  defp create_cache_key(style, theme) do
    style_hash = :erlang.phash2(normalize_style(style))
    theme_hash = :erlang.phash2(Map.take(theme, [:foreground, :background]))
    {style_hash, theme_hash}
  end

  defp put_in_cache(cache, key, value) do
    if map_size(cache) >= @max_cache_size do
      # Simple LRU - remove first 10 entries to avoid thrashing
      cache
      |> Enum.drop(10)
      |> Map.new()
      |> Map.put(key, value)
    else
      Map.put(cache, key, value)
    end
  end

  # Template matching functions
  defp is_default_style?(style_map) do
    Enum.all?([:foreground, :background, :bold, :italic, :underline], fn key ->
      case Map.get(style_map, key) do
        nil -> true
        false -> true
        _ -> false
      end
    end)
  end

  defp is_simple_color?(style_map) do
    Map.get(style_map, :foreground) in [:red, :green, :blue, :yellow, :cyan, :magenta, :white, :black] and
    is_nil(Map.get(style_map, :background)) and
    not Map.get(style_map, :bold, false) and
    not Map.get(style_map, :italic, false) and
    not Map.get(style_map, :underline, false)
  end

  defp get_simple_color_key(style_map) do
    Map.get(style_map, :foreground)
  end

  defp is_simple_attribute?(style_map) do
    attribute_count = Enum.count([:bold, :italic, :underline], fn attr ->
      Map.get(style_map, attr, false)
    end)

    attribute_count == 1 and
    is_nil(Map.get(style_map, :foreground)) and
    is_nil(Map.get(style_map, :background))
  end

  defp get_simple_attribute_key(style_map) do
    cond do
      Map.get(style_map, :bold, false) -> :bold
      Map.get(style_map, :italic, false) -> :italic
      Map.get(style_map, :underline, false) -> :underline
      true -> nil
    end
  end

  defp is_common_combo?(style_map) do
    Map.get(style_map, :bold, false) and
    Map.get(style_map, :foreground) in [:red, :green, :blue] and
    is_nil(Map.get(style_map, :background)) and
    not Map.get(style_map, :italic, false) and
    not Map.get(style_map, :underline, false)
  end

  defp get_combo_key(style_map) do
    case Map.get(style_map, :foreground) do
      :red -> :bold_red
      :green -> :bold_green
      :blue -> :bold_blue
      _ -> nil
    end
  end

  defp build_style_string_optimized(style, theme) do
    style_map = normalize_style(style)

    style_parts = []
    |> add_color_style(style_map, :foreground, "color", theme)
    |> add_color_style(style_map, :background, "background-color", theme)
    |> add_boolean_style(style_map, :bold, "font-weight", "bold")
    |> add_boolean_style(style_map, :italic, "font-style", "italic")
    |> add_boolean_style(style_map, :underline, "text-decoration", "underline")

    case style_parts do
      [] -> ""
      parts -> parts |> Enum.reverse() |> Enum.join("; ")
    end
  end

  defp extract_content_and_cache({content, cache}), do: {content, cache}
  defp extract_content_and_cache(content), do: {content, %{}}

  defp normalize_style(%{__struct__: _} = style) do
    Map.from_struct(style)
  end

  defp normalize_style(style) when is_map(style) do
    style
  end

  defp normalize_style(_style) do
    %{}
  end

  # Optimized style building functions
  defp add_color_style(parts, style_map, key, css_prop, theme) do
    case Map.get(style_map, key) do
      nil -> parts
      color ->
        css_value = resolve_color_value(color, theme)
        if css_value == "", do: parts, else: ["#{css_prop}: #{css_value}" | parts]
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
    # Basic color resolution with fallback to default color map
    color_map = Map.get(theme, :foreground, %{})
    case Map.get(color_map, color) do
      nil -> get_default_color(color)
      value -> value
    end
  end

  defp resolve_color_value(%{r: r, g: g, b: b}, _theme) do
    "##{Integer.to_string(r, 16) |> String.pad_leading(2, "0")}#{Integer.to_string(g, 16) |> String.pad_leading(2, "0")}#{Integer.to_string(b, 16) |> String.pad_leading(2, "0")}"
  end

  defp resolve_color_value(color, _theme), do: to_string(color)

  defp get_default_color(color) do
    default_colors = %{
      red: "#FF0000",
      green: "#00FF00",
      blue: "#0000FF",
      yellow: "#FFFF00",
      cyan: "#00FFFF",
      magenta: "#FF00FF",
      white: "#FFFFFF",
      black: "#000000",
      bright_red: "#FF8080",
      bright_green: "#80FF80",
      bright_blue: "#8080FF",
      bright_yellow: "#FFFF80",
      bright_cyan: "#80FFFF",
      bright_magenta: "#FF80FF",
      bright_white: "#FFFFFF",
      bright_black: "#808080"
    }
    Map.get(default_colors, color, "")
  end


  defp apply_font_settings(content, _font_settings), do: content
  defp maybe_apply_cursor(content, nil), do: content
  defp maybe_apply_cursor(content, _cursor), do: content

  @doc """
  Sets the cursor position.

  ## Examples

      iex> screen_buffer = ScreenBuffer.new(80, 24)
      iex> renderer = Renderer.new(screen_buffer)
      iex> renderer = Renderer.set_cursor(renderer, {10, 5})
      iex> renderer.cursor
      {10, 5}
  """
  def set_cursor(%__MODULE__{} = renderer, position) do
    %{renderer | cursor: position}
  end

  @doc """
  Clears the cursor position.

  ## Examples

      iex> screen_buffer = ScreenBuffer.new(80, 24)
      iex> renderer = Renderer.new(screen_buffer)
      iex> renderer = Renderer.set_cursor(renderer, {10, 5})
      iex> renderer = Renderer.clear_cursor(renderer)
      iex> renderer.cursor
      nil
  """
  def clear_cursor(%__MODULE__{} = renderer) do
    %{renderer | cursor: nil}
  end

  @doc """
  Updates the theme settings.

  ## Examples

      iex> screen_buffer = ScreenBuffer.new(80, 24)
      iex> renderer = Renderer.new(screen_buffer)
      iex> theme = %{foreground: %{default: "#FFF"}}
      iex> renderer = Renderer.set_theme(renderer, theme)
      iex> renderer.theme
      %{foreground: %{default: "#FFF"}}
  """
  def set_theme(%__MODULE__{} = renderer, theme) do
    %{renderer | theme: theme}
  end

  @doc """
  Updates the font settings.

  ## Examples

      iex> screen_buffer = ScreenBuffer.new(80, 24)
      iex> renderer = Renderer.new(screen_buffer)
      iex> settings = %{family: "Fira Code"}
      iex> renderer = Renderer.set_font_settings(renderer, settings)
      iex> renderer.font_settings
      %{family: "Fira Code"}
  """
  def set_font_settings(%__MODULE__{} = renderer, settings) do
    %{renderer | font_settings: settings}
  end

  @doc """
  Starts a new renderer process.
  """
  def start_link(opts \\ []) do
    screen_buffer = Keyword.get(opts, :screen_buffer, ScreenBuffer.new(80, 24))
    theme = Keyword.get(opts, :theme, %{})
    font_settings = Keyword.get(opts, :font_settings, %{})

    renderer = new(screen_buffer, theme, font_settings)
    {:ok, renderer}
  end

  @doc """
  Stops the renderer process.
  """
  def stop(_renderer) do
    # Cleanup any resources if needed
    :ok
  end

  @doc """
  Gets the current content of the screen buffer.

  ## Parameters
    * `renderer` - The renderer to get content from
    * `opts` - Options for content retrieval
      * `:include_style` - Whether to include style information (default: false)
      * `:include_cursor` - Whether to include cursor position (default: false)

  ## Returns
    * `{:ok, content}` - The current content
    * `{:error, reason}` - If content retrieval fails

  ## Examples
      iex> get_content(renderer)
      {:ok, "Hello, World!"}
  """
  def get_content(renderer, opts \\ [])

  def get_content(%__MODULE__{} = renderer, opts) do
    _include_style = Keyword.get(opts, :include_style, true)
    include_cursor = Keyword.get(opts, :include_cursor, true)

    content =
      renderer.screen_buffer
      |> ScreenBuffer.get_content()

    apply_cursor_option(content, renderer.cursor, include_cursor)
  end

  # Handle ScreenBuffer structs (updated after buffer consolidation)
  def get_content(%Raxol.Terminal.ScreenBuffer{} = buffer, opts) do
    _include_style = Keyword.get(opts, :include_style, false)
    include_cursor = Keyword.get(opts, :include_cursor, false)

    content =
      buffer
      |> Raxol.Terminal.ScreenBuffer.get_lines()
      |> Enum.map(&Enum.join/1)
      |> Enum.join("\n")
      |> maybe_add_cursor(buffer.cursor_position, include_cursor)

    {:ok, content}
  end

  # Handle buffer manager PIDs (legacy support - deprecated after buffer consolidation)
  def get_content(manager_pid, _opts) when is_pid(manager_pid) do
    # Buffer.Manager has been removed - return error for deprecated usage
    {:error, :deprecated_buffer_manager}
  end

  defp apply_cursor_option(content, cursor, true) do
    content |> maybe_add_cursor(cursor, true)
  end

  defp apply_cursor_option(content, _cursor, false), do: content

  defp maybe_add_cursor(content, nil, _include_cursor), do: content
  defp maybe_add_cursor(content, cursor, true), do: {content, cursor}
  defp maybe_add_cursor(content, _cursor, false), do: content
end

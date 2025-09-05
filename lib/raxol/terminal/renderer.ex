defmodule Raxol.Terminal.Renderer do
  @behaviour Raxol.Terminal.RendererBehaviour

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
          font_settings: map()
        }

  defstruct [
    :screen_buffer,
    :cursor,
    :theme,
    :font_settings,
    :style_batching
  ]

  require Logger

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
        style_batching \\ false
      ) do
    %__MODULE__{
      screen_buffer: screen_buffer,
      cursor: nil,
      theme: theme,
      font_settings: font_settings,
      style_batching: style_batching
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
  """
  def render(%__MODULE__{} = renderer, _opts, _additional_opts) do
    content =
      renderer.screen_buffer
      |> get_styled_content(renderer.theme, renderer.style_batching)
      |> apply_font_settings(renderer.font_settings)
      |> maybe_apply_cursor(renderer.cursor)

    content
  end

  defp get_styled_content(buffer, theme, style_batching) do
    buffer.cells
    |> Enum.map_join("\n", fn row ->
      render_row_with_style_batching(row, theme, style_batching)
    end)
  end

  defp render_row_with_style_batching(row, theme, style_batching) do
    apply_style_batching(style_batching, row, theme)
  end

  defp apply_style_batching(true, row, theme) do
    row
    |> group_cells_by_style(theme)
    |> Enum.map_join("", fn {style_attrs, chars} ->
      "<span style=\"#{style_attrs}\">#{chars}</span>"
    end)
  end

  defp apply_style_batching(false, row, theme) do
    row
    |> Enum.map_join("", fn cell -> render_cell(cell, theme) end)
  end

  defp group_cells_by_style(row, theme) do
    row
    |> Enum.chunk_by(fn cell -> build_style_string(cell.style, theme) end)
    |> Enum.map(fn cells_with_same_style ->
      style_attrs = build_style_string(hd(cells_with_same_style).style, theme)
      chars = Enum.map_join(cells_with_same_style, "", & &1.char)
      {style_attrs, chars}
    end)
  end

  defp render_cell(cell, theme) do
    style_attrs = build_style_string(cell.style, theme)
    "<span style=\"#{style_attrs}\">#{cell.char}</span>"
  end

  defp build_style_string(style, theme) do
    style_map = normalize_style(style)

    []
    |> add_background_color(style_map, theme)
    |> add_foreground_color(style_map, theme)
    |> add_text_attributes(style_map)
    |> build_style_string()
  end

  defp normalize_style(%{__struct__: _} = style) do
    Map.from_struct(style)
  end

  defp normalize_style(style) when is_map(style) do
    style
  end

  defp normalize_style(_style) do
    %{}
  end

  defp add_background_color(attrs, style_map, theme) do
    color = get_style_color(style_map, :background, theme, :background)
    add_color_attr(attrs, color, "background-color")
  end

  defp add_color_attr(attrs, "", _attr_name), do: attrs
  defp add_color_attr(attrs, color, attr_name), do: [{attr_name, color} | attrs]

  defp add_foreground_color(attrs, style_map, theme) do
    color = get_style_color(style_map, :foreground, theme, :foreground)
    add_color_attr(attrs, color, "color")
  end

  defp get_style_color(style_map, key, theme, theme_key) do
    color_value = Map.get(style_map, key)
    resolve_style_color(color_value, Map.get(theme, theme_key, %{}))
  end

  defp resolve_style_color(nil, theme_colors),
    do: get_color(:default, theme_colors)

  defp resolve_style_color(color_value, theme_colors),
    do: get_color(color_value, theme_colors)

  defp add_text_attributes(attrs, style_map) do
    attrs
    |> add_if_present(style_map, :bold, "font-weight", "bold")
    |> add_if_present(style_map, :underline, "text-decoration", "underline")
    |> add_if_present(style_map, :italic, "font-style", "italic")
  end

  defp add_if_present(attrs, style_map, key, css_prop, css_value) do
    style_enabled = Map.get(style_map, key, false)
    add_style_if_enabled(attrs, style_enabled, css_prop, css_value)
  end

  defp add_style_if_enabled(attrs, false, _css_prop, _css_value), do: attrs

  defp add_style_if_enabled(attrs, true, css_prop, css_value),
    do: [{css_prop, css_value} | attrs]

  defp build_style_string(attrs) do
    attrs
    |> Enum.reverse()
    |> Enum.map_join("; ", fn {k, v} -> "#{k}: #{v}" end)
  end

  defp get_color(color_name, color_map) do
    case Map.get(color_map, color_name) do
      nil -> ""
      color when is_binary(color) -> color
      color when is_map(color) -> convert_rgb_to_hex(color)
      color when is_atom(color) -> convert_color_atom(color)
      _ -> ""
    end
  end

  defp convert_rgb_to_hex(color) do
    convert_color_map(Map.has_key?(color, :r), color)
  end

  defp convert_color_map(false, _color), do: ""

  defp convert_color_map(true, color) do
    r = Map.get(color, :r, 0)
    g = Map.get(color, :g, 0)
    b = Map.get(color, :b, 0)

    "##{Integer.to_string(r, 16) |> String.pad_leading(2, "0")}#{Integer.to_string(g, 16) |> String.pad_leading(2, "0")}#{Integer.to_string(b, 16) |> String.pad_leading(2, "0")}"
  end

  defp convert_color_atom(color) do
    color_map = %{
      red: "#FF0000",
      green: "#00FF00",
      blue: "#0000FF",
      yellow: "#FFFF00",
      magenta: "#FF00FF",
      cyan: "#00FFFF",
      white: "#FFFFFF",
      black: "#000000",
      bright_red: "#FF8080",
      bright_green: "#80FF80",
      bright_blue: "#8080FF",
      bright_yellow: "#FFFF80",
      bright_magenta: "#FF80FF",
      bright_cyan: "#80FFFF",
      bright_white: "#FFFFFF",
      bright_black: "#808080"
    }

    Map.get(color_map, color, "")
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

  defp apply_cursor_option(content, cursor, true) do
    content |> maybe_add_cursor(cursor, true)
  end

  defp apply_cursor_option(content, _cursor, false), do: content

  # Handle ScreenBuffer structs
  def get_content(%Raxol.Terminal.ScreenBuffer{} = buffer, opts) do
    _include_style = Keyword.get(opts, :include_style, true)
    content = ScreenBuffer.get_content(buffer)
    {:ok, content}
  end

  # Handle BufferImpl structs (used by tests)
  def get_content(%Raxol.Terminal.Buffer.Manager.BufferImpl{} = buffer, opts) do
    _include_style = Keyword.get(opts, :include_style, false)
    include_cursor = Keyword.get(opts, :include_cursor, false)

    content =
      buffer
      |> Raxol.Terminal.Buffer.Manager.BufferImpl.get_content()
      |> maybe_add_cursor(buffer.cursor_position, include_cursor)

    {:ok, content}
  end

  # Handle buffer manager PIDs (used by tests)
  def get_content(manager_pid, opts) when is_pid(manager_pid) do
    case Raxol.Terminal.Buffer.Manager.read(manager_pid, opts) do
      {content, _new_buffer} -> {:ok, content}
      content when is_binary(content) or is_list(content) -> {:ok, content}
      {:error, reason} -> {:error, reason}
      other -> {:ok, other}
    end
  end

  defp maybe_add_cursor(content, nil, _include_cursor), do: content
  defp maybe_add_cursor(content, cursor, true), do: {content, cursor}
  defp maybe_add_cursor(content, _cursor, false), do: content
end

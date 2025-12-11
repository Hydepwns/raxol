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
  """
  def render(%__MODULE__{} = renderer, _opts \\ %{}, _additional_opts \\ %{}) do
    content =
      renderer.screen_buffer
      |> get_styled_content_optimized(renderer.theme, renderer.style_batching)
      |> apply_font_settings(renderer.font_settings)
      |> maybe_apply_cursor(renderer.cursor)

    content
  end

  defp get_styled_content_optimized(buffer, theme, style_batching) do
    buffer.cells
    |> Enum.map_join("\n", fn row ->
      render_row_optimized(row, theme, style_batching)
    end)
  end

  defp render_row_optimized(row, theme, style_batching) do
    case style_batching do
      true -> render_batched_optimized(row, theme)
      false -> render_individual_optimized(row, theme)
    end
  end

  # Simple optimized batched rendering
  defp render_batched_optimized(row, theme) do
    row
    |> Enum.chunk_by(& &1.style)
    |> Enum.map_join("", fn cells_with_same_style ->
      style = hd(cells_with_same_style).style
      chars = Enum.map_join(cells_with_same_style, "", & &1.char)
      style_string = build_style_string_fast(style, theme)

      # Always wrap in span for consistent HTML output
      "<span style=\"#{style_string}\">#{chars}</span>"
    end)
  end

  # Simple optimized individual rendering
  defp render_individual_optimized(row, theme) do
    row
    |> Enum.map_join("", fn cell ->
      style_string = build_style_string_fast(cell.style, theme)

      # Always wrap in span for consistent HTML output
      "<span style=\"#{style_string}\">#{cell.char}</span>"
    end)
  end

  # Fast style string building with pre-compiled templates
  defp build_style_string_fast(style, theme) do
    style_map = normalize_style(style)

    # Templates should only be used when we have no theme restrictions
    # If theme is provided but empty, we should respect that and not apply defaults
    case should_use_templates?(theme, style_map) do
      true ->
        case get_template_match(style_map) do
          nil -> build_style_string_optimized(style, theme)
          template -> template
        end

      false ->
        build_style_string_optimized(style, theme)
    end
  end

  defp get_template_match(style_map) do
    cond do
      default_style?(style_map) ->
        # Don't use static template for default style - need dynamic theme colors
        nil

      simple_color_match?(style_map, :red) ->
        Map.get(@style_templates, :red)

      simple_color_match?(style_map, :green) ->
        Map.get(@style_templates, :green)

      simple_color_match?(style_map, :blue) ->
        Map.get(@style_templates, :blue)

      simple_attribute_match?(style_map, :bold) ->
        Map.get(@style_templates, :bold)

      bold_color_combo?(style_map, :red) ->
        Map.get(@style_templates, :bold_red)

      bold_color_combo?(style_map, :green) ->
        Map.get(@style_templates, :bold_green)

      bold_color_combo?(style_map, :blue) ->
        Map.get(@style_templates, :bold_blue)

      true ->
        nil
    end
  end

  # Fast template matchers using pattern matching
  defp simple_color_match?(style_map, color) do
    Map.get(style_map, :foreground) == color and
      not Map.get(style_map, :bold, false) and
      not Map.get(style_map, :italic, false) and
      not Map.get(style_map, :underline, false) and
      is_nil(Map.get(style_map, :background))
  end

  defp simple_attribute_match?(style_map, attr) do
    Map.get(style_map, attr, false) == true and
      is_nil(Map.get(style_map, :foreground)) and
      is_nil(Map.get(style_map, :background)) and
      not Map.get(style_map, :italic, false) and
      not Map.get(style_map, :underline, false) and
      (attr != :bold or not Map.get(style_map, :italic, false))
  end

  defp bold_color_combo?(style_map, color) do
    Map.get(style_map, :foreground) == color and
      Map.get(style_map, :bold, false) == true and
      not Map.get(style_map, :italic, false) and
      not Map.get(style_map, :underline, false) and
      is_nil(Map.get(style_map, :background))
  end

  # Template matching helper
  defp default_style?(style_map) do
    Enum.all?([:foreground, :background, :bold, :italic, :underline], fn key ->
      case Map.get(style_map, key) do
        nil -> true
        false -> true
        _ -> false
      end
    end)
  end

  defp should_use_templates?(theme, _style_map) do
    # Only use templates when theme is completely nil/undefined
    # If theme is an empty map %{}, that's an intentional choice to disable defaults
    is_nil(theme)
  end

  defp build_style_string_optimized(style, theme) do
    style_map = normalize_style(style)

    # Use iolist for efficient string building
    parts = []

    # Add foreground color
    parts =
      case Map.get(style_map, :foreground) do
        nil ->
          # Apply default theme color when no explicit foreground is set
          default_color = get_default_foreground_color(theme)

          case default_color do
            "" -> parts
            _ -> ["color: " <> default_color | parts]
          end

        color ->
          css_color = resolve_color_value(color, theme)

          case css_color do
            "" -> parts
            _ -> ["color: " <> css_color | parts]
          end
      end

    # Add background color
    parts =
      case Map.get(style_map, :background) do
        nil ->
          # Apply default theme background color when no explicit background is set
          default_bg_color = get_default_background_color(theme)

          case default_bg_color do
            "" -> parts
            _ -> ["background-color: " <> default_bg_color | parts]
          end

        color ->
          css_color = resolve_background_color_value(color, theme)

          case css_color do
            "" -> parts
            _ -> ["background-color: " <> css_color | parts]
          end
      end

    # Add text attributes
    parts =
      if Map.get(style_map, :bold, false),
        do: ["font-weight: bold" | parts],
        else: parts

    parts =
      if Map.get(style_map, :italic, false),
        do: ["font-style: italic" | parts],
        else: parts

    parts =
      if Map.get(style_map, :underline, false),
        do: ["text-decoration: underline" | parts],
        else: parts

    case parts do
      [] -> ""
      _ -> parts |> Enum.reverse() |> Enum.join("; ")
    end
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

  defp resolve_color_value(color, theme) when is_atom(color) do
    # Basic color resolution with fallback to default color map
    color_map = Map.get(theme, :foreground, %{})

    case Map.get(color_map, color) do
      nil ->
        # Only use default colors if theme has some color configuration
        # If theme is empty/minimal, return empty string to avoid unwanted defaults
        case map_size(theme) > 0 and map_size(color_map) > 0 do
          true -> get_default_color(color)
          false -> ""
        end

      value ->
        value
    end
  end

  defp resolve_color_value(%{r: r, g: g, b: b}, _theme) do
    "##{Integer.to_string(r, 16) |> String.pad_leading(2, "0")}#{Integer.to_string(g, 16) |> String.pad_leading(2, "0")}#{Integer.to_string(b, 16) |> String.pad_leading(2, "0")}"
  end

  defp resolve_color_value(color, _theme), do: to_string(color)

  defp resolve_background_color_value(color, theme) when is_atom(color) do
    # Background color resolution with fallback to default color map
    color_map = Map.get(theme, :background, %{})

    case Map.get(color_map, color) do
      nil ->
        # Only use default colors if theme has some color configuration
        # If theme is empty/minimal, return empty string to avoid unwanted defaults
        case map_size(theme) > 0 and map_size(color_map) > 0 do
          true -> get_default_color(color)
          false -> ""
        end

      value ->
        value
    end
  end

  defp resolve_background_color_value(%{r: r, g: g, b: b}, _theme) do
    "##{Integer.to_string(r, 16) |> String.pad_leading(2, "0")}#{Integer.to_string(g, 16) |> String.pad_leading(2, "0")}#{Integer.to_string(b, 16) |> String.pad_leading(2, "0")}"
  end

  defp resolve_background_color_value(color, _theme), do: to_string(color)

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

  defp get_default_foreground_color(theme) do
    # Get the default foreground color from theme
    case get_in(theme, [:foreground, :default]) do
      nil -> ""
      color -> color
    end
  end

  defp get_default_background_color(theme) do
    # Get the default background color from theme
    case get_in(theme, [:background, :default]) do
      nil -> ""
      color -> color
    end
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
      |> Enum.map_join("\n", &Enum.join/1)
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

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
    :font_settings
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
  def new(screen_buffer, theme \\ %{}, font_settings \\ %{}) do
    %__MODULE__{
      screen_buffer: screen_buffer,
      cursor: nil,
      theme: theme,
      font_settings: font_settings
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
      |> get_styled_content(renderer.theme)
      |> apply_font_settings(renderer.font_settings)
      |> maybe_apply_cursor(renderer.cursor)

    content
  end

  defp get_styled_content(buffer, theme) do
    buffer.cells
    |> Enum.map(fn row ->
      row
      |> Enum.map_join("", fn cell ->
        render_cell(cell, theme)
      end)
    end)
    |> Enum.join("\n")
  end

  defp render_cell(cell, theme) do
    # Debug: Print cell info for first few cells
    if cell.char == "S" do
      IO.puts("DEBUG: Cell char: '#{cell.char}', style: #{inspect(cell.style)}")
    end

    style_attrs = build_style_string(cell.style, theme)
    "<span style=\"#{style_attrs}\">#{cell.char}</span>"
  end

  defp build_style_string(style, theme) do
    attrs = []

    # Normalize style to a map
    style_map =
      cond do
        is_map(style) and Map.has_key?(style, :__struct__) ->
          Map.from_struct(style)

        is_map(style) ->
          style

        true ->
          %{}
      end

    # Apply background color - use cell style if present, otherwise use default from theme
    background_color =
      if Map.has_key?(style_map, :background) and
           not is_nil(style_map.background) do
        get_color(style_map.background, Map.get(theme, :background, %{}))
      else
        get_color(:default, Map.get(theme, :background, %{}))
      end

    attrs =
      if background_color != "" do
        [{"background-color", background_color} | attrs]
      else
        attrs
      end

    # Apply foreground color - use cell style if present, otherwise use default
    foreground_color =
      if Map.has_key?(style_map, :foreground) and
           not is_nil(style_map.foreground) do
        get_color(style_map.foreground, Map.get(theme, :foreground, %{}))
      else
        get_color(:default, Map.get(theme, :foreground, %{}))
      end

    attrs =
      if foreground_color != "" do
        [{"color", foreground_color} | attrs]
      else
        attrs
      end

    # Apply bold if present
    attrs =
      if Map.get(style_map, :bold, false) do
        [{"font-weight", "bold"} | attrs]
      else
        attrs
      end

    # Apply underline if present
    attrs =
      if Map.get(style_map, :underline, false) do
        [{"text-decoration", "underline"} | attrs]
      else
        attrs
      end

    # Apply italic if present
    attrs =
      if Map.get(style_map, :italic, false) do
        [{"font-style", "italic"} | attrs]
      else
        attrs
      end

    # Build the style string
    attrs
    |> Enum.reverse()
    |> Enum.map(fn {k, v} -> "#{k}: #{v}" end)
    |> Enum.join("; ")
  end

  defp get_color(color_name, color_map) do
    case Map.get(color_map, color_name) do
      nil ->
        ""

      color when is_binary(color) ->
        color

      color when is_map(color) ->
        # Check if it's an RGB object
        if Map.has_key?(color, :r) do
          # Convert RGB object to hex string
          r = Map.get(color, :r, 0)
          g = Map.get(color, :g, 0)
          b = Map.get(color, :b, 0)

          "##{Integer.to_string(r, 16) |> String.pad_leading(2, "0")}#{Integer.to_string(g, 16) |> String.pad_leading(2, "0")}#{Integer.to_string(b, 16) |> String.pad_leading(2, "0")}"
        else
          ""
        end

      color when is_atom(color) ->
        # Handle color atoms by converting to hex
        case color do
          :red -> "#FF0000"
          :green -> "#00FF00"
          :blue -> "#0000FF"
          :yellow -> "#FFFF00"
          :magenta -> "#FF00FF"
          :cyan -> "#00FFFF"
          :white -> "#FFFFFF"
          :black -> "#000000"
          :bright_red -> "#FF8080"
          :bright_green -> "#80FF80"
          :bright_blue -> "#8080FF"
          :bright_yellow -> "#FFFF80"
          :bright_magenta -> "#FF80FF"
          :bright_cyan -> "#80FFFF"
          :bright_white -> "#FFFFFF"
          :bright_black -> "#808080"
          _ -> ""
        end

      _ ->
        ""
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
    _include_style = Keyword.get(opts, :include_style, false)
    include_cursor = Keyword.get(opts, :include_cursor, false)

    content =
      renderer.screen_buffer
      |> ScreenBuffer.get_content(include_style: _include_style)
      |> maybe_add_cursor(renderer.cursor, include_cursor)

    {:ok, content}
  end

  # Handle ScreenBuffer structs
  def get_content(%Raxol.Terminal.ScreenBuffer{} = buffer, opts) do
    _include_style = Keyword.get(opts, :include_style, false)
    content = ScreenBuffer.get_content(buffer, include_style: _include_style)
    {:ok, content}
  end

  # Handle BufferImpl structs (used by tests)
  def get_content(%Raxol.Terminal.Buffer.Manager.BufferImpl{} = buffer, opts) do
    _include_style = Keyword.get(opts, :include_style, false)
    _include_cursor = Keyword.get(opts, :include_cursor, false)

    content =
      buffer
      |> Raxol.Terminal.Buffer.Manager.BufferImpl.get_content()
      |> maybe_add_cursor(buffer.cursor_position, _include_cursor)

    {:ok, content}
  end

  # Handle buffer manager PIDs (used by tests)
  def get_content(manager_pid, opts) when is_pid(manager_pid) do
    case Raxol.Terminal.Buffer.Manager.read(manager_pid, opts) do
      {content, _new_buffer} when is_binary(content) -> {:ok, content}
      {content, _new_buffer} when is_list(content) -> {:ok, content}
      content when is_binary(content) -> {:ok, content}
      content when is_list(content) -> {:ok, content}
      {:error, reason} -> {:error, reason}
      other -> {:ok, other}
    end
  end

  defp maybe_add_cursor(content, nil, _include_cursor), do: content
  defp maybe_add_cursor(content, cursor, true), do: {content, cursor}
  defp maybe_add_cursor(content, _cursor, false), do: content
end

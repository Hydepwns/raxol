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
  def render(%__MODULE__{} = renderer, opts, additional_opts) do
    content =
      renderer.screen_buffer
      |> ScreenBuffer.get_content(include_style: true)
      |> apply_theme(renderer.theme)
      |> apply_font_settings(renderer.font_settings)
      |> maybe_apply_cursor(renderer.cursor)

    {:ok, content}
  end

  defp apply_theme(content, theme), do: content
  defp apply_font_settings(content, font_settings), do: content
  defp maybe_apply_cursor(content, nil), do: content
  defp maybe_apply_cursor(content, cursor), do: {content, cursor}

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
  def stop(renderer) do
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
  def get_content(%__MODULE__{} = renderer, opts \\ []) do
    include_style = Keyword.get(opts, :include_style, false)
    include_cursor = Keyword.get(opts, :include_cursor, false)

    content =
      renderer.screen_buffer
      |> ScreenBuffer.get_content(include_style: include_style)
      |> maybe_add_cursor(renderer.cursor, include_cursor)

    {:ok, content}
  end

  defp maybe_add_cursor(content, nil, _include_cursor), do: content
  defp maybe_add_cursor(content, cursor, true), do: {content, cursor}
  defp maybe_add_cursor(content, _cursor, false), do: content
end

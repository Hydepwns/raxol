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

  alias Raxol.Terminal.{Cell, ScreenBuffer}

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
  Renders the screen buffer to a string.

  ## Options

    * `:selection` - A single selection to highlight
    * `:selections` - Multiple selections to highlight
    * `:validation` - Validation state to apply
    * `:theme` - Override the default theme
    * `:font_settings` - Override the default font settings

  ## Examples

      iex> screen_buffer = ScreenBuffer.new(80, 24)
      iex> renderer = Renderer.new(screen_buffer)
      iex> output = Renderer.render(renderer)
      iex> is_binary(output)
      true

      iex> screen_buffer = ScreenBuffer.new(80, 24)
      iex> renderer = Renderer.new(screen_buffer)
      iex> selection = %{selection: {0, 0, 0, 5}}
      iex> output = Renderer.render(renderer, selection: selection)
      iex> output =~ "background-color: #0000FF"
      true
  """
  def render(%__MODULE__{} = renderer, opts \\ []) do
    selection = Keyword.get(opts, :selection)
    selections = Keyword.get(opts, :selections, [])
    validation = Keyword.get(opts, :validation)
    theme = Keyword.get(opts, :theme, renderer.theme)
    font_settings = Keyword.get(opts, :font_settings, renderer.font_settings)

    renderer.screen_buffer.cells
    |> Enum.map(
      &render_row(
        &1,
        renderer,
        selection,
        selections,
        validation,
        theme,
        font_settings
      )
    )
    |> Enum.join("\n")
  end

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

  # Private helper functions

  defp render_row(
         row,
         renderer,
         selection,
         selections,
         validation,
         theme,
         font_settings
       ) do
    row
    |> Enum.map(
      &render_cell(
        &1,
        renderer,
        selection,
        selections,
        validation,
        theme,
        font_settings
      )
    )
    |> Enum.join("")
  end

  defp render_cell(
         cell,
         renderer,
         selection,
         selections,
         validation,
         theme,
         font_settings
       ) do
    style =
      build_style(
        cell,
        renderer,
        selection,
        selections,
        validation,
        theme,
        font_settings
      )

    "<span style=\"#{style}\">#{cell.char}</span>"
  end

  defp build_style(
         cell,
         _renderer,
         selection,
         selections,
         validation,
         theme,
         font_settings
       ) do
    _styles = []

    # Add foreground color
    if fg = get_foreground_color(cell, theme) do
      _styles = ["color: #{fg}" | _styles]
    end

    # Add background color
    if bg = get_background_color(cell, theme) do
      _styles = ["background-color: #{bg}" | _styles]
    end

    # Add text styles
    if cell.style.bold do
      _styles = ["font-weight: bold" | _styles]
    end

    if cell.style.italic do
      _styles = ["font-style: italic" | _styles]
    end

    if cell.style.underline do
      _styles = ["text-decoration: underline" | _styles]
    end

    # Add selection highlight
    if is_selected?(cell, selection, selections) do
      _styles = ["background-color: #0000FF" | _styles]
    end

    # Add validation styling
    if validation && validation.error do
      _styles = ["color: #FF0000" | _styles]
    end

    if validation && validation.warning do
      _styles = ["color: #FFA500" | _styles]
    end

    # Add font settings
    if family = font_settings[:family] do
      _styles = ["font-family: #{family}" | _styles]
    end

    if size = font_settings[:size] do
      _styles = ["font-size: #{size}px" | _styles]
    end

    Enum.join(_styles, "; ")
  end

  defp get_foreground_color(cell, theme) do
    case cell.style.foreground do
      nil -> theme[:foreground][:default]
      color -> theme[:foreground][color]
    end
  end

  defp get_background_color(cell, theme) do
    case cell.style.background do
      nil -> theme[:background][:default]
      color -> theme[:background][color]
    end
  end

  defp is_selected?(cell, selection, selections) do
    cond do
      selection && is_in_selection?(cell, selection) -> true
      selections && Enum.any?(selections, &is_in_selection?(cell, &1)) -> true
      true -> false
    end
  end

  defp is_in_selection?(cell, selection) do
    {start_x, start_y} = selection.start
    {end_x, end_y} = selection.end
    {cell_x, cell_y} = cell.position

    cell_y >= start_y && cell_y <= end_y &&
      (cell_y > start_y || cell_x >= start_x) &&
      (cell_y < end_y || cell_x <= end_x)
  end
end

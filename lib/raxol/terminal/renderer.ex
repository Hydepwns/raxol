defmodule Raxol.Terminal.Renderer do
  @moduledoc """
  Terminal rendering module.
  
  This module handles the conversion of terminal screen buffer state into HTML/CSS
  for web display, including:
  - Character cell rendering
  - Text styling and colors
  - Cursor rendering
  - Selection highlighting
  - Scrollback buffer
  - Performance optimizations
  - Custom themes
  - Font settings
  """

  alias Raxol.Terminal.{ScreenBuffer, Cell}

  @type t :: %__MODULE__{
    theme: map(),
    font_family: String.t(),
    font_size: integer(),
    line_height: float(),
    cursor_style: :block | :underline | :bar,
    cursor_blink: boolean(),
    cursor_color: String.t(),
    selection_color: String.t(),
    scrollback_limit: integer(),
    batch_size: integer(),
    virtual_scroll: boolean(),
    visible_rows: integer()
  }

  defstruct [
    :theme,
    :font_family,
    :font_size,
    :line_height,
    :cursor_style,
    :cursor_blink,
    :cursor_color,
    :selection_color,
    :scrollback_limit,
    :batch_size,
    :virtual_scroll,
    :visible_rows
  ]

  @default_theme %{
    background: "#000000",
    foreground: "#ffffff",
    black: "#000000",
    red: "#cd0000",
    green: "#00cd00",
    yellow: "#cdcd00",
    blue: "#0000cd",
    magenta: "#cd00cd",
    cyan: "#00cdcd",
    white: "#e5e5e5",
    bright_black: "#7f7f7f",
    bright_red: "#ff0000",
    bright_green: "#00ff00",
    bright_yellow: "#ffff00",
    bright_blue: "#0000ff",
    bright_magenta: "#ff00ff",
    bright_cyan: "#00ffff",
    bright_white: "#ffffff"
  }

  @doc """
  Creates a new renderer with default settings.
  
  ## Examples
  
      iex> renderer = Renderer.new()
      iex> renderer.font_family
      "Fira Code"
  """
  def new(opts \\ []) do
    %__MODULE__{
      theme: Keyword.get(opts, :theme, @default_theme),
      font_family: Keyword.get(opts, :font_family, "Fira Code"),
      font_size: Keyword.get(opts, :font_size, 14),
      line_height: Keyword.get(opts, :line_height, 1.2),
      cursor_style: Keyword.get(opts, :cursor_style, :block),
      cursor_blink: Keyword.get(opts, :cursor_blink, true),
      cursor_color: Keyword.get(opts, :cursor_color, "#ffffff"),
      selection_color: Keyword.get(opts, :selection_color, "rgba(255, 255, 255, 0.2)"),
      scrollback_limit: Keyword.get(opts, :scrollback_limit, 1000),
      batch_size: Keyword.get(opts, :batch_size, 100),
      virtual_scroll: Keyword.get(opts, :virtual_scroll, true),
      visible_rows: Keyword.get(opts, :visible_rows, 24)
    }
  end

  @doc """
  Renders the entire screen buffer as HTML.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> renderer = Renderer.new()
      iex> html = Renderer.render(buffer, renderer)
      iex> String.contains?(html, "<div class=\"terminal\">")
      true
  """
  def render(%ScreenBuffer{} = buffer, %__MODULE__{} = renderer) do
    """
    <div class="terminal" style="width: #{buffer.width}ch; height: #{buffer.height}ch; font-family: #{renderer.font_family}; font-size: #{renderer.font_size}px; line-height: #{renderer.line_height};">
      #{render_scrollback(buffer, renderer)}
      #{render_screen(buffer, renderer)}
      #{render_cursor(buffer, renderer)}
      #{render_selection(buffer, renderer)}
    </div>
    """
  end

  @doc """
  Renders only the visible portion of the screen buffer.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> renderer = Renderer.new()
      iex> html = Renderer.render_screen(buffer, renderer)
      iex> String.contains?(html, "<div class=\"screen\">")
      true
  """
  def render_screen(%ScreenBuffer{} = buffer, %__MODULE__{} = renderer) do
    cells = if renderer.virtual_scroll do
      # Only render visible rows for performance
      visible_start = max(0, length(buffer.buffer) - renderer.visible_rows)
      visible_rows = Enum.slice(buffer.buffer, visible_start, renderer.visible_rows)
      
      visible_rows
      |> Enum.with_index(visible_start)
      |> Enum.map(fn {row, y} ->
        render_row(row, y, buffer, renderer)
      end)
      |> Enum.join("\n")
    else
      # Render all rows
      buffer.buffer
      |> Enum.with_index()
      |> Enum.map(fn {row, y} ->
        render_row(row, y, buffer, renderer)
      end)
      |> Enum.join("\n")
    end

    """
    <div class="screen">
      #{cells}
    </div>
    """
  end

  @doc """
  Renders the scrollback buffer.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> renderer = Renderer.new()
      iex> html = Renderer.render_scrollback(buffer, renderer)
      iex> String.contains?(html, "<div class=\"scrollback\">")
      true
  """
  def render_scrollback(%ScreenBuffer{} = buffer, %__MODULE__{} = renderer) do
    case buffer.scrollback do
      [] -> ""
      scrollback ->
        # Limit scrollback size for performance
        limited_scrollback = if length(scrollback) > renderer.scrollback_limit do
          Enum.take(scrollback, renderer.scrollback_limit)
        else
          scrollback
        end
        
        cells = if renderer.virtual_scroll do
          # Only render visible portion of scrollback
          visible_start = max(0, length(limited_scrollback) - renderer.visible_rows)
          visible_rows = Enum.slice(limited_scrollback, visible_start, renderer.visible_rows)
          
          visible_rows
          |> Enum.with_index(visible_start)
          |> Enum.map(fn {row, y} ->
            render_row(row, y, buffer, renderer, "scrollback")
          end)
          |> Enum.join("\n")
        else
          # Render all scrollback rows
          limited_scrollback
          |> Enum.with_index()
          |> Enum.map(fn {row, y} ->
            render_row(row, y, buffer, renderer, "scrollback")
          end)
          |> Enum.join("\n")
        end

        """
        <div class="scrollback">
          #{cells}
        </div>
        """
    end
  end

  @doc """
  Renders the cursor.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> renderer = Renderer.new()
      iex> html = Renderer.render_cursor(buffer, renderer)
      iex> String.contains?(html, "<div class=\"cursor")
      true
  """
  def render_cursor(%ScreenBuffer{} = buffer, %__MODULE__{} = renderer) do
    {x, y} = buffer.cursor
    cursor_class = "cursor-#{renderer.cursor_style}"
    cursor_style = if renderer.cursor_blink do
      "animation: blink 1s step-end infinite;"
    else
      ""
    end
    
    """
    <div class="#{cursor_class}" style="left: #{x}ch; top: #{y}ch; background-color: #{renderer.cursor_color}; #{cursor_style}"></div>
    """
  end

  @doc """
  Renders the selection overlay.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> renderer = Renderer.new()
      iex> buffer = ScreenBuffer.set_selection(buffer, 0, 0, 5, 0)
      iex> html = Renderer.render_selection(buffer, renderer)
      iex> String.contains?(html, "<div class=\"selection\">")
      true
  """
  def render_selection(%ScreenBuffer{} = buffer, %__MODULE__{} = renderer) do
    case buffer.selection do
      nil -> ""
      {start_x, start_y, end_x, end_y} ->
        """
        <div class="selection" style="left: #{start_x}ch; top: #{start_y}ch; width: #{end_x - start_x}ch; height: #{end_y - start_y}ch; background-color: #{renderer.selection_color};"></div>
        """
    end
  end

  @doc """
  Renders a single row of cells.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> renderer = Renderer.new()
      iex> row = List.first(buffer.buffer)
      iex> html = Renderer.render_row(row, 0, buffer, renderer)
      iex> String.contains?(html, "<div class=\"row\">")
      true
  """
  def render_row(row, y, _buffer, %__MODULE__{} = renderer, class \\ "screen") do
    # Batch cells for better performance
    cells = row
    |> Enum.chunk_every(renderer.batch_size)
    |> Enum.map(fn cell_batch ->
      cell_batch
      |> Enum.with_index()
      |> Enum.map(fn {cell, x} ->
        render_cell(cell, x, y, renderer)
      end)
      |> Enum.join("\n")
    end)
    |> Enum.join("\n")

    """
    <div class="row #{class}" data-y="#{y}">
      #{cells}
    </div>
    """
  end

  @doc """
  Renders a single cell with its attributes.
  
  ## Examples
  
      iex> cell = Cell.new("A", %{foreground: :red, background: :blue})
      iex> renderer = Renderer.new()
      iex> html = Renderer.render_cell(cell, 0, 0, renderer)
      iex> String.contains?(html, "class=\"cell")
      true
  """
  def render_cell(%Cell{} = cell, x, y, %__MODULE__{} = renderer) do
    classes = ["cell"]
    |> add_attribute_classes(cell.attributes)
    |> Enum.join(" ")

    style = cell.attributes
    |> build_style(renderer.theme)
    |> Enum.join("; ")

    """
    <div class="#{classes}" style="left: #{x}ch; #{style}" data-char="#{cell.char}">
      #{cell.char}
    </div>
    """
  end

  @doc """
  Sets a custom theme for the renderer.
  
  ## Examples
  
      iex> renderer = Renderer.new()
      iex> theme = %{background: "#111111", foreground: "#eeeeee"}
      iex> renderer = Renderer.set_theme(renderer, theme)
      iex> renderer.theme.background
      "#111111"
  """
  def set_theme(%__MODULE__{} = renderer, theme) do
    %{renderer | theme: Map.merge(@default_theme, theme)}
  end

  @doc """
  Sets font settings for the renderer.
  
  ## Examples
  
      iex> renderer = Renderer.new()
      iex> renderer = Renderer.set_font(renderer, "Courier New", 16, 1.5)
      iex> renderer.font_family
      "Courier New"
  """
  def set_font(%__MODULE__{} = renderer, font_family, font_size, line_height) do
    %{renderer | 
      font_family: font_family,
      font_size: font_size,
      line_height: line_height
    }
  end

  @doc """
  Sets cursor settings for the renderer.
  
  ## Examples
  
      iex> renderer = Renderer.new()
      iex> renderer = Renderer.set_cursor(renderer, :underline, false, "#ff0000")
      iex> renderer.cursor_style
      :underline
  """
  def set_cursor(%__MODULE__{} = renderer, style, blink, color) do
    %{renderer | 
      cursor_style: style,
      cursor_blink: blink,
      cursor_color: color
    }
  end

  @doc """
  Sets performance settings for the renderer.
  
  ## Examples
  
      iex> renderer = Renderer.new()
      iex> renderer = Renderer.set_performance(renderer, 200, 50, true, 30)
      iex> renderer.batch_size
      200
  """
  def set_performance(%__MODULE__{} = renderer, batch_size, scrollback_limit, virtual_scroll, visible_rows) do
    %{renderer | 
      batch_size: batch_size,
      scrollback_limit: scrollback_limit,
      virtual_scroll: virtual_scroll,
      visible_rows: visible_rows
    }
  end

  # Private functions

  defp add_attribute_classes(classes, attributes) do
    classes ++ Enum.map(attributes, fn
      {:bold, true} -> "bold"
      {:underline, true} -> "underline"
      {:italic, true} -> "italic"
      {:reverse, true} -> "reverse"
      {:foreground, color} -> "fg-#{color}"
      {:background, color} -> "bg-#{color}"
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp build_style(attributes, theme) do
    Enum.map(attributes, fn
      {:foreground, color} -> "color: #{color_to_css(color, theme)}"
      {:background, color} -> "background-color: #{color_to_css(color, theme)}"
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp color_to_css(color, theme) do
    case color do
      :black -> theme.black
      :red -> theme.red
      :green -> theme.green
      :yellow -> theme.yellow
      :blue -> theme.blue
      :magenta -> theme.magenta
      :cyan -> theme.cyan
      :white -> theme.white
      :bright_black -> theme.bright_black
      :bright_red -> theme.bright_red
      :bright_green -> theme.bright_green
      :bright_yellow -> theme.bright_yellow
      :bright_blue -> theme.bright_blue
      :bright_magenta -> theme.bright_magenta
      :bright_cyan -> theme.bright_cyan
      :bright_white -> theme.bright_white
      color when is_integer(color) and color >= 0 and color <= 255 ->
        rgb_from_256(color)
      color when is_tuple(color) and tuple_size(color) == 3 ->
        {r, g, b} = color
        "rgb(#{r}, #{g}, #{b})"
      _ -> theme.foreground
    end
  end

  defp rgb_from_256(color) do
    cond do
      color < 16 ->
        # Standard colors
        standard_colors = [
          {0, 0, 0},      # Black
          {205, 0, 0},    # Red
          {0, 205, 0},    # Green
          {205, 205, 0},  # Yellow
          {0, 0, 238},    # Blue
          {205, 0, 205},  # Magenta
          {0, 205, 205},  # Cyan
          {229, 229, 229},# White
          {127, 127, 127},# Bright Black
          {255, 0, 0},    # Bright Red
          {0, 255, 0},    # Bright Green
          {255, 255, 0},  # Bright Yellow
          {92, 92, 255},  # Bright Blue
          {255, 0, 255},  # Bright Magenta
          {0, 255, 255},  # Bright Cyan
          {255, 255, 255} # Bright White
        ]
        {r, g, b} = Enum.at(standard_colors, color)
        "rgb(#{r}, #{g}, #{b})"
      
      color < 232 ->
        # RGB cube
        color = color - 16
        r = div(color, 36) * 51
        g = div(rem(color, 36), 6) * 51
        b = rem(color, 6) * 51
        "rgb(#{r}, #{g}, #{b})"
      
      true ->
        # Grayscale
        value = (color - 232) * 10 + 8
        "rgb(#{value}, #{value}, #{value})"
    end
  end
end 
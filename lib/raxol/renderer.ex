defmodule Raxol.Renderer do
  @moduledoc """
  The Renderer module handles drawing UI elements to the terminal.

  This module translates the virtual DOM representation of the UI
  into actual terminal output using ex_termbox.
  """

  use GenServer

  alias Raxol.Renderer.Layout

  # Client API

  @doc """
  Starts a new renderer process.

  ## Options

  * `:fps` - Target frames per second (default: 60)
  * `:debug` - Enable debug mode (default: false)
  """
  def start_link(options \\ %{}) do
    GenServer.start_link(__MODULE__, options)
  end

  @doc """
  Renders a view to the terminal.
  """
  def render(pid, view) do
    GenServer.cast(pid, {:render, view})
  end

  # Server callbacks

  @impl true
  def init(options) do
    state = %{
      fps: Map.get(options, :fps, 60),
      debug: Map.get(options, :debug, false),
      last_render: nil,
      render_count: 0,
      last_dimensions: get_terminal_dimensions()
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:render, view}, state) do
    # Get current terminal dimensions
    dimensions = get_terminal_dimensions()

    # Only re-render if something changed
    should_render =
      state.last_render != view ||
      state.last_dimensions != dimensions

    if should_render do
      # Clear the screen
      :ex_termbox.clear()

      # Render the view using the dimensions
      render_view(view, dimensions)

      # Present the changes to the terminal
      :ex_termbox.present()

      # Update render stats
      state = %{
        state |
        last_render: view,
        render_count: state.render_count + 1,
        last_dimensions: dimensions
      }

      # Print debug info if enabled
      if state.debug do
        IO.puts("Rendered frame ##{state.render_count}")
      end

      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  # Private functions

  defp get_terminal_dimensions do
    {:width, width, :height, height} = :ex_termbox.info()
    %{width: width, height: height}
  end

  defp render_view(view, dimensions) do
    # Apply layouts to get absolute positions
    positioned_elements = Layout.apply_layout(view, dimensions)

    # Draw each element at its calculated position
    Enum.each(positioned_elements, &draw_element/1)
  end

  defp draw_element(%{type: :text, x: x, y: y, text: text, attrs: attrs}) do
    # Parse colors
    fg = parse_color(attrs.fg)
    bg = parse_color(attrs.bg)

    # Apply styling if present
    {text, fg, bg} = apply_styling(text, fg, bg, attrs)

    # Draw the text
    :ex_termbox.put_string(x, y, text, fg, bg)
  end

  defp draw_element(%{type: :box, x: x, y: y, width: w, height: h, attrs: attrs}) do
    # Parse colors
    fg = parse_color(attrs.fg)
    bg = parse_color(attrs.bg)

    # Get border style
    border_style = Map.get(attrs, :border_style, :normal)
    {h_char, v_char, tl_char, tr_char, bl_char, br_char} = get_border_chars(border_style)

    # Draw horizontal lines (top and bottom)
    for dx <- 0..(w-1) do
      :ex_termbox.put_cell(x + dx, y, h_char, fg, bg) # Top
      :ex_termbox.put_cell(x + dx, y + h - 1, h_char, fg, bg) # Bottom
    end

    # Draw vertical lines (left and right)
    for dy <- 0..(h-1) do
      :ex_termbox.put_cell(x, y + dy, v_char, fg, bg) # Left
      :ex_termbox.put_cell(x + w - 1, y + dy, v_char, fg, bg) # Right
    end

    # Draw corners
    :ex_termbox.put_cell(x, y, tl_char, fg, bg) # Top-left
    :ex_termbox.put_cell(x + w - 1, y, tr_char, fg, bg) # Top-right
    :ex_termbox.put_cell(x, y + h - 1, bl_char, fg, bg) # Bottom-left
    :ex_termbox.put_cell(x + w - 1, y + h - 1, br_char, fg, bg) # Bottom-right

    # Fill the box if needed
    fill = Map.get(attrs, :fill, true)
    if fill do
      for dy <- 1..(h-2), dx <- 1..(w-2) do
        :ex_termbox.put_cell(x + dx, y + dy, ?\s, fg, bg)
      end
    end
  end

  # defp draw_element(%{type: :styled_element, style: style, content: content}) do
  #   # Handle styled elements (typically from Raxol.Style.render/2)
  #   # This is a placeholder - full implementation would need to convert
  #   # the style to positioned elements
  #   draw_element(%{
  #     type: :text,
  #     x: 0,
  #     y: 0,
  #     text: content,
  #     attrs: %{
  #       fg: Map.get(style, :color, :white),
  #       bg: Map.get(style, :background, :black),
  #       bold: Map.get(style, :bold, false),
  #       italic: Map.get(style, :italic, false),
  #       underline: Map.get(style, :underline, false)
  #     }
  #   })
  # end

  defp draw_element(_) do
    # Ignore unsupported elements
  end

  defp apply_styling(text, fg, bg, attrs) do
    # Apply text styling (bold, italic, underline)
    # Note: actual support depends on the terminal
    text =
      cond do
        Map.get(attrs, :bold, false) -> "\e[1m#{text}\e[22m"
        Map.get(attrs, :italic, false) -> "\e[3m#{text}\e[23m"
        Map.get(attrs, :underline, false) -> "\e[4m#{text}\e[24m"
        true -> text
      end

    {text, fg, bg}
  end

  defp get_border_chars(:normal), do: {?─, ?│, ?┌, ?┐, ?└, ?┘}
  defp get_border_chars(:thick), do: {?━, ?┃, ?┏, ?┓, ?┗, ?┛}
  defp get_border_chars(:double), do: {?═, ?║, ?╔, ?╗, ?╚, ?╝}
  defp get_border_chars(:rounded), do: {?─, ?│, ?╭, ?╮, ?╰, ?╯}
  defp get_border_chars(_), do: {?─, ?│, ?┌, ?┐, ?└, ?┘}

  defp parse_color(:default), do: -1 # Terminal default
  defp parse_color(:black), do: 0
  defp parse_color(:red), do: 1
  defp parse_color(:green), do: 2
  defp parse_color(:yellow), do: 3
  defp parse_color(:blue), do: 4
  defp parse_color(:magenta), do: 5
  defp parse_color(:cyan), do: 6
  defp parse_color(:white), do: 7
  defp parse_color(:light_black), do: 8
  defp parse_color(:light_red), do: 9
  defp parse_color(:light_green), do: 10
  defp parse_color(:light_yellow), do: 11
  defp parse_color(:light_blue), do: 12
  defp parse_color(:light_magenta), do: 13
  defp parse_color(:light_cyan), do: 14
  defp parse_color(:light_white), do: 15
  defp parse_color(:gray), do: 8
  defp parse_color(:dark_gray), do: 8
  defp parse_color(n) when is_integer(n), do: n
  defp parse_color(_), do: -1 # Default
end
